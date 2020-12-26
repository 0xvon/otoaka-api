// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Batch",
    products: [
        .executable(
            name: "NotifyTomorrowLives",
            targets: ["NotifyTomorrowLives"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "0.3.0"),
        .package(path: "../Endpoint"),
    ],
    targets: [
        .target(name: "NotifyTomorrowLives", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
        ]),
        .target(name: "Persistance", package: "App"),
        .target(name: "Service", path: "../Sources/Service"),
        .target(name: "Domain", path: "../Sources/Domain"),
    ]
)
