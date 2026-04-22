import SwiftUI

struct ReposView: View {
    @State private var viewModel = ReposViewModel()
    @State private var isEditing = false
    @State private var selectedRepos: Set<String> = []

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.repos.isEmpty {
                ProgressView("Loading repos…")
            } else if viewModel.repos.isEmpty {
                ContentUnavailableView(
                    "No Repos",
                    systemImage: "folder.badge.questionmark",
                    description: Text("No AutoPkg repos are installed. Add a repo to get started.")
                )
            } else {
                repoList
            }
        }
        .navigationTitle("Repos")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isEditing {
                    Button("Cancel") {
                        isEditing = false
                        selectedRepos.removeAll()
                    }
                } else {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .disabled(viewModel.repos.isEmpty)
                    .help("Select repos to remove")
                }

                Button {
                    viewModel.updateAllRepos()
                } label: {
                    Label("Update All", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isUpdating || isEditing)
                .help("Update all repos")

                Button {
                    viewModel.showAddSheet = true
                } label: {
                    Label("Add Repo", systemImage: "plus")
                }
                .disabled(isEditing)
                .help("Add a new repo")
            }
        }
        .task {
            await viewModel.loadRepos()
        }
        .refreshable {
            await viewModel.loadRepos()
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddRepoSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showUpdateLog) {
            UpdateLogSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
    }

    private var repoList: some View {
        VStack(spacing: 0) {
            List {
                ForEach(viewModel.repos) { repo in
                    HStack {
                        if isEditing {
                            Button {
                                toggleSelection(repo)
                            } label: {
                                Image(systemName: selectedRepos.contains(repo.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedRepos.contains(repo.id) ? .blue : .secondary)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)
                        }
                        RepoRow(repo: repo)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isEditing {
                            toggleSelection(repo)
                        }
                    }
                    .contextMenu {
                        if !isEditing {
                            Button("Delete Repo", role: .destructive) {
                                Task {
                                    await viewModel.deleteRepo(repo)
                                }
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if !isEditing {
                            Button("Delete", role: .destructive) {
                                Task {
                                    await viewModel.deleteRepo(repo)
                                }
                            }
                        }
                    }
                }
            }

            if isEditing {
                HStack {
                    Button(role: .destructive) {
                        Task {
                            await deleteSelectedRepos()
                        }
                    } label: {
                        Label("Delete Selected", systemImage: "trash")
                    }
                    .disabled(selectedRepos.isEmpty)

                    Spacer()

                    Text("\(selectedRepos.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
    }

    private func toggleSelection(_ repo: AutoPkgRepo) {
        if selectedRepos.contains(repo.id) {
            selectedRepos.remove(repo.id)
        } else {
            selectedRepos.insert(repo.id)
        }
    }

    private func deleteSelectedRepos() async {
        let reposToDelete = viewModel.repos.filter { selectedRepos.contains($0.id) }
        for repo in reposToDelete {
            await viewModel.deleteRepo(repo)
        }
        selectedRepos.removeAll()
        isEditing = false
    }
}

// MARK: - Subviews

struct RepoRow: View {
    let repo: AutoPkgRepo

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(repo.displayName)
                .font(.headline)
            if !repo.url.isEmpty {
                Text(repo.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct AddRepoSheet: View {
    @Bindable var viewModel: ReposViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Add AutoPkg Repo")
                .font(.headline)

            Text("Enter a repo short name (e.g. \"grahampugh-recipes\") or a full GitHub URL.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Repo name or URL", text: $viewModel.newRepoName)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    Task { await viewModel.addRepo() }
                }

            HStack {
                Button("Cancel") {
                    viewModel.newRepoName = ""
                    viewModel.showAddSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    Task { await viewModel.addRepo() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.newRepoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isFocused = true
            }
        }
    }
}

struct UpdateLogSheet: View {
    @Bindable var viewModel: ReposViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Updating Repos")
                    .font(.headline)
                Spacer()
                if viewModel.isUpdating {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(viewModel.updateLog.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: viewModel.updateLog.count) { _, _ in
                    if let last = viewModel.updateLog.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Close") {
                    viewModel.showUpdateLog = false
                }
                .keyboardShortcut(.cancelAction)
                .disabled(viewModel.isUpdating)
            }
        }
        .padding(20)
        .frame(width: 560, height: 400)
    }
}
