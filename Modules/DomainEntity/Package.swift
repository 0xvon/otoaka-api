// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "DomainEntity",
    products: [
        .library(name: "DomainEntity", type: .dynamic, targets: ["DomainEntity"]),
    ],
    targets: [
        .target(name: "DomainEntity"),
    ]
)
