// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SidebarFixture",
    products: [
        .library(name: "FixtureCore", targets: ["FixtureCore"]),
        .library(name: "FixtureExtras", targets: ["FixtureExtras"]),
    ],
    targets: [
        .target(name: "FixtureCore"),
        .target(name: "FixtureExtras", dependencies: ["FixtureCore"]),
    ]
)
