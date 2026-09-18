// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PlnFlrKernel",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
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
