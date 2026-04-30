// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DesktopToggle",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "DesktopToggle",
            path: "Sources/DesktopToggle"
        )
    ]
)
