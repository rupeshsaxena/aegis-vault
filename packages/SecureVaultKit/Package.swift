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
            dependencies: [],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "SecureVaultKitTests",
            dependencies: ["SecureVaultKit"]
        )
    ]
)
