import Testing
@testable import AutoPkg_Wizard

@Suite("RecipeInfo")
struct RecipeInfoTests {

    @Test func parsesHeaderFieldsAndInputValues() {
        let output = """
        Description:         Downloads the latest Firefox.
        Identifier:          com.github.autopkg.download.Firefox
        Munki import recipe: False
        Has check phase:     True
        Builds package:      False
        Recipe file path:    /Users/jane/Library/AutoPkg/RecipeRepos/com.github.autopkg.recipes/Firefox/Firefox.download.recipe
        Parent recipe(s):    None
        Input values:
            'NAME': 'Firefox',
            'LOCALE': 'en-US',
        """
        let info = RecipeInfo.parse(from: output)
        #expect(info.description == "Downloads the latest Firefox.")
        #expect(info.identifier == "com.github.autopkg.download.Firefox")
        #expect(info.munkiImportRecipe == "False")
        #expect(info.hasCheckPhase == "True")
        #expect(info.buildsPackage == "False")
        #expect(info.recipeFilePath.hasSuffix("Firefox.download.recipe"))
        #expect(info.parentRecipes == ["None"])
        #expect(info.inputValues.count == 2)
        #expect(info.inputValues[0].key == "NAME")
        #expect(info.inputValues[0].value == "Firefox")
        #expect(info.inputValues[1].key == "LOCALE")
        #expect(info.inputValues[1].value == "en-US")
    }

    @Test func parsesMultipleParentRecipesAcrossContinuationLines() {
        let output = """
        Description:         test
        Identifier:          com.example.child
        Parent recipe(s):    /path/parent.download.recipe
                             /path/grandparent.download.recipe
        Input values:
        """
        let info = RecipeInfo.parse(from: output)
        #expect(info.parentRecipes == [
            "/path/parent.download.recipe",
            "/path/grandparent.download.recipe",
        ])
    }
}
