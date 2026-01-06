# ``docc_static``

@Metadata {
    @DisplayName("docc-static")
}

A command-line tool for generating static HTML/CSS documentation from Swift packages.

## Overview

The `docc-static` command-line tool generates pure HTML/CSS documentation from Swift packages.
The output works locally as `file://` URLs and can be hosted on any static web server
without requiring JavaScript (on the server or in the browser) for basic navigation.

### Installation

Install using Homebrew:

```bash
brew tap mipalgu/tap
brew install swift-docc-static
```

Or build from source:

```bash
git clone https://github.com/mipalgu/swift-docc-static.git
cd swift-docc-static
swift build -c release
```

### Quick Start

Generate documentation for a Swift package:

```bash
docc-static generate --package-path /path/to/package --output ./docs
```

Preview the generated documentation:

```bash
docc-static preview --output ./docs
```

## Commands

### generate

Generate documentation from a Swift package:

```bash
docc-static generate [options]
```

**Options:**

| Option                           | Description                                        |
|----------------------------------|----------------------------------------------------|
| `-p, --package-path`             | Path to the Swift package (default: `.`)           |
| `-o, --output`                   | Output directory (default: `.build/documentation`) |
| `--scratch-path`.                | Scratch path for Swift build operations            |
| `--symbol-graph-dir`             | Pre-generated symbol graph directory               |
| `-t, --target`                   | Specific targets to document (repeatable)          |
| `-I, --include-all-dependencies` | Include all dependencies                           |
| `-i, --include-dependency`       | Include specific dependency (repeatable)           |
| `-x, --exclude-dependency`       | Exclude specific dependency (repeatable)           |
| `-e, --external-docs`            | External docs URL mapping (`Package=URL`)          |
| `--disable-search`               | Disable client-side search                         |
| `--footer`                       | Custom HTML for page footer                        |
| `-v, --verbose`                  | Enable verbose output                              |

**Examples:**

```bash
# Generate with verbose output
docc-static generate -v

# Document specific targets
docc-static generate -t MyLib -t MyOtherLib

# Include dependencies except specific ones
docc-static generate -I -x ExcludedPackage

# Link to external documentation
docc-static generate -e Foundation=https://developer.apple.com/documentation/foundation
```

### render

Render static HTML from an existing DocC archive:

```bash
docc-static render <archive-path> --output ./docs
```

### preview

Start a local preview server:

```bash
docc-static preview --output ./docs --port 8080
```

