import Foundation

/// Sidebar navigation items
enum SidebarItem: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case repos = "Repos"
    case recipes = "Recipes"
    case overrides = "Overrides"
    case schedule = "Schedule"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .overview: "house"
        case .repos: "folder"
        case .recipes: "list.bullet.rectangle"
        case .overrides: "doc.on.doc"
        case .schedule: "clock"
        }
    }
}
