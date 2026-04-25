import Foundation
import Testing
@testable import AutoPkg_Wizard

@Suite("ScheduleViewModel", .serialized)
@MainActor
struct ScheduleViewModelTests {

    @Test func selectAllDaysSetsEveryWeekday() {
        let vm = ScheduleViewModel()
        vm.schedule.selectedDays = [1]
        vm.selectAllDays()
        #expect(vm.schedule.selectedDays == Set(0...6))
    }

    @Test func selectWeekdaysOnlyExcludesWeekends() {
        let vm = ScheduleViewModel()
        vm.selectWeekdaysOnly()
        #expect(vm.schedule.selectedDays == Set(1...5))
    }

    @Test func toggleDayAddsThenRemovesDay() {
        let vm = ScheduleViewModel()
        vm.schedule.selectedDays = [1, 2, 3]

        vm.toggleDay(4)
        #expect(vm.schedule.selectedDays.contains(4))

        vm.toggleDay(4)
        #expect(vm.schedule.selectedDays.contains(4) == false)
    }

    @Test func toggleDayRefusesToEmptyTheSelection() {
        let vm = ScheduleViewModel()
        vm.schedule.selectedDays = [3]
        vm.toggleDay(3)
        #expect(vm.schedule.selectedDays == [3])
    }

    @Test func selectedTimeSetterUpdatesHourAndMinute() {
        let vm = ScheduleViewModel()
        var components = DateComponents()
        components.hour = 7
        components.minute = 45
        let date = Calendar.current.date(from: components)!

        vm.selectedTime = date

        #expect(vm.schedule.hour == 7)
        #expect(vm.schedule.minute == 45)
    }
}
