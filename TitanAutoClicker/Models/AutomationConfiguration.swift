import Foundation

public enum AutomationMode: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case singleTarget
    case multiTarget

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .singleTarget: return "Single Target"
        case .multiTarget: return "Multi Target"
        }
    }

    public var subtitle: String {
        switch self {
        case .singleTarget: return "Repeats one focal tap point at a fixed interval."
        case .multiTarget: return "Executes an ordered sequence of taps and swipes."
        }
    }

    public var systemImage: String {
        switch self {
        case .singleTarget: return "scope"
        case .multiTarget: return "point.3.connected.trianglepath.dotted"
        }
    }
}

public struct AutomationConfiguration: Identifiable, Codable, Equatable, Hashable, Sendable {
    public static let currentSchemaVersion: Int = 1

    public var schemaVersion: Int
    public var id: UUID
    public var name: String
    public var mode: AutomationMode
    public var targets: [TargetPoint]
    public var settings: ExecutionSettings
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = AutomationConfiguration.currentSchemaVersion,
        id: UUID = UUID(),
        name: String,
        mode: AutomationMode = .multiTarget,
        targets: [TargetPoint] = [],
        settings: ExecutionSettings = ExecutionSettings(),
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = trimmed.isEmpty ? "Untitled Profile" : String(trimmed.prefix(ValidationBounds.maxConfigurationNameLength))
        self.mode = mode
        self.targets = Array(targets.prefix(ValidationBounds.maxTargetsPerConfiguration))
        self.settings = settings.validated()
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Targets eligible for execution in the currently selected mode.
    public var activeTargets: [TargetPoint] {
        switch mode {
        case .singleTarget:
            if let firstTap = targets.first(where: { $0.kind == .tap }) {
                return [firstTap]
            }
            return targets.first.map { [$0] } ?? []
        case .multiTarget:
            return targets
        }
    }

    public static func sampleDefault() -> AutomationConfiguration {
        AutomationConfiguration(
            name: "Starter Sequence",
            mode: .multiTarget,
            targets: [
                TargetPoint(
                    label: "Primary Tap",
                    kind: .tap,
                    startPoint: NormalizedPoint(x: 0.32, y: 0.42),
                    delayValue: 400,
                    delayUnit: .milliseconds,
                    durationMs: 60,
                    repeatCount: 1
                ),
                TargetPoint(
                    label: "Secondary Tap",
                    kind: .tap,
                    startPoint: NormalizedPoint(x: 0.66, y: 0.36),
                    delayValue: 500,
                    delayUnit: .milliseconds,
                    durationMs: 60,
                    repeatCount: 2
                ),
                TargetPoint(
                    label: "Horizontal Swipe",
                    kind: .swipe,
                    startPoint: NormalizedPoint(x: 0.25, y: 0.72),
                    endPoint: NormalizedPoint(x: 0.75, y: 0.72),
                    delayValue: 600,
                    delayUnit: .milliseconds,
                    durationMs: 450,
                    repeatCount: 1
                )
            ],
            settings: ExecutionSettings(
                startDelayMs: 500,
                defaultIntervalValue: 400,
                defaultIntervalUnit: .milliseconds,
                stopCondition: .cycles(count: 5),
                randomizePositionOffset: false
            )
        )
    }
}
