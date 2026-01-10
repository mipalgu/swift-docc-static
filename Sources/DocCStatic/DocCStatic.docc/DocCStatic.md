# ``DocCStatic``

@Metadata {
    @DisplayName("DocCStatic Library")
}

Generate static HTML/CSS documentation from Swift packages.

## Overview

swift-docc-static generates pure HTML/CSS documentation from Swift packages, combining the symbol graph processing of Swift-DocC with a static output approach. The generated documentation works locally as file:// URLs and can be hosted on any web server without requiring JavaScript for basic navigation.

This package provides:
- The **DocCStatic** Swift library for programmatic use (documented here)
- The **docc-static** command-line tool (see the docc-static module)
- The **SPM plugin** for Swift Package Manager integration (see the GenerateStaticDocumentation module)

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

### Guides

- <doc:Configuration>
- <doc:CrossPackageLinking>
- <doc:CustomThemes>

### Library API

- ``Configuration``
- ``StaticDocumentationGenerator``
- ``GenerationResult``
- ``GenerationError``

### Rendering

- ``HTMLPageBuilder``
- ``RenderContentHTMLRenderer``
- ``IndexPageBuilder``
- ``StaticHTMLConsumer``

### Search

- ``SearchIndexBuilder``

### Supporting Types

- ``DependencyInclusionPolicy``
- ``ThemeConfiguration``
- ``Warning``
- ``SourceLocation``

### Related

- ``docc_static``
- ``GenerateStaticDocumentation``
