// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "scipio-s3-storage",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "ScipioS3Storage",
            targets: ["ScipioS3Storage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/soto-project/soto-codegenerator", 
                 from: "7.1.0"),
        .package(url: "https://github.com/soto-project/soto-core.git",
                 from: "7.1.0"),
        .package(url: "https://github.com/giginet/scipio-cache-storage.git",
                 from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "ScipioS3Storage",
            dependencies: [
                .product(name: "ScipioStorage", package: "scipio-cache-storage"),
                .product(name: "SotoCore", package: "soto-core"),
            ],
            plugins: [
                .plugin(name: "SotoCodeGeneratorPlugin", package: "soto-codegenerator"),
            ]
        ),
        .testTarget(
            name: "ScipioS3StorageTests",
            dependencies: ["ScipioS3Storage"]),
    ],
    swiftLanguageModes: [.v6]
)
