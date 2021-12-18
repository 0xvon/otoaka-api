// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "rocket-api",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .executable(name: "Run", targets: ["Run"]),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.54.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.4.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.3.0"),
        .package(url: "https://github.com/kateinoigakukun/StubKit.git", from: "0.1.6"),
        .package(url: "https://github.com/soto-project/soto.git", from: "5.2.0"),
        .package(url: "https://github.com/MaxDesiatov/XMLCoder.git", from: "0.12.0"),
        .package(path: "Modules/LoggingDiscord"),
        .package(path: "Modules/Core"),
        .package(path: "Modules/Endpoint"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "XMLCoder", package: "XMLCoder"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "Persistance", package: "Core"),
                .product(name: "Service", package: "Core"),
                .product(name: "Endpoint", package: "Endpoint"),
                .product(name: "LoggingDiscord", package: "LoggingDiscord"),
                .product(name: "SotoCognitoIdentityProvider", package: "soto"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
        .target(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
            .product(name: "SotoCognitoIdentityProvider", package: "soto"),
            .product(name: "StubKit", package: "StubKit"),
        ]),
    ]
)
