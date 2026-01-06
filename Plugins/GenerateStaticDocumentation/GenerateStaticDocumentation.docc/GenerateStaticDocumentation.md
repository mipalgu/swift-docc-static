# Static Documentation Plugin

A Swift Package Manager plugin for generating static documentation
using DocC.

## Overview

The plugin integrates with Swift Package Manager to generate static HTML/CSS documentation
directly from your package.  It expands the `swift package` command with a subcommand
`generate-static-documentation` that renders static HTML / CSS documentation by calling
the `docc-static` command.

### Setup

Add `swift-docc-static` as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mipalgu/swift-docc-static.git", branch: "main"),
]
```

No additional configuration is needed - the plugin is automatically available.

### Usage

Run the plugin from your package directory:

```bash
swift package generate-static-documentation
```

For faster builds, use a custom scratch path:

```bash
swift package --scratch-path /tmp/build generate-static-documentation
```

### Output

The plugin generates documentation in `.build/documentation` by default. Open `index.html` in a browser to view the documentation:

```bash
open .build/documentation/index.html
```

## Topics

### Plugin

- ``GenerateStaticDocumentation``
