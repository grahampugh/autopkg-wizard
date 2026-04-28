import Testing
@testable import AutoPkg_Wizard

@Suite("AutoPkgRepo")
struct AutoPkgRepoTests {

    @Test func parsesStandardRepoListLine() {
        let output = """
        /Users/jane/Library/AutoPkg/RecipeRepos/com.github.autopkg.recipes (https://github.com/autopkg/recipes.git)
        """
        let repos = AutoPkgRepo.parse(from: output)
        #expect(repos.count == 1)
        #expect(repos[0].path == "/Users/jane/Library/AutoPkg/RecipeRepos/com.github.autopkg.recipes")
        #expect(repos[0].url == "https://github.com/autopkg/recipes.git")
    }

    @Test func parsesMultipleReposAndIgnoresBlankLines() {
        let output = """
        /a/com.github.autopkg.recipes (https://github.com/autopkg/recipes.git)

        /b/com.github.autopkg.grahampugh-recipes (https://github.com/grahampugh/recipes.git)
        """
        let repos = AutoPkgRepo.parse(from: output)
        #expect(repos.count == 2)
    }

    @Test func displayNameStripsAutoPkgPrefix() {
        let repo = AutoPkgRepo(
            path: "/Users/jane/Library/AutoPkg/RecipeRepos/com.github.autopkg.grahampugh-recipes",
            url: "https://github.com/grahampugh/recipes.git"
        )
        #expect(repo.displayName == "grahampugh-recipes")
    }

    @Test func displayNameFallsBackToLastPathComponent() {
        let repo = AutoPkgRepo(path: "/some/other/dir/custom-repo", url: "")
        #expect(repo.displayName == "custom-repo")
    }
}
