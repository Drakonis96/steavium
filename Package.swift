// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Steavium",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Steavium", targets: ["Steavium"])
    ],
    targets: [
        .executableTarget(
            name: "Steavium",
            path: "Sources",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "SteaviumTests",
            dependencies: ["Steavium"],
            path: "Tests"
        )
    ]
)
