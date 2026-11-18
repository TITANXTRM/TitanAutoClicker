import XCTest
@testable import TitanAutoClicker

@MainActor
final class ExecutionEngineTests: XCTestCase {
    private func waitUntil(
        timeoutSeconds: TimeInterval = 3.0,
        condition: @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(15))
        }
        return condition()
    }

    func testStartWithEmptyTargetsFailsCleanly() {
        let engine = ExecutionEngine()
        let emptyConfig = AutomationConfiguration(name: "Empty", mode: .multiTarget, targets: [])

        let started = engine.start(configuration: emptyConfig)
        XCTAssertFalse(started)
        guard case .failed(_, let message) = engine.state else {
            return XCTFail("Expected .failed state, got \(engine.state)")
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertFalse(engine.state.isActive)
    }

    func testDuplicateStartRejectedWhileActive() async {
        let engine = ExecutionEngine()
        let config = AutomationConfiguration(
            name: "Indefinite",
            mode: .multiTarget,
            targets: [
                TargetPoint(label: "Tap", kind: .tap, startPoint: NormalizedPoint(x: 0.5, y: 0.5), delayValue: 200, delayUnit: .milliseconds, durationMs: 20)
            ],
            settings: ExecutionSettings(startDelayMs: 0, stopCondition: .indefinite)
        )

        XCTAssertTrue(engine.start(configuration: config))
        XCTAssertFalse(engine.start(configuration: config), "Second start() while active must be rejected")

        engine.stop(reason: .userStopped)
        let stopped = await waitUntil { !engine.state.isActive }
        XCTAssertTrue(stopped)
    }

    func testCyclesStopConditionCompletesDeterministically() async {
        let engine = ExecutionEngine()
        var receivedEvents: [ExecutionEvent] = []
        let config = AutomationConfiguration(
            name: "Two Cycles",
            mode: .multiTarget,
            targets: [
                TargetPoint(label: "T1", kind: .tap, startPoint: NormalizedPoint(x: 0.3, y: 0.3), delayValue: 15, delayUnit: .milliseconds, durationMs: 10, repeatCount: 2),
                TargetPoint(label: "T2", kind: .tap, startPoint: NormalizedPoint(x: 0.7, y: 0.7), delayValue: 15, delayUnit: .milliseconds, durationMs: 10, repeatCount: 1)
            ],
            settings: ExecutionSettings(startDelayMs: 0, stopCondition: .cycles(count: 2))
        )

        XCTAssertTrue(engine.start(configuration: config) { event in
            receivedEvents.append(event)
        })

        let completed = await waitUntil {
            if case .completed(_, .cyclesReached) = engine.state { return true }
            return false
        }
        XCTAssertTrue(completed, "Engine should reach .completed(.cyclesReached), got \(engine.state)")
        XCTAssertEqual(engine.completedCycles, 2)
        XCTAssertEqual(engine.dispatchedStepCount, 6) // (2 + 1) steps * 2 cycles
        XCTAssertEqual(receivedEvents.count, 6)
        XCTAssertNil(engine.activeTargetId)
    }

    func testSingleTargetModeUsesFirstTapOnly() async {
        let engine = ExecutionEngine()
        let swipe = TargetPoint(label: "Swipe", kind: .swipe, startPoint: NormalizedPoint(x: 0.2, y: 0.2))
        let tap = TargetPoint(label: "Focal Tap", kind: .tap, startPoint: NormalizedPoint(x: 0.6, y: 0.6), delayValue: 5_000, delayUnit: .milliseconds, durationMs: 10)
        var eventTargetIds: [UUID] = []

        let config = AutomationConfiguration(
            name: "Single Mode",
            mode: .singleTarget,
            targets: [swipe, tap],
            settings: ExecutionSettings(
                startDelayMs: 0,
                defaultIntervalValue: 15,
                defaultIntervalUnit: .milliseconds,
                stopCondition: .cycles(count: 2)
            )
        )

        XCTAssertTrue(engine.start(configuration: config) { event in
            eventTargetIds.append(event.targetId)
        })

        let done = await waitUntil {
            if case .completed(_, .cyclesReached) = engine.state { return true }
            return false
        }
        XCTAssertTrue(done)
        XCTAssertEqual(eventTargetIds, [tap.id, tap.id])
    }

    func testPauseSuspendsSleepAndDoesNotAdvanceCyclesWhilePaused() async {
        let engine = ExecutionEngine()
        let config = AutomationConfiguration(
            name: "Pause Integrity",
            mode: .multiTarget,
            targets: [
                TargetPoint(
                    label: "Slow Step",
                    kind: .tap,
                    startPoint: NormalizedPoint(x: 0.5, y: 0.5),
                    delayValue: 200,
                    delayUnit: .milliseconds,
                    durationMs: 20
                )
            ],
            settings: ExecutionSettings(startDelayMs: 0, stopCondition: .cycles(count: 1))
        )

        XCTAssertTrue(engine.start(configuration: config))

        // Wait until first step dispatches, then pause mid-sleep.
        let dispatched = await waitUntil { engine.dispatchedStepCount == 1 }
        XCTAssertTrue(dispatched)

        engine.pause()
        XCTAssertTrue(engine.state.isPaused)
        let elapsedAtPause = engine.elapsedSeconds

        // Remain paused longer than the step sleep duration; cycle must NOT complete while paused.
        try? await Task.sleep(for: .milliseconds(320))
        XCTAssertTrue(engine.state.isPaused, "Engine must stay paused and not complete while paused")
        XCTAssertEqual(engine.completedCycles, 0)
        XCTAssertEqual(engine.elapsedSeconds, elapsedAtPause, accuracy: 0.001)

        // Resume and confirm completion happens cleanly afterward.
        engine.resume()
        let finished = await waitUntil {
            if case .completed(_, .cyclesReached) = engine.state { return true }
            return false
        }
        XCTAssertTrue(finished)
        XCTAssertEqual(engine.completedCycles, 1)
    }

    func testDurationStopConditionDoesNotConsumeStartDelay() async {
        let engine = ExecutionEngine()
        let config = AutomationConfiguration(
            name: "Start Delay + Duration",
            mode: .multiTarget,
            targets: [
                TargetPoint(label: "Fast Tap", kind: .tap, startPoint: NormalizedPoint(x: 0.5, y: 0.5), delayValue: 40, delayUnit: .milliseconds, durationMs: 10)
            ],
            settings: ExecutionSettings(
                startDelayMs: 250,
                stopCondition: .duration(seconds: 1)
            )
        )

        XCTAssertTrue(engine.start(configuration: config))
        let finished = await waitUntil(timeoutSeconds: 3.5) {
            if case .completed(_, .timeLimitReached) = engine.state { return true }
            return false
        }
        XCTAssertTrue(finished, "Expected .completed(.timeLimitReached), got \(engine.state)")
        XCTAssertGreaterThan(engine.dispatchedStepCount, 0, "Duration timer must start after startDelayMs so steps actually execute")
    }

    func testStopWhilePausedAndLifecycleSuspensionReason() async {
        let engine = ExecutionEngine()
        let config = AutomationConfiguration(
            name: "Stop Paused",
            mode: .multiTarget,
            targets: [
                TargetPoint(label: "Tap", kind: .tap, startPoint: NormalizedPoint(x: 0.5, y: 0.5), delayValue: 500, delayUnit: .milliseconds, durationMs: 20)
            ],
            settings: ExecutionSettings(startDelayMs: 0, stopCondition: .indefinite)
        )

        XCTAssertTrue(engine.start(configuration: config))
        let started = await waitUntil { engine.dispatchedStepCount == 1 }
        XCTAssertTrue(started)

        engine.pause()
        XCTAssertTrue(engine.state.isPaused)

        engine.stop(reason: .lifecycleSuspended)
        let done = await waitUntil {
            if case .completed(_, .lifecycleSuspended) = engine.state { return true }
            return false
        }
        XCTAssertTrue(done, "Stopping while paused must immediately wake continuation and report .lifecycleSuspended")
    }

    func testSequentialRunsAllocateMonotonicRunIds() async {
        let engine = ExecutionEngine()
        let config = AutomationConfiguration(
            name: "Quick",
            mode: .multiTarget,
            targets: [
                TargetPoint(label: "Tap", kind: .tap, startPoint: NormalizedPoint(x: 0.5, y: 0.5), delayValue: 10, delayUnit: .milliseconds, durationMs: 10)
            ],
            settings: ExecutionSettings(startDelayMs: 0, stopCondition: .cycles(count: 1))
        )

        XCTAssertTrue(engine.start(configuration: config))
        let firstId = engine.state.runId
        let done1 = await waitUntil { !engine.state.isActive }
        XCTAssertTrue(done1)

        XCTAssertTrue(engine.start(configuration: config))
        let secondId = engine.state.runId
        let done2 = await waitUntil { !engine.state.isActive }
        XCTAssertTrue(done2)

        XCTAssertNotNil(firstId)
        XCTAssertNotNil(secondId)
        if let firstId, let secondId {
            XCTAssertGreaterThan(secondId, firstId)
        }
    }
}
