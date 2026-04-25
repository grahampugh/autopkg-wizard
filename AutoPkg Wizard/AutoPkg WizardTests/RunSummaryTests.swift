import Foundation
import Testing
@testable import AutoPkg_Wizard

@Suite("RunSummary")
struct RunSummaryTests {

    @Test func extractsBuiltPackagesAndDownloads() {
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

        let summary = RunSummary.extract(from: output)
        #expect(summary != nil)
        #expect(summary?.downloadedItems.count == 1)
        #expect(summary?.downloadedItems.first?.path == "/tmp/Firefox-130.0.dmg")
        #expect(summary?.builtPackages.count == 1)
        #expect(summary?.builtPackages.first?.identifier == "com.example.firefox")
        #expect(summary?.builtPackages.first?.version == "130.0")
        #expect(summary?.builtPackages.first?.path == "/pkgs/Firefox-130.0.pkg")
        #expect(summary?.failedRecipes.isEmpty == true)
    }

    @Test func extractsFailedRecipesWithReasons() {
        let output = """
        Processing began.

        The following recipes failed:
            Firefox.munki
                No recipe found.
        """
        let summary = RunSummary.extract(from: output)
        #expect(summary?.failedRecipes.count == 1)
        #expect(summary?.failedRecipes.first?.name == "Firefox.munki")
        #expect(summary?.failedRecipes.first?.reason == "No recipe found.")
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
