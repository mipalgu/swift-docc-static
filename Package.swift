// swift-tools-version: 6.2

import PackageDescription

#if os(Windows)
    let serverTargets: [PackageDescription.Target] = []
    let serverProducts: [PackageDescription.Product] = []
    let serverTestTargets: [PackageDescription.Target] = []
    let nioDependencies: [PackageDescription.Package.Dependency] = []
    let asyncHTTPClientDependencies: [PackageDescription.Package.Dependency] = []
    let executableServerDependencies: [PackageDescription.Target.Dependency] = []
#else
    let serverTargets: [PackageDescription.Target] = [
        .target(
            name: "DocCStaticServer",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
            path: "Sources/DocCStaticServer"
        )
    ]
    let serverProducts: [PackageDescription.Product] = [
        // Preview server library
        .library(
            name: "DocCStaticServer",
            targets: ["DocCStaticServer"]
        )
    ]
    let serverTestTargets: [PackageDescription.Target] = [
        .testTarget(
            name: "DocCStaticServerTests",
            dependencies: [
                "DocCStaticServer",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            path: "Tests/DocCStaticServerTests"
        )
    ]
    let nioDependencies: [PackageDescription.Package.Dependency] = [
        // HTTP server for preview
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.79.0")
    ]
    let asyncHTTPClientDependencies: [PackageDescription.Package.Dependency] = [
        // HTTP client for testing (test-only)
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0")
    ]
    let executableServerDependencies: [PackageDescription.Target.Dependency] = [
        "DocCStaticServer"
    ]
#endif

let package = Package(
    name: "swift-docc-static",
    platforms: [
        .macOS(.v14)
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
    ] + serverProducts,
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
    ] + nioDependencies + asyncHTTPClientDependencies,
    targets: [
        .executableTarget(
            name: "docc-static",
            dependencies: [
                "DocCStatic",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ] + executableServerDependencies,
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
                "docc-static"
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
    ] + serverTargets + serverTestTargets
)
