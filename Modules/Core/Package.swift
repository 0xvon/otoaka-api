// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "Service", targets: ["Service"]),
        .library(name: "Persistance", targets: ["Persistance"]),
        .library(name: "Domain", targets: ["Domain"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/fluent-kit.git", from: "1.10.0"),
        .package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.18.0"),
        .package(url: "https://github.com/kateinoigakukun/StubKit.git", from: "0.1.6"),
        .package(name: "AWSSDKSwift", url: "https://github.com/soto-project/soto.git", from: "4.0.0"),
        .package(path: "../Endpoint"),
    ],
    targets: [
        .target(name: "Service", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .target(name: "Domain"),
            .product(name: "SNS", package: "AWSSDKSwift"),
        ]),
        .target(name: "Persistance", dependencies: [
            .product(name: "FluentKit", package: "fluent-kit"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "FluentMySQLDriver", package: "fluent-mysql-driver"),
            .target(name: "Domain"),
        ]),
        .target(name: "Domain", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "Endpoint", package: "Endpoint"),
        ]),
        .testTarget(name: "DomainTests", dependencies: [
            .target(name: "Domain"),
            .product(name: "StubKit", package: "StubKit"),
        ]),
    ]
)
