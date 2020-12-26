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
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.18.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.0.0"),
        .package(url: "https://github.com/kateinoigakukun/StubKit.git", from: "0.1.6"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.2.1"),
        .package(name: "AWSSDKSwift", url: "https://github.com/soto-project/soto.git", from: "4.0.0"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "0.3.0"),
        .package(path: "Endpoint"),
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .target(name: "Persistance"),
                .target(name: "LoggingDiscord"),
                .target(name: "Service")
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
        .target(name: "NotifyTomorrowLives", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .target(name: "Persistance"),
            .target(name: "Service")
        ]),
        .target(name: "Seed", dependencies: [
            .product(name: "Endpoint", package: "Endpoint"),
            .product(name: "StubKit", package: "StubKit"),
            .product(name: "CognitoIdentityProvider", package: "AWSSDKSwift"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ]),
        .target(name: "LoggingDiscord", dependencies: [
            .product(name: "Logging", package: "swift-log"),
        ]),
        .target(name: "Service", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .target(name: "Domain"),
            .product(name: "SNS", package: "AWSSDKSwift"),
        ]),
        .target(name: "Domain", dependencies: [
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "Endpoint", package: "Endpoint"),
        ]),
        .target(name: "Persistance", dependencies: [
            .product(name: "Fluent", package: "fluent"),
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "FluentMySQLDriver", package: "fluent-mysql-driver"),
            .target(name: "Domain"),
        ]),
        .target(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "DomainTests", dependencies: [
            .target(name: "Domain"),
            .product(name: "StubKit", package: "StubKit"),
        ]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
            .product(name: "CognitoIdentityProvider", package: "AWSSDKSwift"),
            .product(name: "StubKit", package: "StubKit"),
        ]),
    ]
)
