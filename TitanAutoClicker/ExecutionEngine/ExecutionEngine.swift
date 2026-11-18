import Foundation
import Observation

/// Deterministic, MainActor-isolated Swift 6 execution engine for in-app preview automation.
///
/// Concurrency guarantees:
/// - All state transitions serialize on `@MainActor`; no duplicate execution sessions can overlap.
/// - Every session allocates a monotonic `runId`; stale task completions/events are discarded.
/// - `Task.sleep(for:)` yields the MainActor between steps so iPadOS UI stays responsive.
/// - Explicit `pause()`, `resume()`, and `stop(reason:)` transition cleanly with guaranteed cleanup.
/// - Strictly in-app preview execution only (no cross-app touch injection; see `PlatformLimitationItem`).
@MainActor
@Observable
public final class ExecutionEngine {
    public private(set) var state: ExecutionState = .idle
    public private(set) var completedCycles: Int = 0
    public private(set) var dispatchedStepCount: Int = 0
    public private(set) var elapsedSeconds: TimeInterval = 0
    public private(set) var activeTargetId: UUID?
    public private(set) var lastEvent: ExecutionEvent?
    public private(set) var recentEvents: [ExecutionEvent] = []

    private var latestRunId: UInt64 = 0
    private var executionTask: Task<Void, Never>?
    private var elapsedTickerTask: Task<Void, Never>?
    private var stopDeadlineTask: Task<Void, Never>?
    private var pauseContinuation: CheckedContinuation<Void, Never>?
    private var pendingStopReason: CompletionReason?
    private var runStartDate: Date?
    private var accumulatedActiveSeconds: TimeInterval = 0
    private var remainingTimeLimitSeconds: TimeInterval?
    private var hasStartedActiveExecution: Bool = false

    public init() {}

    /// Starts a new deterministic execution session if currently inactive.
    /// Returns `true` if started, `false` if a session is already active or targets are empty.
    @discardableResult
    public func start(
        configuration: AutomationConfiguration,
        onEvent: (@MainActor (ExecutionEvent) -> Void)? = nil
    ) -> Bool {
        guard !state.isActive else { return false }

        let targets = configuration.activeTargets
        guard !targets.isEmpty else {
            let failedRunId = allocateRunId()
            state = .failed(runId: failedRunId, message: "Add at least one target before starting execution.")
            return false
        }

        let runId = allocateRunId()
        let settings = configuration.settings.validated()

        resetMetrics()
        pendingStopReason = nil
        hasStartedActiveExecution = false
        state = .running(runId: runId)

        if case .duration(let seconds) = settings.stopCondition {
            remainingTimeLimitSeconds = TimeInterval(seconds)
        } else {
            remainingTimeLimitSeconds = nil
        }

        if settings.startDelayMs == 0 {
            beginActiveExecutionPhase(runId: runId)
        }

        executionTask = Task { [weak self] in
            guard let self else { return }
            await self.runSession(
                runId: runId,
                mode: configuration.mode,
                targets: targets,
                settings: settings,
                onEvent: onEvent
            )
        }
        return true
    }

    public func pause() {
        guard case .running(let runId) = state, runId == latestRunId else { return }
        if hasStartedActiveExecution, let start = runStartDate {
            let delta = max(0, Date().timeIntervalSince(start))
            accumulatedActiveSeconds += delta
            elapsedSeconds = accumulatedActiveSeconds
            if let remaining = remainingTimeLimitSeconds {
                remainingTimeLimitSeconds = max(0, remaining - delta)
            }
            runStartDate = nil
        }
        stopDeadlineTask?.cancel()
        stopDeadlineTask = nil
        state = .paused(runId: runId)
    }

    public func resume() {
        guard case .paused(let runId) = state, runId == latestRunId else { return }
        state = .running(runId: runId)
        if hasStartedActiveExecution {
            runStartDate = Date()
            if let remaining = remainingTimeLimitSeconds {
                if remaining <= 0 {
                    stop(reason: .timeLimitReached)
                    return
                }
                scheduleDurationDeadline(runId: runId, seconds: remaining)
            }
        }
        let continuation = pauseContinuation
        pauseContinuation = nil
        continuation?.resume()
    }

    public func stop(reason: CompletionReason = .userStopped) {
        guard let runId = state.activeRunId, state.isActive, runId == latestRunId else { return }
        if pendingStopReason == nil || reason == .lifecycleSuspended {
            pendingStopReason = reason
        }
        state = .stopping(runId: runId)
        stopDeadlineTask?.cancel()
        stopDeadlineTask = nil
        elapsedTickerTask?.cancel()
        elapsedTickerTask = nil

        let continuation = pauseContinuation
        pauseContinuation = nil
        continuation?.resume()

        executionTask?.cancel()
    }

    public func resetToIdle() {
        guard !state.isActive else { return }
        state = .idle
        activeTargetId = nil
    }

    // MARK: - Private Execution Loop

    private func allocateRunId() -> UInt64 {
        latestRunId &+= 1
        if latestRunId == 0 { latestRunId = 1 }
        return latestRunId
    }

    private func resetMetrics() {
        completedCycles = 0
        dispatchedStepCount = 0
        elapsedSeconds = 0
        accumulatedActiveSeconds = 0
        activeTargetId = nil
        lastEvent = nil
        recentEvents.removeAll(keepingCapacity: true)
    }

    private func startElapsedTicker(runId: UInt64) {
        elapsedTickerTask?.cancel()
        elapsedTickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, self.latestRunId == runId, self.state.isActive else { break }
                if case .running = self.state, let start = self.runStartDate {
                    self.elapsedSeconds = self.accumulatedActiveSeconds + Date().timeIntervalSince(start)
                }
            }
        }
    }

    private func beginActiveExecutionPhase(runId: UInt64) {
        guard !hasStartedActiveExecution, latestRunId == runId, case .running = state else { return }
        hasStartedActiveExecution = true
        runStartDate = Date()
        startElapsedTicker(runId: runId)
        if let remaining = remainingTimeLimitSeconds {
            if remaining <= 0 {
                stop(reason: .timeLimitReached)
                return
            }
            scheduleDurationDeadline(runId: runId, seconds: remaining)
        }
    }

    private func scheduleDurationDeadline(runId: UInt64, seconds: TimeInterval) {
        stopDeadlineTask?.cancel()
        let finiteSeconds = seconds.isFinite ? seconds : TimeInterval(ValidationBounds.maxStopDurationSeconds)
        let clampedMs = Int64(max(1, (finiteSeconds * 1_000).rounded()))
        stopDeadlineTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(clampedMs))
                guard let self, self.latestRunId == runId, case .running = self.state else { return }
                self.stop(reason: .timeLimitReached)
            } catch {
                // Cancelled cleanly on pause or stop.
            }
        }
    }

    private func waitIfPaused(runId: UInt64) async -> Bool {
        while case .paused(let activeId) = state, activeId == runId, !Task.isCancelled {
            await withCheckedContinuation { continuation in
                self.pauseContinuation = continuation
            }
        }
        return !Task.isCancelled && latestRunId == runId && state.isRunning
    }

    /// Sleeps for `milliseconds` of active (non-paused) execution time in small slices so
    /// `pause()` suspends promptly and preserves remaining wait budget until `resume()`.
    private func sleepRespectingPause(milliseconds: Int64, runId: UInt64) async -> Bool {
        var remainingMs = max(0, milliseconds)
        let sliceMs: Int64 = 50
        while remainingMs > 0 {
            if !(await waitIfPaused(runId: runId)) { return false }
            let stepMs = min(remainingMs, sliceMs)
            let sliceStart = ContinuousClock.now
            do {
                try await Task.sleep(for: .milliseconds(stepMs))
            } catch {
                return false
            }
            guard !Task.isCancelled, latestRunId == runId else { return false }
            let elapsed = sliceStart.duration(to: .now)
            let elapsedMs = Int64(elapsed.components.seconds) * 1_000
                + elapsed.components.attoseconds / 1_000_000_000_000_000
            remainingMs = max(0, remainingMs - max(1, elapsedMs))
            if !(await waitIfPaused(runId: runId)) { return false }
        }
        return await waitIfPaused(runId: runId)
    }

    private func runSession(
        runId: UInt64,
        mode: AutomationMode,
        targets: [TargetPoint],
        settings: ExecutionSettings,
        onEvent: (@MainActor (ExecutionEvent) -> Void)?
    ) async {
        var finalReason: CompletionReason = .userStopped
        defer {
            if latestRunId == runId {
                stopDeadlineTask?.cancel()
                stopDeadlineTask = nil
                elapsedTickerTask?.cancel()
                elapsedTickerTask = nil
                executionTask = nil
                activeTargetId = nil
                if hasStartedActiveExecution, let start = runStartDate {
                    accumulatedActiveSeconds += max(0, Date().timeIntervalSince(start))
                    elapsedSeconds = accumulatedActiveSeconds
                    runStartDate = nil
                }
                hasStartedActiveExecution = false
                let resolvedReason = pendingStopReason ?? finalReason
                pendingStopReason = nil
                if case .failed = state {
                    // Preserve explicit failure state.
                } else {
                    state = .completed(runId: runId, reason: resolvedReason)
                }
            }
        }

        // Initial start delay (does not consume duration stop-condition budget)
        if settings.startDelayMs > 0 {
            if !(await sleepRespectingPause(milliseconds: Int64(settings.startDelayMs), runId: runId)) {
                return
            }
        }

        beginActiveExecutionPhase(runId: runId)
        guard !Task.isCancelled, latestRunId == runId, state.isRunning else { return }

        var cycle = 0
        while !Task.isCancelled && latestRunId == runId {
            if !(await waitIfPaused(runId: runId)) { return }

            for (index, target) in targets.enumerated() {
                let repeats = max(1, target.repeatCount)
                for _ in 0..<repeats {
                    if !(await waitIfPaused(runId: runId)) { return }

                    let resolvedStart = applyOptionalJitter(
                        target.startPoint,
                        enabled: settings.randomizePositionOffset
                    )
                    let resolvedEnd = target.endPoint.map {
                        applyOptionalJitter($0, enabled: settings.randomizePositionOffset)
                    }

                    activeTargetId = target.id
                    dispatchedStepCount += 1

                    let event = ExecutionEvent(
                        runId: runId,
                        targetId: target.id,
                        targetLabel: target.label,
                        kind: target.kind,
                        point: resolvedStart,
                        endPoint: resolvedEnd,
                        durationMs: target.durationMs,
                        cycleIndex: cycle + 1,
                        stepIndex: index + 1
                    )
                    lastEvent = event
                    recentEvents.insert(event, at: 0)
                    if recentEvents.count > 40 {
                        recentEvents.removeLast(recentEvents.count - 40)
                    }
                    onEvent?(event)

                    // Wait gesture duration + step delay (overflow-safe Int64, pause-aware)
                    let stepDelayMs: Int64 = (mode == .singleTarget)
                        ? settings.defaultIntervalMilliseconds
                        : target.delayMilliseconds
                    let totalWaitMs = min(
                        Int64(target.durationMs) + stepDelayMs,
                        ValidationBounds.maxDelayMilliseconds
                    )
                    if !(await sleepRespectingPause(milliseconds: max(1, totalWaitMs), runId: runId)) {
                        return
                    }
                }
            }

            if !(await waitIfPaused(runId: runId)) { return }
            cycle += 1
            completedCycles = cycle

            if case .cycles(let targetCycles) = settings.stopCondition, cycle >= targetCycles {
                finalReason = .cyclesReached
                return
            }
        }
    }

    private func applyOptionalJitter(_ point: NormalizedPoint, enabled: Bool) -> NormalizedPoint {
        guard enabled else { return point }
        let dx = Double.random(in: -0.015...0.015)
        let dy = Double.random(in: -0.015...0.015)
        return NormalizedPoint(x: point.x + dx, y: point.y + dy)
    }
}
