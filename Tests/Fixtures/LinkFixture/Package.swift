// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LinkFixture",
    products: [
        .library(name: "FixtureShapes", targets: ["FixtureShapes"]),
        .library(name: "FixtureSketches", targets: ["FixtureSketches"]),
    ],
    dependencies: [
        .package(path: "FixturePalette"),
    ],
    targets: [
        .target(
            name: "FixtureShapes",
            dependencies: [.product(name: "FixtureColours", package: "FixturePalette")]
        ),
        .target(
            name: "FixtureSketches",
            dependencies: [.product(name: "FixtureColours", package: "FixturePalette")]
        ),
    ]
)
