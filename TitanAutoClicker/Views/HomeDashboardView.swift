import SwiftUI

public struct HomeDashboardView: View {
    @Bindable public var viewModel: TitanAppViewModel
    public let onNavigate: @MainActor (AppNavigation) -> Void
    public let onShowLimitations: @MainActor () -> Void

    public init(
        viewModel: TitanAppViewModel,
        onNavigate: @escaping @MainActor (AppNavigation) -> Void,
        onShowLimitations: @escaping @MainActor () -> Void
    ) {
        self.viewModel = viewModel
        self.onNavigate = onNavigate
        self.onShowLimitations = onShowLimitations
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerStatusSection
                controlDeckSection
                modeAndSettingsGrid
                livePreviewSection
                recentConfigurationsSection
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
    }

    // MARK: - Sections

    private var headerStatusSection: some View {
        GlassPanel {
            let statusIdentity = HStack(alignment: .center, spacing: 14) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 14, height: 14)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.activeConfiguration.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(statusSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            let metricRow = HStack(spacing: 16) {
                metricPill(title: "State", value: viewModel.engine.state.badgeTitle, accent: statusColor)
                metricPill(title: "Cycles", value: "\(viewModel.engine.completedCycles)", accent: TitanTheme.accentPrimary)
                metricPill(title: "Steps", value: "\(viewModel.engine.dispatchedStepCount)", accent: TitanTheme.accentSecondary)
                metricPill(title: "Elapsed", value: String(format: "%.1fs", viewModel.engine.elapsedSeconds), accent: .white)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    statusIdentity
                    Spacer(minLength: 16)
                    metricRow
                }

                VStack(alignment: .leading, spacing: 12) {
                    statusIdentity
                    metricRow
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let error = viewModel.lastErrorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(TitanTheme.statusDanger)
            }
        }
    }

    private var controlDeckSection: some View {
        GlassPanel(title: "In-App Execution Controls", systemImage: "play.circle.fill") {
            let primaryControls = HStack(spacing: 12) {
                if !viewModel.engine.state.isActive {
                    Button {
                        viewModel.startExecution()
                    } label: {
                        Label("Start Preview", systemImage: "play.fill")
                            .font(.headline)
                            .frame(minWidth: 160, minHeight: 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TitanTheme.statusRunning)
                } else {
                    if viewModel.engine.state.isPaused {
                        Button {
                            viewModel.resumeExecution()
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                                .font(.headline)
                                .frame(minWidth: 120, minHeight: 46)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TitanTheme.accentPrimary)
                    } else {
                        Button {
                            viewModel.pauseExecution()
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                                .font(.headline)
                                .frame(minWidth: 120, minHeight: 46)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(TitanTheme.statusPaused)
                    }

                    Button(role: .destructive) {
                        viewModel.stopExecution()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.headline)
                            .frame(minWidth: 110, minHeight: 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TitanTheme.statusDanger)
                }
            }

            let limitationButton = Button {
                onShowLimitations()
            } label: {
                Label("PLATFORM_LIMITATION: In-App Only", systemImage: "exclamationmark.shield")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(TitanTheme.statusPaused)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    primaryControls
                    Spacer(minLength: 12)
                    limitationButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    primaryControls
                    limitationButton
                }
            }
        }
    }

    private var modeAndSettingsGrid: some View {
        let columns = [
            GridItem(.adaptive(minimum: 300), spacing: 16)
        ]

        return LazyVGrid(columns: columns, spacing: 16) {
            GlassPanel(title: "Execution Mode", systemImage: "slider.horizontal.3") {
                VStack(spacing: 10) {
                    ForEach(AutomationMode.allCases) { mode in
                        let selected = viewModel.activeConfiguration.mode == mode
                        Button {
                            viewModel.setMode(mode)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mode.systemImage)
                                    .font(.title3)
                                    .foregroundStyle(selected ? TitanTheme.accentPrimary : .secondary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(mode.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(TitanTheme.accentPrimary)
                                }
                            }
                            .padding(12)
                            .background(
                                selected ? TitanTheme.accentPrimary.opacity(0.14) : Color.white.opacity(0.03),
                                in: RoundedRectangle(cornerRadius: TitanTheme.controlCornerRadius, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: TitanTheme.controlCornerRadius, style: .continuous)
                                    .strokeBorder(selected ? TitanTheme.accentPrimary.opacity(0.6) : TitanTheme.surfaceStroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.engine.state.isActive)
                    }
                }
            }

            GlassPanel(title: "Execution Settings", systemImage: "timer") {
                let settings = viewModel.activeConfiguration.settings
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Start Delay")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Stepper(
                            "\(settings.startDelayMs) ms",
                            value: Binding(
                                get: { settings.startDelayMs },
                                set: { newVal in viewModel.updateSettings { $0.startDelayMs = newVal } }
                            ),
                            in: ValidationBounds.minStartDelayMs...ValidationBounds.maxStartDelayMs,
                            step: 100
                        )
                        .fixedSize()
                    }

                    HStack {
                        Text("Default Interval")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Stepper(
                            "\(settings.defaultIntervalValue) \(settings.defaultIntervalUnit.displayName)",
                            value: Binding(
                                get: { settings.defaultIntervalValue },
                                set: { newVal in viewModel.updateSettings { $0.defaultIntervalValue = newVal } }
                            ),
                            in: ValidationBounds.minDelayValue...(ValidationBounds.maxDelayValueForUnit[settings.defaultIntervalUnit] ?? 60_000),
                            step: settings.defaultIntervalUnit == .milliseconds ? 50 : 1
                        )
                        .fixedSize()
                    }

                    Picker(
                        "Stop Condition",
                        selection: Binding<StopCondition.Kind>(
                            get: { settings.stopCondition.kind },
                            set: { kind in
                                viewModel.updateSettings { s in
                                    switch kind {
                                    case .indefinite: s.stopCondition = .indefinite
                                    case .duration: s.stopCondition = .duration(seconds: 30)
                                    case .cycles: s.stopCondition = .cycles(count: 10)
                                    }
                                }
                            }
                        )
                    ) {
                        ForEach(StopCondition.Kind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch settings.stopCondition {
                    case .indefinite:
                        Text("Runs until Pause or Stop is pressed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .duration(let seconds):
                        Stepper(
                            "Duration: \(seconds) sec",
                            value: Binding(
                                get: { seconds },
                                set: { val in viewModel.updateSettings { $0.stopCondition = .duration(seconds: val) } }
                            ),
                            in: ValidationBounds.minStopDurationSeconds...ValidationBounds.maxStopDurationSeconds,
                            step: 5
                        )
                    case .cycles(let count):
                        Stepper(
                            "Cycles: \(count)",
                            value: Binding(
                                get: { count },
                                set: { val in viewModel.updateSettings { $0.stopCondition = .cycles(count: val) } }
                            ),
                            in: ValidationBounds.minCycles...ValidationBounds.maxCycles,
                            step: 1
                        )
                    }

                    Toggle(
                        "Subtle Coordinate Jitter",
                        isOn: Binding(
                            get: { settings.randomizePositionOffset },
                            set: { enabled in viewModel.updateSettings { $0.randomizePositionOffset = enabled } }
                        )
                    )
                    .font(.subheadline)
                }
                .disabled(viewModel.engine.state.isActive)
            }
        }
    }

    private var livePreviewSection: some View {
        GlassPanel(title: "Interactive Target Preview Canvas", systemImage: "rectangle.dashed") {
            InteractiveTargetCanvas(
                targets: viewModel.activeConfiguration.activeTargets,
                selectedTargetId: viewModel.selectedTargetId,
                activeTargetId: viewModel.engine.activeTargetId,
                isLockedDuringExecution: viewModel.engine.state.isActive,
                onSelectTarget: { viewModel.selectedTargetId = $0 },
                onUpdateTarget: { viewModel.updateTarget($0) }
            )
            .frame(height: 300)

            let editorButtons = HStack(spacing: 10) {
                Button {
                    onNavigate(.targetEditor)
                } label: {
                    Label("Open Target Editor", systemImage: "scope")
                }
                .buttonStyle(.bordered)

                Button {
                    onNavigate(.swipeEditor)
                } label: {
                    Label("Open Swipe Editor", systemImage: "hand.draw")
                }
                .buttonStyle(.bordered)
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    editorButtons
                    Spacer(minLength: 12)
                    if let last = viewModel.engine.lastEvent {
                        Text("Last step: \(last.targetLabel) (Cycle \(last.cycleIndex))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    editorButtons
                    if let last = viewModel.engine.lastEvent {
                        Text("Last step: \(last.targetLabel) (Cycle \(last.cycleIndex))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var recentConfigurationsSection: some View {
        GlassPanel(title: "Recent Configurations", systemImage: "clock.arrow.circlepath") {
            VStack(spacing: 8) {
                ForEach(viewModel.recentConfigurations.prefix(4)) { config in
                    let isSelected = config.id == viewModel.activeConfiguration.id
                    Button {
                        viewModel.selectConfiguration(id: config.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(config.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("\(config.mode.title) • \(config.targets.count) targets • \(config.settings.stopCondition.summaryText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isSelected {
                                Text("Active")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(TitanTheme.accentPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(TitanTheme.accentPrimary.opacity(0.16), in: Capsule())
                            }
                        }
                        .padding(10)
                        .background(
                            isSelected ? TitanTheme.accentPrimary.opacity(0.10) : Color.white.opacity(0.03),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.engine.state.isActive)
                }

                HStack {
                    Spacer()
                    Button("Manage All Configurations") {
                        onNavigate(.configurations)
                    }
                    .font(.subheadline.weight(.medium))
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch viewModel.engine.state {
        case .idle: return .secondary
        case .running: return TitanTheme.statusRunning
        case .paused: return TitanTheme.statusPaused
        case .stopping: return TitanTheme.statusDanger
        case .completed: return TitanTheme.accentPrimary
        case .failed: return TitanTheme.statusDanger
        }
    }

    private var statusSubtitle: String {
        switch viewModel.engine.state {
        case .idle:
            return "\(viewModel.activeConfiguration.mode.title) • Ready for in-app preview"
        case .running:
            return "Executing \(viewModel.activeConfiguration.activeTargets.count) targets in preview canvas"
        case .paused:
            return "Execution paused — tap Resume to continue"
        case .stopping:
            return "Cancelling active timers and tasks..."
        case .completed(_, let reason):
            return reason.displayText
        case .failed(_, let message):
            return message
        }
    }

    private func metricPill(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(accent)
        }
    }
}
