import Foundation

/// Configuration for additional autopkg run arguments
struct ArgumentsConfig: Codable, Sendable, Equatable {
    /// Verbosity level: 0 = quiet, 1 = -v, 2 = -vv, 3 = -vvv, 4 = -vvvv
    var verbosity: Int = 1

    /// Pre-processor names (each becomes --pre=NAME when enabled)
    var preProcessors: [ToggleableItem] = []

    /// Post-processor names (each becomes --post=NAME when enabled)
    var postProcessors: [ToggleableItem] = []

    /// Key-value pairs (each becomes --key=KEY=VALUE when enabled)
    var keyValuePairs: [KeyValuePair] = []

    /// Source packages (only one can be enabled at a time, becomes --pkg=PATH)
    var sourcePackages: [ToggleableItem] = []

    /// A named item that can be enabled or disabled
    struct ToggleableItem: Codable, Sendable, Equatable, Identifiable {
        var id = UUID()
        var name: String
        var isEnabled: Bool = true
    }

    struct KeyValuePair: Codable, Sendable, Equatable, Identifiable {
        var id = UUID()
        var key: String
        var value: String
        var isEnabled: Bool = true
    }

    // MARK: - Persistence

    private static var configPath: String {
        NSString(string: "~/Library/AutoPkg/ArgumentsConfig.json").expandingTildeInPath
    }

    /// Save configuration to disk
    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(self)
        let dir = (Self.configPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: Self.configPath))
    }

    /// Load configuration from disk
    static func load() -> ArgumentsConfig {
        let path = configPath
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let config = try? JSONDecoder().decode(ArgumentsConfig.self, from: data) else {
            return ArgumentsConfig()
        }
        return config
    }

    // MARK: - Build CLI Arguments

    /// Convert configuration into an array of CLI argument strings for autopkg run
    func buildArguments() -> [String] {
        var args: [String] = []

        // Verbosity
        if verbosity > 0 {
            args.append("-" + String(repeating: "v", count: verbosity))
        }

        // Pre-processors (only enabled)
        for pre in preProcessors where pre.isEnabled && !pre.name.isEmpty {
            args.append("--pre=\(pre.name)")
        }

        // Post-processors (only enabled)
        for post in postProcessors where post.isEnabled && !post.name.isEmpty {
            args.append("--post=\(post.name)")
        }

        // Key-value pairs (only enabled)
        for kv in keyValuePairs where kv.isEnabled && !kv.key.isEmpty {
            args.append("--key=\(kv.key)=\(kv.value)")
        }

        // Source package (only the first enabled one)
        if let pkg = sourcePackages.first(where: { $0.isEnabled && !$0.name.isEmpty }) {
            args.append("--pkg=\(pkg.name)")
        }

        return args
    }

    /// Verbosity description for display
    var verbosityDescription: String {
        switch verbosity {
        case 0: return "Quiet (no verbose output)"
        case 1: return "Normal (-v)"
        case 2: return "Verbose (-vv)"
        case 3: return "Very Verbose (-vvv)"
        case 4: return "Debug (-vvvv)"
        default: return "Unknown"
        }
    }
}
