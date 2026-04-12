import Foundation

/// Errors surfaced by AutoPkg CLI operations
enum AutoPkgError: LocalizedError, Sendable {
    case notInstalled(path: String)
    case commandFailed(command: String, exitCode: Int32, stderr: String)
    case parseError(detail: String)
    case fileError(detail: String)

    var errorDescription: String? {
        switch self {
        case .notInstalled(let path):
            "AutoPkg not found at \(path). Please install AutoPkg from https://github.com/autopkg/autopkg/releases"
        case .commandFailed(let command, let exitCode, let stderr):
            "Command '\(command)' failed (exit \(exitCode)): \(stderr)"
        case .parseError(let detail):
            "Failed to parse autopkg output: \(detail)"
        case .fileError(let detail):
            "File error: \(detail)"
        }
    }
}

/// Service layer that wraps the autopkg CLI binary.
/// All methods are isolated to @MainActor for simple UI binding.
@MainActor
@Observable
final class AutoPkgCLI {
    // MARK: - Singleton

    static let shared = AutoPkgCLI()

    // MARK: - Configuration

    /// Path to the autopkg binary
    var autoPkgPath: String {
        get { UserDefaults.standard.string(forKey: "autoPkgPath") ?? "/usr/local/bin/autopkg" }
        set { UserDefaults.standard.set(newValue, forKey: "autoPkgPath") }
    }

    /// Path to the recipe list file
    var recipeListPath: String {
        get {
            UserDefaults.standard.string(forKey: "recipeListPath")
                ?? NSString(string: "~/Library/AutoPkg/recipe-list.txt").expandingTildeInPath
        }
        set { UserDefaults.standard.set(newValue, forKey: "recipeListPath") }
    }

    /// Path to the recipe overrides directory
    var overridesDirectory: String {
        get {
            UserDefaults.standard.string(forKey: "overridesDirectory")
                ?? NSString(string: "~/Library/AutoPkg/RecipeOverrides").expandingTildeInPath
        }
        set { UserDefaults.standard.set(newValue, forKey: "overridesDirectory") }
    }

    // MARK: - State

    /// Whether autopkg is installed and accessible
    var isInstalled: Bool = false

    /// The installed autopkg version string
    var installedVersion: String = ""

    // MARK: - Init

    private init() {}

    // MARK: - Install Check

    /// Check if autopkg is installed and get version
    func checkInstallation() async {
        let path = autoPkgPath
        guard FileManager.default.isExecutableFile(atPath: path) else {
            isInstalled = false
            installedVersion = ""
            return
        }
        do {
            let version = try await runSimple(arguments: ["version"])
            installedVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
            isInstalled = true
        } catch {
            isInstalled = false
            installedVersion = ""
        }
    }

    // MARK: - Repo Operations

    /// List installed recipe repos
    func repoList() async throws -> [AutoPkgRepo] {
        let output = try await runSimple(arguments: ["repo-list"])
        return AutoPkgRepo.parse(from: output)
    }

    /// Add a recipe repo
    func repoAdd(_ repo: String) async throws -> String {
        try await runSimple(arguments: ["repo-add", repo])
    }

    /// Delete a recipe repo
    func repoDelete(_ repoPath: String) async throws -> String {
        try await runSimple(arguments: ["repo-delete", repoPath])
    }

    /// Update all recipe repos (streaming)
    func repoUpdate() -> (stream: AsyncStream<String>, task: Task<Int32, Never>) {
        runStreaming(arguments: ["repo-update", "all"])
    }

    // MARK: - Recipe Operations

    /// List locally available recipes
    func listRecipes() async throws -> [AutoPkgRecipe] {
        let output = try await runSimple(arguments: ["list-recipes"])
        return AutoPkgRecipe.parse(from: output)
    }

    /// Search for recipes
    func search(_ query: String) async throws -> [AutoPkgSearchResult] {
        let output = try await runSimple(arguments: ["search", query])
        return AutoPkgSearchResult.parse(from: output)
    }

    /// Run recipes from the configured recipe list (streaming)
    func runRecipeList(recipeListPath: String? = nil) -> (stream: AsyncStream<String>, task: Task<Int32, Never>) {
        let path = recipeListPath ?? self.recipeListPath
        let config = ArgumentsConfig.load()
        var args = ["run", "--recipe-list", path]
        args.append(contentsOf: config.buildArguments())
        return runStreaming(arguments: args)
    }

    /// Run a single recipe by name (streaming)
    func runRecipe(_ name: String) -> (stream: AsyncStream<String>, task: Task<Int32, Never>) {
        let config = ArgumentsConfig.load()
        var args = ["run", name]
        args.append(contentsOf: config.buildArguments())
        return runStreaming(arguments: args)
    }

    /// Get info about a recipe
    func recipeInfo(_ name: String) async throws -> String {
        try await runSimple(arguments: ["info", name])
    }

    // MARK: - Override Operations

    /// Create a recipe override
    func makeOverride(_ recipeName: String) async throws -> String {
        try await runSimple(arguments: ["make-override", recipeName])
    }

    /// Verify trust info for a recipe override
    func verifyTrustInfo(_ recipeName: String) async throws -> String {
        try await runSimple(arguments: ["verify-trust-info", recipeName])
    }

    /// Update trust info for a recipe override
    func updateTrustInfo(_ recipeName: String) async throws -> String {
        try await runSimple(arguments: ["update-trust-info", recipeName])
    }

    // MARK: - Recipe List File Management

    /// Read recipes from the recipe list file
    func readRecipeList() throws -> [String] {
        let path = recipeListPath
        let expandedPath = NSString(string: path).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return []
        }
        let content = try String(contentsOfFile: expandedPath, encoding: .utf8)
        return content.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// Write recipes to the recipe list file
    func writeRecipeList(_ recipes: [String]) throws {
        let path = recipeListPath
        let expandedPath = NSString(string: path).expandingTildeInPath

        // Ensure directory exists
        let directory = (expandedPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        let content = recipes.joined(separator: "\n") + "\n"
        try content.write(toFile: expandedPath, atomically: true, encoding: .utf8)
    }

    // MARK: - Private Helpers

    /// Run an autopkg command and return the full stdout output
    @discardableResult
    private func runSimple(arguments: [String]) async throws -> String {
        let path = autoPkgPath
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw AutoPkgError.notInstalled(path: path)
        }

        let args = arguments
        return try await Task.detached {
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                throw AutoPkgError.commandFailed(
                    command: "autopkg \(args.joined(separator: " "))",
                    exitCode: -1,
                    stderr: error.localizedDescription
                )
            }

            // Read pipe data BEFORE waitUntilExit to avoid deadlock when
            // the output exceeds the pipe buffer size (~64 KB).
            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            process.waitUntilExit()

            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""

            if process.terminationStatus != 0 {
                throw AutoPkgError.commandFailed(
                    command: "autopkg \(args.joined(separator: " "))",
                    exitCode: process.terminationStatus,
                    stderr: stderr
                )
            }
            return stdout
        }.value
    }

    /// Run an autopkg command with real-time streaming output via AsyncStream
    private nonisolated func runStreaming(arguments: [String]) -> (stream: AsyncStream<String>, task: Task<Int32, Never>) {
        let path = MainActor.assumeIsolated { self.autoPkgPath }
        var streamContinuation: AsyncStream<String>.Continuation?

        let stream = AsyncStream<String> { continuation in
            streamContinuation = continuation
        }

        let task = Task<Int32, Never>.detached { [streamContinuation] in
            guard let continuation = streamContinuation else { return -1 }

            guard FileManager.default.isExecutableFile(atPath: path) else {
                continuation.yield("ERROR: AutoPkg not found at \(path)")
                continuation.finish()
                return -1
            }

            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            // Stream stdout line by line
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { return }
                if let str = String(data: data, encoding: .utf8) {
                    let lines = str.components(separatedBy: "\n")
                    for line in lines where !line.isEmpty {
                        continuation.yield(line)
                    }
                }
            }

            // Stream stderr line by line
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { return }
                if let str = String(data: data, encoding: .utf8) {
                    let lines = str.components(separatedBy: "\n")
                    for line in lines where !line.isEmpty {
                        continuation.yield("⚠️ \(line)")
                    }
                }
            }

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                continuation.yield("ERROR: \(error.localizedDescription)")
            }

            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            continuation.finish()

            return process.terminationStatus
        }

        return (stream, task)
    }
}
