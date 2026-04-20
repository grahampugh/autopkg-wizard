import SwiftUI

struct OverviewView: View {
    @State private var viewModel = OverviewViewModel()
    private var autoPkgCLI = AutoPkgCLI.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    if let url = Bundle.main.url(forResource: "autopkg_logo", withExtension: "png"),
                       let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 80)
                    }

                    Text("AutoPkg Wizard")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if autoPkgCLI.isInstalled {
                        Label("AutoPkg \(autoPkgCLI.installedVersion)", systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.green)
                    } else {
                        Label("AutoPkg not installed", systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.top, 20)

                // Summary cards
                HStack(spacing: 16) {
                    SummaryCard(
                        title: "Repos",
                        count: viewModel.repoCount,
                        icon: "folder",
                        color: .blue
                    )
                    SummaryCard(
                        title: "Recipes",
                        count: viewModel.recipeCount,
                        icon: "list.bullet.rectangle",
                        color: .orange
                    )
                    SummaryCard(
                        title: "Overrides",
                        count: viewModel.overrideCount,
                        icon: "doc.on.doc",
                        color: .purple
                    )
                }
                .padding(.horizontal, 20)

                Divider()
                    .padding(.horizontal, 20)

                // Preferences button
                VStack(spacing: 8) {
                    Text("AutoPkg Preferences")
                        .font(.headline)

                    Text("View and edit the autopkg configuration stored in the com.github.autopkg defaults domain.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)

                    Button {
                        viewModel.loadPreferences()
                        viewModel.showPreferences = true
                    } label: {
                        Label("View Preferences", systemImage: "gearshape")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("")
        .task {
            await viewModel.loadCounts()
        }
        .sheet(isPresented: $viewModel.showPreferences) {
            PreferencesSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text("\(count)")
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preferences Sheet

struct PreferencesSheet: View {
    @Bindable var viewModel: OverviewViewModel
    @State private var editingItemID: UUID?
    @State private var editKey: String = ""
    @State private var editValue: String = ""
    @State private var itemToDelete: OverviewViewModel.PreferenceItem?
    @State private var showDeleteConfirmation = false
    @State private var scrollTarget: UUID?

    /// Whether there is already an unsaved new item being edited
    private var hasUnsavedNewItem: Bool {
        viewModel.preferences.contains { $0.isNew }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("AutoPkg Preferences")
                    .font(.headline)
                Spacer()
                Button {
                    let newItem = viewModel.addNewPreference()
                    editingItemID = newItem.id
                    editKey = ""
                    editValue = ""
                    scrollTarget = newItem.id
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(hasUnsavedNewItem)
            }

            if viewModel.preferences.isEmpty {
                ContentUnavailableView(
                    "No Preferences",
                    systemImage: "gearshape",
                    description: Text("No autopkg preferences found.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List {
                        // Header row
                        HStack(spacing: 0) {
                            Text("Key")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .frame(width: 200, alignment: .leading)
                            Text("Value")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                                .frame(width: 110)
                        }
                        .listRowSeparator(.visible)

                        ForEach(viewModel.preferences) { item in
                            HStack(spacing: 8) {
                                if editingItemID == item.id {
                                    TextField("Key", text: $editKey)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 200)
                                    TextField("Value", text: $editValue)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(maxWidth: .infinity)
                                    HStack(spacing: 4) {
                                        Button("Save") {
                                            saveEdit(item)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        .disabled(editKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                        Button("Cancel") {
                                            cancelEdit(item)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                    .frame(width: 110)
                                } else {
                                    Text(item.key)
                                        .fontWeight(.medium)
                                        .frame(width: 200, alignment: .leading)
                                        .lineLimit(1)
                                        .help(item.key)
                                    Text(item.value)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .lineLimit(1)
                                        .help(item.value)
                                    HStack(spacing: 4) {
                                        Button {
                                            editingItemID = item.id
                                            editKey = item.key
                                            editValue = item.value
                                        } label: {
                                            Image(systemName: "pencil")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .help("Edit")

                                        Button(role: .destructive) {
                                            itemToDelete = item
                                            showDeleteConfirmation = true
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .help("Delete")
                                    }
                                    .frame(width: 110)
                                }
                            }
                            .id(item.id)
                        }
                    }
                    .onChange(of: scrollTarget) { _, target in
                        if let target {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    proxy.scrollTo(target, anchor: .bottom)
                                }
                                scrollTarget = nil
                            }
                        }
                    }
                }
            }

            HStack {
                Text("\(viewModel.preferences.count) preference\(viewModel.preferences.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Done") {
                    viewModel.showPreferences = false
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 700, height: 480)
        .alert("Delete Preference", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    viewModel.deletePreference(item)
                    if editingItemID == item.id {
                        editingItemID = nil
                    }
                }
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            if let item = itemToDelete {
                Text("Are you sure you want to delete the preference \"\(item.key)\"?")
            }
        }
    }

    private func saveEdit(_ item: OverviewViewModel.PreferenceItem) {
        let trimmedKey = editKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }

        var updated = item
        updated.key = trimmedKey
        updated.value = editValue
        viewModel.savePreference(updated)
        editingItemID = nil
    }

    private func cancelEdit(_ item: OverviewViewModel.PreferenceItem) {
        if item.isNew {
            viewModel.preferences.removeAll { $0.id == item.id }
        }
        editingItemID = nil
    }
}
