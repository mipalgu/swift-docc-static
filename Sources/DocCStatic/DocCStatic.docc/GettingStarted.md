# Getting Started with DocCStatic

Use the DocCStatic library to generate static documentation programmatically.

## Overview

The DocCStatic library provides a Swift API for generating static HTML/CSS
documentation from Swift packages. Use it when you need programmatic control
over the documentation generation process, such as integrating into custom
build systems or creating documentation tooling.

> Tip: For most use cases, consider using the **docc-static** command-line tool
> or the **SPM plugin** instead. See the related documentation below.

## Adding DocCStatic to Your Project

Add DocCStatic as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mipalgu/swift-docc-static.git", from: "1.0.0"),
]
```

For a command-line tool or script, add the product dependency:

```swift
.executableTarget(
    name: "MyDocTool",
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

### Configuration Options

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

See ``Configuration`` for all available options.

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

The generator returns a ``GenerationResult`` with statistics about the
generated documentation.

## Output Structure

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

## Rendering from Archives

If you have pre-generated DocC archives, render them directly:

```swift
let generator = StaticDocumentationGenerator(configuration: configuration)
let result = try await generator.renderFromArchive(archiveURL)
```

## Error Handling

The generator throws ``GenerationError`` for recoverable errors:

```swift
do {
    let result = try await generator.generate()
} catch let error as GenerationError {
    switch error {
    case .packageNotFound:
        print("Package.swift not found")
    case .buildFailed(let message):
        print("Build failed: \(message)")
    case .archiveParsingFailed(let message):
        print("Archive parsing failed: \(message)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Next Steps

- <doc:Configuration>
- <doc:CrossPackageLinking>
- <doc:CustomThemes>

## Alternatives

For simpler use cases, consider:

- **docc-static CLI** - Command-line tool for direct usage
- **SPM Plugin** - Integrated Swift Package Manager workflow
