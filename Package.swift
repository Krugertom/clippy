// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Clippy",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Clippy",
            path: "Sources/Clippy",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
