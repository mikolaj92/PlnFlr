// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "PlnFlrApp",
    platforms: [
        .iOS("26.4"),
        .macOS("26.4"),
    ],
    products: [
        .library(name: "PlnFlrCapture", targets: ["PlnFlrCapture"]),
        .executable(name: "PlnFlrApp", targets: ["PlnFlrApp"]),
    ],
    dependencies: [
        .package(path: "../Kernel"),
        .package(url: "git@github.com:pointfreeco/TCA26.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "PlnFlrCapture",
            dependencies: [
                .product(name: "PlnFlrLayout", package: "Kernel"),
                .product(name: "ComposableArchitecture2", package: "TCA26"),
            ]
        ),
        .executableTarget(
            name: "PlnFlrApp",
            dependencies: ["PlnFlrCapture"]
        ),
        .testTarget(
            name: "PlnFlrCaptureTests",
            dependencies: ["PlnFlrCapture"]
        ),
    ]
)
