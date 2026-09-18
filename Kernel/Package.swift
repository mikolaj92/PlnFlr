// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "PlnFlrKernel",
    platforms: [
        .iOS(.v27),
        .macOS(.v27),
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
