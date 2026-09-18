// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "PlnFlrKernel",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
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
