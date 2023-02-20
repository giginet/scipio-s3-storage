// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ScipioS3Storage",
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
                 from: "0.7.0"),
        .package(url: "https://github.com/awslabs/aws-sdk-swift.git", 
                 from: "0.10.0"),
    ],
    targets: [
        .target(
            name: "ScipioS3Storage",
            dependencies: [
                .product(name: "ScipioKit", package: "Scipio"),
                .product(name: "AWSS3", package: "aws-sdk-swift"),
            ]),
        .testTarget(
            name: "ScipioS3StorageTests",
            dependencies: ["ScipioS3Storage"]),
    ]
)
