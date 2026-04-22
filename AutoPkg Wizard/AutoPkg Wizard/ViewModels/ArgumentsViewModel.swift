import SwiftUI

@MainActor
@Observable
final class ArgumentsViewModel {
    var config: ArgumentsConfig
    var statusMessage: String?
    var showError = false
    var errorMessage: String?

    init() {
        config = ArgumentsConfig.load()
    }

    // MARK: - Verbosity

    func setVerbosity(_ level: Int) {
        config.verbosity = max(0, min(4, level))
        save()
    }

    // MARK: - Pre-Processors

    func addPreProcessor(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !config.preProcessors.contains(where: { $0.name == trimmed }) else { return }
        config.preProcessors.append(.init(name: trimmed))
        save()
    }

    func removePreProcessor(id: UUID) {
        config.preProcessors.removeAll { $0.id == id }
        save()
    }

    func togglePreProcessor(id: UUID) {
        guard let index = config.preProcessors.firstIndex(where: { $0.id == id }) else { return }
        config.preProcessors[index].isEnabled.toggle()
        save()
    }

    // MARK: - Post-Processors

    func addPostProcessor(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !config.postProcessors.contains(where: { $0.name == trimmed }) else { return }
        config.postProcessors.append(.init(name: trimmed))
        save()
    }

    func removePostProcessor(id: UUID) {
        config.postProcessors.removeAll { $0.id == id }
        save()
    }

    func togglePostProcessor(id: UUID) {
        guard let index = config.postProcessors.firstIndex(where: { $0.id == id }) else { return }
        config.postProcessors[index].isEnabled.toggle()
        save()
    }

    // MARK: - Key-Value Pairs

    func addKeyValuePair(key: String, value: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        let pair = ArgumentsConfig.KeyValuePair(key: trimmedKey, value: value)
        config.keyValuePairs.append(pair)
        save()
    }

    func removeKeyValuePair(id: UUID) {
        config.keyValuePairs.removeAll { $0.id == id }
        save()
    }

    func toggleKeyValuePair(id: UUID) {
        guard let index = config.keyValuePairs.firstIndex(where: { $0.id == id }) else { return }
        config.keyValuePairs[index].isEnabled.toggle()
        save()
    }

    func updateKeyValuePair(id: UUID, key: String, value: String) {
        guard let index = config.keyValuePairs.firstIndex(where: { $0.id == id }) else { return }
        config.keyValuePairs[index].key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        config.keyValuePairs[index].value = value
        save()
    }

    // MARK: - Source Packages

    func addSourcePackage(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !config.sourcePackages.contains(where: { $0.name == trimmed }) else { return }
        // Disable all others, enable this one
        for i in config.sourcePackages.indices {
            config.sourcePackages[i].isEnabled = false
        }
        config.sourcePackages.append(.init(name: trimmed, isEnabled: true))
        save()
    }

    func removeSourcePackage(id: UUID) {
        config.sourcePackages.removeAll { $0.id == id }
        save()
    }

    /// Enable one source package and disable all others (radio behaviour)
    func enableSourcePackage(id: UUID) {
        for i in config.sourcePackages.indices {
            config.sourcePackages[i].isEnabled = (config.sourcePackages[i].id == id)
        }
        save()
    }

    /// Disable a source package (allows none to be active)
    func disableSourcePackage(id: UUID) {
        guard let index = config.sourcePackages.firstIndex(where: { $0.id == id }) else { return }
        config.sourcePackages[index].isEnabled = false
        save()
    }

    // MARK: - Persistence

    func save() {
        do {
            try config.save()
            statusMessage = "Arguments saved."
            Task {
                try? await Task.sleep(for: .seconds(2))
                if statusMessage == "Arguments saved." {
                    statusMessage = nil
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Preview / Summary

    /// Generate the command-line preview string
    var commandPreview: String {
        let args = config.buildArguments()
        if args.isEmpty {
            return "autopkg run --recipe-list <path>"
        }
        return "autopkg run --recipe-list <path> " + args.joined(separator: " ")
    }
}
