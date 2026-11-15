// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FixturePalette",
    products: [
        .library(name: "FixtureColours", targets: ["FixtureColours"]),
    ],
    targets: [
        .target(name: "FixtureColours"),
    ]
)
