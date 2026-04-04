// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "agent-manager",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.7.1")
    ],
    targets: [
        .executableTarget(
            name: "agent-manager",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/AgentManager"
        ),
        .testTarget(
            name: "AgentManagerTests",
            dependencies: ["agent-manager"],
            path: "Tests/AgentManagerTests"
        )
    ]
)
