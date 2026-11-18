import Foundation

/// Event emitted by ExecutionEngine to visualize in-app gesture execution on the preview canvas.
public struct ExecutionEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let runId: UInt64
    public let targetId: UUID
    public let targetLabel: String
    public let kind: TargetKind
    public let point: NormalizedPoint
    public let endPoint: NormalizedPoint?
    public let durationMs: Int
    public let cycleIndex: Int
    public let stepIndex: Int
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        runId: UInt64,
        targetId: UUID,
        targetLabel: String,
        kind: TargetKind,
        point: NormalizedPoint,
        endPoint: NormalizedPoint?,
        durationMs: Int,
        cycleIndex: Int,
        stepIndex: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.runId = runId
        self.targetId = targetId
        self.targetLabel = targetLabel
        self.kind = kind
        self.point = point
        self.endPoint = endPoint
        self.durationMs = durationMs
        self.cycleIndex = cycleIndex
        self.stepIndex = stepIndex
        self.timestamp = timestamp
    }
}
