import Foundation
import Testing
@testable import AutoPkg_Wizard

@Suite("ArgumentsConfig")
struct ArgumentsConfigTests {

    @Test func defaultConfigProducesNormalVerbosityFlag() {
        let config = ArgumentsConfig()
        #expect(config.buildArguments() == ["-v"])
    }

    @Test func quietVerbosityEmitsNoFlag() {
        var config = ArgumentsConfig()
        config.verbosity = 0
        #expect(config.buildArguments() == [])
    }

    @Test func verbosityScalesUpToFourVs() {
        var config = ArgumentsConfig()
        config.verbosity = 4
        #expect(config.buildArguments() == ["-vvvv"])
    }

    @Test func enabledPreAndPostProcessorsAppearAsFlags() {
        var config = ArgumentsConfig()
        config.verbosity = 0
        config.preProcessors = [
            .init(name: "com.example.pre.One"),
            .init(name: "com.example.pre.Two", isEnabled: false),
        ]
        config.postProcessors = [
            .init(name: "com.example.post.One"),
        ]
        #expect(config.buildArguments() == [
            "--pre=com.example.pre.One",
            "--post=com.example.post.One",
        ])
    }

    @Test func disabledKeyValuePairsAreOmitted() {
        var config = ArgumentsConfig()
        config.verbosity = 0
        config.keyValuePairs = [
            .init(key: "MUNKI_REPO", value: "/munki"),
            .init(key: "DISABLED", value: "x", isEnabled: false),
        ]
        #expect(config.buildArguments() == ["--key=MUNKI_REPO=/munki"])
    }

    @Test func onlyFirstEnabledSourcePackageIsUsed() {
        var config = ArgumentsConfig()
        config.verbosity = 0
        config.sourcePackages = [
            .init(name: "/path/a.pkg", isEnabled: false),
            .init(name: "/path/b.pkg", isEnabled: true),
            .init(name: "/path/c.pkg", isEnabled: true),
        ]
        #expect(config.buildArguments() == ["--pkg=/path/b.pkg"])
    }

    @Test func emptyNamedItemsAreSkipped() {
        var config = ArgumentsConfig()
        config.verbosity = 0
        config.preProcessors = [.init(name: "")]
        config.postProcessors = [.init(name: "")]
        config.keyValuePairs = [.init(key: "", value: "x")]
        config.sourcePackages = [.init(name: "")]
        #expect(config.buildArguments() == [])
    }

    @Test func verbosityDescriptionMatchesKnownLevels() {
        for (level, expected) in [
            (0, "Quiet (no verbose output)"),
            (1, "Normal (-v)"),
            (2, "Verbose (-vv)"),
            (3, "Very Verbose (-vvv)"),
            (4, "Debug (-vvvv)"),
        ] {
            var config = ArgumentsConfig()
            config.verbosity = level
            #expect(config.verbosityDescription == expected)
        }
    }

    @Test func codableRoundtripPreservesAllFields() throws {
        var original = ArgumentsConfig()
        original.verbosity = 3
        original.preProcessors = [.init(name: "Pre")]
        original.postProcessors = [.init(name: "Post", isEnabled: false)]
        original.keyValuePairs = [.init(key: "K", value: "V")]
        original.sourcePackages = [.init(name: "/x.pkg")]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ArgumentsConfig.self, from: data)

        #expect(decoded == original)
    }
}
