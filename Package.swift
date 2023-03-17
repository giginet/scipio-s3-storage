// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "scipio-s3-storage",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "ScipioS3Storage",
            targets: ["ScipioS3Storage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/giginet/Scipio.git",
                 branch: "support-async-cache"),
        .package(url: "https://github.com/soto-project/soto-codegenerator", 
                 from: "0.6.0"),
        .package(url: "https://github.com/soto-project/soto-core.git", 
                 from: "6.4.0"),
    ],
    targets: [
        .target(
            name: "ScipioS3Storage",
            dependencies: [
                .product(name: "ScipioKit", package: "Scipio"),
                .product(name: "SotoCore", package: "soto-core"),
            ],
            plugins: [
                .plugin(name: "SotoCodeGeneratorPlugin", package: "soto-codegenerator"),
            ]
        ),
        .testTarget(
            name: "ScipioS3StorageTests",
            dependencies: ["ScipioS3Storage"]),
    ]
)
