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
                        Button("Every Day") {
                            viewModel.selectAllDays()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Weekdays Only") {
                            viewModel.selectWeekdaysOnly()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Section("Configuration") {
                    LabeledContent("Recipe List") {
                        Text(AutoPkgCLI.shared.recipeListPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    LabeledContent("AutoPkg Path") {
                        Text(AutoPkgCLI.shared.autoPkgPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    LabeledContent("LaunchAgent") {
                        Text(LaunchAgentManager.agentPlistPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    LabeledContent("Log File") {
                        Text("~/Library/Logs/\(LaunchAgentManager.agentLabel).log")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                if let nextRun = viewModel.nextRun {
                    Section("Status") {
                        LabeledContent("Agent Loaded") {
                            Image(systemName: viewModel.agentLoaded ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(viewModel.agentLoaded ? .green : .red)
                        }

                        LabeledContent("Next Scheduled Run") {
                            Text(nextRun, style: .date)
                            + Text(" at ")
                            + Text(nextRun, style: .time)
                        }
                        .font(.callout)

                        if let lastRun = viewModel.lastRunDate {
                            LabeledContent("Last Run") {
                                Text(lastRun, style: .relative)
                                + Text(" ago")
                            }
                            .font(.callout)
                        }
                    }
                }
            }

            Section {
                HStack {
                    if let status = viewModel.statusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Spacer()

                    Button("Refresh Status") {
                        viewModel.refreshStatus()
                    }
                    .buttonStyle(.bordered)

                    Button("Save") {
                        viewModel.saveSchedule()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Schedule")
        .onAppear {
            viewModel.refreshStatus()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Day Selector

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
