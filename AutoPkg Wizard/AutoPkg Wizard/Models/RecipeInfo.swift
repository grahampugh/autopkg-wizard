import Foundation

/// Parsed representation of `autopkg info <recipe>` output.
struct RecipeInfo {
    let description: String
    let identifier: String
    let munkiImportRecipe: String
    let hasCheckPhase: String
    let buildsPackage: String
    let recipeFilePath: String
    let parentRecipes: [String]
    let inputValues: [(key: String, value: String)]

    /// Parse the output of `autopkg info <recipe>`.
    ///
    /// The format has two sections:
    /// 1. Key-value header lines like `Description:         some text`
    ///    with continuation lines indented to the same column.
    /// 2. An `Input values:` section containing Python dict-style entries
    ///    like `    'KEY': 'value',`
    static func parse(from output: String) -> RecipeInfo {
        let lines = output.components(separatedBy: "\n")

        var description = ""
        var identifier = ""
        var munkiImport = ""
        var checkPhase = ""
        var buildsPackage = ""
        var filePath = ""
        var parentRecipes: [String] = []
        var inputValues: [(key: String, value: String)] = []

        var inInputValues = false
        var currentKey: String?
        var currentValue: String = ""

        for line in lines {
            // Detect start of Input values section
            if line.hasPrefix("Input values:") {
                inInputValues = true
                continue
            }

            if inInputValues {
                parseInputLine(line, keys: &inputValues)
            } else {
                // Header key-value section
                if let (key, value) = parseHeaderLine(line) {
                    // Save previous multi-line key
                    saveHeaderField(
                        key: currentKey, value: currentValue,
                        description: &description, identifier: &identifier,
                        munkiImport: &munkiImport, checkPhase: &checkPhase,
                        buildsPackage: &buildsPackage, filePath: &filePath,
                        parentRecipes: &parentRecipes
                    )
                    currentKey = key
                    currentValue = value
                } else if currentKey != nil {
                    // Continuation line (indented)
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        if currentKey == "Parent recipe(s)" {
                            // Each continuation line is another parent recipe
                            currentValue += "\n" + trimmed
                        } else {
                            currentValue += "\n" + trimmed
                        }
                    }
                }
            }
        }
        // Save last header field
        saveHeaderField(
            key: currentKey, value: currentValue,
            description: &description, identifier: &identifier,
            munkiImport: &munkiImport, checkPhase: &checkPhase,
            buildsPackage: &buildsPackage, filePath: &filePath,
            parentRecipes: &parentRecipes
        )

        return RecipeInfo(
            description: description,
            identifier: identifier,
            munkiImportRecipe: munkiImport,
            hasCheckPhase: checkPhase,
            buildsPackage: buildsPackage,
            recipeFilePath: filePath,
            parentRecipes: parentRecipes,
            inputValues: inputValues
        )
    }

    // MARK: - Private Helpers

    /// Parse a header line of the form `Label:           value`
    private static func parseHeaderLine(_ line: String) -> (key: String, value: String)? {
        // Header keys start at column 0 and are followed by `:` then spaces
        guard let colonRange = line.range(of: ":") else { return nil }
        let key = String(line[line.startIndex..<colonRange.lowerBound])
        // Keys should not start with whitespace (that would be a continuation)
        guard !key.isEmpty, !key.hasPrefix(" "), !key.hasPrefix("'") else { return nil }
        let value = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        return (key, value)
    }

    /// Save a completed header field into the appropriate property.
    private static func saveHeaderField(
        key: String?, value: String,
        description: inout String, identifier: inout String,
        munkiImport: inout String, checkPhase: inout String,
        buildsPackage: inout String, filePath: inout String,
        parentRecipes: inout [String]
    ) {
        guard let key else { return }
        switch key {
        case "Description":
            description = value
        case "Identifier":
            identifier = value
        case "Munki import recipe":
            munkiImport = value
        case "Has check phase":
            checkPhase = value
        case "Builds package":
            buildsPackage = value
        case "Recipe file path":
            filePath = value
        case "Parent recipe(s)":
            parentRecipes = value.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        default:
            break
        }
    }

    /// Parse a single line from the Input values section.
    /// Lines look like:  `    'KEY': 'value',`  or  `    'KEY': value,`
    private static func parseInputLine(_ line: String, keys: inout [(key: String, value: String)]) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Match lines starting with 'KEY':
        // The key is always quoted with single quotes
        guard trimmed.hasPrefix("'") else {
            // Continuation of a previous value (e.g. nested dict) – append to last entry
            if !keys.isEmpty {
                keys[keys.count - 1].value += "\n" + trimmed
            }
            return
        }

        guard let keyEnd = trimmed.range(of: "': ") ?? trimmed.range(of: "':") else { return }
        let key = String(trimmed[trimmed.index(after: trimmed.startIndex)..<keyEnd.lowerBound])
        var value = String(trimmed[keyEnd.upperBound...])
            .trimmingCharacters(in: .whitespaces)

        // Strip trailing comma
        if value.hasSuffix(",") {
            value = String(value.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        // Strip surrounding single quotes
        if value.hasPrefix("'") && value.hasSuffix("'") && value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        }

        keys.append((key: key, value: value))
    }
}
