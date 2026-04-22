import Foundation

/// Manages the launchd LaunchAgent for scheduling autopkg runs
struct LaunchAgentManager: Sendable {
    nonisolated static let agentLabel = "com.github.autopkg.wizard.runner"
    nonisolated static var agentPlistPath: String {
        NSString(string: "~/Library/LaunchAgents/\(agentLabel).plist").expandingTildeInPath
    }

    /// Schedule configuration
    struct ScheduleConfig: Codable, Sendable, Equatable {
        var isEnabled: Bool = false
        var hour: Int = 9
        var minute: Int = 0
        var selectedDays: Set<Int> = Set(0...6) // 0=Sunday ... 6=Saturday

        /// Day names for display
        static let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        static let dayAbbreviations = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }

    /// Load current schedule configuration from the plist if it exists.
    /// Does not check agent loaded state (that requires a Process call).
    static func loadScheduleConfig() -> ScheduleConfig {
        let path = agentPlistPath
        guard FileManager.default.fileExists(atPath: path),
              let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return ScheduleConfig()
        }

        var config = ScheduleConfig()
        // If the plist exists, the schedule was saved as enabled
        config.isEnabled = true

        // Parse StartCalendarInterval
        if let intervals = plist["StartCalendarInterval"] as? [[String: Int]] {
            if let first = intervals.first {
                config.hour = first["Hour"] ?? 9
                config.minute = first["Minute"] ?? 0
            }
            config.selectedDays = Set(intervals.compactMap { $0["Weekday"] })
        } else if let interval = plist["StartCalendarInterval"] as? [String: Int] {
            config.hour = interval["Hour"] ?? 9
            config.minute = interval["Minute"] ?? 0
            config.selectedDays = Set(0...6) // all days
        }

        return config
    }

    /// Write and optionally load the launch agent
    static func saveSchedule(_ config: ScheduleConfig, autoPkgPath: String, recipeListPath: String) throws {
        // Unload existing agent first
        if isAgentLoaded() {
            unloadAgent()
        }

        if !config.isEnabled {
            // Remove the plist if disabled
            try? FileManager.default.removeItem(atPath: agentPlistPath)
            return
        }

        // Build calendar intervals
        let intervals: [[String: Int]] = config.selectedDays.sorted().map { day in
            [
                "Hour": config.hour,
                "Minute": config.minute,
                "Weekday": day
            ]
        }

        // Build program arguments including user-configured run arguments
        let argsConfig = ArgumentsConfig.load()
        var programArgs = [autoPkgPath, "run", "--recipe-list", recipeListPath]
        programArgs.append(contentsOf: argsConfig.buildArguments())

        // Build the launch agent plist
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": programArgs,
            "StartCalendarInterval": intervals,
            "StandardOutPath": NSString(string: "~/Library/Logs/\(agentLabel).log").expandingTildeInPath,
            "StandardErrorPath": NSString(string: "~/Library/Logs/\(agentLabel).error.log").expandingTildeInPath,
            "RunAtLoad": false,
            "Nice": 5
        ]

        // Ensure LaunchAgents directory exists
        let launchAgentsDir = (agentPlistPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)

        // Write the plist
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: URL(fileURLWithPath: agentPlistPath))

        // Load the agent
        if config.isEnabled {
            loadAgent()
        }
    }

    /// Check if the agent is currently loaded
    nonisolated static func isAgentLoaded() -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", agentLabel]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Load the agent using launchctl
    nonisolated static func loadAgent() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        let uid = getuid()
        process.arguments = ["bootstrap", "gui/\(uid)", agentPlistPath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    /// Unload the agent using launchctl
    nonisolated static func unloadAgent() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        let uid = getuid()
        process.arguments = ["bootout", "gui/\(uid)/\(agentLabel)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    /// Calculate next scheduled run date
    static func nextRunDate(for config: ScheduleConfig) -> Date? {
        guard config.isEnabled, !config.selectedDays.isEmpty else { return nil }

        let calendar = Calendar.current
        let now = Date()
        let currentWeekday = calendar.component(.weekday, from: now) - 1 // 0-based Sunday

        // Sort days and find next one
        let sortedDays = config.selectedDays.sorted()

        for dayOffset in 0..<7 {
            let candidateDay = (currentWeekday + dayOffset) % 7
            guard sortedDays.contains(candidateDay) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = config.hour
            components.minute = config.minute
            components.second = 0

            if let candidateDate = calendar.date(from: components) {
                let adjustedDate = calendar.date(byAdding: .day, value: dayOffset, to: candidateDate)!
                if adjustedDate > now {
                    return adjustedDate
                }
            }
        }

        // Wrap around to next week
        if let firstDay = sortedDays.first {
            let daysUntil = (firstDay - currentWeekday + 7) % 7
            let adjustedDays = daysUntil == 0 ? 7 : daysUntil
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = config.hour
            components.minute = config.minute
            components.second = 0
            if let base = calendar.date(from: components) {
                return calendar.date(byAdding: .day, value: adjustedDays, to: base)
            }
        }

        return nil
    }
}
