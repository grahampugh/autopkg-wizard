import SwiftUI

struct OverridesView: View {
    @State private var viewModel = OverridesViewModel()
    @State private var isEditing = false
    @State private var selectedOverrides: Set<String> = []

    var body: some View {
        HSplitView {
            overridesList
                .frame(minWidth: 250, maxHeight: .infinity, alignment: .top)

            detailPane
                .frame(minWidth: 300, maxHeight: .infinity)
        }
        .navigationTitle("Overrides")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isEditing {
                    Button("Cancel") {
                        isEditing = false
                        selectedOverrides.removeAll()
                    }
                } else {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .disabled(viewModel.overrides.isEmpty)
                    .help("Select overrides to remove")
                }

                Button {
                    viewModel.loadOverrides()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isEditing)
                .help("Refresh override list")
            }
        }
        .onAppear {
            viewModel.loadOverrides()
        }
        .onReceive(NotificationCenter.default.publisher(for: .overridesDidChange)) { _ in
            viewModel.loadOverrides()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Override List

    private var overridesList: some View {
        VStack(spacing: 0) {
            if viewModel.overrides.isEmpty {
                ContentUnavailableView(
                    "No Overrides",
                    systemImage: "doc.on.doc",
                    description: Text("No recipe overrides found in\n\(AutoPkgCLI.shared.overridesDirectory)")
                )
            } else {
                List(viewModel.overrides, selection: Binding(
                        get: { viewModel.selectedOverride },
                        set: { override in
                            if !isEditing, let override {
                                viewModel.selectOverride(override)
                            }
                        }
                    )) { override in
                        HStack {
                            if isEditing {
                                Button {
                                    toggleSelection(override)
                                } label: {
                                    Image(systemName: selectedOverrides.contains(override.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedOverrides.contains(override.id) ? .blue : .secondary)
                                        .imageScale(.large)
                                }
                                .buttonStyle(.plain)
                            }
                            OverrideRow(override: override, trustState: viewModel.trustStatus[override.id] ?? .unknown)
                            Spacer()
                            if !isEditing {
                                Button {
                                    NSWorkspace.shared.selectFile(override.filePath, inFileViewerRootedAtPath: "")
                                } label: {
                                    Image(systemName: "folder")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Reveal in Finder")
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(isEditing ? TapGesture().onEnded {
                            toggleSelection(override)
                        } : nil)
                        .contextMenu {
                            if !isEditing {
                                Button("Verify Trust Info") {
                                    Task { await viewModel.verifyTrust(for: override) }
                                }
                                Button("Update Trust Info") {
                                    Task { await viewModel.updateTrust(for: override) }
                                }
                                Divider()
                                Button("Show in Finder") {
                                    NSWorkspace.shared.selectFile(override.filePath, inFileViewerRootedAtPath: "")
                                }
                                Divider()
                                Button("Delete Override", role: .destructive) {
                                    viewModel.deleteOverride(override)
                                }
                            }
                        }
                        .tag(override)
                }
                .listStyle(.plain)
                .frame(maxHeight: .infinity, alignment: .top)

                if isEditing {
                        HStack {
                            Button(role: .destructive) {
                                deleteSelectedOverrides()
                            } label: {
                                Label("Delete Selected", systemImage: "trash")
                            }
                            .disabled(selectedOverrides.isEmpty)

                            Spacer()

                            Text("\(selectedOverrides.count) selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.bar)
                }
            }
        }
    }

    // MARK: - Detail Pane

    private var detailPane: some View {
        Group {
            if let override = viewModel.selectedOverride {
                VStack(alignment: .leading, spacing: 8) {
                    // File name
                    Text(override.fileName)
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Trust info and action buttons
                    HStack {
                        let trustState = viewModel.trustStatus[override.id] ?? .unknown
                        trustBadge(trustState)

                        Spacer()

                        Button("Verify") {
                            Task { await viewModel.verifyTrust(for: override) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Update Trust") {
                            Task { await viewModel.updateTrust(for: override) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Save") {
                            viewModel.saveOverrideContents()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .keyboardShortcut("s", modifiers: .command)
                    }
                    .padding(.horizontal)

                    if let status = viewModel.statusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.green)
                            .padding(.horizontal)
                    }

                    if let validationError = viewModel.validationError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(validationError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal)
                    }

                    Divider()

                    SyntaxHighlightEditor(
                        text: $viewModel.selectedOverrideContents,
                        language: OverrideFileType.detect(
                            fileName: override.fileName,
                            content: viewModel.selectedOverrideContents
                        ).highlightrLanguage
                    )
                    .id(override.id)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            } else {
                ContentUnavailableView(
                    "Select an Override",
                    systemImage: "doc.text",
                    description: Text("Select an override from the list to view its contents.")
                )
            }
        }
    }

    @ViewBuilder
    private func trustBadge(_ state: OverridesViewModel.TrustState) -> some View {
        HStack(spacing: 4) {
            Image(systemName: state.icon)
                .foregroundStyle(state.color)
            switch state {
            case .unknown:
                Text("Not Checked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .verifying:
                Text("Verifying…")
                    .font(.caption)
                    .foregroundStyle(.blue)
            case .verified:
                Text("Verified")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .failed(let message):
                Text("Failed")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help(message)
            }
        }
    }

    private func toggleSelection(_ override: AutoPkgOverride) {
        if selectedOverrides.contains(override.id) {
            selectedOverrides.remove(override.id)
        } else {
            selectedOverrides.insert(override.id)
        }
    }

    private func deleteSelectedOverrides() {
        let toDelete = viewModel.overrides.filter { selectedOverrides.contains($0.id) }
        for override in toDelete {
            viewModel.deleteOverride(override)
        }
        selectedOverrides.removeAll()
        isEditing = false
    }
}

// MARK: - Override Row

struct OverrideRow: View {
    let override: AutoPkgOverride
    let trustState: OverridesViewModel.TrustState

    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text(override.recipeName)
                    .font(.body)
                    .lineLimit(1)
                Text(override.fileName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if case .unknown = trustState {
                // Don't show anything for unchecked trust
            } else {
                Image(systemName: trustState.icon)
                    .foregroundStyle(trustState.color)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}
