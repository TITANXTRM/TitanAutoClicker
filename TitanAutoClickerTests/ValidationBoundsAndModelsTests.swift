import CoreGraphics
import XCTest
@testable import TitanAutoClicker

final class ValidationBoundsAndModelsTests: XCTestCase {
    func testDelayMillisecondsOverflowSafety() {
        XCTAssertEqual(
            ValidationBounds.delayMilliseconds(value: Int.max, unit: .minutes),
            ValidationBounds.maxDelayMilliseconds
        )
        XCTAssertEqual(
            ValidationBounds.delayMilliseconds(value: Int.max, unit: .seconds),
            ValidationBounds.maxDelayMilliseconds
        )
        XCTAssertEqual(
            ValidationBounds.delayMilliseconds(value: Int.max, unit: .milliseconds),
            ValidationBounds.maxDelayMilliseconds
        )
        XCTAssertEqual(ValidationBounds.delayMilliseconds(value: -500, unit: .seconds), 1_000)
        XCTAssertEqual(ValidationBounds.delayMilliseconds(value: 0, unit: .milliseconds), 1)
        XCTAssertEqual(ValidationBounds.delayMilliseconds(value: 2, unit: .minutes), 120_000)
    }

    func testDurationRepeatCyclesAndStartDelayClamping() {
        XCTAssertEqual(ValidationBounds.clampTapDuration(0), ValidationBounds.minTapDurationMs)
        XCTAssertEqual(ValidationBounds.clampTapDuration(99_999), ValidationBounds.maxTapDurationMs)

        XCTAssertEqual(ValidationBounds.clampSwipeDuration(10), ValidationBounds.minSwipeDurationMs)
        XCTAssertEqual(ValidationBounds.clampSwipeDuration(500_000), ValidationBounds.maxSwipeDurationMs)

        XCTAssertEqual(ValidationBounds.clampRepeatCount(0), ValidationBounds.minRepeatCount)
        XCTAssertEqual(ValidationBounds.clampRepeatCount(999_999), ValidationBounds.maxRepeatCount)

        XCTAssertEqual(ValidationBounds.clampCycles(-10), ValidationBounds.minCycles)
        XCTAssertEqual(ValidationBounds.clampCycles(9_999_999), ValidationBounds.maxCycles)

        XCTAssertEqual(ValidationBounds.clampStopDurationSeconds(0), ValidationBounds.minStopDurationSeconds)
        XCTAssertEqual(ValidationBounds.clampStopDurationSeconds(999_999), ValidationBounds.maxStopDurationSeconds)

        XCTAssertEqual(ValidationBounds.clampStartDelayMs(-5), ValidationBounds.minStartDelayMs)
        XCTAssertEqual(ValidationBounds.clampStartDelayMs(999_999), ValidationBounds.maxStartDelayMs)
    }

    func testParseIntBounded() {
        XCTAssertEqual(ValidationBounds.parseIntBounded("  250 ", default: 10, min: 1, max: 1_000), 250)
        XCTAssertEqual(ValidationBounds.parseIntBounded("-99", default: 10, min: 1, max: 1_000), 1)
        XCTAssertEqual(ValidationBounds.parseIntBounded("999999999999", default: 10, min: 1, max: 1_000), 1_000)
        XCTAssertEqual(ValidationBounds.parseIntBounded("not-a-number", default: 42, min: 1, max: 1_000), 42)
        XCTAssertEqual(ValidationBounds.parseIntBounded("", default: 42, min: 1, max: 1_000), 42)
    }

    func testNormalizedPointClampingAndNonFiniteHandling() {
        let clampedLow = NormalizedPoint(x: -0.5, y: -100.0)
        XCTAssertEqual(clampedLow.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(clampedLow.y, 0.0, accuracy: 0.0001)

        let clampedHigh = NormalizedPoint(x: 1.5, y: 99.0)
        XCTAssertEqual(clampedHigh.x, 1.0, accuracy: 0.0001)
        XCTAssertEqual(clampedHigh.y, 1.0, accuracy: 0.0001)

        let nonFinite = NormalizedPoint(x: .nan, y: .infinity)
        XCTAssertEqual(nonFinite.x, 0.5, accuracy: 0.0001)
        XCTAssertEqual(nonFinite.y, 0.5, accuracy: 0.0001)
    }

    func testTargetPointSwipeDefaultEndpointAndSanitization() {
        // Near right edge: default swipe endPoint should move inward instead of collapsing to a zero-length vector.
        let rightEdgeSwipe = TargetPoint(
            label: "   Right Edge Swipe   ",
            kind: .swipe,
            startPoint: NormalizedPoint(x: 0.95, y: 0.4),
            endPoint: nil,
            durationMs: 20
        )
        XCTAssertEqual(rightEdgeSwipe.label, "Right Edge Swipe")
        XCTAssertEqual(rightEdgeSwipe.durationMs, ValidationBounds.minSwipeDurationMs)
        XCTAssertNotNil(rightEdgeSwipe.endPoint)
        if let end = rightEdgeSwipe.endPoint {
            XCTAssertEqual(end.x, 0.75, accuracy: 0.0001)
            XCTAssertEqual(end.y, 0.4, accuracy: 0.0001)
            XCTAssertNotEqual(end.x, rightEdgeSwipe.startPoint.x)
        }

        // Validated should derive missing swipe endpoint relative to startPoint and cap label to 40 chars.
        var mutable = TargetPoint(
            label: String(repeating: "A", count: 80),
            kind: .swipe,
            startPoint: NormalizedPoint(x: 0.2, y: 0.8),
            endPoint: nil
        )
        mutable.endPoint = nil
        let validated = mutable.validated(fallbackLabel: "Fallback")
        XCTAssertEqual(validated.label.count, 40)
        XCTAssertEqual(validated.endPoint?.x ?? -1, 0.4, accuracy: 0.0001)
        XCTAssertEqual(validated.endPoint?.y ?? -1, 0.8, accuracy: 0.0001)
    }

    func testPreviewInteractionServiceRoundTripAndNonFiniteSafety() {
        let size = CGSize(width: 800, height: 600)
        let original = NormalizedPoint(x: 0.25, y: 0.75)
        let canvasPt = PreviewInteractionService.canvasPoint(from: original, in: size)
        XCTAssertEqual(canvasPt.x, 200, accuracy: 0.001)
        XCTAssertEqual(canvasPt.y, 450, accuracy: 0.001)

        let roundTripped = PreviewInteractionService.normalizedPoint(from: canvasPt, in: size)
        XCTAssertEqual(roundTripped.x, 0.25, accuracy: 0.001)
        XCTAssertEqual(roundTripped.y, 0.75, accuracy: 0.001)

        // Degenerate or non-finite geometry must never trap.
        var badPoint = NormalizedPoint(x: 0.5, y: 0.5)
        badPoint.x = .nan
        let formatted = PreviewInteractionService.formattedCoordinates(badPoint, in: CGSize(width: CGFloat.infinity, height: 0))
        XCTAssertEqual(formatted, "(1, 1) pt")
    }

    func testAutomationConfigurationActiveTargetsByMode() {
        let swipe = TargetPoint(label: "Swipe 1", kind: .swipe, startPoint: NormalizedPoint(x: 0.2, y: 0.5))
        let tap = TargetPoint(label: "Tap 1", kind: .tap, startPoint: NormalizedPoint(x: 0.5, y: 0.5))

        let singlePrefersTap = AutomationConfiguration(
            name: "Single",
            mode: .singleTarget,
            targets: [swipe, tap]
        )
        XCTAssertEqual(singlePrefersTap.activeTargets.map(\.id), [tap.id])

        let singleFallsBackToSwipe = AutomationConfiguration(
            name: "Swipe Only",
            mode: .singleTarget,
            targets: [swipe]
        )
        XCTAssertEqual(singleFallsBackToSwipe.activeTargets.map(\.id), [swipe.id])

        let multi = AutomationConfiguration(
            name: "Multi",
            mode: .multiTarget,
            targets: [swipe, tap]
        )
        XCTAssertEqual(multi.activeTargets.map(\.id), [swipe.id, tap.id])
    }

    func testExecutionStateRunIdSemantics() {
        XCTAssertNil(ExecutionState.idle.activeRunId)
        XCTAssertNil(ExecutionState.idle.runId)

        let running = ExecutionState.running(runId: 7)
        XCTAssertTrue(running.isActive)
        XCTAssertEqual(running.activeRunId, 7)
        XCTAssertEqual(running.runId, 7)

        let completed = ExecutionState.completed(runId: 7, reason: .cyclesReached)
        XCTAssertFalse(completed.isActive)
        XCTAssertNil(completed.activeRunId)
        XCTAssertEqual(completed.runId, 7)

        let failed = ExecutionState.failed(runId: 8, message: "No targets")
        XCTAssertFalse(failed.isActive)
        XCTAssertNil(failed.activeRunId)
        XCTAssertEqual(failed.runId, 8)
    }
}
