import Foundation

public enum StopCondition: Codable, Equatable, Hashable, Sendable {
    case indefinite
    case duration(seconds: Int)
    case cycles(count: Int)

    public enum Kind: String, CaseIterable, Identifiable, Sendable {
        case indefinite
        case duration
        case cycles

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .indefinite: return "Run Indefinitely"
            case .duration: return "Stop After Time"
            case .cycles: return "Stop After Cycles"
            }
        }
    }

    public var kind: Kind {
        switch self {
        case .indefinite: return .indefinite
        case .duration: return .duration
        case .cycles: return .cycles
        }
    }

    public var summaryText: String {
        switch self {
        case .indefinite:
            return "Manual stop"
        case .duration(let seconds):
            let mins = seconds / 60
            let rem = seconds % 60
            return mins > 0 ? "\(mins)m \(rem)s limit" : "\(seconds)s limit"
        case .cycles(let count):
            return "\(count) \(count == 1 ? "cycle" : "cycles")"
        }
    }

    public func validated() -> StopCondition {
        switch self {
        case .indefinite:
            return .indefinite
        case .duration(let seconds):
            return .duration(seconds: ValidationBounds.clampStopDurationSeconds(seconds))
        case .cycles(let count):
            return .cycles(count: ValidationBounds.clampCycles(count))
        }
    }
}
