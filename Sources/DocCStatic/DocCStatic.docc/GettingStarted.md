# Getting Started with DocCStatic

Generate your first static documentation from a Swift package.

## Overview

DocCStatic generates static HTML documentation from Swift packages. Unlike standard DocC output which requires a web server and JavaScript, DocCStatic produces pure HTML/CSS that works directly in a browser via file:// URLs.

This guide walks you through:
1. Adding DocCStatic to your project
2. Configuring the generator
3. Generating documentation
4. Viewing the output

## Adding DocCStatic to Your Project

Add DocCStatic as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mipalgu/swift-docc-static.git", from: "1.0.0"),
]
```

For a command-line tool or script, add the product dependency:

```swift
.target(
    name: "MyTool",
    dependencies: [
        .product(name: "DocCStatic", package: "swift-docc-static"),
    ]
)
```

## Configuring the Generator

Create a ``Configuration`` with your package and output directories:

```swift
import DocCStatic

let configuration = Configuration(
    packageDirectory: URL(fileURLWithPath: "/path/to/my-package"),
    outputDirectory: URL(fileURLWithPath: "/path/to/docs")
)
```

### Optional Configuration

Customise the generation with additional options:

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    targets: ["MyLib", "MyOtherLib"],           // Specific targets only
    dependencyPolicy: .exclude(["SomeDep"]),    // Exclude specific deps
    includeSearch: true,                        // Enable Lunr.js search
    isVerbose: true                             // Verbose logging
)
```

## Generating Documentation

Create a generator and call ``StaticDocumentationGenerator/generate()``:

```swift
let generator = StaticDocumentationGenerator(configuration: configuration)

do {
    let result = try await generator.generate()
    print("Generated \(result.generatedPages) pages")
    print("Output: \(result.outputDirectory.path)")
} catch {
    print("Error: \(error)")
}
```

## Viewing the Output

Open the generated `index.html` directly in a browser:

```bash
open /path/to/docs/index.html
```

The documentation works without a web server. All links use relative paths that function correctly with file:// URLs.

### Output Structure

The generator creates the following structure:

```
docs/
├── index.html              # Combined landing page
├── css/
│   └── main.css           # Stylesheet
├── js/
│   ├── lunr.min.js        # Search library (if enabled)
│   └── search.js          # Search functionality
├── documentation/
│   └── {module}/
│       ├── index.html     # Module overview
│       └── {symbol}/
│           └── index.html # Symbol documentation
└── search-index.json      # Search index (if enabled)
```

## Using the Command-Line Tool

You can also use the `docc-static` command-line tool:

```bash
# Basic usage
docc-static generate --package-path /path/to/package --output /path/to/docs

# With options
docc-static generate \
    --package-path . \
    --output ./docs \
    --target MyLib \
    --verbose
```

See the **docc-static** module documentation for a complete reference of all commands and options.

## Using the SPM Plugin

Add the plugin to your package and run:

```bash
swift package generate-static-documentation --output ./docs
```

## Next Steps

- <doc:Configuration> - Learn about all configuration options
- <doc:CrossPackageLinking> - Understand how cross-package links work
- <doc:CustomThemes> - Customise the documentation appearance
