import Foundation
import CoreGraphics

/// Maps normalized [0.0, 1.0] target coordinates to and from the live iPadOS canvas geometry.
/// Strictly operates inside Titan's own interactive preview canvas (no private APIs or external touch injection).
public enum PreviewInteractionService: Sendable {
    private static func safeDimension(_ value: CGFloat) -> CGFloat {
        (value.isFinite && value > 0) ? value : 1
    }

    public static func canvasPoint(from normalized: NormalizedPoint, in size: CGSize) -> CGPoint {
        let clamped = normalized.validated()
        return CGPoint(
            x: clamped.x * safeDimension(size.width),
            y: clamped.y * safeDimension(size.height)
        )
    }

    public static func normalizedPoint(from location: CGPoint, in size: CGSize) -> NormalizedPoint {
        let safeW = safeDimension(size.width)
        let safeH = safeDimension(size.height)
        return NormalizedPoint(
            x: Double(location.x / safeW),
            y: Double(location.y / safeH)
        )
    }

    public static func formattedCoordinates(_ point: NormalizedPoint, in size: CGSize) -> String {
        let clamped = point.validated()
        let safeW = safeDimension(size.width)
        let safeH = safeDimension(size.height)
        let px = Int((clamped.x * Double(safeW)).rounded())
        let py = Int((clamped.y * Double(safeH)).rounded())
        return "(\(px), \(py)) pt"
    }
}
