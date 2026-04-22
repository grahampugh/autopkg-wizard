import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    var autoPkgCLI = AutoPkgCLI.shared

    var body: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            Label(item.rawValue, systemImage: item.systemImage)
                .tag(item)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 4) {
                Divider()
                if autoPkgCLI.isInstalled {
                    Label("AutoPkg \(autoPkgCLI.installedVersion)", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("AutoPkg not installed", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}
