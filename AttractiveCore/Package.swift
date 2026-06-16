// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AttractiveKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "AttractiveKit", targets: ["AttractiveKit"])
    ],
    targets: [
        .target(
            name: "AttractiveKit",
            path: ".",
            exclude: ["Package.swift", "Tests"]
        ),
        .testTarget(
            name: "AttractiveKitTests",
            dependencies: ["AttractiveKit"],
            path: "Tests"
        )
    ]
)
