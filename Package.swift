// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "docc-static",
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "docc-static"
        ),
    ]
)
