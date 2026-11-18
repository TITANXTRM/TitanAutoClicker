import Foundation

public enum CompletionReason: String, Equatable, Hashable, Sendable {
    case cyclesReached
    case timeLimitReached
    case userStopped
    case lifecycleSuspended

    public var displayText: String {
        switch self {
        case .cyclesReached: return "Cycle target reached"
        case .timeLimitReached: return "Time limit reached"
        case .userStopped: return "Stopped by user"
        case .lifecycleSuspended: return "Stopped on background transition"
        }
    }
}

/// Deterministic execution lifecycle state machine.
/// Every active state carries a monotonic `runId` to guarantee stale async callbacks are rejected.
public enum ExecutionState: Equatable, Hashable, Sendable {
    case idle
    case running(runId: UInt64)
    case paused(runId: UInt64)
    case stopping(runId: UInt64)
    case completed(runId: UInt64, reason: CompletionReason)
    case failed(runId: UInt64, message: String)

    public var isActive: Bool {
        switch self {
        case .running, .paused, .stopping:
            return true
        case .idle, .completed, .failed:
            return false
        }
    }

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    public var activeRunId: UInt64? {
        switch self {
        case .running(let id), .paused(let id), .stopping(let id):
            return id
        case .idle, .completed, .failed:
            return nil
        }
    }

    public var runId: UInt64? {
        switch self {
        case .running(let id), .paused(let id), .stopping(let id),
             .completed(let id, _), .failed(let id, _):
            return id
        case .idle:
            return nil
        }
    }

    public var badgeTitle: String {
        switch self {
        case .idle: return "Idle"
        case .running: return "Running"
        case .paused: return "Paused"
        case .stopping: return "Stopping"
        case .completed: return "Completed"
        case .failed: return "Error"
        }
    }
}
