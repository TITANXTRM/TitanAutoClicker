import SwiftUI

/// iPad-first NavigationSplitView shell supporting portrait, landscape, and Split View.
public struct RootSplitView: View {
    @Bindable public var viewModel: TitanAppViewModel
    @State private var selection: AppNavigation? = .home
    @State private var showLimitationsSheet = false

    public init(viewModel: TitanAppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Workspace") {
                    ForEach(AppNavigation.allCases) { destination in
                        NavigationLink(value: destination) {
                            Label(destination.title, systemImage: destination.systemImage)
                                .font(.body.weight(.medium))
                        }
                    }
                }

                Section("Active Profile") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.activeConfiguration.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            Text(viewModel.activeConfiguration.mode.title)
                            Text("•")
                            Text("\(viewModel.activeConfiguration.targets.count) targets")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("iPadOS Sandbox") {
                    Button {
                        showLimitationsSheet = true
                    } label: {
                        Label("Platform Limitations", systemImage: "info.circle")
                            .foregroundStyle(TitanTheme.statusPaused)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Titan")
        } detail: {
            Group {
                switch selection ?? .home {
                case .home:
                    HomeDashboardView(
                        viewModel: viewModel,
                        onNavigate: { selection = $0 },
                        onShowLimitations: { showLimitationsSheet = true }
                    )
                case .targetEditor:
                    TargetEditorView(viewModel: viewModel)
                case .swipeEditor:
                    SwipeEditorView(viewModel: viewModel)
                case .configurations:
                    ConfigurationsView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TitanTheme.canvasBackground.ignoresSafeArea())
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showLimitationsSheet) {
            PlatformLimitationsSheet()
        }
    }
}
