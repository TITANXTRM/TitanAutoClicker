import SwiftUI
import UniformTypeIdentifiers

public struct ConfigurationsView: View {
    @Bindable public var viewModel: TitanAppViewModel

    @State private var isImporterPresented = false
    @State private var isExporterPresented = false
    @State private var exportDocument: ConfigurationJSONDocument?
    @State private var renamingConfig: AutomationConfiguration?
    @State private var renameDraft: String = ""

    public init(viewModel: TitanAppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let banner = viewModel.statusBannerMessage {
                    GlassPanel {
                        HStack {
                            Label(banner, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(TitanTheme.statusRunning)
                            Spacer()
                            Button("Dismiss") { viewModel.clearTransientMessages() }
                                .font(.caption)
                        }
                    }
                }

                if let error = viewModel.lastErrorMessage {
                    GlassPanel {
                        HStack {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(TitanTheme.statusDanger)
                            Spacer()
                            Button("Dismiss") { viewModel.clearTransientMessages() }
                                .font(.caption)
                        }
                    }
                }

                GlassPanel(title: "Saved Configurations (\(viewModel.configurations.count))", systemImage: "folder.fill") {
                    VStack(spacing: 10) {
                        ForEach(viewModel.configurations) { config in
                            configurationRow(config)
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Configurations")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.createNewConfiguration(name: "Profile \(viewModel.configurations.count + 1)")
                } label: {
                    Label("New", systemImage: "plus")
                }
                .disabled(viewModel.engine.state.isActive)

                Button {
                    isImporterPresented = true
                } label: {
                    Label("Import JSON", systemImage: "square.and.arrow.down")
                }
                .disabled(viewModel.engine.state.isActive)

                Button {
                    if let doc = viewModel.makeExportDocument() {
                        exportDocument = doc
                        isExporterPresented = true
                    }
                } label: {
                    Label("Export JSON", systemImage: "square.and.arrow.up")
                }
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.importConfigurations(from: url)
                }
            case .failure(let error):
                viewModel.lastErrorMessage = "Import cancelled or failed: \(error.localizedDescription)"
            }
        }
        .fileExporter(
            isPresented: $isExporterPresented,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "titan-configurations-v1"
        ) { result in
            exportDocument = nil
            viewModel.clearTransientMessages()
            if case .failure(let error) = result {
                viewModel.lastErrorMessage = "Export failed: \(error.localizedDescription)"
            } else if case .success = result {
                viewModel.statusBannerMessage = "Exported \(viewModel.configurations.count) configurations as versioned JSON."
            }
        }
        .alert(
            "Rename Configuration",
            isPresented: Binding(
                get: { renamingConfig != nil },
                set: { if !$0 { renamingConfig = nil } }
            )
        ) {
            TextField("Configuration name", text: $renameDraft)
            Button("Save") {
                if let target = renamingConfig {
                    viewModel.renameConfiguration(id: target.id, newName: renameDraft)
                }
                renamingConfig = nil
            }
            Button("Cancel", role: .cancel) {
                renamingConfig = nil
            }
        }
    }

    private func configurationRow(_ config: AutomationConfiguration) -> some View {
        let isActive = config.id == viewModel.activeConfiguration.id
        let metadata = VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(config.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if isActive {
                    Text("ACTIVE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(TitanTheme.accentPrimary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(TitanTheme.accentPrimary.opacity(0.16), in: Capsule())
                }
            }
            Text("\(config.mode.title) • \(config.targets.count) targets • \(config.settings.stopCondition.summaryText) • Schema v\(config.schemaVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }

        let actions = HStack(spacing: 8) {
            if !isActive {
                Button("Load") {
                    viewModel.selectConfiguration(id: config.id)
                }
                .buttonStyle(.borderedProminent)
                .tint(TitanTheme.accentPrimary)
                .disabled(viewModel.engine.state.isActive)
            }

            Button {
                renameDraft = config.name
                renamingConfig = config
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.engine.state.isActive)
            .help("Rename")

            Button {
                viewModel.duplicateConfiguration(id: config.id)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.engine.state.isActive)
            .help("Duplicate")

            Button(role: .destructive) {
                viewModel.deleteConfiguration(id: config.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.engine.state.isActive)
            .help("Delete")
        }

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                metadata
                Spacer(minLength: 12)
                actions
            }

            VStack(alignment: .leading, spacing: 10) {
                metadata
                actions
            }
        }
        .padding(14)
        .background(
            isActive ? TitanTheme.accentPrimary.opacity(0.10) : Color.white.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isActive ? TitanTheme.accentPrimary.opacity(0.5) : TitanTheme.surfaceStroke, lineWidth: 1)
        )
    }
}
