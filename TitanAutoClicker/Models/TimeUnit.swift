import Foundation

public enum TimeUnit: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case milliseconds
    case seconds
    case minutes

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .milliseconds: return "ms"
        case .seconds: return "sec"
        case .minutes: return "min"
        }
    }

    public var longDisplayName: String {
        switch self {
        case .milliseconds: return "Milliseconds"
        case .seconds: return "Seconds"
        case .minutes: return "Minutes"
        }
    }

    public var millisecondsMultiplier: Int64 {
        switch self {
        case .milliseconds: return 1
        case .seconds: return 1_000
        case .minutes: return 60_000
        }
    }
}
