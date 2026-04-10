import Foundation

/// Represents a recipe that is available locally (from `autopkg list-recipes`)
struct AutoPkgRecipe: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String

    /// Parse output from `autopkg list-recipes`
    /// Each line is a recipe identifier, e.g. "Firefox.munki"
    static func parse(from output: String) -> [AutoPkgRecipe] {
        output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { AutoPkgRecipe(name: $0) }
    }
}

/// Represents a search result from `autopkg search`
struct AutoPkgSearchResult: Identifiable, Hashable, Sendable {
    var id: String { "\(repo)/\(name)" }
    let name: String
    let repo: String
    let path: String

    /// Parse output from `autopkg search <query>`
    /// Format:
    /// Name                  Repo               Path
    /// ----                  ----               ----
    /// Firefox.download      autopkg/recipes    Recipes/Firefox/Firefox.download.recipe
    static func parse(from output: String) -> [AutoPkgSearchResult] {
        let lines = output.components(separatedBy: "\n")
        // Find the header separator line (contains "----")
        guard let separatorIndex = lines.firstIndex(where: { $0.contains("----") }) else {
            return []
        }
        return lines.dropFirst(separatorIndex + 1)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 3 else { return nil }
                return AutoPkgSearchResult(
                    name: String(parts[0]),
                    repo: String(parts[1]),
                    path: String(parts[2])
                )
            }
    }
}

/// Represents a recipe override file in ~/Library/AutoPkg/RecipeOverrides/
struct AutoPkgOverride: Identifiable, Hashable, Sendable {
    var id: String { filePath }
    let filePath: String
    let fileName: String

    /// The recipe name derived from the file name (strip extension)
    var recipeName: String {
        let name = (fileName as NSString).deletingPathExtension
        // .recipe files may have a double extension like Firefox.download.recipe
        return name
    }

    /// Read the file contents for display
    func contents() throws -> String {
        try String(contentsOfFile: filePath, encoding: .utf8)
    }

    /// List override files from the overrides directory
    static func listOverrides(in directory: String) -> [AutoPkgOverride] {
        let fm = FileManager.default
        let expandedDir = NSString(string: directory).expandingTildeInPath
        guard let files = try? fm.contentsOfDirectory(atPath: expandedDir) else {
            return []
        }
        return files
            .filter { $0.hasSuffix(".recipe") || $0.hasSuffix(".recipe.yaml") || $0.hasSuffix(".recipe.plist") }
            .sorted()
            .map { fileName in
                let fullPath = (expandedDir as NSString).appendingPathComponent(fileName)
                return AutoPkgOverride(filePath: fullPath, fileName: fileName)
            }
    }
}
