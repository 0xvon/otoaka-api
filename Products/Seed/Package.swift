// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "Seed",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(url: "https://github.com/kateinoigakukun/StubKit.git", from: "0.1.6"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.2.1"),
        .package(name: "AWSSDKSwift", url: "https://github.com/soto-project/soto.git", from: "4.0.0"),
        .package(path: "../../Modules/Endpoint"),
    ],
    targets: [
        .target(name: "Seed", dependencies: [
            .product(name: "Endpoint", package: "Endpoint"),
            .product(name: "StubKit", package: "StubKit"),
            .product(name: "CognitoIdentityProvider", package: "AWSSDKSwift"),
            .product(name: "AsyncHTTPClient", package: "async-http-client"),
        ]),
    ]
)
