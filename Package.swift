// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "cli-manager",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.7.1")
    ],
    targets: [
        .executableTarget(
            name: "cli-manager",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/CLIManager"
        ),
        .testTarget(
            name: "CLIManagerTests",
            dependencies: ["cli-manager"],
            path: "Tests/CLIManagerTests"
        )
    ]
)
