# Cross-Package Linking

Understand how DocCStatic handles links between packages.

## Overview

DocCStatic generates documentation with relative paths, ensuring links work correctly whether viewing locally via file:// URLs or hosting on a web server. This article explains how cross-package linking works and how to configure it.

## Relative Path Resolution

All links in the generated documentation use relative paths calculated at generation time. For example, a symbol in module A linking to a symbol in module B uses paths like:

```html
<a href="../../moduleb/symbol/index.html">Symbol</a>
```

This approach ensures:
- **Local viewing**: Documentation works directly in a browser via file:// URLs
- **Portable output**: The entire documentation directory can be moved without breaking links
- **Simple hosting**: Any static file server can host the documentation

## Linking Within Your Package

Links between symbols, articles, and tutorials within the same package are automatically resolved. DocCStatic uses the standard DocC reference syntax:

```markdown
See ``MyOtherType`` for more information.

For an introduction, read <doc:GettingStarted>.
```

These references become relative HTML links in the output.

## Linking to Dependencies

When documenting dependencies alongside your main package, links to dependency symbols are resolved relative to the dependency's documentation location:

```
docs/
├── documentation/
│   ├── mypackage/
│   │   └── mytype/        # Links to ../mydependency/deptype/
│   └── mydependency/
│       └── deptype/
```

## External Documentation Links

For dependencies you've excluded from documentation, use ``Configuration/externalDocumentationURLs`` to provide external link targets:

```swift
let configuration = Configuration(
    packageDirectory: packageURL,
    outputDirectory: outputURL,
    dependencyPolicy: .exclude(["SwiftNIO"]),
    externalDocumentationURLs: [
        "SwiftNIO": URL(string: "https://example.com/swiftnio/docs")!
    ]
)
```

References to excluded packages become links to the external URL:

```html
<!-- Before: doc:SwiftNIO/Channel -->
<a href="https://example.com/swiftnio/docs/channel">Channel</a>
```

## Unresolved References

When a reference cannot be resolved and no external URL is configured, DocCStatic:

1. Renders the text without a link
2. Generates a warning in the result
3. Logs the issue in verbose mode

```swift
let result = try await generator.generate()
for warning in result.warnings {
    print(warning) // [warning] Unresolved reference: doc:MissingPackage/Symbol
}
```

## Best Practices

### Organise Your Documentation Structure

Keep your documentation well-organised for cleaner relative paths:

```
package/
├── Sources/
│   └── MyLib/
│       └── MyLib.docc/     # Documentation catalogue
└── Package.swift
```

### Use Consistent Package Names

When referencing external packages, use the exact package name as it appears in your `Package.swift` dependencies.

### Verify Links in Output

After generation, spot-check links by:
1. Opening `index.html` in a browser
2. Navigating to pages with cross-package references
3. Verifying the links work correctly

### Handle Missing Dependencies Gracefully

If you expect some dependencies to be unavailable, configure external URLs:

```swift
let configuration = Configuration(
    // ...
    externalDocumentationURLs: [
        "Foundation": URL(string: "https://developer.apple.com/documentation/foundation")!,
        "Swift": URL(string: "https://developer.apple.com/documentation/swift")!
    ]
)
```

## Troubleshooting

### Links Are Broken When Viewing Locally

Ensure you're opening the root `index.html` and navigating from there, rather than opening individual pages directly.

### External Links Not Working

Verify the URLs in `externalDocumentationURLs` are:
1. Valid, fully-qualified URLs
2. Pointing to the root of the documentation, not a specific page
3. Using the exact package name as the dictionary key

### Missing Cross-References

Enable verbose mode to see which references couldn't be resolved:

```swift
let configuration = Configuration(
    // ...
    isVerbose: true
)
```

## See Also

- <doc:Configuration>
- ``Configuration``
- ``DependencyInclusionPolicy``
