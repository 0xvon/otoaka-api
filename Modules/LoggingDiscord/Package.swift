// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "LoggingDiscord",
    products: [
        .library(name: "LoggingDiscord", targets: ["LoggingDiscord"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "LoggingDiscord", dependencies: [
            .product(name: "Logging", package: "swift-log"),
        ]),
    ]
)
