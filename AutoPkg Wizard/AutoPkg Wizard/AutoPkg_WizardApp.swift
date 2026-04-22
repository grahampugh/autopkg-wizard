//
//  AutoPkg_WizardApp.swift
//  AutoPkg Wizard
//
//  Created by Graham Pugh on 22.04.26.
//

import SwiftUI

@main
struct AutoPkg_WizardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var autoPkgCLI = AutoPkgCLI.shared
    @State private var selectedSidebarItem: SidebarItem? = .overview
    @State private var showNotInstalledAlert = false

    var body: some Scene {
        Window("AutoPkg Wizard", id: "main") {
            NavigationSplitView {
                SidebarView(selection: $selectedSidebarItem)
                    .frame(minWidth: 180)
            } detail: {
                Group {
                    switch selectedSidebarItem {
                    case .overview:
                        OverviewView()
                    case .repos:
                        ReposView()
                    case .recipes:
                        RecipesView()
                    case .overrides:
                        OverridesView()
                    case .arguments:
                        ArgumentsView()
                    case .schedule:
                        ScheduleView()
                    case nil:
                        ContentUnavailableView(
                            "Select a Section",
                            systemImage: "sidebar.left",
                            description: Text("Choose a section from the sidebar to get started.")
                        )
                    }
                }
                .frame(minWidth: 500, minHeight: 400)
            }
            .frame(minWidth: 720, minHeight: 480)
            .task {
                await autoPkgCLI.checkInstallation()
                if !autoPkgCLI.isInstalled {
                    showNotInstalledAlert = true
                }
            }
            .alert("AutoPkg Not Found", isPresented: $showNotInstalledAlert) {
                Button("Open Downloads Page") {
                    if let url = URL(string: "https://github.com/autopkg/autopkg/releases") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("AutoPkg was not found at \(autoPkgCLI.autoPkgPath). Please install AutoPkg to use this application. You can configure the path in Settings.")
            }
            .alert("AutoPkg Not Responding", isPresented: $autoPkgCLI.showTimeoutAlert) {
                Button("Wait") {
                    autoPkgCLI.dismissTimeout()
                }
                Button("Cancel", role: .destructive) {
                    autoPkgCLI.cancelStalledCommand()
                }
            } message: {
                Text("AutoPkg does not appear to be responding.\n\n\(autoPkgCLI.stalledCommandDescription)")
            }
        }
        .defaultSize(width: 900, height: 600)

        Settings {
            SettingsView()
        }
    }
}

/// Quit the app when the last window is closed.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
