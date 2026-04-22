import SwiftUI

struct ScheduleView: View {
    @State private var viewModel = ScheduleViewModel()

    var body: some View {
        Form {
            Section {
                Toggle("Enable Scheduled Runs", isOn: $viewModel.schedule.isEnabled)
                    .toggleStyle(.switch)
            } header: {
                Text("Schedule")
            } footer: {
                Text("When enabled, AutoPkg will automatically run your recipe list at the specified time.")
            }

            if viewModel.schedule.isEnabled {
                Section("Time") {
                    DatePicker(
                        "Run at",
                        selection: Binding(
                            get: { viewModel.selectedTime },
                            set: { viewModel.selectedTime = $0 }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.stepperField)
                }

                Section("Days") {
                    daySelector

                    HStack(spacing: 12) {
                        Button("Every Day") { viewModel.selectAllDays() }
                            .buttonStyle(.bordered).controlSize(.small)
                        Button("Weekdays Only") { viewModel.selectWeekdaysOnly() }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }

                Section("Configuration") {
                    LabeledContent("Recipe List") {
                        Text(AutoPkgCLI.shared.recipeListPath)
                            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    LabeledContent("AutoPkg Path") {
                        Text(AutoPkgCLI.shared.autoPkgPath)
                            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    LabeledContent("LaunchAgent") {
                        Text(LaunchAgentManager.agentPlistPath)
                            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    LabeledContent("Log File") {
                        Text("~/Library/Logs/\(LaunchAgentManager.agentLabel).log")
                            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }

                if let nextRun = viewModel.nextRun {
                    Section("Status") {
                        LabeledContent("Agent Loaded") {
                            Image(systemName: viewModel.agentLoaded ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(viewModel.agentLoaded ? .green : .red)
                        }
                        LabeledContent("Next Scheduled Run") {
                            Text("\(nextRun, style: .date) at \(nextRun, style: .time)")
                        }
                        .font(.callout)

                        if let lastRun = viewModel.lastRunDate {
                            LabeledContent("Last Run") {
                                HStack(spacing: 8) {
                                    Text("\(lastRun, style: .relative) ago")
                                    if viewModel.lastRunSummary != nil {
                                        Button {
                                            viewModel.showSummary = true
                                        } label: {
                                            Image(systemName: "info.circle").foregroundStyle(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        .help("View run summary")
                                    }
                                }
                            }
                            .font(.callout)
                        }
                    }
                }
            }

            Section {
                HStack {
                    if let status = viewModel.statusMessage {
                        Text(status).font(.caption).foregroundStyle(.green)
                    }
                    Spacer()
                    Button("Refresh Status") { viewModel.refreshStatus() }
                        .buttonStyle(.bordered)
                    Button("Save") { viewModel.saveSchedule() }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isSaving)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Schedule")
        .onAppear { viewModel.refreshStatus() }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .sheet(isPresented: $viewModel.showSummary) {
            if let summary = viewModel.lastRunSummary {
                RunSummarySheet(summary: summary)
            }
        }
    }

    private var daySelector: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { day in
                DayToggleButton(
                    dayName: LaunchAgentManager.ScheduleConfig.dayAbbreviations[day],
                    isSelected: viewModel.schedule.selectedDays.contains(day)
                ) {
                    viewModel.toggleDay(day)
                }
            }
        }
    }
}

// MARK: - Day Toggle Button

struct DayToggleButton: View {
    let dayName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(dayName)
                .font(.caption.weight(.medium))
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.accentColor : Color.clear)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Run Summary Sheet

struct RunSummarySheet: View {
    let summary: RunSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass").font(.title2).foregroundStyle(.blue)
                Text("Run Summary").font(.headline)
                Spacer()
                Text("\(summary.date, style: .date) at \(summary.date, style: .time)")
            }
            .foregroundStyle(.secondary)
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !summary.failedRecipes.isEmpty {
                        summarySection(title: "Failed Recipes", icon: "xmark.circle.fill", iconColor: .red, count: summary.failedRecipes.count) {
                            ForEach(Array(summary.failedRecipes.enumerated()), id: \.offset) { _, recipe in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(recipe.name).font(.body.weight(.medium))
                                    if !recipe.reason.isEmpty {
                                        Text(recipe.reason).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    if !summary.downloadedItems.isEmpty {
                        summarySection(title: "New Downloads", icon: "arrow.down.circle.fill", iconColor: .blue, count: summary.downloadedItems.count) {
                            ForEach(Array(summary.downloadedItems.enumerated()), id: \.offset) { _, item in
                                Text(item.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }
                    }

                    if !summary.builtPackages.isEmpty {
                        summarySection(title: "Packages Built", icon: "shippingbox.fill", iconColor: .green, count: summary.builtPackages.count) {
                            ForEach(Array(summary.builtPackages.enumerated()), id: \.offset) { _, pkg in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(pkg.identifier).font(.body.weight(.medium))
                                        if !pkg.version.isEmpty {
                                            Text("v\(pkg.version)")
                                                .font(.caption).foregroundStyle(.secondary)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.green.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    if !pkg.path.isEmpty {
                                        Text(pkg.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }

                    if summary.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle").font(.largeTitle).foregroundStyle(.green)
                                Text("Nothing to report").font(.headline)
                                Text("No failures, downloads, or new packages.").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    }

                    DisclosureGroup("Raw Output") {
                        Text(summary.rawText)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                .padding()
            }

            Divider()

            HStack {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(summary.rawText, forType: .string)
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(minWidth: 550, maxWidth: 550, minHeight: 400, maxHeight: 600)
    }

    private func summarySection<Content: View>(
        title: String, icon: String, iconColor: Color, count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(iconColor)
                Text(title).font(.subheadline.weight(.semibold))
                Text("(\(count))").font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 6) { content() }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
