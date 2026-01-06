# Getting Started with docc-static

Install and use the command-line tool to generate static documentation.

## Overview

The `docc-static` command-line tool generates pure HTML/CSS documentation from Swift packages.
The output works locally as `file://` URLs and can be hosted on any static web server
without requiring JavaScript for basic navigation.

## Installation

### Using Homebrew (Recommended)

Install using [Homebrew](https://brew.sh):

```bash
brew tap mipalgu/tap
brew install swift-docc-static
```

To upgrade to the latest version:

```bash
brew upgrade swift-docc-static
```

### Building from Source

Clone the repository and build:

```bash
git clone https://github.com/mipalgu/swift-docc-static.git
cd swift-docc-static
swift build -c release
```

The executable is located at `.build/release/docc-static`.

### Verifying Installation

Check that docc-static is installed correctly:

```bash
docc-static --version
```

## Your First Documentation

Generate documentation for a Swift package:

```bash
cd /path/to/your/package
docc-static generate --output ./docs
```

Open the generated documentation:

```bash
open ./docs/index.html
```

## Basic Commands

### Generate Documentation

```bash
docc-static generate --package-path . --output ./docs
```

### Preview with Local Server

```bash
docc-static preview --output ./docs --port 8080
```

Then open `http://localhost:8080` in your browser.

### Render from Existing Archive

If you have a pre-built DocC archive:

```bash
docc-static render /path/to/MyLibrary.doccarchive --output ./docs
```

## Common Options

| Option | Description |
|--------|-------------|
| `-p, --package-path` | Path to the Swift package (default: current directory) |
| `-o, --output` | Output directory for generated documentation |
| `-t, --target` | Document specific targets only (can be repeated) |
| `-v, --verbose` | Show detailed progress information |
| `--disable-search` | Disable client-side search functionality |

## Next Steps

- <doc:LocalUsage> - Detailed local development workflows
- <doc:ServerDeployment> - Deploy documentation to web servers
- <doc:CIIntegration> - Automate with CI/CD pipelines

## See Also

- ``docc_static``
