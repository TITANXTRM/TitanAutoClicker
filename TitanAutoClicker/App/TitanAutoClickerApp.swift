import SwiftUI

@main
struct TitanAutoClickerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = TitanAppViewModel()

    var body: some Scene {
        WindowGroup {
            RootSplitView(viewModel: viewModel)
                .preferredColorScheme(.dark)
                .tint(TitanTheme.accentPrimary)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        viewModel.handleSceneBackgrounded()
                    }
                }
        }
    }
}
