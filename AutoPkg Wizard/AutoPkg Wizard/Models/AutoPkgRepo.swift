import Foundation

/// Represents a single autopkg recipe repository
struct AutoPkgRepo: Identifiable, Hashable, Sendable {
    var id: String { path }
    let path: String
    let url: String

    /// Parse output from `autopkg repo-list` which outputs lines like:
    /// /Users/user/Library/AutoPkg/RecipeRepos/com.github.autopkg.recipes (https://github.com/autopkg/recipes.git)
    static func parse(from output: String) -> [AutoPkgRepo] {
        output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { line in
                // Format: /path/to/repo (URL)
                guard let parenStart = line.lastIndex(of: "("),
                      let parenEnd = line.lastIndex(of: ")") else {
                    return AutoPkgRepo(path: line, url: "")
                }
                let path = String(line[line.startIndex..<parenStart]).trimmingCharacters(in: .whitespaces)
                let url = String(line[line.index(after: parenStart)..<parenEnd])
                return AutoPkgRepo(path: path, url: url)
            }
    }

    /// Friendly display name derived from the repo path
    var displayName: String {
        // Extract the repo name from the path, e.g. "com.github.autopkg.grahampugh-recipes" -> "grahampugh-recipes"
        let lastComponent = (path as NSString).lastPathComponent
        if lastComponent.hasPrefix("com.github.autopkg.") {
            return String(lastComponent.dropFirst("com.github.autopkg.".count))
        }
        return lastComponent
    }
}
