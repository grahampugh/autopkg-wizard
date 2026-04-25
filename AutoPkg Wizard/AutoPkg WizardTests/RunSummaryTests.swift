import Foundation
import Testing
@testable import AutoPkg_Wizard

@Suite("RunSummary")
struct RunSummaryTests {

    @Test func extractsBuiltPackagesAndDownloads() throws {
        let output = """
        Processing Firefox.download...
        ... (lots of recipe output)

        The following new items were downloaded:
            Download Path
            -------------
            /tmp/Firefox-130.0.dmg

        The following packages were built:
            Identifier                                Version  Pkg Path
            ----------                                -------  --------
            com.example.firefox                       130.0    /pkgs/Firefox-130.0.pkg
        """

        let summary = try #require(RunSummary.extract(from: output))
        #expect(summary.downloadedItems.map(\.path) == ["/tmp/Firefox-130.0.dmg"])
        #expect(summary.builtPackages.count == 1)
        let built = try #require(summary.builtPackages.first)
        #expect(built.identifier == "com.example.firefox")
        #expect(built.version == "130.0")
        #expect(built.path == "/pkgs/Firefox-130.0.pkg")
        #expect(summary.failedRecipes.isEmpty)
    }

    @Test func extractsFailedRecipesWithReasons() throws {
        let output = """
        Processing began.

        The following recipes failed:
            Firefox.munki
                No recipe found.
        """
        let summary = try #require(RunSummary.extract(from: output))
        #expect(summary.failedRecipes.count == 1)
        let failed = try #require(summary.failedRecipes.first)
        #expect(failed.name == "Firefox.munki")
        #expect(failed.reason == "No recipe found.")
    }

    @Test func extractReturnsNilWhenNoSummarySectionPresent() {
        let summary = RunSummary.extract(from: "Processing Firefox... done.\n")
        #expect(summary == nil)
    }

    @Test func briefDescriptionSummarizesCounts() {
        let summary = RunSummary(
            date: .init(),
            rawText: "",
            failedRecipes: [.init(name: "X", reason: "")],
            downloadedItems: [.init(path: "/a"), .init(path: "/b")],
            builtPackages: []
        )
        #expect(summary.briefDescription == "1 failed, 2 downloaded")
        #expect(summary.isEmpty == false)
    }

    @Test func emptySummaryReportsNoOutput() {
        let summary = RunSummary(
            date: .init(),
            rawText: "",
            failedRecipes: [],
            downloadedItems: [],
            builtPackages: []
        )
        #expect(summary.isEmpty)
        #expect(summary.briefDescription == "No notable output")
    }
}
