// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AutoPkgWizard",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "AutoPkgWizard",
            path: "Sources/AutoPkgWizard",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
