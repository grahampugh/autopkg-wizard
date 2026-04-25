import Foundation
import Testing
@testable import AutoPkg_Wizard

@Suite("LaunchAgentManager")
struct LaunchAgentManagerTests {

    @Test func defaultScheduleConfigIsDisabledAtNineAmAllDays() {
        let config = LaunchAgentManager.ScheduleConfig()
        #expect(config.isEnabled == false)
        #expect(config.hour == 9)
        #expect(config.minute == 0)
        #expect(config.selectedDays == Set(0...6))
    }

    @Test func nextRunDateIsNilWhenScheduleDisabled() {
        var config = LaunchAgentManager.ScheduleConfig()
        config.isEnabled = false
        #expect(LaunchAgentManager.nextRunDate(for: config) == nil)
    }

    @Test func nextRunDateIsNilWhenNoDaysSelected() {
        var config = LaunchAgentManager.ScheduleConfig()
        config.isEnabled = true
        config.selectedDays = []
        #expect(LaunchAgentManager.nextRunDate(for: config) == nil)
    }

    @Test func nextRunDateIsInFutureForEnabledSchedule() throws {
        var config = LaunchAgentManager.ScheduleConfig()
        config.isEnabled = true
        config.hour = 9
        config.minute = 0
        config.selectedDays = Set(0...6)

        let next = try #require(LaunchAgentManager.nextRunDate(for: config))
        #expect(next > Date())
    }

    @Test func nextRunDateMatchesConfiguredHourAndMinute() throws {
        var config = LaunchAgentManager.ScheduleConfig()
        config.isEnabled = true
        config.hour = 14
        config.minute = 30
        config.selectedDays = Set(0...6)

        let next = try #require(LaunchAgentManager.nextRunDate(for: config))
        let components = Calendar.current.dateComponents([.hour, .minute], from: next)
        #expect(components.hour == 14)
        #expect(components.minute == 30)
    }
}
