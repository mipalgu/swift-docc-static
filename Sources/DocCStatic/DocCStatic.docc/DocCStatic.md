# ``DocCStatic``

Generate static HTML/CSS documentation from Swift packages.

## Overview

DocCStatic generates pure HTML/CSS documentation from Swift packages, combining the symbol graph processing of Swift-DocC with a static output approach. The generated documentation works locally as file:// URLs and can be hosted on any web server without requiring JavaScript for basic navigation.

### Key Features

- **Pure HTML/CSS output**: JavaScript is only used for optional client-side search
- **Multi-target support**: Document all targets and products in a package
- **Cross-package linking**: Relative links work correctly for local file:// URLs
- **DocC compatibility**: Supports symbols, articles, and tutorials
- **Customisable styling**: Match Apple's DocC appearance or use your own theme

### Quick Start

Create a generator with your configuration, then call `generate()`:

```swift
let configuration = Configuration(
    packageDirectory: URL(fileURLWithPath: "/path/to/package"),
    outputDirectory: URL(fileURLWithPath: "/path/to/docs"),
    includeSearch: true
)
let generator = StaticDocumentationGenerator(configuration: configuration)
let result = try await generator.generate()
print("Generated \(result.generatedPages) pages")
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Configuration>
- ``Configuration``
- ``StaticDocumentationGenerator``

### Generation

- ``GenerationResult``
- ``GenerationError``

### Rendering

- ``HTMLPageBuilder``
- ``RenderContentHTMLRenderer``
- ``IndexPageBuilder``
- ``StaticHTMLConsumer``

### Search

- ``SearchIndexBuilder``

### Configuration Types

- ``DependencyInclusionPolicy``
- ``ThemeConfiguration``
- ``Warning``
- ``SourceLocation``
