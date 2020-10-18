// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "Endpoint",
    products: [
        .library(
            name: "Endpoint",
            targets: ["Endpoint"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Endpoint",
            dependencies: []
        ),
    ]
)
