import Foundation

public struct ExecutionSettings: Codable, Equatable, Hashable, Sendable {
    public var startDelayMs: Int
    public var defaultIntervalValue: Int
    public var defaultIntervalUnit: TimeUnit
    public var stopCondition: StopCondition
    public var randomizePositionOffset: Bool

    public init(
        startDelayMs: Int = 500,
        defaultIntervalValue: Int = 300,
        defaultIntervalUnit: TimeUnit = .milliseconds,
        stopCondition: StopCondition = .cycles(count: 10),
        randomizePositionOffset: Bool = false
    ) {
        self.startDelayMs = ValidationBounds.clampStartDelayMs(startDelayMs)
        self.defaultIntervalValue = ValidationBounds.clampDelayValue(defaultIntervalValue, unit: defaultIntervalUnit)
        self.defaultIntervalUnit = defaultIntervalUnit
        self.stopCondition = stopCondition.validated()
        self.randomizePositionOffset = randomizePositionOffset
    }

    public var defaultIntervalMilliseconds: Int64 {
        ValidationBounds.delayMilliseconds(value: defaultIntervalValue, unit: defaultIntervalUnit)
    }

    public func validated() -> ExecutionSettings {
        ExecutionSettings(
            startDelayMs: startDelayMs,
            defaultIntervalValue: defaultIntervalValue,
            defaultIntervalUnit: defaultIntervalUnit,
            stopCondition: stopCondition.validated(),
            randomizePositionOffset: randomizePositionOffset
        )
    }
}
