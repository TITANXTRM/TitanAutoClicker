import Foundation

/// Centralized numeric and structural validation bounds for Titan Auto Clicker.
/// All arithmetic uses 64-bit integer clamping to eliminate 32-bit overflow hazards.
public enum ValidationBounds: Sendable {
    public static let minDelayValue: Int = 1
    public static let maxDelayMilliseconds: Int64 = 86_400_000 // 24 hours max per step
    public static let maxDelayValueForUnit: [TimeUnit: Int] = [
        .milliseconds: 86_400_000,
        .seconds: 86_400,
        .minutes: 1_440
    ]

    public static let minTapDurationMs: Int = 10
    public static let maxTapDurationMs: Int = 5_000

    public static let minSwipeDurationMs: Int = 100
    public static let maxSwipeDurationMs: Int = 60_000

    public static let minRepeatCount: Int = 1
    public static let maxRepeatCount: Int = 10_000

    public static let minCycles: Int = 1
    public static let maxCycles: Int = 1_000_000

    public static let minStopDurationSeconds: Int = 1
    public static let maxStopDurationSeconds: Int = 86_400 // 24 hours

    public static let minStartDelayMs: Int = 0
    public static let maxStartDelayMs: Int = 300_000 // 5 minutes

    public static let maxTargetsPerConfiguration: Int = 200
    public static let maxConfigurationNameLength: Int = 80
    public static let maxImportFileBytes: Int = 5 * 1024 * 1024 // 5 MB

    /// Normalized canvas coordinate bounds [0.0, 1.0].
    public static let minNormalizedCoord: Double = 0.0
    public static let maxNormalizedCoord: Double = 1.0

    public static func clampNormalized(_ value: Double) -> Double {
        guard value.isFinite else { return 0.5 }
        return min(max(value, minNormalizedCoord), maxNormalizedCoord)
    }

    public static func clampDelayValue(_ value: Int, unit: TimeUnit) -> Int {
        let upper = maxDelayValueForUnit[unit] ?? 86_400
        return min(max(value, minDelayValue), upper)
    }

    public static func delayMilliseconds(value: Int, unit: TimeUnit) -> Int64 {
        let clamped = Int64(clampDelayValue(value, unit: unit))
        let multiplied = clamped.multipliedReportingOverflow(by: unit.millisecondsMultiplier)
        if multiplied.overflow {
            return maxDelayMilliseconds
        }
        return min(max(multiplied.partialValue, 1), maxDelayMilliseconds)
    }

    public static func clampTapDuration(_ ms: Int) -> Int {
        min(max(ms, minTapDurationMs), maxTapDurationMs)
    }

    public static func clampSwipeDuration(_ ms: Int) -> Int {
        min(max(ms, minSwipeDurationMs), maxSwipeDurationMs)
    }

    public static func clampRepeatCount(_ count: Int) -> Int {
        min(max(count, minRepeatCount), maxRepeatCount)
    }

    public static func clampCycles(_ count: Int) -> Int {
        min(max(count, minCycles), maxCycles)
    }

    public static func clampStopDurationSeconds(_ seconds: Int) -> Int {
        min(max(seconds, minStopDurationSeconds), maxStopDurationSeconds)
    }

    public static func clampStartDelayMs(_ ms: Int) -> Int {
        min(max(ms, minStartDelayMs), maxStartDelayMs)
    }

    public static func parseIntBounded(
        _ raw: String,
        default defaultValue: Int,
        min minValue: Int,
        max maxValue: Int
    ) -> Int {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let parsed = Int64(trimmed) else {
            return defaultValue
        }
        let clamped = Swift.min(Swift.max(parsed, Int64(minValue)), Int64(maxValue))
        return Int(clamped)
    }
}
