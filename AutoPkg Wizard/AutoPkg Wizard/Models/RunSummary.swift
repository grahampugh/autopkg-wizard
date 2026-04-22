import Foundation

/// Represents the summary section of an autopkg run output
struct RunSummary: Codable, Sendable {
    let date: Date
    let rawText: String
    let failedRecipes: [FailedRecipe]
    let downloadedItems: [DownloadedItem]
    let builtPackages: [BuiltPackage]

    struct FailedRecipe: Codable, Sendable {
        let name: String
        let reason: String
    }

    struct DownloadedItem: Codable, Sendable {
        let path: String
    }

    struct BuiltPackage: Codable, Sendable {
        let identifier: String
        let version: String
        let path: String
    }

    /// Whether the summary has any content worth showing
    var isEmpty: Bool {
        failedRecipes.isEmpty && downloadedItems.isEmpty && builtPackages.isEmpty
    }

    /// A short description for display
    var briefDescription: String {
        var parts: [String] = []
        if !failedRecipes.isEmpty {
            parts.append("\(failedRecipes.count) failed")
        }
        if !downloadedItems.isEmpty {
            parts.append("\(downloadedItems.count) downloaded")
        }
        if !builtPackages.isEmpty {
            parts.append("\(builtPackages.count) built")
        }
        return parts.isEmpty ? "No notable output" : parts.joined(separator: ", ")
    }

    // MARK: - Parsing

    /// Summary section markers
    private static let sectionHeaders = [
        "The following recipes failed:",
        "The following new items were downloaded:",
        "The following packages were built:",
        "The following new items were imported:",
        "The following new items were copied:",
    ]

    /// Extract the summary section from autopkg run output lines
    static func extract(from lines: [String]) -> RunSummary? {
        // Find the start of the summary — it begins with one of the known section headers
        // Summary is always at the end of the output
        let text = lines.joined(separator: "\n")

        guard let summaryStart = findSummaryStart(in: text) else {
            return nil
        }

        let summaryText = String(text[summaryStart...]).trimmingCharacters(in: .whitespacesAndNewlines)

        let failed = parseFailedRecipes(from: summaryText)
        let downloaded = parseDownloadedItems(from: summaryText)
        let built = parseBuiltPackages(from: summaryText)

        return RunSummary(
            date: Date(),
            rawText: summaryText,
            failedRecipes: failed,
            downloadedItems: downloaded,
            builtPackages: built
        )
    }

    /// Extract summary from a single string (e.g. log file contents)
    static func extract(from text: String) -> RunSummary? {
        let lines = text.components(separatedBy: "\n")
        return extract(from: lines)
    }

    private static func findSummaryStart(in text: String) -> String.Index? {
        // Find the first occurrence of any section header, searching from the end
        var earliestIndex: String.Index?
        for header in sectionHeaders {
            if let range = text.range(of: header, options: .backwards) {
                // Walk backwards to see if this is part of a cluster of section headers
                if earliestIndex == nil || range.lowerBound < earliestIndex! {
                    earliestIndex = range.lowerBound
                }
            }
        }

        // Now find the true start: walk backwards from the earliest header to find
        // where the summary block begins (there may be an empty line before it)
        guard var idx = earliestIndex else { return nil }

        // Look for any earlier section headers that are part of this same summary block
        // by searching the text before our earliest match
        let prefix = String(text[..<idx])
        for header in sectionHeaders {
            if let range = prefix.range(of: header, options: .backwards) {
                // Check that there's only whitespace between this header and the next section
                let between = String(text[range.lowerBound..<idx])
                // It's part of the same summary if it doesn't contain very long stretches of
                // non-summary text (recipe processing output). Accept if it's within ~2000 chars.
                if between.count < 3000 {
                    idx = range.lowerBound
                }
            }
        }

        return idx
    }

    private static func parseFailedRecipes(from text: String) -> [FailedRecipe] {
        guard let sectionText = extractSection(named: "The following recipes failed:", from: text) else {
            return []
        }

        var results: [FailedRecipe] = []
        let lines = sectionText.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            // A recipe name line is not empty and doesn't start with a known header
            if !line.isEmpty && !sectionHeaders.contains(where: { line.hasPrefix($0) }) {
                // The next line (if present and indented more) is the reason
                let reason: String
                if i + 1 < lines.count {
                    let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                    if !nextLine.isEmpty && !sectionHeaders.contains(where: { nextLine.hasPrefix($0) }) {
                        reason = nextLine
                        i += 2
                    } else {
                        reason = ""
                        i += 1
                    }
                } else {
                    reason = ""
                    i += 1
                }
                results.append(FailedRecipe(name: line, reason: reason))
            } else {
                i += 1
            }
        }
        return results
    }

    private static func parseDownloadedItems(from text: String) -> [DownloadedItem] {
        guard let sectionText = extractSection(named: "The following new items were downloaded:", from: text) else {
            return []
        }

        let lines = sectionText.components(separatedBy: "\n")
        var results: [DownloadedItem] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip header/separator lines and empty lines
            if trimmed.isEmpty || trimmed == "Download Path" || trimmed.allSatisfy({ $0 == "-" || $0 == " " }) {
                continue
            }
            results.append(DownloadedItem(path: trimmed))
        }
        return results
    }

    private static func parseBuiltPackages(from text: String) -> [BuiltPackage] {
        guard let sectionText = extractSection(named: "The following packages were built:", from: text) else {
            return []
        }

        let lines = sectionText.components(separatedBy: "\n")
        var results: [BuiltPackage] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip header/separator lines and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("Identifier") || trimmed.allSatisfy({ $0 == "-" || $0 == " " }) {
                continue
            }
            // Split by whitespace — columns are: Identifier, Version, Pkg Path
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count >= 3 {
                results.append(BuiltPackage(identifier: parts[0], version: parts[1], path: parts[2]))
            } else if parts.count == 2 {
                results.append(BuiltPackage(identifier: parts[0], version: parts[1], path: ""))
            } else if parts.count == 1 {
                results.append(BuiltPackage(identifier: parts[0], version: "", path: ""))
            }
        }
        return results
    }

    /// Extract the text content of a named section (between its header and the next section header or end)
    private static func extractSection(named header: String, from text: String) -> String? {
        guard let headerRange = text.range(of: header) else { return nil }

        let afterHeader = text[headerRange.upperBound...]

        // Find the next section header
        var endIndex = afterHeader.endIndex
        for otherHeader in sectionHeaders where otherHeader != header {
            if let range = afterHeader.range(of: otherHeader) {
                if range.lowerBound < endIndex {
                    endIndex = range.lowerBound
                }
            }
        }

        return String(afterHeader[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Persistence

    /// Path where the last run summary is saved
    static var summaryFilePath: String {
        NSString(string: "~/Library/AutoPkg/RunSummary.json").expandingTildeInPath
    }

    /// Save the summary to disk
    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)
            try data.write(to: URL(fileURLWithPath: Self.summaryFilePath))
        } catch {
            print("Failed to save run summary: \(error)")
        }
    }

    /// Load the last saved summary from disk
    static func load() -> RunSummary? {
        let path = summaryFilePath
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(RunSummary.self, from: data)
    }

    /// Load summary from the scheduled run log file
    static func loadFromScheduledLog() -> RunSummary? {
        let logPath = NSString(string: "~/Library/Logs/\(LaunchAgentManager.agentLabel).log").expandingTildeInPath
        guard FileManager.default.fileExists(atPath: logPath),
              let content = try? String(contentsOfFile: logPath, encoding: .utf8) else {
            return nil
        }

        // Get the log file modification date as the run date
        let logDate: Date
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logPath),
           let modDate = attrs[.modificationDate] as? Date {
            logDate = modDate
        } else {
            logDate = Date()
        }

        guard var summary = extract(from: content) else { return nil }
        // Override the date with the log file's modification date
        summary = RunSummary(
            date: logDate,
            rawText: summary.rawText,
            failedRecipes: summary.failedRecipes,
            downloadedItems: summary.downloadedItems,
            builtPackages: summary.builtPackages
        )
        return summary
    }
}
