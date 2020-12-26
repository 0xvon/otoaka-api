// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "rocket-api",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.0.0"),
        .package(url: "https://github.com/kateinoigakukun/StubKit.git", from: "0.1.6"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.2.1"),
        .package(name: "AWSSDKSwift", url: "https://github.com/soto-project/soto.git", from: "4.0.0"),
        .package(path: "Modules/LoggingDiscord"),
        .package(path: "Modules/Core"),
        .package(path: "Modules/Endpoint"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "Persistance", package: "Core"),
                .product(name: "Service", package: "Core"),
                .product(name: "LoggingDiscord", package: "LoggingDiscord"),
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
        .target(name: "Seed", dependencies: [
            .product(name: "Endpoint", package: "Endpoint"),
            .product(name: "StubKit", package: "StubKit"),
            .product(name: "CognitoIdentityProvider", package: "AWSSDKSwift"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ]),
        .target(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
            .product(name: "CognitoIdentityProvider", package: "AWSSDKSwift"),
            .product(name: "StubKit", package: "StubKit"),
        ]),
    ]
)
