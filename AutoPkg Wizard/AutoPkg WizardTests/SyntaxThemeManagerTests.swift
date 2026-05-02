import AppKit
import Testing
@testable import AutoPkg_Wizard

@Suite("SyntaxThemeManager")
@MainActor
struct SyntaxThemeManagerTests {

    private var manager: SyntaxThemeManager { SyntaxThemeManager.shared }

    @Test func defaultLightThemeIsXcode() {
        // Reset to defaults for test isolation
        UserDefaults.standard.removeObject(forKey: "syntaxThemeLight")
        let mgr = SyntaxThemeManager.shared
        #expect(mgr.lightTheme == "xcode")
    }

    @Test func defaultDarkThemeIsAtomOneDark() {
        UserDefaults.standard.removeObject(forKey: "syntaxThemeDark")
        let mgr = SyntaxThemeManager.shared
        #expect(mgr.darkTheme == "atom-one-dark")
    }

    @Test func currentThemeReturnsDarkThemeForDarkAppearance() {
        let mgr = manager
        let original = mgr.darkTheme
        defer { mgr.darkTheme = original }

        mgr.darkTheme = "dracula"
        let darkAppearance = NSAppearance(named: .darkAqua)
        #expect(mgr.currentTheme(for: darkAppearance) == "dracula")
    }

    @Test func currentThemeReturnsLightThemeForLightAppearance() {
        let mgr = manager
        let original = mgr.lightTheme
        defer { mgr.lightTheme = original }

        mgr.lightTheme = "github"
        let lightAppearance = NSAppearance(named: .aqua)
        #expect(mgr.currentTheme(for: lightAppearance) == "github")
    }

    @Test func currentThemeReturnsLightThemeForNilAppearance() {
        let mgr = manager
        let original = mgr.lightTheme
        defer { mgr.lightTheme = original }

        mgr.lightTheme = "vs"
        #expect(mgr.currentTheme(for: nil) == "vs")
    }

    @Test func availableThemesIsNotEmpty() {
        #expect(!manager.availableThemes.isEmpty)
    }

    @Test func availableThemesContainsDefaults() {
        let themes = manager.availableThemes
        #expect(themes.contains("xcode"))
        #expect(themes.contains("atom-one-dark"))
    }

    @Test func recommendedDarkThemesAreNotEmpty() {
        #expect(!SyntaxThemeManager.recommendedDarkThemes.isEmpty)
    }

    @Test func recommendedLightThemesAreNotEmpty() {
        #expect(!SyntaxThemeManager.recommendedLightThemes.isEmpty)
    }

    @Test func settingThemePersistsToUserDefaults() {
        let mgr = manager
        let original = mgr.lightTheme
        defer { mgr.lightTheme = original }

        mgr.lightTheme = "monokai"
        #expect(UserDefaults.standard.string(forKey: "syntaxThemeLight") == "monokai")
    }
}
