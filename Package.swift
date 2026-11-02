// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CopilotUsage",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CopilotUsageCore"),
        .executableTarget(
            name: "CopilotUsage",
            dependencies: ["CopilotUsageCore"]
        ),
        .testTarget(
            name: "CopilotUsageCoreTests",
            dependencies: ["CopilotUsageCore"]
        ),
    ]
)
