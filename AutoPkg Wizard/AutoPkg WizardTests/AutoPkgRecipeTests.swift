import Testing
@testable import AutoPkg_Wizard

@Suite("AutoPkgRecipe")
struct AutoPkgRecipeTests {

    @Test func parsesRecipesAndDropsBlankLines() {
        let output = """
        Firefox.munki
        GoogleChrome.download

        Slack.pkg
        """
        let recipes = AutoPkgRecipe.parse(from: output)
        #expect(recipes.map(\.name) == ["Firefox.munki", "GoogleChrome.download", "Slack.pkg"])
    }

    @Test func parseEmptyOutputReturnsEmpty() {
        #expect(AutoPkgRecipe.parse(from: "").isEmpty)
    }
}

@Suite("AutoPkgSearchResult")
struct AutoPkgSearchResultTests {

    @Test func parsesTabularSearchOutput() {
        let output = """
        Name                  Repo               Path
        ----                  ----               ----
        Firefox.download      autopkg/recipes    Recipes/Firefox/Firefox.download.recipe
        Firefox.munki         autopkg/recipes    Recipes/Firefox/Firefox.munki.recipe
        """
        let results = AutoPkgSearchResult.parse(from: output)
        #expect(results.count == 2)
        #expect(results[0].name == "Firefox.download")
        #expect(results[0].repo == "autopkg/recipes")
        #expect(results[0].path == "Recipes/Firefox/Firefox.download.recipe")
    }

    @Test func parseWithoutSeparatorReturnsEmpty() {
        let output = "no header here just random text"
        #expect(AutoPkgSearchResult.parse(from: output).isEmpty)
    }
}
