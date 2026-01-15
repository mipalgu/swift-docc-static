# Configuration Reference

Configure DocCStatic for your documentation needs.

## Overview

The ``Configuration`` type controls all aspects of documentation generation, from which targets to document to the visual appearance of the output.

## Basic Configuration

At minimum, you need to specify the package and output directories:

```swift
let configuration = Configuration(
    packageDirectory: URL(fileURLWithPath: "/path/to/package"),
    outputDirectory: URL(fileURLWithPath: "/path/to/docs")
)
```

## Target Selection

By default, DocCStatic documents all targets in your package. To document specific targets only:

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    targets: ["MyLibrary", "MyUtilities"]
)
```

## Dependency Policies

Control which dependencies are included using ``DependencyInclusionPolicy``:

### Include All Dependencies (Default)

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    dependencyPolicy: .all
)
```

### Exclude Specific Packages

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    dependencyPolicy: .exclude(["LargeDependency", "InternalOnly"])
)
```

### Include Only Specific Packages

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    dependencyPolicy: .includeOnly(["PublicAPI"])
)
```

### Exclude All Dependencies

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    dependencyPolicy: .none
)
```

## External Documentation Links

Link to external documentation for excluded dependencies:

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    dependencyPolicy: .exclude(["SwiftNIO"]),
    externalDocumentationURLs: [
        "SwiftNIO": URL(string: "https://swiftpackageindex.com/apple/swift-nio")!
    ]
)
```

When a symbol from an excluded package is referenced, the generated documentation links to the external URL instead of an internal page.

## Search Configuration

Enable client-side search with Lunr.js:

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    includeSearch: true
)
```

When search is enabled, the generator:
1. Creates a `search-index.json` file with all searchable content
2. Includes the Lunr.js library
3. Adds a search form to the index page
4. Provides incremental search across all documentation

> Note: Search requires JavaScript and works when served from a web server. It typically does not function with `file://` URLs due to browser security restrictions.

## Theme Configuration

Customise the visual appearance with ``ThemeConfiguration``:

### Custom Accent Colour

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    theme: ThemeConfiguration(
        accentColour: "#ff5500",
        includeDarkMode: true
    )
)
```

### Disable Dark Mode

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    theme: ThemeConfiguration(
        accentColour: "#0066cc",
        includeDarkMode: false
    )
)
```

### Custom CSS

Append custom CSS to the generated stylesheet:

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    theme: ThemeConfiguration(
        accentColour: "#0066cc",
        includeDarkMode: true,
        customCSS: """
        .my-custom-class {
            font-weight: bold;
        }
        """
    )
)
```

## Verbose Output

Enable detailled logging during generation:

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    isVerbose: true
)
```

This outputs progress messages including:
- Symbol graph generation status
- DocC conversion progress
- Page rendering information
- Asset writing confirmation

## Complete Example

A fully-configured example:

```swift
let configuration = Configuration(
    packageDirectory: URL(fileURLWithPath: "."),
    outputDirectory: URL(fileURLWithPath: ".build/docs"),
    targets: ["MyLibrary"],
    dependencyPolicy: .exclude(["TestSupport"]),
    externalDocumentationURLs: [
        "com.apple.documentation": URL(string: "https://developer.apple.com")!
    ],
    includeSearch: true,
    theme: ThemeConfiguration(
        accentColour: "#007aff",
        includeDarkMode: true,
        customCSS: ".header { background: linear-gradient(...); }"
    ),
    isVerbose: true
)
```

## See Also

- ``Configuration``
- ``DependencyInclusionPolicy``
- ``ThemeConfiguration``
- <doc:GettingStarted>
