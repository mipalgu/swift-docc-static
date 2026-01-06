// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-docc-static",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // Command-line tool
        .executable(
            name: "docc-static",
            targets: ["docc-static"]
        ),
        // SPM plugin for documentation generation
        .plugin(
            name: "Static Documentation Plugin",
            targets: ["GenerateStaticDocumentation"]
        ),
        // Core library for programmatic use
        .library(
            name: "DocCStatic",
            targets: ["DocCStatic"]
        ),
    ],
    dependencies: [
        // Core DocC functionality
        .package(url: "https://github.com/swiftlang/swift-docc.git", branch: "main"),

        // CLI argument parsing
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),

        // Subprocess handling
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.1.0"),

        // System types (for Linux compatibility)
        .package(url: "https://github.com/apple/swift-system.git", from: "1.4.0"),

        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "docc-static",
            dependencies: [
                "DocCStatic",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/docc-static"
        ),
        .plugin(
            name: "GenerateStaticDocumentation",
            capability: .command(
                intent: .custom(
                    verb: "generate-static-documentation",
                    description: "Generate static HTML documentation for the package"
                )
            ),
            dependencies: [
                "docc-static",
            ],
            path: "Plugins/GenerateStaticDocumentation"
        ),
        .target(
            name: "DocCStatic",
            dependencies: [
                .product(name: "SwiftDocC", package: "swift-docc"),
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "SystemPackage", package: "swift-system"),
            ],
            path: "Sources/DocCStatic"
        ),
        .testTarget(
            name: "DocCStaticTests",
            dependencies: ["DocCStatic"],
            path: "Tests/DocCStaticTests"
//            resources: [
//                .copy("Fixtures"),
//            ]
        ),
    ]
)
