// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "PlnFlrWeb",
    platforms: [
        .macOS("26.4"),
    ],
    products: [
        .library(name: "PlnFlrWeb", targets: ["PlnFlrWeb"]),
        .executable(name: "PlnFlrServe", targets: ["PlnFlrWebRun"]),
    ],
    dependencies: [
        .package(path: "../Kernel"),
        .package(url: "https://github.com/vapor/vapor.git", exact: "5.0.0-beta.2"),
    ],
    targets: [
        .target(
            name: "PlnFlrWeb",
            dependencies: [
                .product(name: "PlnFlrLayout", package: "Kernel"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .executableTarget(
            name: "PlnFlrWebRun",
            dependencies: ["PlnFlrWeb"]
        ),
        .testTarget(
            name: "PlnFlrWebTests",
            dependencies: [
                "PlnFlrWeb",
                .product(name: "PlnFlrLayout", package: "Kernel"),
                .product(name: "VaporTesting", package: "vapor"),
            ]
        ),
    ]
)
