import Foundation

/// Normalized 2D point in [0.0, 1.0] coordinates so targets scale cleanly across
/// iPad portrait/landscape orientations and Split View window sizes.
public struct NormalizedPoint: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = ValidationBounds.clampNormalized(x)
        self.y = ValidationBounds.clampNormalized(y)
    }

    public func validated() -> NormalizedPoint {
        NormalizedPoint(x: x, y: y)
    }
}

public enum TargetKind: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case tap
    case swipe

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .tap: return "Tap"
        case .swipe: return "Swipe"
        }
    }

    public var systemImage: String {
        switch self {
        case .tap: return "hand.tap.fill"
        case .swipe: return "hand.draw.fill"
        }
    }
}

/// Represents either a single tap target or a directional swipe gesture target
/// within Titan's interactive in-app preview canvas.
public struct TargetPoint: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var label: String
    public var kind: TargetKind
    public var startPoint: NormalizedPoint
    public var endPoint: NormalizedPoint?
    public var delayValue: Int
    public var delayUnit: TimeUnit
    public var durationMs: Int
    public var repeatCount: Int

    public init(
        id: UUID = UUID(),
        label: String,
        kind: TargetKind = .tap,
        startPoint: NormalizedPoint,
        endPoint: NormalizedPoint? = nil,
        delayValue: Int = 300,
        delayUnit: TimeUnit = .milliseconds,
        durationMs: Int? = nil,
        repeatCount: Int = 1
    ) {
        self.id = id
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.label = trimmedLabel.isEmpty ? (kind == .swipe ? "Swipe" : "Tap") : String(trimmedLabel.prefix(40))
        self.kind = kind
        let clampedStart = startPoint.validated()
        self.startPoint = clampedStart
        if kind == .swipe {
            let resolvedEnd = endPoint ?? Self.defaultSwipeEndPoint(from: clampedStart)
            self.endPoint = resolvedEnd.validated()
            self.durationMs = ValidationBounds.clampSwipeDuration(durationMs ?? 350)
        } else {
            self.endPoint = nil
            self.durationMs = ValidationBounds.clampTapDuration(durationMs ?? 50)
        }
        self.delayValue = ValidationBounds.clampDelayValue(delayValue, unit: delayUnit)
        self.delayUnit = delayUnit
        self.repeatCount = ValidationBounds.clampRepeatCount(repeatCount)
    }

    public static func defaultSwipeEndPoint(from start: NormalizedPoint) -> NormalizedPoint {
        let clampedStart = start.validated()
        let endX = clampedStart.x <= 0.75
            ? clampedStart.x + 0.2
            : max(clampedStart.x - 0.2, 0.05)
        return NormalizedPoint(x: endX, y: clampedStart.y)
    }

    public var delayMilliseconds: Int64 {
        ValidationBounds.delayMilliseconds(value: delayValue, unit: delayUnit)
    }

    public func validated(fallbackLabel: String) -> TargetPoint {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let clampedStart = startPoint.validated()
        return TargetPoint(
            id: id,
            label: trimmedLabel.isEmpty ? fallbackLabel : String(trimmedLabel.prefix(40)),
            kind: kind,
            startPoint: clampedStart,
            endPoint: kind == .swipe ? (endPoint ?? Self.defaultSwipeEndPoint(from: clampedStart)).validated() : nil,
            delayValue: delayValue,
            delayUnit: delayUnit,
            durationMs: durationMs,
            repeatCount: repeatCount
        )
    }
}
