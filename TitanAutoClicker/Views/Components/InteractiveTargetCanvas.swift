import SwiftUI

/// Interactive in-app preview canvas supporting draggable tap markers, draggable swipe
/// start/end vectors, subtle coordinate grid, and live execution step pulses.
public struct InteractiveTargetCanvas: View {
    public let targets: [TargetPoint]
    public let selectedTargetId: UUID?
    public let activeTargetId: UUID?
    public let isLockedDuringExecution: Bool
    public let onSelectTarget: @MainActor (UUID) -> Void
    public let onUpdateTarget: @MainActor (TargetPoint) -> Void

    public init(
        targets: [TargetPoint],
        selectedTargetId: UUID?,
        activeTargetId: UUID?,
        isLockedDuringExecution: Bool,
        onSelectTarget: @escaping @MainActor (UUID) -> Void,
        onUpdateTarget: @escaping @MainActor (TargetPoint) -> Void
    ) {
        self.targets = targets
        self.selectedTargetId = selectedTargetId
        self.activeTargetId = activeTargetId
        self.isLockedDuringExecution = isLockedDuringExecution
        self.onSelectTarget = onSelectTarget
        self.onUpdateTarget = onUpdateTarget
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                // Dark precision grid backdrop
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.05, green: 0.07, blue: 0.11),
                                Color(red: 0.08, green: 0.10, blue: 0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Canvas { context, canvasSize in
                    let step: CGFloat = 36
                    var gridPath = Path()
                    var x: CGFloat = step
                    while x < canvasSize.width {
                        gridPath.move(to: CGPoint(x: x, y: 0))
                        gridPath.addLine(to: CGPoint(x: x, y: canvasSize.height))
                        x += step
                    }
                    var y: CGFloat = step
                    while y < canvasSize.height {
                        gridPath.move(to: CGPoint(x: 0, y: y))
                        gridPath.addLine(to: CGPoint(x: canvasSize.width, y: y))
                        y += step
                    }
                    context.stroke(gridPath, with: .color(.white.opacity(0.05)), lineWidth: 1)

                    // Draw swipe connector vectors
                    for target in targets where target.kind == .swipe {
                        guard let endNorm = target.endPoint else { continue }
                        let startPt = PreviewInteractionService.canvasPoint(from: target.startPoint, in: canvasSize)
                        let endPt = PreviewInteractionService.canvasPoint(from: endNorm, in: canvasSize)
                        var line = Path()
                        line.move(to: startPt)
                        line.addLine(to: endPt)

                        let isActive = (target.id == activeTargetId)
                        let isSelected = (target.id == selectedTargetId)
                        let strokeColor: Color = isActive
                            ? TitanTheme.statusRunning
                            : (isSelected ? TitanTheme.accentPrimary : TitanTheme.accentSecondary.opacity(0.85))
                        context.stroke(
                            line,
                            with: .color(strokeColor),
                            style: StrokeStyle(lineWidth: isActive ? 4 : 2.5, lineCap: .round, dash: [8, 6])
                        )
                    }
                }
                .allowsHitTesting(false)

                if targets.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "scope")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("No targets on canvas")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("Add a Tap or Swipe target to preview and drag coordinates.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .multilineTextAlignment(.center)
                    .padding()
                }

                // Draggable target handles
                ForEach(Array(targets.enumerated()), id: \.element.id) { idx, target in
                    let startPos = PreviewInteractionService.canvasPoint(from: target.startPoint, in: size)
                    let isSelected = target.id == selectedTargetId
                    let isActive = target.id == activeTargetId

                    TargetHandleView(
                        badge: "\(idx + 1)",
                        subLabel: target.kind == .swipe ? "S" : nil,
                        isSelected: isSelected,
                        isActive: isActive,
                        accent: target.kind == .swipe ? TitanTheme.accentSecondary : TitanTheme.accentPrimary
                    )
                    .position(startPos)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("TitanCanvas"))
                            .onChanged { value in
                                onSelectTarget(target.id)
                                guard !isLockedDuringExecution else { return }
                                var edited = target
                                edited.startPoint = PreviewInteractionService.normalizedPoint(
                                    from: value.location,
                                    in: size
                                )
                                onUpdateTarget(edited)
                            }
                    )

                    if target.kind == .swipe, let endNorm = target.endPoint {
                        let endPos = PreviewInteractionService.canvasPoint(from: endNorm, in: size)
                        TargetHandleView(
                            badge: "\(idx + 1)",
                            subLabel: "E",
                            isSelected: isSelected,
                            isActive: isActive,
                            accent: TitanTheme.statusPaused
                        )
                        .position(endPos)
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("TitanCanvas"))
                                .onChanged { value in
                                    onSelectTarget(target.id)
                                    guard !isLockedDuringExecution else { return }
                                    var edited = target
                                    edited.endPoint = PreviewInteractionService.normalizedPoint(
                                        from: value.location,
                                        in: size
                                    )
                                    onUpdateTarget(edited)
                                }
                        )
                    }
                }

                // Bottom-left status overlay
                VStack {
                    Spacer()
                    HStack {
                        Label(
                            isLockedDuringExecution
                                ? "Canvas locked while executing in-app preview"
                                : "Drag target rings to reposition",
                            systemImage: isLockedDuringExecution ? "lock.fill" : "hand.point.up.left.fill"
                        )
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.45), in: Capsule())

                        Spacer()

                        if let selected = targets.first(where: { $0.id == selectedTargetId }) {
                            Text(PreviewInteractionService.formattedCoordinates(selected.startPoint, in: size))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(TitanTheme.accentPrimary)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.45), in: Capsule())
                        }
                    }
                    .padding(12)
                }
                .allowsHitTesting(false)
            }
            .coordinateSpace(.named("TitanCanvas"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(TitanTheme.surfaceStroke, lineWidth: 1)
            )
        }
    }
}

private struct TargetHandleView: View {
    let badge: String
    let subLabel: String?
    let isSelected: Bool
    let isActive: Bool
    let accent: Color

    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .stroke(TitanTheme.statusRunning.opacity(0.7), lineWidth: 3)
                    .frame(width: 62, height: 62)
            }

            Circle()
                .fill(accent.opacity(isSelected ? 0.32 : 0.18))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .strokeBorder(isActive ? TitanTheme.statusRunning : accent, lineWidth: isSelected ? 2.5 : 1.5)
                )

            VStack(spacing: -2) {
                Text(badge)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
                if let subLabel {
                    Text(subLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .animation(.easeOut(duration: 0.14), value: isActive)
        .accessibilityLabel("Target \(badge)")
    }
}
