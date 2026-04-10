import SwiftUI

@MainActor
@Observable
final class ScheduleViewModel {
    private let cli = AutoPkgCLI.shared

    var schedule: LaunchAgentManager.ScheduleConfig
    var isSaving = false
    var showError = false
    var errorMessage: String?
    var statusMessage: String?
    var nextRun: Date?
    var agentLoaded: Bool = false
    var lastRunDate: Date?

    init() {
        schedule = LaunchAgentManager.loadScheduleConfig()
        updateNextRun()
    }

    var selectedTime: Date {
        get {
            var components = DateComponents()
            components.hour = schedule.hour
            components.minute = schedule.minute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            schedule.hour = components.hour ?? 9
            schedule.minute = components.minute ?? 0
        }
    }

    func toggleDay(_ day: Int) {
        if schedule.selectedDays.contains(day) {
            if schedule.selectedDays.count > 1 {
                schedule.selectedDays.remove(day)
            }
        } else {
            schedule.selectedDays.insert(day)
        }
    }

    func selectAllDays() {
        schedule.selectedDays = Set(0...6)
    }

    func selectWeekdaysOnly() {
        schedule.selectedDays = Set(1...5)
    }

    func saveSchedule() {
        isSaving = true
        defer { isSaving = false }

        do {
            try LaunchAgentManager.saveSchedule(
                schedule,
                autoPkgPath: cli.autoPkgPath,
                recipeListPath: cli.recipeListPath
            )
            updateNextRun()
            if schedule.isEnabled {
                statusMessage = "Schedule saved and enabled."
            } else {
                statusMessage = "Schedule disabled."
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        // Refresh agent status asynchronously after save
        Task {
            await checkAgentStatus()
        }
    }

    func refreshStatus() {
        Task {
            await checkAgentStatus()
        }
    }

    private func checkAgentStatus() async {
        let loaded = await Task.detached {
            LaunchAgentManager.isAgentLoaded()
        }.value
        agentLoaded = loaded
        updateNextRun()
        updateLastRunDate()
    }

    private func updateNextRun() {
        nextRun = LaunchAgentManager.nextRunDate(for: schedule)
    }

    private func updateLastRunDate() {
        let logPath = NSString(string: "~/Library/Logs/\(LaunchAgentManager.agentLabel).log").expandingTildeInPath
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logPath),
           let modDate = attrs[.modificationDate] as? Date {
            lastRunDate = modDate
        } else {
            lastRunDate = nil
        }
    }
}
