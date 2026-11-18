import Foundation

public enum AppNavigation: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home
    case targetEditor
    case swipeEditor
    case configurations

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home: return "Dashboard"
        case .targetEditor: return "Target Editor"
        case .swipeEditor: return "Swipe Editor"
        case .configurations: return "Configurations"
        }
    }

    public var systemImage: String {
        switch self {
        case .home: return "gauge.with.dots.needle.67percent"
        case .targetEditor: return "scope"
        case .swipeEditor: return "hand.draw"
        case .configurations: return "folder.badge.gearshape"
        }
    }
}
