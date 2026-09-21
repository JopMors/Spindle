// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Spindle",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Spindle",
            path: "Sources/Spindle",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SpindleTests",
            dependencies: ["Spindle"],
            path: "Tests/SpindleTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
