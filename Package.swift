// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "OpenAPILoggingMiddleware",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "OpenAPILoggingMiddleware",
            targets: ["OpenAPILoggingMiddleware"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "OpenAPILoggingMiddleware",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "Logging", package: "swift-log")
            ]
        )
    ]
)
