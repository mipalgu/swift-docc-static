# Xcode Integration

Generate static documentation from Xcode projects and workspaces.

## Overview

While the Static Documentation Plugin is designed for Swift packages,
you can also use it with Xcode projects that contain Swift packages
or use Swift Package Manager for dependencies.

## Swift Packages in Xcode

If your Xcode project uses a Swift package (either local or as a dependency),
you can generate documentation from the command line:

```bash
cd /path/to/your/package
swift package generate-static-documentation --output ./docs
```

## Build Phase Integration

Add a Run Script build phase to generate documentation during builds:

1. Select your target in Xcode
2. Go to **Build Phases**
3. Click **+** and select **New Run Script Phase**
4. Add the script:

```bash
if [ "$CONFIGURATION" = "Release" ]; then
    cd "$SRCROOT"
    swift package generate-static-documentation --output "$BUILT_PRODUCTS_DIR/Documentation"
fi
```

This generates documentation only for Release builds.

## Custom Build Rules

For more control, create a custom build rule:

1. Select your target
2. Go to **Build Rules**
3. Click **+** to add a rule
4. Configure:
   - Process: Source files with names matching `*.docc`
   - Using: Custom script

## Xcode Cloud

For Xcode Cloud workflows, add a post-clone script:

Create `ci_scripts/ci_post_clone.sh`:

```bash
#!/bin/bash
set -e

# Install dependencies
brew tap mipalgu/tap
brew install swift-docc-static

# Generate documentation
cd "$CI_PRIMARY_REPOSITORY_PATH"
docc-static generate --output ./docs
```

Make the script executable:

```bash
chmod +x ci_scripts/ci_post_clone.sh
```

## Documentation Viewer

After generating documentation, you can:

1. **Open directly**: Double-click `index.html` in Finder
2. **Use Quick Look**: Select the docs folder and press Space
3. **Add to Xcode**: Drag the docs folder into your project navigator

## Alternative: Using docc-static Directly

If you prefer not to modify your Xcode project, use the command-line
tool directly:

```bash
# Install
brew tap mipalgu/tap
brew install swift-docc-static

# Generate from your package directory
cd /path/to/package
docc-static generate --output ~/Desktop/docs

# Open
open ~/Desktop/docs/index.html
```

## Troubleshooting

### "Package not found" Error

Ensure you're in the directory containing `Package.swift`:

```bash
cd /path/to/your/package
ls Package.swift  # Should show the file
swift package generate-static-documentation
```

### Build Failures

If the plugin fails to build your package:

1. Ensure the package builds successfully:
   ```bash
   swift build
   ```

2. Check for Swift version compatibility:
   ```bash
   swift --version
   ```

3. Try with verbose output:
   ```bash
   swift package generate-static-documentation --verbose
   ```

### Missing Dependencies

If dependencies aren't resolved:

```bash
swift package resolve
swift package generate-static-documentation
```

## See Also

- <doc:GettingStarted> - Basic setup and usage
- <doc:PluginOptions> - Available configuration options
- ``docc_static`` - The standalone command-line tool
