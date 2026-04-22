import SwiftUI

@MainActor
@Observable
final class OverviewViewModel {
    private let cli = AutoPkgCLI.shared

    var repoCount: Int = 0
    var recipeCount: Int = 0
    var overrideCount: Int = 0

    var showPreferences = false
    var preferences: [PreferenceItem] = []
    var showError = false
    var errorMessage: String?

    /// Keys to exclude from the preferences editor (managed elsewhere)
    private static let excludedKeys: Set<String> = ["RECIPE_REPOS", "RECIPE_SEARCH_DIRS"]

    /// Represents a single autopkg preference key/value pair
    struct PreferenceItem: Identifiable {
        let id = UUID()
        var key: String
        var value: String
        var originalKey: String? // nil for new items

        /// Whether this is a newly added item (not yet saved)
        var isNew: Bool { originalKey == nil }
    }

    // MARK: - Loading

    func loadCounts() async {
        do {
            let repos = try await cli.repoList()
            repoCount = repos.count
        } catch {
            repoCount = 0
        }

        do {
            let recipes = try cli.readRecipeList()
            recipeCount = recipes.count
        } catch {
            recipeCount = 0
        }

        let overrides = AutoPkgOverride.listOverrides(in: cli.overridesDirectory)
        overrideCount = overrides.count
    }

    // MARK: - Preferences

    private static let defaultsDomain = "com.github.autopkg"

    func loadPreferences() {
        guard let dict = UserDefaults.standard.persistentDomain(forName: Self.defaultsDomain) else {
            preferences = []
            return
        }

        preferences = dict
            .filter { !Self.excludedKeys.contains($0.key) }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { key, value in
                PreferenceItem(
                    key: key,
                    value: Self.stringValue(from: value),
                    originalKey: key
                )
            }
    }

    func savePreference(_ item: PreferenceItem) {
        let defaults = UserDefaults(suiteName: Self.defaultsDomain)

        // If the key was renamed, delete the old one
        if let originalKey = item.originalKey, originalKey != item.key {
            defaults?.removeObject(forKey: originalKey)
        }

        // Write the value — try to preserve type
        let parsed = Self.parseValue(item.value)
        defaults?.set(parsed, forKey: item.key)
        defaults?.synchronize()

        loadPreferences()
    }

    func deletePreference(_ item: PreferenceItem) {
        let keyToDelete = item.originalKey ?? item.key
        let defaults = UserDefaults(suiteName: Self.defaultsDomain)
        defaults?.removeObject(forKey: keyToDelete)
        defaults?.synchronize()

        loadPreferences()
    }

    @discardableResult
    func addNewPreference() -> PreferenceItem {
        let item = PreferenceItem(key: "", value: "", originalKey: nil)
        preferences.append(item)
        return item
    }

    // MARK: - Helpers

    private static func stringValue(from value: Any) -> String {
        switch value {
        case let bool as Bool:
            return bool ? "true" : "false"
        case let number as NSNumber:
            return number.stringValue
        case let string as String:
            return string
        case let array as [Any]:
            return array.map { stringValue(from: $0) }.joined(separator: ", ")
        case let dict as [String: Any]:
            return dict.map { "\($0.key)=\(stringValue(from: $0.value))" }.joined(separator: "; ")
        default:
            return String(describing: value)
        }
    }

    private static func parseValue(_ string: String) -> Any {
        let lower = string.lowercased()
        if lower == "true" || lower == "yes" { return true }
        if lower == "false" || lower == "no" { return false }
        if let intVal = Int(string) { return intVal }
        if string.contains("."), let doubleVal = Double(string) { return doubleVal }
        return string
    }
}
