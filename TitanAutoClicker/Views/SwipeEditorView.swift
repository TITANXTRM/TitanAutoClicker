import SwiftUI

public struct SwipeEditorView: View {
    @Bindable public var viewModel: TitanAppViewModel
    @State private var previewProgress: Double = 0
    @State private var isAnimatingPreview = false
    @State private var previewTask: Task<Void, Never>?

    public init(viewModel: TitanAppViewModel) {
        self.viewModel = viewModel
    }

    private var swipeTargets: [TargetPoint] {
        viewModel.activeConfiguration.targets.filter { $0.kind == .swipe }
    }

    private var selectedSwipe: TargetPoint? {
        if let id = viewModel.selectedTargetId,
           let match = swipeTargets.first(where: { $0.id == id }) {
            return match
        }
        return swipeTargets.first
    }

    public var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 900
            Group {
                if isWide {
                    HStack(spacing: 18) {
                        swipeCanvasPanel
                        ScrollView {
                            swipeControlsPanel
                        }
                        .frame(width: 380)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            swipeCanvasPanel.frame(height: 360)
                            swipeControlsPanel
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Swipe Editor")
        .onDisappear {
            cancelGesturePreview()
        }
        .onChange(of: viewModel.engine.state.isActive) { _, isActive in
            if isActive {
                cancelGesturePreview()
            }
        }
        .onChange(of: selectedSwipe?.id) { _, _ in
            cancelGesturePreview()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.addSwipeTarget()
                } label: {
                    Label("New Swipe", systemImage: "plus.circle.fill")
                }
                .disabled(viewModel.engine.state.isActive)
            }
        }
    }

    private var swipeCanvasPanel: some View {
        GlassPanel(title: "Swipe Vector Preview", systemImage: "hand.draw.fill") {
            ZStack {
                InteractiveTargetCanvas(
                    targets: swipeTargets,
                    selectedTargetId: selectedSwipe?.id,
                    activeTargetId: viewModel.engine.activeTargetId,
                    isLockedDuringExecution: viewModel.engine.state.isActive,
                    onSelectTarget: { viewModel.selectedTargetId = $0 },
                    onUpdateTarget: { viewModel.updateTarget($0) }
                )

                // Animated swipe preview dot along selected swipe vector
                if isAnimatingPreview, let swipe = selectedSwipe, let endPt = swipe.endPoint {
                    GeometryReader { geo in
                        let s = PreviewInteractionService.canvasPoint(from: swipe.startPoint, in: geo.size)
                        let e = PreviewInteractionService.canvasPoint(from: endPt, in: geo.size)
                        let current = CGPoint(
                            x: s.x + (e.x - s.x) * previewProgress,
                            y: s.y + (e.y - s.y) * previewProgress
                        )
                        Circle()
                            .fill(TitanTheme.statusRunning)
                            .frame(width: 22, height: 22)
                            .shadow(color: TitanTheme.statusRunning.opacity(0.8), radius: 10)
                            .position(current)
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var swipeControlsPanel: some View {
        VStack(spacing: 16) {
            GlassPanel(title: "Swipe Gestures (\(swipeTargets.count))", systemImage: "arrow.up.right.circle") {
                if swipeTargets.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No swipe gestures in this configuration.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            viewModel.addSwipeTarget()
                        } label: {
                            Label("Add First Swipe", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.engine.state.isActive)
                    }
                } else {
                    VStack(spacing: 8) {
                        ForEach(swipeTargets) { swipe in
                            let selected = swipe.id == selectedSwipe?.id
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(swipe.label)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("\(swipe.durationMs) ms swipe • \(swipe.delayValue)\(swipe.delayUnit.displayName) delay")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    viewModel.removeTarget(id: swipe.id)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .disabled(viewModel.engine.state.isActive)
                            }
                            .padding(10)
                            .background(
                                selected ? TitanTheme.accentSecondary.opacity(0.18) : Color.white.opacity(0.03),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedTargetId = swipe.id
                            }
                        }
                    }
                }
            }

            if let swipe = selectedSwipe {
                GlassPanel(title: "Swipe Parameters", systemImage: "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField(
                            "Swipe Label",
                            text: Binding(
                                get: { swipe.label },
                                set: { label in
                                    var edited = swipe
                                    edited.label = label
                                    viewModel.updateTarget(edited)
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)

                        Stepper(
                            "Swipe Duration: \(swipe.durationMs) ms",
                            value: Binding(
                                get: { swipe.durationMs },
                                set: { ms in
                                    var edited = swipe
                                    edited.durationMs = ms
                                    viewModel.updateTarget(edited)
                                }
                            ),
                            in: ValidationBounds.minSwipeDurationMs...ValidationBounds.maxSwipeDurationMs,
                            step: 50
                        )

                        coordinateEditor(
                            title: "Start Coordinate (S)",
                            point: swipe.startPoint
                        ) { newStart in
                            var edited = swipe
                            edited.startPoint = newStart
                            viewModel.updateTarget(edited)
                        }

                        if let endPt = swipe.endPoint {
                            coordinateEditor(
                                title: "End Coordinate (E)",
                                point: endPt
                            ) { newEnd in
                                var edited = swipe
                                edited.endPoint = newEnd
                                viewModel.updateTarget(edited)
                            }
                        }

                        Button {
                            triggerGesturePreview(durationMs: swipe.durationMs)
                        } label: {
                            Label(isAnimatingPreview ? "Previewing..." : "Preview Swipe Animation", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TitanTheme.accentSecondary)
                        .disabled(isAnimatingPreview)
                    }
                    .disabled(viewModel.engine.state.isActive)
                }
            }
        }
    }

    private func coordinateEditor(
        title: String,
        point: NormalizedPoint,
        onChange: @escaping @MainActor (NormalizedPoint) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "%@ — X: %.2f, Y: %.2f", title, point.x, point.y))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Slider(
                    value: Binding(
                        get: { point.x },
                        set: { onChange(NormalizedPoint(x: $0, y: point.y)) }
                    ),
                    in: 0...1
                )
                Slider(
                    value: Binding(
                        get: { point.y },
                        set: { onChange(NormalizedPoint(x: point.x, y: $0)) }
                    ),
                    in: 0...1
                )
            }
        }
    }

    private func triggerGesturePreview(durationMs: Int) {
        cancelGesturePreview()
        let clampedSeconds = min(max(Double(durationMs) / 1_000.0, 0.1), 3.0)
        previewProgress = 0
        isAnimatingPreview = true
        withAnimation(.easeInOut(duration: clampedSeconds)) {
            previewProgress = 1.0
        }
        previewTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(Int64((clampedSeconds * 1_000).rounded()) + 80))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            isAnimatingPreview = false
            previewProgress = 0
            previewTask = nil
        }
    }

    private func cancelGesturePreview() {
        previewTask?.cancel()
        previewTask = nil
        isAnimatingPreview = false
        previewProgress = 0
    }
}
