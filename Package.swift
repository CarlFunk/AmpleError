// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AmpleError",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AmpleError",
            targets: ["AmpleError"])
    ],
    targets: [
        .target(
            name: "AmpleError"),
        .testTarget(
            name: "AmpleErrorTests",
            dependencies: ["AmpleError"])
    ]
)
