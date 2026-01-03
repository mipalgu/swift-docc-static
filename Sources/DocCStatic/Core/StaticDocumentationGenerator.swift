//
// StaticDocumentationGenerator.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import SwiftDocC

/// Errors that can occur during documentation generation.
public enum GenerationError: Error, LocalizedError {
    /// Symbol graph generation failed.
    case symbolGraphGenerationFailed(String)

    /// The docc executable was not found.
    case doccNotFound

    /// Failed to parse the documentation archive.
    case archiveParsingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .symbolGraphGenerationFailed(let message):
            return "Failed to generate symbol graphs: \(message)"
        case .doccNotFound:
            return "Could not find the docc executable. Ensure Xcode or the Swift toolchain is installed."
        case .archiveParsingFailed(let message):
            return "Failed to parse documentation archive: \(message)"
        }
    }
}

/// The main orchestrator for generating static HTML documentation.
///
/// Use this type to generate static HTML documentation from a Swift package.
/// The generator processes symbol graphs, articles, and tutorials, then outputs
/// a complete static website that can be viewed locally or hosted on any web server.
///
/// ## Overview
///
/// Create a generator with a configuration, then call ``generate()`` to produce
/// the documentation:
///
/// ```swift
/// let configuration = Configuration(
///     packageDirectory: URL(fileURLWithPath: "."),
///     outputDirectory: URL(fileURLWithPath: ".build/docs")
/// )
/// let generator = StaticDocumentationGenerator(configuration: configuration)
/// let result = try await generator.generate()
/// print("Generated \(result.generatedPages) pages")
/// ```
///
/// ## Output Structure
///
/// The generator produces the following directory structure:
///
/// ```
/// output/
/// ├── index.html              # Combined landing page
/// ├── css/
/// │   └── main.css           # Stylesheet
/// ├── js/
/// │   └── search.js          # Optional search functionality
/// ├── {package}/
/// │   ├── index.html         # Package overview
/// │   └── {module}/
/// │       ├── index.html     # Module overview
/// │       └── {symbol}/
/// │           └── index.html # Symbol documentation
/// └── search-index.json      # Optional search index
/// ```
public struct StaticDocumentationGenerator: Sendable {
    /// The configuration for this generator.
    public let configuration: Configuration

    /// Creates a new documentation generator.
    ///
    /// - Parameter configuration: The configuration for documentation generation.
    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    /// Generates static HTML documentation.
    ///
    /// This method performs the following steps:
    /// 1. Generates symbol graphs using the Swift Package Manager
    /// 2. Runs docc convert to create a temporary .doccarchive
    /// 3. Parses the JSON render nodes from the archive
    /// 4. Renders all pages to static HTML
    /// 5. Writes CSS and JavaScript assets
    /// 6. Optionally generates a search index
    ///
    /// - Returns: A result containing information about the generated documentation.
    /// - Throws: An error if documentation generation fails.
    public func generate() async throws -> GenerationResult {
        let fileManager = FileManager.default

        if configuration.isVerbose {
            log("Starting documentation generation...")
            log("Package: \(configuration.packageDirectory.path)")
            log("Output: \(configuration.outputDirectory.path)")
        }

        // Create output directory
        try createOutputDirectory()

        // Create temporary directory for intermediate files
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("docc-static-\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Generate symbol graphs and run docc convert
        let symbolGraphsDir = tempDir.appendingPathComponent("symbol-graphs")
        let archiveDir = tempDir.appendingPathComponent("archive.doccarchive")

        try await generateSymbolGraphs(to: symbolGraphsDir)
        try await runDoccConvert(
            symbolGraphsDir: symbolGraphsDir,
            outputDir: archiveDir
        )

        // Parse and render the documentation
        let consumer = StaticHTMLConsumer(
            outputDirectory: configuration.outputDirectory,
            configuration: configuration
        )

        // Create search index builder if search is enabled
        var searchIndexBuilder: SearchIndexBuilder?
        if configuration.includeSearch {
            searchIndexBuilder = SearchIndexBuilder(configuration: configuration)
        }

        try await renderFromArchive(archiveDir, consumer: consumer, searchIndexBuilder: &searchIndexBuilder)

        // Write assets
        try writeAssets()

        // Generate combined index page
        try generateIndexPage(consumer: consumer)

        // Write search index if enabled
        if configuration.includeSearch, let builder = searchIndexBuilder {
            try writeSearchIndex(builder)
        }

        return consumer.result()
    }

    // MARK: - Symbol Graph Generation

    private func generateSymbolGraphs(to outputDir: URL) async throws {
        let fileManager = FileManager.default

        if configuration.isVerbose {
            log("Generating symbol graphs...")
        }

        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Run swift build with emit-symbol-graph
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "swift", "build",
            "--package-path", configuration.packageDirectory.path,
            "-Xswiftc", "-emit-symbol-graph",
            "-Xswiftc", "-emit-symbol-graph-dir",
            "-Xswiftc", outputDir.path
        ]

        // Add target restrictions if specified
        for target in configuration.targets {
            process.arguments?.append(contentsOf: ["--target", target])
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw GenerationError.symbolGraphGenerationFailed(errorMessage)
        }

        if configuration.isVerbose {
            log("Symbol graphs generated at: \(outputDir.path)")
        }
    }

    // MARK: - DocC Conversion

    private func runDoccConvert(symbolGraphsDir: URL, outputDir: URL) async throws {
        if configuration.isVerbose {
            log("Running docc convert...")
        }

        // Find docc executable
        let doccPath = try findDoccExecutable()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: doccPath)
        process.arguments = [
            "convert",
            "--additional-symbol-graph-dir", symbolGraphsDir.path,
            "--output-path", outputDir.path,
            "--emit-digest"
        ]

        // Add DocC catalog if it exists
        let catalogPath = configuration.packageDirectory
            .appendingPathComponent("Sources")
            .appendingPathComponent(configuration.targets.first ?? "")
            .appendingPathExtension("docc")
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: catalogPath.path) {
            process.arguments?.insert(catalogPath.path, at: 1)
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        // docc may return non-zero for warnings, which is fine
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = (String(data: errorData, encoding: .utf8) ?? "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !errorMessage.isEmpty {
                logWarning("docc: \(errorMessage)")
            }
        }

        if configuration.isVerbose {
            log("DocC archive created at: \(outputDir.path)")
        }
    }

    private func findDoccExecutable() throws -> String {
        // Try to find docc in common locations
        let possiblePaths = [
            "/usr/bin/docc",
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/docc",
            "/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin/docc"
        ]
        let fileManager = FileManager.default

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }

        // Try using xcrun
        let xcrunProcess = Process()
        xcrunProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        xcrunProcess.arguments = ["--find", "docc"]
        let pipe = Pipe()
        xcrunProcess.standardOutput = pipe
        try? xcrunProcess.run()
        xcrunProcess.waitUntilExit()

        if xcrunProcess.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        }

        throw GenerationError.doccNotFound
    }

    // MARK: - Archive Rendering

    private func renderFromArchive(
        _ archiveDir: URL,
        consumer: StaticHTMLConsumer,
        searchIndexBuilder: inout SearchIndexBuilder?
    ) async throws {
        if configuration.isVerbose {
            log("Rendering pages from archive...")
        }

        let dataDir = archiveDir.appendingPathComponent("data")
        let documentationDir = dataDir.appendingPathComponent("documentation")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: documentationDir.path) else {
            throw GenerationError.archiveParsingFailed("No documentation data found in archive")
        }

        // Load the navigation index
        let indexPath = archiveDir.appendingPathComponent("index").appendingPathComponent("index.json")
        var navigationIndex: NavigationIndex?
        if fileManager.fileExists(atPath: indexPath.path) {
            do {
                navigationIndex = try NavigationIndex.load(from: indexPath)
                if configuration.isVerbose {
                    log("Loaded navigation index from: \(indexPath.path)")
                }
            } catch {
                if configuration.isVerbose {
                    log("Warning: Failed to load navigation index: \(error)")
                }
            }
        }

        // Set the navigation index on the consumer
        consumer.navigationIndex = navigationIndex

        // Find all JSON files in the data/documentation directory
        let enumerator = fileManager.enumerator(
            at: documentationDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let decoder = JSONDecoder()

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "json" else { continue }

            do {
                let data = try Data(contentsOf: fileURL)
                let renderNode = try decoder.decode(RenderNode.self, from: data)
                try consumer.consume(renderNode: renderNode)

                // Add to search index if enabled
                searchIndexBuilder?.addToIndex(renderNode)
            } catch {
                if configuration.isVerbose {
                    log("Warning: Failed to process \(fileURL.lastPathComponent): \(error)")
                }
            }
        }

        if configuration.isVerbose {
            log("Finished rendering pages")
        }
    }

    /// Writes the search index JSON file.
    private func writeSearchIndex(_ builder: SearchIndexBuilder) throws {
        let indexPath = configuration.outputDirectory
            .appendingPathComponent("search-index.json")

        try builder.writeIndex(to: indexPath)

        if configuration.isVerbose {
            log("Wrote search index: \(indexPath.path)")
        }
    }

    // MARK: - Index Page Generation

    private func generateIndexPage(consumer: StaticHTMLConsumer) throws {
        if configuration.isVerbose {
            log("Generating index page...")
        }

        let indexBuilder = IndexPageBuilder(configuration: configuration)

        // Collect module information from the consumer's generated pages
        var modules: [IndexPageBuilder.ModuleEntry] = []

        // Scan the output directory for module directories
        let docRoot = configuration.outputDirectory.appendingPathComponent("documentation")
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: docRoot.path),
           let contents = try? fileManager.contentsOfDirectory(
               at: docRoot,
               includingPropertiesForKeys: [.isDirectoryKey]
           ) {
            for item in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    let modulePath = item.lastPathComponent
                    // Extract the actual title from the generated HTML
                    let moduleInfo = extractModuleInfo(from: item)
                    modules.append(IndexPageBuilder.ModuleEntry(
                        name: moduleInfo.title,
                        abstract: moduleInfo.abstract,
                        path: "documentation/\(modulePath)/index.html",
                        symbolCount: countSymbols(in: item)
                    ))
                }
            }
        }

        // If no modules found, create entries from configuration targets
        if modules.isEmpty {
            for target in configuration.targets {
                modules.append(IndexPageBuilder.ModuleEntry(
                    name: target,
                    abstract: "Documentation for \(target)",
                    path: "documentation/\(target.lowercased())/index.html",
                    symbolCount: 0
                ))
            }
        }

        let html = indexBuilder.buildIndexPage(modules: modules)
        let indexPath = configuration.outputDirectory.appendingPathComponent("index.html")

        try html.write(to: indexPath, atomically: true, encoding: .utf8)

        if configuration.isVerbose {
            log("Generated index page: \(indexPath.path)")
        }
    }

    /// Extracts module title and abstract from the generated HTML.
    private func extractModuleInfo(from directory: URL) -> (title: String, abstract: String) {
        let indexPath = directory.appendingPathComponent("index.html")
        let modulePath = directory.lastPathComponent

        guard let html = try? String(contentsOf: indexPath, encoding: .utf8) else {
            return (title: modulePath.capitalized, abstract: "Documentation for \(modulePath)")
        }

        // Extract title from <title> tag
        var title = modulePath.capitalized
        if let titleStart = html.range(of: "<title>"),
           let titleEnd = html.range(of: "</title>", range: titleStart.upperBound..<html.endIndex) {
            title = String(html[titleStart.upperBound..<titleEnd.lowerBound])
        }

        // Extract abstract from <p class="abstract">
        var abstract = "Documentation for \(title)"
        if let abstractStart = html.range(of: "<p class=\"abstract\">"),
           let abstractEnd = html.range(of: "</p>", range: abstractStart.upperBound..<html.endIndex) {
            let rawAbstract = String(html[abstractStart.upperBound..<abstractEnd.lowerBound])
            // Strip HTML tags from abstract
            abstract = rawAbstract.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }

        return (title: title, abstract: abstract)
    }

    private func countSymbols(in directory: URL) -> Int {
        let fileManager = FileManager.default
        var count = 0
        if let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            while let file = enumerator.nextObject() as? URL {
                if file.lastPathComponent == "index.html" {
                    count += 1
                }
            }
        }
        return max(0, count - 1) // Subtract 1 for the module index itself
    }

    // MARK: - Private Methods

    private func createOutputDirectory() throws {
        let fileManager = FileManager.default

        // Remove existing output if present
        if fileManager.fileExists(atPath: configuration.outputDirectory.path) {
            try fileManager.removeItem(at: configuration.outputDirectory)
        }

        // Create fresh output directory with subdirectories
        try fileManager.createDirectory(
            at: configuration.outputDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: configuration.outputDirectory.appendingPathComponent("css"),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: configuration.outputDirectory.appendingPathComponent("js"),
            withIntermediateDirectories: true
        )

        if configuration.isVerbose {
            log("Created output directory: \(configuration.outputDirectory.path)")
        }
    }

    private func writeAssets() throws {
        // Write CSS
        let cssPath = configuration.outputDirectory
            .appendingPathComponent("css")
            .appendingPathComponent("main.css")
        try DocCStylesheet.generate(theme: configuration.theme).write(
            to: cssPath,
            atomically: true,
            encoding: .utf8
        )

        if configuration.isVerbose {
            log("Wrote stylesheet: \(cssPath.path)")
        }

        // Write JavaScript (search functionality)
        if configuration.includeSearch {
            // Write the Lunr.js library
            let lunrPath = configuration.outputDirectory
                .appendingPathComponent("js")
                .appendingPathComponent("lunr.min.js")
            try SearchScript.lunrJS.write(
                to: lunrPath,
                atomically: true,
                encoding: .utf8
            )

            // Write the search script
            let jsPath = configuration.outputDirectory
                .appendingPathComponent("js")
                .appendingPathComponent("search.js")
            try SearchScript.content.write(
                to: jsPath,
                atomically: true,
                encoding: .utf8
            )

            if configuration.isVerbose {
                log("Wrote search scripts: \(lunrPath.path), \(jsPath.path)")
            }
        }
    }

    // FIXME: we probably want swift logging (https://github.com/apple/swift-log)
    private func log(_ message: String) {
        print("[DocCStatic] \(message)")
    }

    private func logWarning(_ message: String) {
        let warningMsg = "[DocCStatic] WARNING: \(message)\n"
        FileHandle.standardError.write(warningMsg.data(using: .utf8) ?? Data())
    }

    private func logError(_ message: String) {
        let errorMsg = "[DocCStatic] ERROR: \(message)\n"
        FileHandle.standardError.write(errorMsg.data(using: .utf8) ?? Data())
    }
}

// MARK: - Placeholder Types

/// Generates the CSS stylesheet for documentation.
///
/// This type creates a complete stylesheet matching Apple's DocC visual style,
/// with support for light and dark modes.
enum DocCStylesheet {
    /// Generates the complete CSS stylesheet.
    ///
    /// - Parameter theme: The theme configuration to use.
    /// - Returns: The CSS content as a string.
    static func generate(theme: ThemeConfiguration) -> String {
        return """
        /* swift-docc-static generated stylesheet - DocC-style layout */
        :root {
            --docc-bg: #ffffff;
            --docc-bg-secondary: #f5f5f7;
            --docc-fg: #1d1d1f;
            --docc-fg-secondary: #6e6e73;
            --docc-accent: \(theme.accentColour);
            --docc-border: #d2d2d7;
            --sidebar-width: 320px;
            --header-height: 52px;

            /* Typography */
            --typeface-body: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif;
            --typeface-mono: 'SF Mono', SFMono-Regular, ui-monospace, Menlo, monospace;
            --typeface-headline: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Helvetica Neue', sans-serif;

            /* Swift syntax colours */
            --swift-keyword: #ad3da4;
            --swift-type: #703daa;
            --swift-literal: #d12f1b;
            --swift-comment: #707f8c;
            --swift-string: #d12f1b;
            --swift-number: #272ad8;

            /* Symbol badge colours - monochrome like DocC */
            --badge-bg: #f5f5f7;
            --badge-fg: #6e6e73;
            --badge-border: #d2d2d7;

            /* Aside colours */
            --aside-note-bg: #e3f2fd;
            --aside-note-border: #2196f3;
            --aside-warning-bg: #fff3e0;
            --aside-warning-border: #ff9800;
            --aside-important-bg: #fce4ec;
            --aside-important-border: #e91e63;

            /* Decorative colours */
            --hero-decoration: #d2d2d7;
        }

        \(theme.includeDarkMode ? darkModeStyles : "")

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: var(--typeface-body);
            background: var(--docc-bg);
            color: var(--docc-fg);
            line-height: 1.5;
            -webkit-font-smoothing: antialiased;
        }

        a {
            color: var(--docc-accent);
            text-decoration: none;
        }

        a:hover {
            text-decoration: underline;
        }

        code {
            font-family: var(--typeface-mono);
            font-size: 0.875em;
            background: var(--docc-bg-secondary);
            padding: 0.125em 0.25em;
            border-radius: 4px;
        }

        pre {
            font-family: var(--typeface-mono);
            font-size: 0.8125rem;
            background: var(--docc-bg-secondary);
            padding: 1rem 1.25rem;
            border-radius: 12px;
            overflow-x: auto;
            line-height: 1.6;
            margin: 1rem 0;
        }

        pre code {
            background: none;
            padding: 0;
        }

        /* Syntax highlighting */
        .syntax-keyword {
            color: var(--swift-keyword);
            font-weight: 500;
        }

        .syntax-string {
            color: var(--swift-string);
        }

        .syntax-number {
            color: var(--swift-number);
        }

        .syntax-comment {
            color: var(--swift-comment);
            font-style: italic;
        }

        .syntax-type {
            color: var(--swift-type);
        }

        .syntax-attribute {
            color: var(--swift-keyword);
        }

        h1, h2, h3, h4, h5, h6 {
            font-family: var(--typeface-headline);
            font-weight: 600;
            margin-top: 1.5em;
            margin-bottom: 0.5em;
        }

        h1 { font-size: 2.125rem; margin-top: 0; }
        h2 { font-size: 1.5rem; border-bottom: 1px solid var(--docc-border); padding-bottom: 0.5rem; }
        h3 { font-size: 1.1875rem; }

        p { margin-bottom: 1em; }
        ul, ol { margin-bottom: 1em; padding-left: 1.5em; }
        li { margin-bottom: 0.5em; }

        /* Syntax highlighting */
        .keyword { color: var(--swift-keyword); font-weight: 500; }
        .type { color: var(--swift-type); }
        .identifier { color: #4b21b0; }
        .param { color: #5d6c79; }
        .literal { color: var(--swift-literal); }
        .comment { color: var(--swift-comment); font-style: italic; }
        .string { color: var(--swift-string); }
        .number { color: var(--swift-number); }
        .attribute { color: #947100; }
        .label { color: var(--docc-fg); }

        /* Header bar */
        .doc-header {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            height: var(--header-height);
            background: var(--docc-bg);
            border-bottom: 1px solid var(--docc-border);
            z-index: 100;
        }

        .header-content {
            max-width: 100%;
            height: 100%;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 1.5rem;
        }

        .header-title {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            font-weight: 600;
            font-size: 1rem;
            color: var(--docc-fg);
            text-decoration: none;
        }

        .header-title:hover {
            text-decoration: none;
        }

        .header-icon {
            display: flex;
            align-items: center;
        }

        .header-icon svg {
            width: 20px;
            height: 20px;
        }

        .header-language {
            font-size: 0.875rem;
            color: var(--docc-fg-secondary);
        }

        /* Sidebar toggle (hidden checkbox) */
        .sidebar-toggle-checkbox {
            position: absolute;
            opacity: 0;
            pointer-events: none;
        }

        /* Toggle button (hamburger) */
        .sidebar-toggle-button {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 36px;
            height: 36px;
            cursor: pointer;
            border-radius: 6px;
            transition: background-color 0.2s ease;
        }

        .sidebar-toggle-button:hover {
            background: var(--docc-bg-secondary);
        }

        .toggle-icon {
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            width: 18px;
            height: 14px;
        }

        .toggle-icon .bar {
            display: block;
            width: 100%;
            height: 2px;
            background: var(--docc-fg);
            border-radius: 1px;
            transition: transform 0.3s ease, opacity 0.3s ease;
            transform-origin: center;
        }

        /* Hamburger to X animation when sidebar is collapsed */
        .sidebar-toggle-checkbox:checked ~ .doc-header .toggle-icon .bar:nth-child(1) {
            transform: translateY(6px) rotate(45deg);
        }

        .sidebar-toggle-checkbox:checked ~ .doc-header .toggle-icon .bar:nth-child(2) {
            opacity: 0;
        }

        .sidebar-toggle-checkbox:checked ~ .doc-header .toggle-icon .bar:nth-child(3) {
            transform: translateY(-6px) rotate(-45deg);
        }

        /* Two-column layout */
        .doc-layout {
            display: flex;
            min-height: 100vh;
            padding-top: var(--header-height);
        }

        /* Sidebar */
        .doc-sidebar {
            width: var(--sidebar-width);
            flex-shrink: 0;
            border-right: 1px solid var(--docc-border);
            background: var(--docc-bg);
            position: fixed;
            top: var(--header-height);
            left: 0;
            bottom: 0;
            overflow-y: auto;
            transition: transform 0.3s ease, width 0.3s ease;
            will-change: transform;
        }

        /* Sidebar collapsed state */
        .sidebar-toggle-checkbox:checked ~ .doc-layout .doc-sidebar {
            transform: translateX(-100%);
        }

        .sidebar-content {
            padding: 1rem 0;
        }

        .sidebar-module {
            font-weight: 600;
            font-size: 1rem;
            padding: 0.5rem 1.25rem;
            margin: 0 0 0.5rem 0;
            border: none;
        }

        .sidebar-section {
            margin-bottom: 0.5rem;
        }

        .sidebar-heading {
            font-size: 0.8125rem;
            font-weight: 600;
            color: var(--docc-fg-secondary);
            padding: 0.75rem 1.25rem 0.25rem;
            margin: 0;
            border: none;
        }

        .sidebar-list {
            list-style: none;
            padding: 0;
            margin: 0;
        }

        .sidebar-item {
            display: flex;
            align-items: center;
            gap: 0.375rem;
            padding: 0.1875rem 1rem 0.1875rem 0.75rem;
            font-size: 0.8125rem;
            line-height: 1.3;
        }

        .sidebar-item a {
            color: var(--docc-fg);
            text-decoration: none;
        }

        .sidebar-item:hover {
            background: var(--docc-bg-secondary);
        }

        .sidebar-item a:hover {
            text-decoration: none;
        }

        .sidebar-item.active,
        .sidebar-item.selected {
            background: rgba(0, 102, 204, 0.1);
        }

        .sidebar-item.selected > .nav-link {
            font-weight: 500;
        }

        /* Sidebar module link */
        .sidebar-module-link {
            text-decoration: none;
            color: inherit;
        }

        .sidebar-module-link:hover {
            text-decoration: none;
        }

        /* Disclosure chevron for expandable items */
        .disclosure-checkbox {
            position: absolute;
            opacity: 0;
            pointer-events: none;
        }

        .disclosure-chevron {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 14px;
            height: 14px;
            cursor: pointer;
            flex-shrink: 0;
            color: var(--docc-fg-secondary);
        }

        .disclosure-chevron svg {
            width: 8px;
            height: 8px;
            transform: rotate(0deg);
            transition: transform 0.15s ease;
        }

        .disclosure-checkbox:checked + .disclosure-chevron svg {
            transform: rotate(90deg);
        }

        .sidebar-item.expandable {
            flex-wrap: wrap;
        }

        .sidebar-item.expandable > .nav-link {
            flex: 1;
        }

        /* Nested children (collapsed by default with animation) */
        .nav-children {
            width: 100%;
            list-style: none;
            padding: 0;
            margin: 0;
            margin-left: 1.125rem;
            max-height: 0;
            overflow: hidden;
            opacity: 0;
            transition: max-height 0.2s ease, opacity 0.15s ease;
        }

        .disclosure-checkbox:checked ~ .nav-children {
            max-height: 2000px;
            opacity: 1;
        }

        /* Nested group headers */
        .nav-group-header {
            font-size: 0.75rem;
            font-weight: 600;
            color: var(--docc-fg-secondary);
            padding: 0.5rem 0 0.25rem;
            list-style: none;
        }

        /* Nested child items */
        .nav-child-item {
            display: flex;
            align-items: center;
            gap: 0.375rem;
            padding: 0.125rem 0;
            font-size: 0.8125rem;
            line-height: 1.3;
        }

        .nav-child-item a {
            color: var(--docc-fg);
            text-decoration: none;
        }

        .nav-child-item:hover a {
            color: var(--docc-accent);
        }

        .nav-child-item.selected a {
            font-weight: 500;
            color: var(--docc-accent);
        }

        /* Symbol icon for articles/tutorials */
        .symbol-icon {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 14px;
            height: 14px;
            flex-shrink: 0;
            color: var(--docc-fg-secondary);
        }

        .symbol-icon svg {
            width: 14px;
            height: 14px;
        }

        /* Filter with shortcut indicator */
        .sidebar-filter {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.75rem 1rem;
            border-top: 1px solid var(--docc-border);
            position: sticky;
            bottom: 0;
            background: var(--docc-bg);
        }

        .filter-icon {
            display: flex;
            align-items: center;
            color: var(--docc-fg-secondary);
        }

        .filter-shortcut {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 20px;
            height: 20px;
            font-size: 0.75rem;
            font-weight: 500;
            border: 1px solid var(--docc-border);
            border-radius: 4px;
            color: var(--docc-fg-secondary);
        }

        /* Symbol type badges - monochrome like DocC */
        .symbol-badge {
            width: 17px;
            height: 17px;
            border-radius: 3px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 0.6875rem;
            font-weight: 600;
            flex-shrink: 0;
            background: var(--badge-bg);
            color: var(--badge-fg);
            border: 1px solid var(--badge-border);
        }

        .badge-article,
        .badge-tutorial {
            background: transparent;
            border: none;
            width: auto;
            height: auto;
        }

        .filter-input {
            flex: 1;
            padding: 0.5rem 0.75rem;
            font-size: 0.875rem;
            border: 1px solid var(--docc-border);
            border-radius: 6px;
            background: var(--docc-bg-secondary);
        }

        /* Main content */
        .doc-main {
            flex: 1;
            margin-left: var(--sidebar-width);
            padding: 0;
            max-width: calc(100% - var(--sidebar-width));
            transition: margin-left 0.3s ease, max-width 0.3s ease;
        }

        /* Main content expanded when sidebar is collapsed */
        .sidebar-toggle-checkbox:checked ~ .doc-layout .doc-main {
            margin-left: 0;
            max-width: 100%;
        }

        /* Breadcrumbs */
        .breadcrumbs {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            font-size: 0.8125rem;
            color: var(--docc-fg-secondary);
            padding: 1rem 3rem;
            border-bottom: 1px solid var(--docc-border);
        }

        .breadcrumbs a {
            color: var(--docc-accent);
            text-decoration: none;
        }

        .breadcrumbs a:hover {
            text-decoration: underline;
        }

        .breadcrumbs .separator {
            color: var(--docc-fg-secondary);
        }

        /* Hero section */
        .hero-section {
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
            background: var(--docc-bg-secondary);
            padding: 2rem 3rem 2.5rem;
            margin-bottom: 2rem;
            position: relative;
            overflow: hidden;
        }

        .hero-content {
            flex: 1;
            max-width: 70%;
        }

        .hero-decoration {
            flex-shrink: 0;
            width: 200px;
            height: 200px;
            color: var(--hero-decoration);
            opacity: 0.6;
            margin-left: 2rem;
        }

        .hero-decoration svg {
            width: 100%;
            height: 100%;
        }

        .eyebrow {
            font-size: 0.8125rem;
            color: var(--docc-fg-secondary);
            margin-bottom: 0.25rem;
            text-transform: capitalize;
        }

        .hero-section h1 {
            margin-top: 0;
            margin-bottom: 0.5rem;
        }

        .hero-section .abstract {
            font-size: 1.1875rem;
            color: var(--docc-fg-secondary);
            margin-bottom: 0;
        }

        .abstract {
            font-size: 1.1875rem;
            color: var(--docc-fg-secondary);
            margin-bottom: 1.5rem;
        }

        /* Content sections within main */
        .doc-main section,
        .doc-main .declaration,
        .doc-main > p,
        .doc-main > ul,
        .doc-main > ol,
        .doc-main > pre,
        .doc-main > h2,
        .doc-main > h3 {
            padding-left: 3rem;
            padding-right: 3rem;
        }

        .topics,
        .relationships,
        .see-also,
        .discussion,
        .parameters {
            padding-top: 1rem;
            padding-bottom: 1rem;
        }

        /* Legacy single-column layout (for index page) */
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 2rem;
        }

        .declaration {
            background: var(--docc-bg-secondary);
            padding: 1rem 1.25rem;
            border-radius: 12px;
            margin-bottom: 1.5rem;
        }

        nav.breadcrumbs {
            font-size: 0.8125rem;
            color: var(--docc-fg-secondary);
            margin-bottom: 1rem;
        }

        nav.breadcrumbs a {
            color: var(--docc-fg-secondary);
        }

        /* Symbol cards in Topics section */
        .symbol-list {
            display: flex;
            flex-direction: column;
            gap: 0;
        }

        .symbol-card {
            display: flex;
            align-items: flex-start;
            gap: 0.75rem;
            padding: 0.75rem 0;
        }

        .symbol-card .symbol-badge {
            margin-top: 0.125rem;
        }

        .symbol-info {
            flex: 1;
            min-width: 0;
        }

        .symbol-name {
            font-family: var(--typeface-body);
            font-weight: 400;
            display: block;
            margin-bottom: 0.25rem;
        }

        .symbol-summary {
            color: var(--docc-fg-secondary);
            font-size: 0.875rem;
            margin: 0;
            line-height: 1.4;
        }

        /* Aside boxes */
        .aside {
            padding: 1rem;
            border-radius: 8px;
            margin: 1rem 0;
        }

        .aside.note {
            background: var(--aside-note-bg);
            border-left: 3px solid var(--aside-note-border);
        }

        .aside.warning {
            background: var(--aside-warning-bg);
            border-left: 3px solid var(--aside-warning-border);
        }

        .aside.important {
            background: var(--aside-important-bg);
            border-left: 3px solid var(--aside-important-border);
        }

        .aside .label {
            font-weight: 600;
            margin-bottom: 0.5rem;
        }

        /* Index page styles */
        .index-header {
            text-align: center;
            margin-bottom: 2rem;
            padding-bottom: 1rem;
            border-bottom: 1px solid var(--docc-border);
        }

        .index-header .subtitle {
            color: var(--docc-fg-secondary);
            font-size: 1.1rem;
        }

        .search-form {
            max-width: 500px;
            margin: 0 auto 2rem;
        }

        .search-form input {
            width: 100%;
            padding: 0.75rem 1rem;
            font-size: 1rem;
            border: 1px solid var(--docc-border);
            border-radius: 8px;
            background: var(--docc-bg);
            color: var(--docc-fg);
        }

        .search-results {
            margin-top: 1rem;
            background: var(--docc-bg);
            border: 1px solid var(--docc-border);
            border-radius: 8px;
            max-height: 400px;
            overflow-y: auto;
            display: none;
        }

        .search-results-list {
            list-style: none;
            margin: 0;
            padding: 0;
        }

        .search-result-item {
            padding: 0.75rem 1rem;
            border-bottom: 1px solid var(--docc-border);
        }

        .search-result-item:last-child {
            border-bottom: none;
        }

        .search-result-item:hover {
            background: var(--docc-bg-secondary);
        }

        .result-link {
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }

        .result-title {
            font-weight: 500;
        }

        .result-type {
            font-size: 0.75rem;
            padding: 0.1rem 0.4rem;
            border-radius: 4px;
            background: var(--docc-bg-secondary);
            color: var(--docc-fg-secondary);
        }

        .result-type-symbol {
            background: #e3f2fd;
            color: #1565c0;
        }

        .result-type-article {
            background: #e8f5e9;
            color: #2e7d32;
        }

        .result-type-tutorial {
            background: #fff3e0;
            color: #ef6c00;
        }

        .result-summary {
            font-size: 0.875rem;
            color: var(--docc-fg-secondary);
            margin-top: 0.25rem;
        }

        .no-results {
            padding: 1rem;
            color: var(--docc-fg-secondary);
            text-align: center;
        }

        .search-unavailable {
            color: var(--docc-fg-secondary);
            font-size: 0.875rem;
        }

        .module-list {
            display: grid;
            gap: 1rem;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
        }

        .module-card {
            padding: 1.25rem;
            border: 1px solid var(--docc-border);
            border-radius: 12px;
            background: var(--docc-bg);
            transition: box-shadow 0.2s, border-color 0.2s;
        }

        .module-card:hover {
            border-color: var(--docc-accent);
            box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
        }

        .module-name {
            font-family: var(--typeface-mono);
            font-size: 1.1rem;
            font-weight: 600;
            display: block;
            margin-bottom: 0.5rem;
        }

        .module-abstract {
            color: var(--docc-fg-secondary);
            font-size: 0.9rem;
            margin-bottom: 0.5rem;
        }

        .module-stats {
            color: var(--docc-fg-secondary);
            font-size: 0.8rem;
        }

        .index-footer {
            margin-top: 3rem;
            padding-top: 1rem;
            border-top: 1px solid var(--docc-border);
            text-align: center;
            color: var(--docc-fg-secondary);
            font-size: 0.875rem;
        }

        \(theme.customCSS ?? "")
        """
    }

    private static var darkModeStyles: String {
        """

        @media (prefers-color-scheme: dark) {
            :root {
                --docc-bg: #1d1d1f;
                --docc-bg-secondary: #2c2c2e;
                --docc-fg: #f5f5f7;
                --docc-fg-secondary: #a1a1a6;
                --docc-border: #424245;

                /* Swift syntax colours - dark mode */
                --swift-keyword: #ff7ab2;
                --swift-type: #dabaff;
                --swift-literal: #ff8170;
                --swift-comment: #7f8c8d;
                --swift-string: #ff8170;
                --swift-number: #d9c97c;

                /* Symbol badge colours - dark mode (monochrome) */
                --badge-bg: #2c2c2e;
                --badge-fg: #a1a1a6;
                --badge-border: #424245;

                /* Aside colours - dark mode */
                --aside-note-bg: rgba(59, 130, 246, 0.15);
                --aside-note-border: #3b82f6;
                --aside-warning-bg: rgba(245, 158, 11, 0.15);
                --aside-warning-border: #f59e0b;
                --aside-important-bg: rgba(239, 68, 68, 0.15);
                --aside-important-border: #ef4444;

                /* Decorative colours - dark mode */
                --hero-decoration: #4a4a4a;
            }
        }
        """
    }
}

/// The client-side search script.
enum SearchScript {
    /// The JavaScript content for client-side search.
    static var content: String {
        """
        // swift-docc-static search functionality
        // This script provides client-side search using Lunr.js

        (function() {
            'use strict';

            // Only initialise if the search form exists
            const searchForm = document.getElementById('search-form');
            if (!searchForm) return;

            const searchInput = document.getElementById('search-input');
            const searchResults = document.getElementById('search-results');

            let searchIndex = null;
            let searchData = null;

            // Calculate the base path for relative URLs
            function getBasePath() {
                const path = window.location.pathname;
                const depth = (path.match(/\\//g) || []).length - 1;
                return '../'.repeat(Math.max(0, depth));
            }

            // Load and build the search index
            async function loadSearchIndex() {
                try {
                    const basePath = getBasePath();
                    const response = await fetch(basePath + 'search-index.json');
                    if (!response.ok) throw new Error('Failed to load search index');

                    const data = await response.json();
                    searchData = {};

                    // Build a lookup map for documents
                    data.documents.forEach(doc => {
                        searchData[doc.id] = doc;
                    });

                    // Build the Lunr.js index
                    searchIndex = lunr(function() {
                        this.ref('id');
                        this.field('title', { boost: 10 });
                        this.field('summary', { boost: 5 });
                        this.field('keywords', { boost: 3 });
                        this.field('module', { boost: 2 });

                        data.documents.forEach(doc => {
                            this.add({
                                id: doc.id,
                                title: doc.title,
                                summary: doc.summary,
                                keywords: doc.keywords.join(' '),
                                module: doc.module || ''
                            });
                        });
                    });

                    console.log('Search index loaded with ' + data.documents.length + ' documents');
                } catch (error) {
                    console.warn('Search not available:', error.message);
                    if (searchForm) {
                        searchForm.innerHTML = '<p class="search-unavailable">Search requires JavaScript and a web server.</p>';
                    }
                }
            }

            // Perform search
            function performSearch(query) {
                if (!searchResults) return;

                if (!searchIndex || !query.trim()) {
                    searchResults.innerHTML = '';
                    searchResults.style.display = 'none';
                    return;
                }

                try {
                    const results = searchIndex.search(query + '*');
                    displayResults(results.slice(0, 10));
                } catch (e) {
                    // Handle Lunr query syntax errors gracefully
                    const results = searchIndex.search(query);
                    displayResults(results.slice(0, 10));
                }
            }

            // Display search results
            function displayResults(results) {
                if (results.length === 0) {
                    searchResults.innerHTML = '<p class="no-results">No results found</p>';
                    searchResults.style.display = 'block';
                    return;
                }

                const basePath = getBasePath();
                let html = '<ul class="search-results-list">';

                results.forEach(result => {
                    const doc = searchData[result.ref];
                    if (doc) {
                        const typeClass = 'result-type-' + doc.type;
                        html += '<li class="search-result-item">';
                        html += '<a href="' + basePath + doc.path + '" class="result-link">';
                        html += '<span class="result-title">' + escapeHtml(doc.title) + '</span>';
                        html += '<span class="result-type ' + typeClass + '">' + doc.type + '</span>';
                        html += '</a>';
                        if (doc.summary) {
                            html += '<p class="result-summary">' + escapeHtml(doc.summary.substring(0, 150)) + '</p>';
                        }
                        html += '</li>';
                    }
                });

                html += '</ul>';
                searchResults.innerHTML = html;
                searchResults.style.display = 'block';
            }

            // Escape HTML entities
            function escapeHtml(text) {
                const div = document.createElement('div');
                div.textContent = text;
                return div.innerHTML;
            }

            // Event listeners
            let debounceTimer;
            searchInput.addEventListener('input', (e) => {
                clearTimeout(debounceTimer);
                debounceTimer = setTimeout(() => {
                    performSearch(e.target.value);
                }, 150);
            });

            searchForm.addEventListener('submit', (e) => {
                e.preventDefault();
                performSearch(searchInput.value);
            });

            // Close results when clicking outside
            document.addEventListener('click', (e) => {
                if (!searchForm.contains(e.target)) {
                    searchResults.style.display = 'none';
                }
            });

            // Keyboard navigation
            searchInput.addEventListener('keydown', (e) => {
                if (e.key === 'Escape') {
                    searchResults.style.display = 'none';
                    searchInput.blur();
                }
            });

            // Initialise
            loadSearchIndex();
        })();
        """
    }

    /// The Lunr.js library (minified).
    static var lunrJS: String {
        // Lunr.js v2.3.9 - MIT License
        // https://lunrjs.com
        """
        /**
         * lunr - http://lunrjs.com - A bit like Solr, but much smaller and not as bright - 2.3.9
         * Copyright (C) 2020 Oliver Nightingale
         * @license MIT
         */
        !function(){var e=function(t){var r=new e.Builder;return r.pipeline.add(e.trimmer,e.stopWordFilter,e.stemmer),r.searchPipeline.add(e.stemmer),t.call(r,r),r.build()};e.version="2.3.9",e.utils={},e.utils.warn=function(e){return function(t){e.console&&console.warn&&console.warn(t)}}(this),e.utils.asString=function(e){return void 0===e||null===e?"":e.toString()},e.utils.clone=function(e){if(null===e||void 0===e)return e;for(var t=Object.create(null),r=Object.keys(e),i=0;i<r.length;i++){var n=r[i],s=e[n];if(Array.isArray(s))t[n]=s.slice();else{if("string"!=typeof s&&"number"!=typeof s&&"boolean"!=typeof s)throw new TypeError("clone is not deep and does not support nested objects");t[n]=s}}return t},e.FieldRef=function(e,t,r){this.docRef=e,this.fieldName=t,this._stringValue=r},e.FieldRef.joiner="/",e.FieldRef.fromString=function(t){var r=t.indexOf(e.FieldRef.joiner);if(-1===r)throw"malformed field ref string";var i=t.slice(0,r),n=t.slice(r+1);return new e.FieldRef(n,i,t)},e.FieldRef.prototype.toString=function(){return void 0==this._stringValue&&(this._stringValue=this.fieldName+e.FieldRef.joiner+this.docRef),this._stringValue},e.Set=function(e){if(this.elements=Object.create(null),e){this.length=e.length;for(var t=0;t<this.length;t++)this.elements[e[t]]=!0}else this.length=0},e.Set.complete={intersect:function(e){return e},union:function(){return this},contains:function(){return!0}},e.Set.empty={intersect:function(){return this},union:function(e){return e},contains:function(){return!1}},e.Set.prototype.contains=function(e){return!!this.elements[e]},e.Set.prototype.intersect=function(t){var r,i,n,s=[];if(t===e.Set.complete)return this;if(t===e.Set.empty)return t;this.length<t.length?(r=this,i=t):(r=t,i=this),n=Object.keys(r.elements);for(var o=0;o<n.length;o++){var a=n[o];a in i.elements&&s.push(a)}return new e.Set(s)},e.Set.prototype.union=function(t){return t===e.Set.complete?e.Set.complete:t===e.Set.empty?this:new e.Set(Object.keys(this.elements).concat(Object.keys(t.elements)))},e.idf=function(e,t){var r=0;for(var i in e)"_index"!=i&&(r+=Object.keys(e[i]).length);var n=(t-r+.5)/(r+.5);return n<1&&(n=1e-10),Math.log(1+n)},e.Token=function(e,t){this.str=e||"",this.metadata=t||{}},e.Token.prototype.toString=function(){return this.str},e.Token.prototype.update=function(e){return this.str=e(this.str,this.metadata),this},e.Token.prototype.clone=function(t){return t=t||function(e){return e},new e.Token(t(this.str,this.metadata),this.metadata)},e.tokenizer=function(t,r){if(null==t||void 0==t)return[];if(Array.isArray(t))return t.map((function(t){return new e.Token(e.utils.asString(t).toLowerCase(),e.utils.clone(r))}));for(var i=t.toString().toLowerCase(),n=i.length,s=[],o=0,a=0;o<=n;o++){var u=o-a;if(i.charAt(o).match(e.tokenizer.separator)||o==n){if(u>0){var l=e.utils.clone(r)||{};l.position=[a,u],l.index=s.length,s.push(new e.Token(i.slice(a,o),l))}a=o+1}}return s},e.tokenizer.separator=/[\\s\\-]+/,e.Pipeline=function(){this._stack=[]},e.Pipeline.registeredFunctions=Object.create(null),e.Pipeline.registerFunction=function(t,r){r in this.registeredFunctions&&e.utils.warn("Overwriting existing registered function: "+r),t.label=r,e.Pipeline.registeredFunctions[t.label]=t},e.Pipeline.warnIfFunctionNotRegistered=function(t){t.label&&t.label in this.registeredFunctions||e.utils.warn("Function is not registered with pipeline. This may cause problems when serialising the index.\\n",t)},e.Pipeline.load=function(t){var r=new e.Pipeline;return t.forEach((function(t){var i=e.Pipeline.registeredFunctions[t];if(!i)throw new Error("Cannot load unregistered function: "+t);r.add(i)})),r},e.Pipeline.prototype.add=function(){Array.prototype.slice.call(arguments).forEach((function(t){e.Pipeline.warnIfFunctionNotRegistered(t),this._stack.push(t)}),this)},e.Pipeline.prototype.after=function(t,r){e.Pipeline.warnIfFunctionNotRegistered(r);var i=this._stack.indexOf(t);if(-1==i)throw new Error("Cannot find existingFn");i+=1,this._stack.splice(i,0,r)},e.Pipeline.prototype.before=function(t,r){e.Pipeline.warnIfFunctionNotRegistered(r);var i=this._stack.indexOf(t);if(-1==i)throw new Error("Cannot find existingFn");this._stack.splice(i,0,r)},e.Pipeline.prototype.remove=function(e){var t=this._stack.indexOf(e);-1!=t&&this._stack.splice(t,1)},e.Pipeline.prototype.run=function(e){for(var t=this._stack.length,r=0;r<t;r++){for(var i=this._stack[r],n=[],s=0;s<e.length;s++){var o=i(e[s],s,e);if(null!=o&&""!==o)if(Array.isArray(o))for(var a=0;a<o.length;a++)n.push(o[a]);else n.push(o)}e=n}return e},e.Pipeline.prototype.runString=function(t,r){return r=r||{},this.run(e.tokenizer(t,r))},e.Pipeline.prototype.reset=function(){this._stack=[]},e.Pipeline.prototype.toJSON=function(){return this._stack.map((function(t){return e.Pipeline.warnIfFunctionNotRegistered(t),t.label}))},e.Vector=function(e){this._magnitude=0,this.elements=e||[]},e.Vector.prototype.positionForIndex=function(e){if(0==this.elements.length)return 0;for(var t=0,r=this.elements.length/2,i=r-t,n=Math.floor(i/2),s=this.elements[2*n];i>1&&(s<e&&(t=n),s>e&&(r=n),s!=e);)i=r-t,n=t+Math.floor(i/2),s=this.elements[2*n];return s==e||s>e?2*n:s<e?2*(n+1):void 0},e.Vector.prototype.insert=function(e,t){this.upsert(e,t,(function(){throw"duplicate index"}))},e.Vector.prototype.upsert=function(e,t,r){this._magnitude=0;var i=this.positionForIndex(e);this.elements[i]==e?this.elements[i+1]=r(this.elements[i+1],t):this.elements.splice(i,0,e,t)},e.Vector.prototype.magnitude=function(){if(this._magnitude)return this._magnitude;for(var e=0,t=this.elements.length,r=1;r<t;r+=2){var i=this.elements[r];e+=i*i}return this._magnitude=Math.sqrt(e)},e.Vector.prototype.dot=function(e){for(var t=0,r=this.elements,i=e.elements,n=r.length,s=i.length,o=0,a=0,u=0,l=0;u<n&&l<s;)(o=r[u])<(a=i[l])?u+=2:o>a?l+=2:o==a&&(t+=r[u+1]*i[l+1],u+=2,l+=2);return t},e.Vector.prototype.similarity=function(e){return this.dot(e)/this.magnitude()||0},e.Vector.prototype.toArray=function(){for(var e=new Array(this.elements.length/2),t=1,r=0;t<this.elements.length;t+=2,r++)e[r]=this.elements[t];return e},e.Vector.prototype.toJSON=function(){return this.elements},e.stemmer=function(){var e={ational:"ate",tional:"tion",enci:"ence",anci:"ance",izer:"ize",bli:"ble",alli:"al",entli:"ent",eli:"e",ousli:"ous",ization:"ize",ation:"ate",ator:"ate",alism:"al",iveness:"ive",fulness:"ful",ousness:"ous",aliti:"al",iviti:"ive",biliti:"ble",logi:"log"},t={icate:"ic",ative:"",alize:"al",iciti:"ic",ical:"ic",ful:"",ness:""},r="[^aeiou]",i="[aeiouy]",n=r+"[^aeiouy]*",s=i+"[aeiou]*",o="^("+n+")?"+s+n,a="^("+n+")?"+s+n+"("+s+")?$",u="^("+n+")?"+s+n+s+n,l="^("+n+")?"+i,c=new RegExp(o),h=new RegExp(u),d=new RegExp(a),f=new RegExp(l),p=/^(.+?)(ss|i)es$/,y=/^(.+?)([^s]}s$/,m=/^(.+?)eed$/,g=/^(.+?)(ed|ing)$/,x=/.$/,v=/(at|bl|iz)$/,w=/([^aeiouylsz])\\1$/,Q=/^[^aeiou][^aeiouy]*[aeiouy][^aeiouwxy]$/,k=/^(.+?[^aeiou])y$/,S=/^(.+?)(ational|tional|enci|anci|izer|bli|alli|entli|eli|ousli|ization|ation|ator|alism|iveness|fulness|ousness|aliti|iviti|biliti|logi)$/,E=/^(.+?)(icate|ative|alize|iciti|ical|ful|ness)$/,L=/^(.+?)(al|ance|ence|er|ic|able|ible|ant|ement|ment|ent|ou|ism|ate|iti|ous|ive|ize)$/,b=/^(.+?)(s|t)(ion)$/,P=/^(.+?)e$/,T=/ll$/,O=new RegExp("^("+n+")?"+i+"[^aeiouwxy]$"),I=function(r){var i,n,s,o,a,u,l;if(r.length<3)return r;if("y"==(s=r.substr(0,1))&&(r=s.toUpperCase()+r.substr(1)),a=y,(o=p).test(r)?r=r.replace(o,"$1$2"):a.test(r)&&(r=r.replace(a,"$1$2")),a=g,(o=m).test(r)){var I=o.exec(r);(o=c).test(I[1])&&(o=x,r=r.replace(o,""))}else a.test(r)&&(i=(I=a.exec(r))[1],(a=f).test(i)&&(u=w,l=Q,(a=v).test(r=i)?r+="e":u.test(r)?(o=x,r=r.replace(o,"")):l.test(r)&&(r+="e")));return(o=k).test(r)&&(r=(i=(I=o.exec(r))[1])+"i"),(o=S).test(r)&&(i=(I=o.exec(r))[1],n=I[2],(o=c).test(i)&&(r=i+e[n])),(o=E).test(r)&&(i=(I=o.exec(r))[1],n=I[2],(o=c).test(i)&&(r=i+t[n])),(o=L).test(r)?(i=(I=o.exec(r))[1],(o=h).test(i)&&(r=i)):(o=b).test(r)&&(i=(I=o.exec(r))[1]+I[2],(o=h).test(i)&&(r=i)),(o=P).test(r)&&(i=(I=o.exec(r))[1],a=d,u=O,((o=h).test(i)||a.test(i)&&!u.test(i))&&(r=i)),(o=T).test(r)&&(o=h).test(r)&&(o=x,r=r.replace(o,"")),"y"==s&&(r=s.toLowerCase()+r.substr(1)),r};return function(e){return e.update(I)}}(),e.Pipeline.registerFunction(e.stemmer,"stemmer"),e.generateStopWordFilter=function(e){var t=e.reduce((function(e,t){return e[t]=t,e}),{});return function(e){if(e&&t[e.toString()]!==e.toString())return e}},e.stopWordFilter=e.generateStopWordFilter(["a","able","about","across","after","all","almost","also","am","among","an","and","any","are","as","at","be","because","been","but","by","can","cannot","could","dear","did","do","does","either","else","ever","every","for","from","get","got","had","has","have","he","her","hers","him","his","how","however","i","if","in","into","is","it","its","just","least","let","like","likely","may","me","might","most","must","my","neither","no","nor","not","of","off","often","on","only","or","other","our","own","rather","said","say","says","she","should","since","so","some","than","that","the","their","them","then","there","these","they","this","tis","to","too","twas","us","wants","was","we","were","what","when","where","which","while","who","whom","why","will","with","would","yet","you","your"]),e.Pipeline.registerFunction(e.stopWordFilter,"stopWordFilter"),e.trimmer=function(e){return e.update((function(e){return e.replace(/^\\W+/,"").replace(/\\W+$/,"")}))},e.Pipeline.registerFunction(e.trimmer,"trimmer"),e.TokenSet=function(){this.final=!1,this.edges={},this.id=e.TokenSet._nextId,e.TokenSet._nextId+=1},e.TokenSet._nextId=1,e.TokenSet.fromArray=function(t){for(var r=new e.TokenSet.Builder,i=0,n=t.length;i<n;i++)r.insert(t[i]);return r.finish(),r.root},e.TokenSet.fromClause=function(t){return"leading"in t&&(e.utils.warn("Warning: Leading wildcards are not supported and will be ignored"),t=Object.assign({},t,{leading:!1})),new e.TokenSet.Builder().build(t).root},e.TokenSet.fromFuzzyString=function(t,r){for(var i=new e.TokenSet,n=[{node:i,editsRemaining:r,str:t}];n.length;){var s=n.pop();if(s.str.length>0){var o,a=s.str.charAt(0);a in s.node.edges?o=s.node.edges[a]:(o=new e.TokenSet,s.node.edges[a]=o),1==s.str.length&&(o.final=!0),n.push({node:o,editsRemaining:s.editsRemaining,str:s.str.slice(1)})}if(0!=s.editsRemaining){if("*"in s.node.edges)var u=s.node.edges["*"];else{u=new e.TokenSet;s.node.edges["*"]=u}if(0==s.str.length&&(u.final=!0),n.push({node:u,editsRemaining:s.editsRemaining-1,str:s.str}),s.str.length>1&&n.push({node:s.node,editsRemaining:s.editsRemaining-1,str:s.str.slice(1)}),1==s.str.length&&(s.node.final=!0),s.str.length>=1){if("*"in s.node.edges)var l=s.node.edges["*"];else{l=new e.TokenSet;s.node.edges["*"]=l}1==s.str.length&&(l.final=!0),n.push({node:l,editsRemaining:s.editsRemaining-1,str:s.str.slice(1)})}if(s.str.length>1){var c,h=s.str.charAt(0),d=s.str.charAt(1);d in s.node.edges?c=s.node.edges[d]:(c=new e.TokenSet,s.node.edges[d]=c),1==s.str.length&&(c.final=!0),n.push({node:c,editsRemaining:s.editsRemaining-1,str:h+s.str.slice(2)})}}}return i},e.TokenSet.fromString=function(t){for(var r=new e.TokenSet,i=r,n=0,s=t.length;n<s;n++){var o=t[n],a=n==s-1;if("*"==o)r.edges[o]=r,r.final=a;else{var u=new e.TokenSet;u.final=a,r.edges[o]=u,r=u}}return i},e.TokenSet.prototype.toArray=function(){for(var e=[],t=[{prefix:"",node:this}];t.length;){var r=t.pop(),i=Object.keys(r.node.edges),n=i.length;if(r.node.final&&(r.prefix.length>0||n==0)&&e.push(r.prefix),n)for(var s=0;s<n;s++){var o=i[s];t.push({prefix:r.prefix.concat(o),node:r.node.edges[o]})}}return e},e.TokenSet.prototype.toString=function(){if(this._str)return this._str;for(var e=this.final?"1":"0",t=Object.keys(this.edges).sort(),r=t.length,i=0;i<r;i++){var n=t[i];e=e+n+this.edges[n].id}return e},e.TokenSet.prototype.intersect=function(t){for(var r=new e.TokenSet,i=void 0,n=[{qNode:t,output:r,node:this}];n.length;){var s=n.pop(),o=Object.keys(s.qNode.edges),a=o.length,u=Object.keys(s.node.edges),l=u.length;for(i=0;i<a;i++)for(var c=o[i],h=0;h<l;h++){var d=u[h];if(d==c||"*"==c){var f=s.node.edges[d],p=s.qNode.edges[c],y=f.final&&p.final,m=void 0;d in s.output.edges?(m=s.output.edges[d]).final=m.final||y:((m=new e.TokenSet).final=y,s.output.edges[d]=m),n.push({qNode:p,output:m,node:f})}}}return r},e.TokenSet.Builder=function(){this.previousWord="",this.root=new e.TokenSet,this.uncheckedNodes=[],this.minimizedNodes={}},e.TokenSet.Builder.prototype.insert=function(t){var r,i=0;if(t<this.previousWord)throw new Error("Out of order word insertion");for(;i<t.length&&i<this.previousWord.length&&t[i]==this.previousWord[i];)i++;this.minimize(i),r=0==this.uncheckedNodes.length?this.root:this.uncheckedNodes[this.uncheckedNodes.length-1].child;for(var n=i;n<t.length;n++){var s=new e.TokenSet,o=t[n];r.edges[o]=s,this.uncheckedNodes.push({parent:r,char:o,child:s}),r=s}r.final=!0,this.previousWord=t},e.TokenSet.Builder.prototype.finish=function(){this.minimize(0)},e.TokenSet.Builder.prototype.minimize=function(e){for(var t=this.uncheckedNodes.length-1;t>=e;t--){var r=this.uncheckedNodes[t],i=r.child.toString();i in this.minimizedNodes?r.parent.edges[r.char]=this.minimizedNodes[i]:(r.child._str=i,this.minimizedNodes[i]=r.child),this.uncheckedNodes.pop()}},e.TokenSet.Builder.prototype.build=function(t){return t.wildcard&&this.insertWildcard(t),t.term&&this.insertTerm(t),{root:this.root}},e.TokenSet.Builder.prototype.insertWildcard=function(e){this.root.edges["*"]=this.root},e.TokenSet.Builder.prototype.insertTerm=function(t){for(var r=this.root,i=t.term,n=0;n<i.length;n++){var s=i[n];s in r.edges?r=r.edges[s]:((o=new e.TokenSet).final=n===i.length-1,r.edges[s]=o,r=o)}var o;r.final=!0},e.Index=function(e){this.invertedIndex=e.invertedIndex,this.fieldVectors=e.fieldVectors,this.tokenSet=e.tokenSet,this.fields=e.fields,this.pipeline=e.pipeline},e.Index.prototype.search=function(t){return this.query((function(r){var i=new e.QueryParser(t,r);i.parse()}))},e.Index.prototype.query=function(t){for(var r=new e.Query(this.fields),i=Object.create(null),n=Object.create(null),s=Object.create(null),o=Object.create(null),a=Object.create(null),u=0;u<this.fields.length;u++)n[this.fields[u]]=new e.Vector;t.call(r,r);for(u=0;u<r.clauses.length;u++){var l=r.clauses[u],c=null,h=e.Set.empty;c=l.usePipeline?this.pipeline.runString(l.term,{fields:l.fields}):[l.term];for(var d=0;d<c.length;d++){var f=c[d];l.term=f;var p=e.TokenSet.fromClause(l),y=this.tokenSet.intersect(p).toArray();if(0===y.length&&l.presence===e.Query.presence.REQUIRED){for(var m=0;m<l.fields.length;m++){o[F=l.fields[m]]=e.Set.empty}break}for(var g=0;g<y.length;g++){var x=y[g],v=this.invertedIndex[x],w=v._index;for(m=0;m<l.fields.length;m++){var Q=v[F=l.fields[m]],k=Object.keys(Q),S=x+"/"+F,E=new e.Set(k);if(h=h.union(E),l.presence==e.Query.presence.REQUIRED&&(a[F]=a[F]?a[F].union(E):E,o[F]=o[F]?o[F].union(E):E),l.presence!=e.Query.presence.PROHIBITED){if(n[F].upsert(w,l.boost,(function(e,t){return e+t})),!s[S]){for(var L=0;L<k.length;L++){var b,P=k[L],T=new e.FieldRef(P,F),O=Q[P];void 0===(b=i[T])?i[T]=new e.MatchData(x,F,O):b.add(x,F,O)}s[S]=!0}}else void 0===o[F]&&(o[F]=e.Set.complete)}}}if(l.presence===e.Query.presence.REQUIRED)for(m=0;m<l.fields.length;m++){o[F=l.fields[m]]=o[F].intersect(h)}}for(var I=e.Set.complete,F=0;F<this.fields.length;F++)o[this.fields[F]]&&(I=I.intersect(o[this.fields[F]]));for(var R=Object.keys(i),N=[],_=Object.create(null),u=0;u<R.length;u++){var C=e.FieldRef.fromString(R[u]),D=C.docRef;if(I.contains(D)){var A=this.fieldVectors[C],B=n[C.fieldName].similarity(A),V=_;void 0!==V[D]?(V[D].score+=B,V[D].matchData.combine(i[C])):(_[D]={ref:D,score:B,matchData:i[C]},N.push(_[D]))}}return N.sort((function(e,t){return t.score-e.score}))},e.Index.prototype.toJSON=function(){var t=Object.keys(this.invertedIndex).sort().map((function(e){return[e,this.invertedIndex[e]]}),this),r=Object.keys(this.fieldVectors).map((function(e){return[e,this.fieldVectors[e].toArray()]}),this);return{version:e.version,fields:this.fields,fieldVectors:r,invertedIndex:t,pipeline:this.pipeline.toJSON()}},e.Index.load=function(t){var r={},i={},n=t.fieldVectors,s=Object.create(null),o=t.invertedIndex,a=new e.TokenSet.Builder,u=e.Pipeline.load(t.pipeline);t.version!=e.version&&e.utils.warn("Version mismatch when loading serialised index. Current version of lunr '"+e.version+"' does not match serialized index '"+t.version+"'");for(var l=0;l<n.length;l++){var c=(h=n[l])[0],d=h[1];i[c]=new e.Vector(d)}for(l=0;l<o.length;l++){var h,f=(h=o[l])[0],p=h[1];a.insert(f),s[f]=p}return a.finish(),r.fields=t.fields,r.fieldVectors=i,r.invertedIndex=s,r.tokenSet=a.root,r.pipeline=u,new e.Index(r)},e.Builder=function(){this._ref="id",this._fields=Object.create(null),this._documents=Object.create(null),this.invertedIndex=Object.create(null),this.fieldTermFrequencies={},this.fieldLengths={},this.tokenizer=e.tokenizer,this.pipeline=new e.Pipeline,this.searchPipeline=new e.Pipeline,this.documentCount=0,this._b=.75,this._k1=1.2,this.termIndex=0,this.metadataWhitelist=[]},e.Builder.prototype.ref=function(e){this._ref=e},e.Builder.prototype.field=function(e,t){if(/\\//.test(e))throw new RangeError("Field '"+e+"' contains illegal character '/'");this._fields[e]=t||{}},e.Builder.prototype.b=function(e){this._b=e<0?0:e>1?1:e},e.Builder.prototype.k1=function(e){this._k1=e},e.Builder.prototype.add=function(t,r){var i=t[this._ref],n=Object.keys(this._fields);this._documents[i]=r||{},this.documentCount+=1;for(var s=0;s<n.length;s++){var o=n[s],a=this._fields[o].extractor,u=a?a(t):t[o],l=this.tokenizer(u,{fields:[o]}),c=this.pipeline.run(l),h=new e.FieldRef(i,o),d=Object.create(null);this.fieldTermFrequencies[h]=d,this.fieldLengths[h]=0,this.fieldLengths[h]+=c.length;for(var f=0;f<c.length;f++){var p=c[f];if(null==d[p])d[p]=0;d[p]+=1;null==this.invertedIndex[p]&&(this.invertedIndex[p]=Object.create(null),this.invertedIndex[p]._index=this.termIndex,this.termIndex+=1);null==this.invertedIndex[p][o]&&(this.invertedIndex[p][o]=Object.create(null));null==this.invertedIndex[p][o][i]&&(this.invertedIndex[p][o][i]=Object.create(null));for(var y=0;y<this.metadataWhitelist.length;y++){var m=this.metadataWhitelist[y],g=p.metadata[m];null==this.invertedIndex[p][o][i][m]&&(this.invertedIndex[p][o][i][m]=[]),this.invertedIndex[p][o][i][m].push(g)}}}},e.Builder.prototype.calculateAverageFieldLengths=function(){for(var t=Object.keys(this.fieldLengths),r=t.length,i={},n={},s=0;s<r;s++){var o=e.FieldRef.fromString(t[s]),a=o.fieldName;n[a]||(n[a]=0),n[a]+=1,i[a]||(i[a]=0),i[a]+=this.fieldLengths[o]}var u=Object.keys(this._fields);for(s=0;s<u.length;s++){var l=u[s];i[l]=i[l]/n[l]}this.averageFieldLength=i},e.Builder.prototype.createFieldVectors=function(){for(var t={},r=Object.keys(this.fieldTermFrequencies),i=r.length,n=Object.create(null),s=0;s<i;s++){for(var o=e.FieldRef.fromString(r[s]),a=o.fieldName,u=this.fieldLengths[o],l=new e.Vector,c=this.fieldTermFrequencies[o],h=Object.keys(c),d=h.length,f=this._fields[a].boost||1,p=this._documents[o.docRef].boost||1,y=0;y<d;y++){var m,g,x,v=h[y],w=c[v],Q=this.invertedIndex[v]._index;void 0===n[v]?(m=e.idf(this.invertedIndex[v],this.documentCount),n[v]=m):m=n[v],g=m*((this._k1+1)*w)/(this._k1*(1-this._b+this._b*(u/this.averageFieldLength[a]))+w),g*=f,g*=p,x=Math.round(1e3*g)/1e3,l.insert(Q,x)}t[o]=l}this.fieldVectors=t},e.Builder.prototype.createTokenSet=function(){this.tokenSet=e.TokenSet.fromArray(Object.keys(this.invertedIndex).sort())},e.Builder.prototype.build=function(){return this.calculateAverageFieldLengths(),this.createFieldVectors(),this.createTokenSet(),new e.Index({invertedIndex:this.invertedIndex,fieldVectors:this.fieldVectors,tokenSet:this.tokenSet,fields:Object.keys(this._fields),pipeline:this.searchPipeline})},e.Builder.prototype.use=function(e){var t=Array.prototype.slice.call(arguments,1);t.unshift(this),e.apply(this,t)},e.MatchData=function(e,t,r){for(var i=Object.create(null),n=Object.keys(r||{}),s=0;s<n.length;s++){var o=n[s];i[o]=r[o].slice()}this.metadata=Object.create(null),void 0!==e&&(this.metadata[e]=Object.create(null),this.metadata[e][t]=i)},e.MatchData.prototype.combine=function(e){for(var t=Object.keys(e.metadata),r=0;r<t.length;r++){var i=t[r],n=Object.keys(e.metadata[i]);void 0==this.metadata[i]&&(this.metadata[i]=Object.create(null));for(var s=0;s<n.length;s++){var o=n[s],a=Object.keys(e.metadata[i][o]);void 0==this.metadata[i][o]&&(this.metadata[i][o]=Object.create(null));for(var u=0;u<a.length;u++){var l=a[u];void 0==this.metadata[i][o][l]?this.metadata[i][o][l]=e.metadata[i][o][l].slice():this.metadata[i][o][l]=this.metadata[i][o][l].concat(e.metadata[i][o][l])}}}},e.Query=function(e){this.clauses=[],this.allFields=e},e.Query.wildcard=new String("*"),e.Query.wildcard.NONE=0,e.Query.wildcard.LEADING=1,e.Query.wildcard.TRAILING=2,e.Query.presence={OPTIONAL:1,REQUIRED:2,PROHIBITED:3},e.Query.prototype.clause=function(t){return"fields"in t||(t.fields=this.allFields),"boost"in t||(t.boost=1),"usePipeline"in t||(t.usePipeline=!0),"wildcard"in t||(t.wildcard=e.Query.wildcard.NONE),t.wildcard&e.Query.wildcard.LEADING&&t.term.charAt(0)!=e.Query.wildcard&&(t.term="*"+t.term),t.wildcard&e.Query.wildcard.TRAILING&&t.term.slice(-1)!=e.Query.wildcard&&(t.term=t.term+"*"),"presence"in t||(t.presence=e.Query.presence.OPTIONAL),this.clauses.push(t),this},e.Query.prototype.isNegated=function(){for(var t=0;t<this.clauses.length;t++)if(this.clauses[t].presence!=e.Query.presence.PROHIBITED)return!1;return!0},e.Query.prototype.term=function(t,r){if(Array.isArray(t))return t.forEach((function(t){this.term(t,e.utils.clone(r))}),this),this;var i=r||{};return i.term=t.toString(),this.clause(i),this},e.QueryParseError=function(e,t,r){this.name="QueryParseError",this.message=e,this.start=t,this.end=r},e.QueryParseError.prototype=new Error,e.QueryLexer=function(e){this.lexemes=[],this.str=e,this.length=e.length,this.pos=0,this.start=0,this.escapeCharPositions=[]},e.QueryLexer.prototype.run=function(){for(var t=e.QueryLexer.lexText;t;)t=t(this)},e.QueryLexer.prototype.sliceString=function(){for(var e=[],t=this.start,r=this.pos,i=0;i<this.escapeCharPositions.length;i++)r=this.escapeCharPositions[i],e.push(this.str.slice(t,r)),t=r+1;return e.push(this.str.slice(t,this.pos)),this.escapeCharPositions.length=0,e.join("")},e.QueryLexer.prototype.emit=function(e){this.lexemes.push({type:e,str:this.sliceString(),start:this.start,end:this.pos}),this.start=this.pos},e.QueryLexer.prototype.escapeCharacter=function(){this.escapeCharPositions.push(this.pos-1),this.pos+=1},e.QueryLexer.prototype.next=function(){if(this.pos<this.length)return this.str.charAt(this.pos++)},e.QueryLexer.prototype.width=function(){return this.pos-this.start},e.QueryLexer.prototype.ignore=function(){this.start==this.pos&&(this.pos+=1),this.start=this.pos},e.QueryLexer.prototype.backup=function(){this.pos-=1},e.QueryLexer.prototype.acceptDigitRun=function(){var t,r;do{r=(t=this.next())&&t.charCodeAt(0)}while(r>47&&r<58);t&&this.backup()},e.QueryLexer.prototype.more=function(){return this.pos<this.length},e.QueryLexer.EOS="EOS",e.QueryLexer.FIELD="FIELD",e.QueryLexer.TERM="TERM",e.QueryLexer.EDIT_DISTANCE="EDIT_DISTANCE",e.QueryLexer.BOOST="BOOST",e.QueryLexer.PRESENCE="PRESENCE",e.QueryLexer.lexField=function(t){return t.backup(),t.emit(e.QueryLexer.FIELD),t.ignore(),e.QueryLexer.lexText},e.QueryLexer.lexTerm=function(t){if(t.width()>1&&(t.backup(),t.emit(e.QueryLexer.TERM)),t.ignore(),t.more())return e.QueryLexer.lexText},e.QueryLexer.lexEditDistance=function(t){return t.ignore(),t.acceptDigitRun(),t.emit(e.QueryLexer.EDIT_DISTANCE),e.QueryLexer.lexText},e.QueryLexer.lexBoost=function(t){return t.ignore(),t.acceptDigitRun(),t.emit(e.QueryLexer.BOOST),e.QueryLexer.lexText},e.QueryLexer.lexEOS=function(t){t.width()>0&&t.emit(e.QueryLexer.TERM)},e.QueryLexer.lexText=function(t){for(;;){var r=t.next();if(null==r)return e.QueryLexer.lexEOS;if(92!=r.charCodeAt(0)){if(":"==r)return e.QueryLexer.lexField;if("~"==r)return t.backup(),t.width()>0&&t.emit(e.QueryLexer.TERM),e.QueryLexer.lexEditDistance;if("^"==r)return t.backup(),t.width()>0&&t.emit(e.QueryLexer.TERM),e.QueryLexer.lexBoost;if("+"==r&&1===t.width())return t.emit(e.QueryLexer.PRESENCE),e.QueryLexer.lexText;if("-"==r&&1===t.width())return t.emit(e.QueryLexer.PRESENCE),e.QueryLexer.lexText;if(r.match(e.QueryLexer.termSeparator))return e.QueryLexer.lexTerm}else t.escapeCharacter()}},e.QueryLexer.termSeparator=/[\\s\\-]+/,e.QueryParser=function(t,r){this.lexer=new e.QueryLexer(t),this.query=r,this.currentClause={},this.lexemeIdx=0},e.QueryParser.prototype.parse=function(){this.lexer.run(),this.lexemes=this.lexer.lexemes;for(var t=e.QueryParser.parseClause;t;)t=t(this);return this.query},e.QueryParser.prototype.peekLexeme=function(){return this.lexemes[this.lexemeIdx]},e.QueryParser.prototype.consumeLexeme=function(){var e=this.peekLexeme();return this.lexemeIdx+=1,e},e.QueryParser.prototype.nextClause=function(){var e=this.currentClause;this.query.clause(e),this.currentClause={}},e.QueryParser.parseClause=function(t){var r=t.peekLexeme();if(null!=r)switch(r.type){case e.QueryLexer.PRESENCE:return e.QueryParser.parsePresence;case e.QueryLexer.FIELD:return e.QueryParser.parseField;case e.QueryLexer.TERM:return e.QueryParser.parseTerm;default:var i="expected either a field or a term, found "+r.type;throw r.str.length>=1&&(i+=" with value '"+r.str+"'"),new e.QueryParseError(i,r.start,r.end)}},e.QueryParser.parsePresence=function(t){var r=t.consumeLexeme();if(null!=r){switch(r.str){case"-":t.currentClause.presence=e.Query.presence.PROHIBITED;break;case"+":t.currentClause.presence=e.Query.presence.REQUIRED;break;default:var i="unrecognised presence operator '"+r.str+"'";throw new e.QueryParseError(i,r.start,r.end)}var n=t.peekLexeme();if(null==n){i="expecting term or field, found nothing";throw new e.QueryParseError(i,r.start,r.end)}switch(n.type){case e.QueryLexer.FIELD:return e.QueryParser.parseField;case e.QueryLexer.TERM:return e.QueryParser.parseTerm;default:i="expecting term or field, found '"+n.type+"'";throw new e.QueryParseError(i,n.start,n.end)}}},e.QueryParser.parseField=function(t){var r=t.consumeLexeme();if(null!=r){if(-1==t.query.allFields.indexOf(r.str)){var i=t.query.allFields.map((function(e){return"'"+e+"'"})).join(", "),n="unrecognised field '"+r.str+"', possible fields: "+i;throw new e.QueryParseError(n,r.start,r.end)}t.currentClause.fields=[r.str];var s=t.peekLexeme();if(null==s){n="expecting term, found nothing";throw new e.QueryParseError(n,r.start,r.end)}switch(s.type){case e.QueryLexer.TERM:return e.QueryParser.parseTerm;default:n="expecting term, found '"+s.type+"'";throw new e.QueryParseError(n,s.start,s.end)}}},e.QueryParser.parseTerm=function(t){var r=t.consumeLexeme();if(null!=r){t.currentClause.term=r.str.toLowerCase(),-1!=r.str.indexOf("*")&&(t.currentClause.usePipeline=!1);var i=t.peekLexeme();if(null==i)return void t.nextClause();switch(i.type){case e.QueryLexer.TERM:return t.nextClause(),e.QueryParser.parseTerm;case e.QueryLexer.FIELD:return t.nextClause(),e.QueryParser.parseField;case e.QueryLexer.EDIT_DISTANCE:return e.QueryParser.parseEditDistance;case e.QueryLexer.BOOST:return e.QueryParser.parseBoost;case e.QueryLexer.PRESENCE:return t.nextClause(),e.QueryParser.parsePresence;default:var n="Unexpected lexeme type '"+i.type+"'";throw new e.QueryParseError(n,i.start,i.end)}}},e.QueryParser.parseEditDistance=function(t){var r=t.consumeLexeme();if(null!=r){var i=parseInt(r.str,10);if(isNaN(i)){var n="edit distance must be numeric";throw new e.QueryParseError(n,r.start,r.end)}t.currentClause.editDistance=i;var s=t.peekLexeme();if(null==s)return void t.nextClause();switch(s.type){case e.QueryLexer.TERM:return t.nextClause(),e.QueryParser.parseTerm;case e.QueryLexer.FIELD:return t.nextClause(),e.QueryParser.parseField;case e.QueryLexer.EDIT_DISTANCE:return e.QueryParser.parseEditDistance;case e.QueryLexer.BOOST:return e.QueryParser.parseBoost;case e.QueryLexer.PRESENCE:return t.nextClause(),e.QueryParser.parsePresence;default:n="Unexpected lexeme type '"+s.type+"'";throw new e.QueryParseError(n,s.start,s.end)}}},e.QueryParser.parseBoost=function(t){var r=t.consumeLexeme();if(null!=r){var i=parseInt(r.str,10);if(isNaN(i)){var n="boost must be numeric";throw new e.QueryParseError(n,r.start,r.end)}t.currentClause.boost=i;var s=t.peekLexeme();if(null==s)return void t.nextClause();switch(s.type){case e.QueryLexer.TERM:return t.nextClause(),e.QueryParser.parseTerm;case e.QueryLexer.FIELD:return t.nextClause(),e.QueryParser.parseField;case e.QueryLexer.EDIT_DISTANCE:return e.QueryParser.parseEditDistance;case e.QueryLexer.BOOST:return e.QueryParser.parseBoost;case e.QueryLexer.PRESENCE:return t.nextClause(),e.QueryParser.parsePresence;default:n="Unexpected lexeme type '"+s.type+"'";throw new e.QueryParseError(n,s.start,s.end)}}},function(e,t){"function"==typeof define&&define.amd?define(t):"object"==typeof exports?module.exports=t():e.lunr=t()}(this,(function(){return e}))}();
        """
    }
}
