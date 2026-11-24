// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RonicMacToWindows",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "RonicMacToWindows",
            path: "Sources/RonicMacToWindows",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
            ]
        )
    ]
)
