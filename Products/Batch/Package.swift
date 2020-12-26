// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Batch",
    platforms: [.macOS(.v10_15)],
    products: [
        .executable(
            name: "NotifyTomorrowLives",
            targets: ["NotifyTomorrowLives"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "0.3.0"),
        .package(path: "../../Modules/Core"),
    ],
    targets: [
        .target(name: "NotifyTomorrowLives", dependencies: [
            .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
            .product(name: "Persistance", package: "Core"),
            .product(name: "Service", package: "Core"),
        ]),
    ]
)
