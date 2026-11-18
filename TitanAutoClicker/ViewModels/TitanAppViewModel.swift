import Foundation
import Observation

/// Root @MainActor ViewModel coordinating configurations, editing state, validation, and execution.
@MainActor
@Observable
public final class TitanAppViewModel {
    public var configurations: [AutomationConfiguration] = []
    public var selectedConfigurationId: UUID?
    public var selectedTargetId: UUID?
    public var statusBannerMessage: String?
    public var lastErrorMessage: String?

    public let engine: ExecutionEngine
    private let store: ConfigurationStore

    public init(store: ConfigurationStore = ConfigurationStore(), engine: ExecutionEngine? = nil) {
        self.store = store
        self.engine = engine ?? ExecutionEngine()
        let loaded = store.loadAll()
        self.configurations = loaded
        self.selectedConfigurationId = loaded.first?.id
        self.selectedTargetId = loaded.first?.targets.first?.id
    }

    public var activeConfiguration: AutomationConfiguration {
        get {
            if let id = selectedConfigurationId,
               let match = configurations.first(where: { $0.id == id }) {
                return match
            }
            return configurations.first ?? AutomationConfiguration.sampleDefault()
        }
        set {
            guard !engine.state.isActive else { return }
            upsertConfiguration(newValue)
        }
    }

    public var recentConfigurations: [AutomationConfiguration] {
        configurations.sorted { $0.updatedAt > $1.updatedAt }
    }

    public var selectedTarget: TargetPoint? {
        guard let targetId = selectedTargetId else {
            return activeConfiguration.targets.first
        }
        return activeConfiguration.targets.first(where: { $0.id == targetId })
            ?? activeConfiguration.targets.first
    }

    // MARK: - Execution Controls

    public func startExecution() {
        clearTransientMessages()
        let started = engine.start(configuration: activeConfiguration)
        if !started, case .failed(_, let message) = engine.state {
            lastErrorMessage = message
        }
    }

    public func pauseExecution() {
        engine.pause()
    }

    public func resumeExecution() {
        engine.resume()
    }

    public func stopExecution(reason: CompletionReason = .userStopped) {
        engine.stop(reason: reason)
    }

    public func handleSceneBackgrounded() {
        if engine.state.isActive {
            engine.stop(reason: .lifecycleSuspended)
        }
    }

    // MARK: - Mode & Settings Mutations

    public func setMode(_ mode: AutomationMode) {
        guard !engine.state.isActive else { return }
        var config = activeConfiguration
        config.mode = mode
        config.updatedAt = Date()
        upsertConfiguration(config)
    }

    public func updateSettings(_ transform: (inout ExecutionSettings) -> Void) {
        guard !engine.state.isActive else { return }
        var config = activeConfiguration
        transform(&config.settings)
        config.settings = config.settings.validated()
        config.updatedAt = Date()
        upsertConfiguration(config)
    }

    // MARK: - Target & Swipe CRUD

    public func addTapTarget(at point: NormalizedPoint = NormalizedPoint(x: 0.5, y: 0.5)) {
        guard !engine.state.isActive else { return }
        var config = activeConfiguration
        guard config.targets.count < ValidationBounds.maxTargetsPerConfiguration else {
            lastErrorMessage = "Maximum of \(ValidationBounds.maxTargetsPerConfiguration) targets reached."
            return
        }
        let nextIndex = config.targets.count + 1
        let target = TargetPoint(
            label: "Tap \(nextIndex)",
            kind: .tap,
            startPoint: point,
            delayValue: config.settings.defaultIntervalValue,
            delayUnit: config.settings.defaultIntervalUnit,
            durationMs: 50,
            repeatCount: 1
        )
        config.targets.append(target)
        config.updatedAt = Date()
        upsertConfiguration(config)
        selectedTargetId = target.id
    }

    public func addSwipeTarget(
        from start: NormalizedPoint = NormalizedPoint(x: 0.25, y: 0.55),
        to end: NormalizedPoint = NormalizedPoint(x: 0.75, y: 0.55)
    ) {
        guard !engine.state.isActive else { return }
        var config = activeConfiguration
        guard config.targets.count < ValidationBounds.maxTargetsPerConfiguration else {
            lastErrorMessage = "Maximum of \(ValidationBounds.maxTargetsPerConfiguration) targets reached."
            return
        }
        let nextIndex = config.targets.count + 1
        let target = TargetPoint(
            label: "Swipe \(nextIndex)",
            kind: .swipe,
            startPoint: start,
            endPoint: end,
            delayValue: config.settings.defaultIntervalValue,
            delayUnit: config.settings.defaultIntervalUnit,
            durationMs: 350,
            repeatCount: 1
        )
        config.targets.append(target)
        config.updatedAt = Date()
        upsertConfiguration(config)
        selectedTargetId = target.id
    }

    public func updateTarget(_ updated: TargetPoint) {
        guard !engine.state.isActive else { return }
        var config = activeConfiguration
        guard let idx = config.targets.firstIndex(where: { $0.id == updated.id }) else { return }
        config.targets[idx] = updated.validated(fallbackLabel: "Target \(idx + 1)")
        config.updatedAt = Date()
        upsertConfiguration(config)
    }

    public func removeTarget(id: UUID) {
        guard !engine.state.isActive else { return }
        var config = activeConfiguration
        config.targets.removeAll { $0.id == id }
        config.updatedAt = Date()
        upsertConfiguration(config)
        if selectedTargetId == id {
            selectedTargetId = config.targets.first?.id
        }
    }

    public func moveTargets(from offsets: IndexSet, to destination: Int) {
        guard !engine.state.isActive else { return }
        var config = activeConfiguration
        let movingItems = offsets.sorted().compactMap { idx -> TargetPoint? in
            config.targets.indices.contains(idx) ? config.targets[idx] : nil
        }
        guard !movingItems.isEmpty else { return }
        let removedBeforeDestination = offsets.filter { $0 < destination }.count
        for idx in offsets.sorted(by: >) where config.targets.indices.contains(idx) {
            config.targets.remove(at: idx)
        }
        let insertionIndex = min(max(destination - removedBeforeDestination, 0), config.targets.count)
        config.targets.insert(contentsOf: movingItems, at: insertionIndex)
        config.updatedAt = Date()
        upsertConfiguration(config)
    }

    // MARK: - Configuration CRUD & JSON Import/Export

    public func selectConfiguration(id: UUID) {
        guard !engine.state.isActive else { return }
        guard configurations.contains(where: { $0.id == id }) else { return }
        selectedConfigurationId = id
        selectedTargetId = activeConfiguration.targets.first?.id
    }

    public func createNewConfiguration(name: String = "New Profile") {
        guard !engine.state.isActive else { return }
        let created = AutomationConfiguration(
            name: name,
            mode: .multiTarget,
            targets: [
                TargetPoint(
                    label: "Tap 1",
                    kind: .tap,
                    startPoint: NormalizedPoint(x: 0.5, y: 0.5)
                )
            ]
        )
        configurations.insert(created, at: 0)
        selectedConfigurationId = created.id
        selectedTargetId = created.targets.first?.id
        persist()
    }

    public func renameConfiguration(id: UUID, newName: String) {
        guard !engine.state.isActive else { return }
        guard let idx = configurations.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastErrorMessage = "Configuration name cannot be empty."
            return
        }
        configurations[idx].name = String(trimmed.prefix(ValidationBounds.maxConfigurationNameLength))
        configurations[idx].updatedAt = Date()
        persist()
    }

    public func duplicateConfiguration(id: UUID) {
        guard !engine.state.isActive else { return }
        guard let original = configurations.first(where: { $0.id == id }) else { return }
        let now = Date()
        let copiedTargets = original.targets.map { t in
            TargetPoint(
                id: UUID(),
                label: t.label,
                kind: t.kind,
                startPoint: t.startPoint,
                endPoint: t.endPoint,
                delayValue: t.delayValue,
                delayUnit: t.delayUnit,
                durationMs: t.durationMs,
                repeatCount: t.repeatCount
            )
        }
        let copy = AutomationConfiguration(
            id: UUID(),
            name: "\(original.name) Copy",
            mode: original.mode,
            targets: copiedTargets,
            settings: original.settings,
            createdAt: now,
            updatedAt: now
        )
        configurations.insert(copy, at: 0)
        selectedConfigurationId = copy.id
        selectedTargetId = copy.targets.first?.id
        persist()
    }

    public func deleteConfiguration(id: UUID) {
        guard !engine.state.isActive else { return }
        configurations.removeAll { $0.id == id }
        if configurations.isEmpty {
            let fallback = AutomationConfiguration.sampleDefault()
            configurations = [fallback]
        }
        if selectedConfigurationId == id {
            selectedConfigurationId = configurations.first?.id
            selectedTargetId = activeConfiguration.targets.first?.id
        }
        persist()
    }

    public func makeExportDocument() -> ConfigurationJSONDocument? {
        do {
            return try ConfigurationJSONDocument(configurations: configurations)
        } catch {
            lastErrorMessage = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }

    /// Two-phase atomic JSON import: validates entire payload before touching `configurations`.
    public func importConfigurations(from url: URL) {
        guard !engine.state.isActive else { return }
        clearTransientMessages()
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            switch ConfigurationJSONCodec.decodeAndValidate(data) {
            case .failure(let err):
                lastErrorMessage = err.localizedDescription
            case .success(let bundle):
                // Assign fresh UUIDs to configs and targets to avoid colliding with existing stored profiles
                let imported = bundle.configurations.map { cfg in
                    let freshTargets = cfg.targets.map { t in
                        TargetPoint(
                            id: UUID(),
                            label: t.label,
                            kind: t.kind,
                            startPoint: t.startPoint,
                            endPoint: t.endPoint,
                            delayValue: t.delayValue,
                            delayUnit: t.delayUnit,
                            durationMs: t.durationMs,
                            repeatCount: t.repeatCount
                        )
                    }
                    return AutomationConfiguration(
                        id: UUID(),
                        name: cfg.name,
                        mode: cfg.mode,
                        targets: freshTargets,
                        settings: cfg.settings,
                        createdAt: cfg.createdAt,
                        updatedAt: Date()
                    )
                }
                let previousSnapshot = configurations
                configurations.insert(contentsOf: imported, at: 0)
                do {
                    try store.saveAll(configurations)
                    selectedConfigurationId = imported.first?.id ?? selectedConfigurationId
                    selectedTargetId = activeConfiguration.targets.first?.id
                    let warningSuffix = bundle.warnings.isEmpty ? "" : " (\(bundle.warnings.count) adjusted)"
                    statusBannerMessage = "Imported \(imported.count) \(imported.count == 1 ? "configuration" : "configurations")\(warningSuffix)."
                } catch {
                    configurations = previousSnapshot
                    lastErrorMessage = error.localizedDescription
                }
            }
        } catch {
            lastErrorMessage = "Could not read file: \(error.localizedDescription)"
        }
    }

    public func clearTransientMessages() {
        statusBannerMessage = nil
        lastErrorMessage = nil
    }

    // MARK: - Private Persistence

    private func upsertConfiguration(_ config: AutomationConfiguration) {
        if let idx = configurations.firstIndex(where: { $0.id == config.id }) {
            configurations[idx] = config
        } else {
            configurations.insert(config, at: 0)
        }
        selectedConfigurationId = config.id
        persist()
    }

    private func persist() {
        do {
            try store.saveAll(configurations)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
