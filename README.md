# swift-docc-static

A tool and plugin to generate static HTML/CSS documentation for Swift packages
that works without JavaScript.

## Overview

`swift-docc-static` generates pure HTML/CSS documentation from Swift packages
using the [DocC](https://github.com/swiftlang/swift-docc) infrastructure.
The output can be viewed locally as `file://` URLs or hosted on any static web server
without requiring JavaScript for core functionality.

### Aims / Features

- **Pure HTML/CSS output** - Documentation works without JavaScript enabled
- **Full DocC support** - API documentation, articles, and tutorials
- **Light/Dark mode** - Automatic theme switching based on system preferences
- **Interactive tutorials** - Display step-by-step tutorials with code examples and quizzes
- **Cross-package linking** - Relative links work with `file://` URLs for testing
- **Multi-target support** - Document all targets in a package
- **Optional search** - Client-side search using Lunr.js (requires JavaScript)
- **SPM plugin** - Integrate documentation generation into your build process

## Requirements

- Swift 6.2+
- Linux or macOS 14+

## Installation

### Building from Source

```bash
git clone https://github.com/mipalgu/swift-docc-static.git
cd swift-docc-static
swift build -c release
```

The executable will be at `.build/release/docc-static`.

### As a Package Dependency

The package provides a `generate-static-documentation` package command plugin
that you can use directly in your own packages by simply adding the following
to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mipalgu/swift-docc-static.git", branch: "main"),
]
```

## Usage

### Generate Documentation

Generate documentation for a Swift package using the command-line tool:

```bash
docc-static generate --package-path /path/to/package --output ./docs
```

#### Options

| Option                           | Description                                            |
|----------------------------------|--------------------------------------------------------|
| `-p, --package-path`.            | Path to the package directory (default: `.`).          |
| `-o, --output`                   | Output directory (default: `.build/documentation`)     |
| `--scratch-path`                 | Scratch path for Swift build operations                |
| `--symbol-graph-dir`             | Pre-generated symbol graph directory (skips build).    |
| `-t, --target`                   | Specific targets to document (can be repeated)         |
| `-I, --include-all-dependencies` | Include documentation for all dependencies             |
| `-i, --include-dependency`       | Include a specific dependency (can be repeated)        |
| `-x, --exclude-dependency`       | Exclude a specific dependency (can be repeated)        |
| `-e, --external-docs`            | External documentation URL (format: `PackageName=URL`) |
| `-s, --include-search`           | Generate client-side search functionality              |
| `--footer`                       | Custom HTML for the page footer                        |
| `-v, --verbose`                  | Enable verbose output                                  |

#### Examples

Generate documentation with verbose output:

```bash
docc-static generate -p ./MyPackage -o ./docs -v
```

Generate documentation for specific targets:

```bash
docc-static generate -t MyLibrary -t MyOtherLibrary -o ./docs
```

Include all dependencies except specific ones:

```bash
docc-static generate -I -x ExcludedPackage -o ./docs
```

Link to external documentation:

```bash
docc-static generate -e Foundation=https://developer.apple.com/documentation/foundation -o ./docs
```

### Render from DocC Archive

Render static HTML from an existing `.doccarchive`:

```bash
docc-static render /path/to/MyPackage.doccarchive --output ./docs
```

### Preview Documentation

Start a local preview server:

```bash
docc-static preview --output ./docs --port 8080
```

Then open `http://localhost:8080` in your browser.

### SPM Plugin

Use the Swift Package Manager plugin to generate documentation:

```bash
swift package generate-static-documentation
```

Or with options:

```bash
swift package --scratch-path /tmp/build generate-static-documentation
```

## Output Structure

```
docs/
├── index.html              # Main landing page
├── css/
│   └── main.css            # Stylesheet
├── js/                     # Optional JavaScript (search)
├── images/                 # Image assets
├── downloads/              # Downloadable files
├── videos/                 # Video assets
├── documentation/
│   └── mypackage/
│       ├── index.html      # Module overview
│       └── mytype/
│           └── index.html  # Type documentation
└── tutorials/
    ├── tutorials/
    │   └── index.html      # Tutorials overview
    └── mypackage/
        └── my-tutorial/
            └── index.html  # Tutorial page
```

## Customisation

### Custom Footer

Add custom HTML to the page footer:

```bash
docc-static generate --footer '<a href="https://example.com">My Company</a>'
```

### Theming

The generated CSS uses CSS custom properties for theming. Override these in your own stylesheet to customise colours:

```css
:root {
    --docc-bg: #ffffff;
    --docc-fg: #1d1d1f;
    --docc-accent: #0066cc;
    /* ... */
}

@media (prefers-color-scheme: dark) {
    :root {
        --docc-bg: #1d1d1f;
        --docc-fg: #f5f5f7;
        /* ... */
    }
}
```

## Architecture

`swift-docc-static` leverages the existing DocC infrastructure:

- Uses `SwiftDocC` for symbol graph processing and content parsing
- Implements `ConvertOutputConsumer` to generate static HTML
- Renders `RenderNode` structures to pure HTML/CSS pages
- Supports all DocC content types: symbols, articles, and tutorials

### Key Components

| Component                      | Description                                    |
|--------------------------------|------------------------------------------------|
| `StaticDocumentationGenerator` | Main orchestrator for documentation generation |
| `StaticHTMLConsumer`           | Implements `ConvertOutputConsumer` protocol    |
| `HTMLPageBuilder`              | Builds HTML pages from `RenderNode` data       |
| `IndexPageBuilder`             | Creates the combined index page                |
| `SearchIndexBuilder`           | Generates Lunr.js search index                 |

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Licence

This project is available under the Apache License 2.0. See the [LICENCE](LICENCE) file for details.

## Acknowledgements

- [Swift DocC](https://github.com/swiftlang/swift-docc) - Documentation compiler
- [Swift DocC Plugin](https://github.com/swiftlang/swift-docc-plugin) - Package documentation plugin
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser) - CLI argument parsing
- [Lunr.js](https://lunrjs.com) - Client-side search (optional, requires JavaScript enabled in the browser)
