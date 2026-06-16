// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SecureVaultKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SecureVaultKit",
            targets: ["SecureVaultKit"]
        )
    ],
    targets: [
        .target(
            name: "SecureVaultKit",
            dependencies: []
        ),
        .testTarget(
            name: "SecureVaultKitTests",
            dependencies: ["SecureVaultKit"]
        )
    ]
)
