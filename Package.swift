// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TheCaddie",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "TheCaddieDomain",
            targets: ["TheCaddieDomain"]
        )
    ],
    targets: [
        .target(
            name: "TheCaddieDomain"
        ),
        .testTarget(
            name: "TheCaddieDomainTests",
            dependencies: ["TheCaddieDomain"]
        )
    ]
)
