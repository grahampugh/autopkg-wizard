import SwiftUI

@MainActor
@Observable
final class OverridesViewModel {
    private let cli = AutoPkgCLI.shared

    var overrides: [AutoPkgOverride] = []
    var selectedOverride: AutoPkgOverride?
    var selectedOverrideContents: String = ""
    var trustStatus: [String: TrustState] = [:]

    var isLoading = false
    var showError = false
    var errorMessage: String?
    var statusMessage: String?

    enum TrustState: Sendable {
        case unknown
        case verifying
        case verified
        case failed(String)

        var icon: String {
            switch self {
            case .unknown: "questionmark.circle"
            case .verifying: "clock"
            case .verified: "checkmark.circle.fill"
            case .failed: "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .unknown: .secondary
            case .verifying: .blue
            case .verified: .green
            case .failed: .orange
            }
        }
    }

    func loadOverrides() {
        overrides = AutoPkgOverride.listOverrides(in: cli.overridesDirectory)
    }

    func selectOverride(_ override: AutoPkgOverride) {
        selectedOverride = override
        do {
            selectedOverrideContents = try override.contents()
        } catch {
            selectedOverrideContents = "Error reading file: \(error.localizedDescription)"
        }
    }

    func verifyTrust(for override: AutoPkgOverride) async {
        let name = override.recipeName
        trustStatus[override.id] = .verifying
        do {
            _ = try await cli.verifyTrustInfo(name)
            trustStatus[override.id] = .verified
        } catch let error as AutoPkgError {
            if case .commandFailed(_, _, let stderr) = error {
                trustStatus[override.id] = .failed(stderr)
            } else {
                trustStatus[override.id] = .failed(error.localizedDescription)
            }
        } catch {
            trustStatus[override.id] = .failed(error.localizedDescription)
        }
    }

    func updateTrust(for override: AutoPkgOverride) async {
        let name = override.recipeName
        do {
            _ = try await cli.updateTrustInfo(name)
            trustStatus[override.id] = .verified
            statusMessage = "Trust info updated for \(name)"
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func deleteOverride(_ override: AutoPkgOverride) {
        do {
            try FileManager.default.removeItem(atPath: override.filePath)
            if selectedOverride?.id == override.id {
                selectedOverride = nil
                selectedOverrideContents = ""
            }
            loadOverrides()
            NotificationCenter.default.post(name: .overridesDidChange, object: nil)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

extension Notification.Name {
    static let overridesDidChange = Notification.Name("overridesDidChange")
}
