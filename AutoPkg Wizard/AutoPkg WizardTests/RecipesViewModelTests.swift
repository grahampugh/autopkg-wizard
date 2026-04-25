import Testing
@testable import AutoPkg_Wizard

@Suite("RecipesViewModel")
@MainActor
struct RecipesViewModelTests {

    @Test(arguments: [
        ("Firefox.munki.recipe", "Firefox.munki"),
        ("Firefox.munki.recipe.yaml", "Firefox.munki"),
        ("Firefox.munki.recipe.plist", "Firefox.munki"),
        ("Firefox.munki", "Firefox.munki"),
    ])
    func strippedRecipeNameRemovesKnownSuffixes(input: String, expected: String) {
        #expect(RecipesViewModel.strippedRecipeName(input) == expected)
    }

    @Test func isInRecipeListMatchesAcrossSuffixVariants() {
        let vm = RecipesViewModel()
        vm.recipeList = ["Firefox.munki", "GoogleChrome.download"]

        #expect(vm.isInRecipeList("Firefox.munki"))
        #expect(vm.isInRecipeList("Firefox.munki.recipe"))
        #expect(vm.isInRecipeList("Firefox.munki.recipe.yaml"))
        #expect(vm.isInRecipeList("Slack.pkg") == false)
    }

    @Test func hasOverrideMatchesCaseInsensitively() {
        let vm = RecipesViewModel()
        vm.existingOverrides = ["firefox.munki"]

        #expect(vm.hasOverride("Firefox.munki"))
        #expect(vm.hasOverride("FIREFOX.MUNKI"))
        #expect(vm.hasOverride("Slack.pkg") == false)
    }
}
