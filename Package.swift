// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-docc-static",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        // Core library for programmatic use
        .library(
            name: "DocCStatic",
            targets: ["DocCStatic"]
        ),
        // Command-line tool
        .executable(
            name: "docc-static",
            targets: ["docc-static"]
        ),
    ],
    dependencies: [
        // Core DocC functionality
        .package(url: "https://github.com/swiftlang/swift-docc.git", branch: "main"),

        // CLI argument parsing
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        // MARK: - Core Library

        .target(
            name: "DocCStatic",
            dependencies: [
                .product(name: "SwiftDocC", package: "swift-docc"),
            ],
            path: "Sources/DocCStatic"
        ),

        // MARK: - CLI Executable

        .executableTarget(
            name: "docc-static",
            dependencies: [
                "DocCStatic",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/docc-static"
        ),

        // MARK: - SPM Plugin

        .plugin(
            name: "GenerateStaticDocumentation",
            capability: .command(
                intent: .custom(
                    verb: "generate-static-documentation",
                    description: "Generate static HTML documentation for the package"
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Write generated documentation to the package directory"),
                ]
            ),
            dependencies: [
                "docc-static",
            ],
            path: "Plugins/GenerateStaticDocumentation"
        ),

        // MARK: - Tests

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
