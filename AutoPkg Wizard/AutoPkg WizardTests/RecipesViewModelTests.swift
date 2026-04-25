import Testing
@testable import AutoPkg_Wizard

@Suite("RecipesViewModel", .serialized)
@MainActor
struct RecipesViewModelTests {

    @Test func strippedRecipeNameRemovesPlainRecipeSuffix() {
        #expect(RecipesViewModel.strippedRecipeName("Firefox.munki.recipe") == "Firefox.munki")
    }

    @Test func strippedRecipeNameRemovesYamlSuffix() {
        #expect(RecipesViewModel.strippedRecipeName("Firefox.munki.recipe.yaml") == "Firefox.munki")
    }

    @Test func strippedRecipeNameRemovesPlistSuffix() {
        #expect(RecipesViewModel.strippedRecipeName("Firefox.munki.recipe.plist") == "Firefox.munki")
    }

    @Test func strippedRecipeNameLeavesBareIdentifierUnchanged() {
        #expect(RecipesViewModel.strippedRecipeName("Firefox.munki") == "Firefox.munki")
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
