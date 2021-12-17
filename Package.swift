// swift-tools-version:5.2
import PackageDescription

// Disable availability checking to use concurrency API on macOS for development purpose
// SwiftNIO exposes concurrency API with availability for deployment environment,
// but in our use case, the deployment target is Linux, and we only use macOS while development,
// so it's always safe to disable the checking in this situation.
let swiftSettings: [SwiftSetting] = [
    .unsafeFlags(["-Xfrontend", "-disable-availability-checking"])
]

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
<<<<<<< HEAD
        .package(url: "https://github.com/soto-project/soto.git", from: "5.2.0"),
=======
>>>>>>> c569d8f... Auth0Client test
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
            ] + swiftSettings
        ),
        .target(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
            .product(name: "SotoCognitoIdentityProvider", package: "soto"),
            .product(name: "StubKit", package: "StubKit"),
        ], swiftSettings: swiftSettings),
    ]
)
