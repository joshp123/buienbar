// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BuienBar",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "BuienBar",
            path: "Sources/BuienBar"),
        .testTarget(
            name: "BuienBarTests",
            dependencies: ["BuienBar"],
            path: "Tests/BuienBarTests")
    ]
)
