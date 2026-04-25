import Foundation
import Testing
@testable import AutoPkg_Wizard

@Suite("ScheduleViewModel")
@MainActor
struct ScheduleViewModelTests {

    private func makeViewModel() -> ScheduleViewModel {
        ScheduleViewModel(schedule: LaunchAgentManager.ScheduleConfig())
    }

    @Test func selectAllDaysSetsEveryWeekday() {
        let vm = makeViewModel()
        vm.schedule.selectedDays = [1]
        vm.selectAllDays()
        #expect(vm.schedule.selectedDays == Set(0...6))
    }

    @Test func selectWeekdaysOnlyExcludesWeekends() {
        let vm = makeViewModel()
        vm.selectWeekdaysOnly()
        #expect(vm.schedule.selectedDays == Set(1...5))
    }

    @Test func toggleDayAddsThenRemovesDay() {
        let vm = makeViewModel()
        vm.schedule.selectedDays = [1, 2, 3]

        vm.toggleDay(4)
        #expect(vm.schedule.selectedDays.contains(4))

        vm.toggleDay(4)
        #expect(vm.schedule.selectedDays.contains(4) == false)
    }

    @Test func toggleDayRefusesToEmptyTheSelection() {
        let vm = makeViewModel()
        vm.schedule.selectedDays = [3]
        vm.toggleDay(3)
        #expect(vm.schedule.selectedDays == [3])
    }

    @Test func selectedTimeSetterUpdatesHourAndMinute() throws {
        let vm = makeViewModel()
        var components = DateComponents()
        components.hour = 7
        components.minute = 45
        let date = try #require(Calendar.current.date(from: components))

        vm.selectedTime = date

        #expect(vm.schedule.hour == 7)
        #expect(vm.schedule.minute == 45)
    }
}
