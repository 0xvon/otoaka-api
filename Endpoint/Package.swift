// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "Endpoint",
    products: [
        .library(name: "Endpoint", targets: ["Endpoint"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kateinoigakukun/CodableURL.git", from: "0.3.0")
    ],
    targets: [
        .target(name: "Endpoint", dependencies: ["CodableURL"]),
    ]
)
