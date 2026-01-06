# Using docc-static Locally

Generate and preview documentation during development.

## Overview

During development, you'll want to quickly generate and view documentation
as you write code and documentation comments. This guide covers efficient
local workflows.

## Basic Development Workflow

### Generate and View

Generate documentation for your package:

```bash
docc-static generate --package-path . --output ./docs --verbose
```

Open directly in your browser:

```bash
open ./docs/index.html
```

### Using the Preview Server

For a better experience, use the built-in preview server:

```bash
docc-static preview --output ./docs --port 8080
```

This starts a local HTTP server at `http://localhost:8080`. The preview
server provides proper MIME types and handles relative URLs correctly.

## Speeding Up Builds

### Use a Scratch Path

By default, docc-static uses Swift's standard build directory. For faster
rebuilds, use a dedicated scratch path:

```bash
docc-static generate \
    --scratch-path /tmp/docc-build \
    --output ./docs
```

This is especially useful when:
- Working with large packages
- Running from different directories
- Avoiding conflicts with your main build

### Document Specific Targets

If your package has multiple targets, document only the ones you're working on:

```bash
docc-static generate \
    --target MyLibrary \
    --output ./docs
```

You can specify multiple targets:

```bash
docc-static generate \
    --target CoreLib \
    --target HelperLib \
    --output ./docs
```

### Use Pre-Generated Symbol Graphs

If you've already built symbol graphs (e.g., from the SPM plugin), reuse them:

```bash
docc-static generate \
    --symbol-graph-dir .build/plugins/GenerateStaticDocumentation/outputs \
    --output ./docs
```

## Working with Dependencies

### Exclude Dependencies

By default, docc-static only documents your package's targets. To explicitly
control dependencies:

```bash
# Include all dependencies
docc-static generate -I --output ./docs

# Include all except specific ones
docc-static generate -I -x SomeLargePackage --output ./docs

# Include only specific dependencies
docc-static generate -i ImportantDep --output ./docs
```

### Link to External Documentation

For dependencies you don't want to build locally, link to their online documentation:

```bash
docc-static generate \
    -e ArgumentParser=https://swiftpackageindex.com/apple/swift-argument-parser/documentation/argumentparser \
    --output ./docs
```

## Viewing Without a Server

The generated documentation is pure HTML/CSS and works directly from the filesystem:

```bash
# On macOS
open ./docs/index.html

# On Linux
xdg-open ./docs/index.html

# Or just drag index.html into your browser
```

All links use relative paths, so navigation works correctly with `file://` URLs.

## Customising Output

### Add a Custom Footer

Include a footer on every page:

```bash
docc-static generate \
    --footer "<p>Built with docc-static</p>" \
    --output ./docs
```

### Disable Search

If you don't need client-side search:

```bash
docc-static generate --disable-search --output ./docs
```

This reduces output size and removes the Lunr.js dependency.

## Tips for Efficient Development

1. **Use a shell alias** for your common command:
   ```bash
   alias docgen='docc-static generate --scratch-path /tmp/docc -o ./docs -v'
   ```

2. **Keep the preview server running** while editing - just refresh the browser.

3. **Use verbose mode** (`-v`) when troubleshooting to see what's being processed.

4. **Clean the output directory** occasionally to remove stale files:
   ```bash
   rm -rf ./docs && docc-static generate -o ./docs
   ```

## See Also

- <doc:GettingStarted> - Installation and basic usage
- <doc:ServerDeployment> - Deploy to production servers
- <doc:CIIntegration> - Automate documentation generation
