// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SpatioSDK",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SpatioSDK",
            targets: ["SpatioSDK"]),
    ],
    dependencies: [],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SpatioSDK",
            path: "Sources/SpatioSDK",
            resources: [.process("Resources")]),
        .testTarget(
            name: "SpatioSDKTests",
            dependencies: ["SpatioSDK"]),
    ],
    swiftLanguageVersions: [.v5]
)
