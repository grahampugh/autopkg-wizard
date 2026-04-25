import Testing
@testable import AutoPkg_Wizard

/// Smoke test that the test target links against the app and Swift Testing is wired up.
@Test func sidebarItemsAreUnique() {
    let ids = SidebarItem.allCases.map(\.id)
    #expect(Set(ids).count == ids.count)
}
