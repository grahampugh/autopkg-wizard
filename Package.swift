// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AutoPkgWizard",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.2.1"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3"),
    ],
    targets: [
        .executableTarget(
            name: "AutoPkgWizard",
            dependencies: ["Highlightr", "Yams"],
            path: "Sources/AutoPkgWizard"
        )
    ]
)
