// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "PlnFlrKernel",
    platforms: [
        .iOS("27"),
        .macOS("27"),
    ],
    products: [
        .library(name: "PlnFlrLayout", targets: ["PlnFlrLayout"]),
    ],
    targets: [
        .target(name: "PlnFlrLayout"),
        .testTarget(
            name: "PlnFlrLayoutTests",
            dependencies: ["PlnFlrLayout"]
        ),
    ]
)
