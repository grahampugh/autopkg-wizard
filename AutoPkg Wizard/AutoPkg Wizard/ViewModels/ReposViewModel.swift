import SwiftUI

@MainActor
@Observable
final class ReposViewModel {
    private let cli = AutoPkgCLI.shared

    var repos: [AutoPkgRepo] = []
    var isLoading = false
    var isUpdating = false
    var showAddSheet = false
    var newRepoName = ""
    var errorMessage: String?
    var showError = false
    var updateLog: [String] = []
    var showUpdateLog = false

    func loadRepos() async {
        isLoading = true
        defer { isLoading = false }
        do {
            repos = try await cli.repoList()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func addRepo() async {
        let name = newRepoName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        do {
            _ = try await cli.repoAdd(name)
            newRepoName = ""
            showAddSheet = false
            await loadRepos()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func deleteRepo(_ repo: AutoPkgRepo) async {
        do {
            _ = try await cli.repoDelete(repo.path)
            await loadRepos()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func deleteRepos(at offsets: IndexSet) async {
        let reposToDelete = offsets.map { repos[$0] }
        for repo in reposToDelete {
            await deleteRepo(repo)
        }
    }

    func updateAllRepos() {
        isUpdating = true
        updateLog = []
        showUpdateLog = true

        let (stream, task) = cli.repoUpdate()

        Task {
            for await line in stream {
                updateLog.append(line)
            }
            let exitCode = await task.value
            if exitCode == 0 {
                updateLog.append("✅ All repos updated successfully.")
            } else {
                updateLog.append("⚠️ Repo update finished with exit code \(exitCode).")
            }
            isUpdating = false
            await loadRepos()
        }
    }
}
