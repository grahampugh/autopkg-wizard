import Foundation
import Testing
@testable import AutoPkg_Wizard

@Suite("AutoPkgOverride")
struct AutoPkgOverrideTests {

    @Test func recipeNameStripsRecipeSuffix() {
        let override = AutoPkgOverride(filePath: "/tmp/Firefox.munki.recipe", fileName: "Firefox.munki.recipe")
        #expect(override.recipeName == "Firefox.munki")
    }

    @Test func recipeNameStripsYamlSuffix() {
        let override = AutoPkgOverride(filePath: "/tmp/Firefox.munki.recipe.yaml", fileName: "Firefox.munki.recipe.yaml")
        #expect(override.recipeName == "Firefox.munki")
    }

    @Test func recipeNameStripsPlistSuffix() {
        let override = AutoPkgOverride(filePath: "/tmp/Firefox.munki.recipe.plist", fileName: "Firefox.munki.recipe.plist")
        #expect(override.recipeName == "Firefox.munki")
    }

    @Test func listOverridesReadsRecipeFilesFromDirectory() throws {
        let tmp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        // Three valid recipe overrides + one unrelated file
        try "".write(toFile: (tmp as NSString).appendingPathComponent("A.munki.recipe"), atomically: true, encoding: .utf8)
        try "".write(toFile: (tmp as NSString).appendingPathComponent("B.download.recipe.yaml"), atomically: true, encoding: .utf8)
        try "".write(toFile: (tmp as NSString).appendingPathComponent("C.pkg.recipe.plist"), atomically: true, encoding: .utf8)
        try "".write(toFile: (tmp as NSString).appendingPathComponent("ignore.txt"), atomically: true, encoding: .utf8)

        let overrides = AutoPkgOverride.listOverrides(in: tmp)
        let names = overrides.map(\.fileName).sorted()
        #expect(names == ["A.munki.recipe", "B.download.recipe.yaml", "C.pkg.recipe.plist"])
    }

    @Test func listOverridesReturnsEmptyForMissingDirectory() {
        let overrides = AutoPkgOverride.listOverrides(in: "/nonexistent/path/should/not/exist/\(UUID().uuidString)")
        #expect(overrides.isEmpty)
    }

    private func makeTempDirectory() throws -> String {
        let path = NSTemporaryDirectory() + "AutoPkgWizardTests-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }
}
