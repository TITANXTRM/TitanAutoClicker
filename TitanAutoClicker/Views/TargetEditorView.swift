import SwiftUI

public struct TargetEditorView: View {
    @Bindable public var viewModel: TitanAppViewModel

    public init(viewModel: TitanAppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 900
            Group {
                if isWide {
                    HStack(spacing: 18) {
                        canvasColumn
                        wideInspectorColumn
                            .frame(width: 370)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            canvasColumn
                                .frame(height: 360)
                            compactInspectorColumn
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Target Editor")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.addTapTarget()
                } label: {
                    Label("Add Tap", systemImage: "plus.circle.fill")
                }
                .disabled(viewModel.engine.state.isActive)

                Button {
                    viewModel.addSwipeTarget()
                } label: {
                    Label("Add Swipe", systemImage: "hand.draw.fill")
                }
                .disabled(viewModel.engine.state.isActive)
            }
        }
    }

    private var canvasColumn: some View {
        GlassPanel(title: "Interactive Target Canvas", systemImage: "scope") {
            InteractiveTargetCanvas(
                targets: viewModel.activeConfiguration.targets,
                selectedTargetId: viewModel.selectedTargetId,
                activeTargetId: viewModel.engine.activeTargetId,
                isLockedDuringExecution: viewModel.engine.state.isActive,
                onSelectTarget: { viewModel.selectedTargetId = $0 },
                onUpdateTarget: { viewModel.updateTarget($0) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var wideInspectorColumn: some View {
        VStack(spacing: 16) {
            GlassPanel(title: "Sequence Order (\(viewModel.activeConfiguration.targets.count))", systemImage: "list.number") {
                if viewModel.activeConfiguration.targets.isEmpty {
                    Text("Tap 'Add Tap' or 'Add Swipe' to create targets.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    List {
                        ForEach(Array(viewModel.activeConfiguration.targets.enumerated()), id: \.element.id) { idx, target in
                            let selected = target.id == viewModel.selectedTarget?.id
                            sequenceRowContent(idx: idx, target: target, selected: selected, showCompactReorderButtons: false)
                                .contentShape(Rectangle())
                                .onTapGesture { viewModel.selectedTargetId = target.id }
                                .listRowBackground(selected ? TitanTheme.accentPrimary.opacity(0.14) : Color.clear)
                                .moveDisabled(viewModel.engine.state.isActive)
                        }
                        .onMove { offsets, dest in
                            viewModel.moveTargets(from: offsets, to: dest)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 160, maxHeight: 240)
                }
            }

            if let target = viewModel.selectedTarget {
                ScrollView {
                    targetInspectorPanel(for: target)
                }
            }
        }
    }

    private var compactInspectorColumn: some View {
        VStack(spacing: 16) {
            GlassPanel(title: "Sequence Order (\(viewModel.activeConfiguration.targets.count))", systemImage: "list.number") {
                if viewModel.activeConfiguration.targets.isEmpty {
                    Text("Tap 'Add Tap' or 'Add Swipe' to create targets.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(viewModel.activeConfiguration.targets.enumerated()), id: \.element.id) { idx, target in
                            let selected = target.id == viewModel.selectedTarget?.id
                            sequenceRowContent(idx: idx, target: target, selected: selected, showCompactReorderButtons: true)
                                .padding(10)
                                .background(
                                    selected ? TitanTheme.accentPrimary.opacity(0.14) : Color.white.opacity(0.03),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { viewModel.selectedTargetId = target.id }
                        }
                    }
                }
            }

            if let target = viewModel.selectedTarget {
                targetInspectorPanel(for: target)
            }
        }
    }

    private func sequenceRowContent(
        idx: Int,
        target: TargetPoint,
        selected: Bool,
        showCompactReorderButtons: Bool
    ) -> some View {
        let count = viewModel.activeConfiguration.targets.count
        return HStack(spacing: 10) {
            Text("\(idx + 1)")
                .font(.caption.weight(.bold).monospacedDigit())
                .frame(width: 24, height: 24)
                .background(
                    selected ? TitanTheme.accentPrimary : Color.white.opacity(0.10),
                    in: Circle()
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(target.label)
                    .font(.subheadline.weight(.semibold))
                Text("\(target.kind.displayName) • \(target.delayValue)\(target.delayUnit.displayName) • ×\(target.repeatCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if showCompactReorderButtons {
                Button {
                    viewModel.moveTargets(from: IndexSet(integer: idx), to: max(0, idx - 1))
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.engine.state.isActive || idx == 0)

                Button {
                    viewModel.moveTargets(from: IndexSet(integer: idx), to: min(count, idx + 2))
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.engine.state.isActive || idx >= count - 1)
            }
            Button(role: .destructive) {
                viewModel.removeTarget(id: target.id)
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.engine.state.isActive)
        }
    }

    private func targetInspectorPanel(for target: TargetPoint) -> some View {
        GlassPanel(title: "Target Settings", systemImage: "slider.horizontal.below.rectangle") {
            VStack(alignment: .leading, spacing: 12) {
                TextField(
                    "Label",
                    text: Binding(
                        get: { target.label },
                        set: { newLabel in
                            var edited = target
                            edited.label = newLabel
                            viewModel.updateTarget(edited)
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)

                HStack {
                    Text("Delay")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(
                        "\(target.delayValue)",
                        value: Binding(
                            get: { target.delayValue },
                            set: { val in
                                var edited = target
                                edited.delayValue = val
                                viewModel.updateTarget(edited)
                            }
                        ),
                        in: ValidationBounds.minDelayValue...(ValidationBounds.maxDelayValueForUnit[target.delayUnit] ?? 60_000),
                        step: target.delayUnit == .milliseconds ? 50 : 1
                    )
                    .fixedSize()

                    Picker(
                        "Unit",
                        selection: Binding(
                            get: { target.delayUnit },
                            set: { unit in
                                var edited = target
                                edited.delayUnit = unit
                                edited.delayValue = ValidationBounds.clampDelayValue(edited.delayValue, unit: unit)
                                viewModel.updateTarget(edited)
                            }
                        )
                    ) {
                        ForEach(TimeUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                }

                let durationRange = target.kind == .swipe
                    ? ValidationBounds.minSwipeDurationMs...ValidationBounds.maxSwipeDurationMs
                    : ValidationBounds.minTapDurationMs...ValidationBounds.maxTapDurationMs

                Stepper(
                    "\(target.kind == .swipe ? "Swipe" : "Tap") Duration: \(target.durationMs) ms",
                    value: Binding(
                        get: { target.durationMs },
                        set: { val in
                            var edited = target
                            edited.durationMs = val
                            viewModel.updateTarget(edited)
                        }
                    ),
                    in: durationRange,
                    step: target.kind == .swipe ? 50 : 10
                )

                Stepper(
                    "Repeat Count: \(target.repeatCount)",
                    value: Binding(
                        get: { target.repeatCount },
                        set: { val in
                            var edited = target
                            edited.repeatCount = val
                            viewModel.updateTarget(edited)
                        }
                    ),
                    in: ValidationBounds.minRepeatCount...ValidationBounds.maxRepeatCount,
                    step: 1
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(format: "Position X: %.2f  •  Y: %.2f", target.startPoint.x, target.startPoint.y))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { target.startPoint.x },
                            set: { x in
                                var edited = target
                                edited.startPoint = NormalizedPoint(x: x, y: edited.startPoint.y)
                                viewModel.updateTarget(edited)
                            }
                        ),
                        in: 0...1
                    )
                    Slider(
                        value: Binding(
                            get: { target.startPoint.y },
                            set: { y in
                                var edited = target
                                edited.startPoint = NormalizedPoint(x: edited.startPoint.x, y: y)
                                viewModel.updateTarget(edited)
                            }
                        ),
                        in: 0...1
                    )
                }
            }
            .disabled(viewModel.engine.state.isActive)
        }
    }
}
