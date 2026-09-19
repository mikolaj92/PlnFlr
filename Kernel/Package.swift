// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "PlnFlrKernel",
    platforms: [
        .iOS("26.4"),
        .macOS("26.4"),
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
