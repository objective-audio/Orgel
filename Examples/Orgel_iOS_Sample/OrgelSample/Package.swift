// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OrgelSample",
    platforms: [.iOS(.v17)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OrgelSample",
            targets: ["OrgelSample"])
    ],
    dependencies: [
        .package(path: "../Orgel"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OrgelSample",
            dependencies: [
                "Orgel",
                .product(name: "OrderedCollections", package: "swift-collections"),
            ]),
        .testTarget(
            name: "OrgelSampleTests",
            dependencies: ["OrgelSample"]),
    ]
)
