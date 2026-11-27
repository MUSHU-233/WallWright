// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WallWright",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(
            name: "WallWright",
            path: "Sources/WallWright",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
