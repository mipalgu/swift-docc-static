# Getting Started with the Plugin

Add the SPM plugin to your package for integrated documentation generation.

## Overview

The Static Documentation Plugin integrates directly with Swift Package Manager,
allowing you to generate documentation using the familiar `swift package` command.
This is the recommended approach for most Swift packages.

## Adding the Plugin

Add `swift-docc-static` as a dependency in your `Package.swift`:

```swift
let package = Package(
    name: "MyPackage",
    dependencies: [
        .package(url: "https://github.com/mipalgu/swift-docc-static.git", branch: "main"),
    ],
    targets: [
        // Your targets here
    ]
)
```

No additional configuration is needed. The plugin is automatically available
once the dependency is added.

## Generating Documentation

From your package directory, run:

```bash
swift package generate-static-documentation
```

This generates documentation for all targets in your package.

### Specifying Output Location

By default, documentation is generated in `.build/documentation`. To specify
a different location:

```bash
swift package generate-static-documentation --output ./docs
```

### Using a Scratch Path

For faster subsequent builds, use a dedicated scratch path:

```bash
swift package --scratch-path /tmp/build generate-static-documentation
```

## Viewing Documentation

Open the generated documentation in your browser:

```bash
open .build/documentation/index.html
```

Or if you specified a custom output:

```bash
open ./docs/index.html
```

## Why Use the Plugin?

The plugin approach has several advantages:

1. **Integrated workflow** - Uses `swift package` like other SPM commands
2. **Automatic symbol graph generation** - Handles the build process for you
3. **Consistent environment** - Uses the same Swift toolchain as your build
4. **No external installation** - Works immediately after adding the dependency

## Next Steps

- <doc:PluginOptions> - Learn about all available options
- <doc:XcodeIntegration> - Use with Xcode projects

## See Also

- ``GenerateStaticDocumentation``
- ``docc_static`` - The standalone command-line tool
- ``DocCStatic`` - The underlying library
