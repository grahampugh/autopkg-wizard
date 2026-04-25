import Foundation
import Testing
@testable import AutoPkg_Wizard

@Suite("AutoPkgOverride")
struct AutoPkgOverrideTests {

    @Test(arguments: [
        ("Firefox.munki.recipe", "Firefox.munki"),
        ("Firefox.munki.recipe.yaml", "Firefox.munki"),
        ("Firefox.munki.recipe.plist", "Firefox.munki"),
    ])
    func recipeNameStripsKnownSuffixes(fileName: String, expected: String) {
        let override = AutoPkgOverride(filePath: "/tmp/\(fileName)", fileName: fileName)
        #expect(override.recipeName == expected)
    }

    @Test func listOverridesReadsRecipeFilesFromDirectory() throws {
        let tmp = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let recipeFiles = ["A.munki.recipe", "B.download.recipe.yaml", "C.pkg.recipe.plist"]
        for name in recipeFiles + ["ignore.txt"] {
            try Data().write(to: tmp.appendingPathComponent(name))
        }

        let overrides = AutoPkgOverride.listOverrides(in: tmp.path)
        #expect(overrides.map(\.fileName).sorted() == recipeFiles.sorted())
    }

    @Test func listOverridesReturnsEmptyForMissingDirectory() {
        let overrides = AutoPkgOverride.listOverrides(in: "/nonexistent/path/should/not/exist/\(UUID().uuidString)")
        #expect(overrides.isEmpty)
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoPkgWizardTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
