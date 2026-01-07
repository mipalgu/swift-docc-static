# Plugin Options

Configure documentation generation with command-line options.

## Overview

The Static Documentation Plugin accepts various options to customise the
documentation generation process. All options are passed after the
`generate-static-documentation` command.

## Available Options

### Output Directory

Specify where to generate documentation:

```bash
swift package generate-static-documentation --output ./docs
```

Default: `.build/documentation`

### Target Selection

Document specific targets only:

```bash
swift package generate-static-documentation --target MyLib
```

Multiple targets:

```bash
swift package generate-static-documentation --target MyLib --target HelperLib
```

### Dependency Handling

Include all dependencies in the documentation:

```bash
swift package generate-static-documentation --include-all-dependencies
```

Include specific dependencies:

```bash
swift package generate-static-documentation --include-dependency SomePackage
```

Exclude specific dependencies:

```bash
swift package generate-static-documentation --exclude-dependency LargePackage
```

### External Documentation Links

Link to external documentation for packages you're not documenting locally:

```bash
swift package generate-static-documentation \
    --external-docs ArgumentParser=https://swiftpackageindex.com/apple/swift-argument-parser/documentation/argumentparser
```

### Search Functionality

Disable client-side search (reduces output size):

```bash
swift package generate-static-documentation --disable-search
```

### Custom Footer

Add a custom footer to all pages:

```bash
swift package generate-static-documentation --footer "<p>Copyright 2024 My Company</p>"
```

### Verbose Output

Show detailed progress information:

```bash
swift package generate-static-documentation --verbose
```

## Common Combinations

### Fast Development Build

Minimal build for quick iteration:

```bash
swift package --scratch-path /tmp/build \
    generate-static-documentation \
    --target MyLib \
    --disable-search
```

### Production Build

Full documentation with all options:

```bash
swift package generate-static-documentation \
    --output ./docs \
    --include-all-dependencies \
    --exclude-dependency TestSupport \
    --footer "<p>Built with swift-docc-static</p>" \
    --verbose
```

### Documentation for Publishing

Ready for hosting:

```bash
swift package generate-static-documentation \
    --output ./public \
    --external-docs Foundation=https://developer.apple.com/documentation/foundation
```

## Using with swift package Options

The plugin respects standard `swift package` options. Specify them before
the plugin command:

```bash
# Use a specific scratch path
swift package --scratch-path /tmp/build generate-static-documentation

# Use a specific configuration
swift package -c release generate-static-documentation

# Specify package location
swift package --package-path /path/to/package generate-static-documentation
```

## Environment Variables

The plugin respects standard Swift environment variables:

| Variable | Description |
|----------|-------------|
| `SWIFT_EXEC` | Path to the Swift compiler |
| `DEVELOPER_DIR` | Xcode developer directory (macOS) |

## See Also

- <doc:GettingStarted>
- <doc:XcodeIntegration>
- ``GenerateStaticDocumentation``
