// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LegacyLense",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "LegacyLense",
            targets: ["LegacyLense"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/awslabs/aws-sdk-swift",
            from: "1.0.0"
        )
    ],
    targets: [
        .target(
            name: "LegacyLense",
            dependencies: [
                .product(name: "AWSS3", package: "aws-sdk-swift"),
                .product(name: "AWSLambda", package: "aws-sdk-swift"),
                .product(name: "AWSClientRuntime", package: "aws-sdk-swift")
            ]),
        .testTarget(
            name: "LegacyLenseTests",
            dependencies: ["LegacyLense"]),
    ]
)