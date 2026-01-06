//
// StaticDocumentationGenerator.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import Subprocess
import SwiftDocC

#if canImport(System)
import System
#else
import SystemPackage
#endif

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

        // Use pre-generated symbol graphs or generate them
        let symbolGraphsDir: URL
        if let preGeneratedDir = configuration.symbolGraphDir {
            if configuration.isVerbose {
                log("Using pre-generated symbol graphs from: \(preGeneratedDir.path)")
            }
            symbolGraphsDir = preGeneratedDir
        } else {
            symbolGraphsDir = tempDir.appendingPathComponent("symbol-graphs")
            try await generateSymbolGraphs(to: symbolGraphsDir)
        }

        // Discover package targets for dependency filtering
        // When using pre-generated symbol graphs, include all modules since the plugin
        // already filtered what to generate symbol graphs for
        let packageTargets: Set<String>
        if configuration.symbolGraphDir != nil {
            packageTargets = []  // Empty means include all
        } else {
            packageTargets = try await getPackageTargets()
        }

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

        // Run docc convert for each catalog separately, then for remaining symbol graphs
        // This is necessary because docc doesn't properly associate catalogs with modules
        // when multiple symbol graphs are present
        let archives = try await runDoccConvertForAllTargets(
            symbolGraphsDir: symbolGraphsDir,
            tempDir: tempDir
        )

        for archiveDir in archives {
            try await renderFromArchive(
                archiveDir,
                consumer: consumer,
                searchIndexBuilder: &searchIndexBuilder,
                packageTargets: packageTargets
            )
            // Copy images and other assets from this archive
            try copyArchiveAssets(from: archiveDir)
        }

        // Write assets
        try writeAssets()

        // Generate tutorial overview pages (landing pages for tutorials)
        try generateTutorialOverviewPages()

        // Generate combined index page
        try generateIndexPage(consumer: consumer)

        // Write search index if enabled
        if configuration.includeSearch, let builder = searchIndexBuilder {
            try writeSearchIndex(builder)
        }

        return consumer.result()
    }

    // MARK: - Package Target Discovery

    /// Returns the set of target names defined in the current package.
    ///
    /// This distinguishes between the package's own targets and external dependencies.
    private func getPackageTargets() async throws -> Set<String> {
        let result = try await run(
            .name("swift"),
            arguments: Arguments([
                "package", "describe",
                "--package-path", configuration.packageDirectory.path,
                "--type", "json"
            ]),
            output: .string(limit: 10 * 1024 * 1024)  // 10MB limit
        )

        guard result.terminationStatus.isSuccess else {
            // If we can't get package info, fall back to empty set
            // which means we'll include everything
            if configuration.isVerbose {
                log("Warning: Could not determine package targets, including all modules")
            }
            return []
        }

        // Parse the JSON to extract target names
        guard let outputString = result.standardOutput,
              let data = outputString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let targets = json["targets"] as? [[String: Any]] else {
            return []
        }

        var targetNames = Set<String>()
        for target in targets {
            if let name = target["name"] as? String {
                targetNames.insert(name)
            }
        }

        if configuration.isVerbose {
            log("Package targets: \(targetNames.sorted().joined(separator: ", "))")
        }

        return targetNames
    }

    /// Determines if a module should be included based on the dependency policy.
    ///
    /// - Parameters:
    ///   - moduleName: The name of the module to check.
    ///   - packageTargets: The set of target names from the current package.
    /// - Returns: `true` if the module should be included, `false` otherwise.
    private func shouldIncludeModule(_ moduleName: String, packageTargets: Set<String>) -> Bool {
        // When using pre-generated symbol graphs (from plugin), include all modules
        // since the plugin already filtered what to generate symbol graphs for
        if configuration.symbolGraphDir != nil {
            return true
        }

        // When packageTargets is empty (e.g., rendering from archive without build),
        // include all modules since we can't determine what's a package target
        if packageTargets.isEmpty {
            return true
        }

        // Package's own targets are always included
        if packageTargets.contains(moduleName) {
            return true
        }

        // Apply dependency policy for external modules
        switch configuration.dependencyPolicy {
        case .all:
            return true
        case .none:
            return false
        case .exclude(let excluded):
            return !excluded.contains(moduleName)
        case .includeOnly(let included):
            return included.contains(moduleName)
        }
    }

    // MARK: - Symbol Graph Generation

    private func generateSymbolGraphs(to outputDir: URL) async throws {
        let fileManager = FileManager.default

        if configuration.isVerbose {
            log("Generating symbol graphs...")
        }

        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Build arguments for swift build with emit-symbol-graph
        var arguments = [
            "build",
            "--package-path", configuration.packageDirectory.path,
            "-Xswiftc", "-emit-symbol-graph",
            "-Xswiftc", "-emit-symbol-graph-dir",
            "-Xswiftc", outputDir.path
        ]

        // Add scratch path if specified
        if let scratchPath = configuration.scratchPath {
            arguments.append(contentsOf: ["--scratch-path", scratchPath.path])
        }

        // Add target restrictions if specified
        for target in configuration.targets {
            arguments.append(contentsOf: ["--target", target])
        }

        // Use streaming API to show output as it arrives
        // Note: swift-subprocess requires discarding stderr when streaming stdout
        // Build diagnostics typically go to stdout anyway
        let isVerbose = configuration.isVerbose
        let result = try await run(
            .name("swift"),
            arguments: Arguments(arguments)
        ) { execution, standardOutput in
            // Stream stdout lines as they arrive
            for try await line in standardOutput.lines(encoding: UTF8.self) {
                if isVerbose {
                    print(line)
                }
            }
        }

        if !result.terminationStatus.isSuccess {
            throw GenerationError.symbolGraphGenerationFailed(
                "Build failed with exit code \(result.terminationStatus)"
            )
        }

        if configuration.isVerbose {
            log("Symbol graphs generated at: \(outputDir.path)")
        }
    }

    // MARK: - DocC Conversion

    /// Runs docc convert with optional catalog and target name.
    ///
    /// - Parameters:
    ///   - symbolGraphsDir: Directory containing symbol graph JSON files.
    ///   - outputDir: Output directory for the doccarchive.
    ///   - catalog: Optional DocC catalog to include.
    ///   - targetName: Optional target name for fallback metadata.
    private func runDoccConvert(
        symbolGraphsDir: URL,
        outputDir: URL,
        catalog: URL? = nil,
        targetName: String? = nil
    ) async throws {
        if configuration.isVerbose {
            log("Running docc convert...")
        }

        // Find docc executable
        let doccPath = try await findDoccExecutable()

        // Determine the target/module name for fallback metadata
        let moduleName: String
        if let name = targetName {
            moduleName = name
        } else if let firstTarget = configuration.targets.first {
            moduleName = firstTarget
        } else {
            // Fall back to package directory name
            moduleName = configuration.packageDirectory.lastPathComponent
        }

        // Build arguments for docc convert
        var arguments = [
            "convert",
            "--additional-symbol-graph-dir", symbolGraphsDir.path,
            "--output-path", outputDir.path,
            "--emit-digest",
            "--fallback-display-name", moduleName,
            "--fallback-bundle-identifier", moduleName
        ]

        // Add catalog as the main input if provided
        if let catalogURL = catalog {
            arguments.insert(catalogURL.path, at: 1)
            if configuration.isVerbose {
                log("Using DocC catalog: \(catalogURL.path)")
            }
        }

        // Use streaming API to show output as it arrives
        // Note: swift-subprocess requires discarding stderr when streaming stdout
        // docc diagnostics typically go to stdout anyway
        let verbose = configuration.isVerbose
        let result = try await run(
            .path(FilePath(doccPath)),
            arguments: Arguments(arguments)
        ) { execution, standardOutput in
            // Stream stdout lines as they arrive
            for try await line in standardOutput.lines(encoding: UTF8.self) {
                if verbose {
                    print(line)
                }
            }
        }

        // docc may return non-zero for warnings, which is fine
        if !result.terminationStatus.isSuccess {
            logWarning("docc exited with status: \(result.terminationStatus)")
        }

        if configuration.isVerbose {
            log("DocC archive created at: \(outputDir.path)")
        }
    }

    /// Runs docc convert for all targets, handling catalogs separately.
    ///
    /// This runs docc convert once per DocC catalog with only the matching symbol graph,
    /// then runs a final conversion for any remaining symbol graphs. This is necessary
    /// because docc doesn't properly associate catalogs with modules when multiple
    /// symbol graphs are present.
    ///
    /// - Parameters:
    ///   - symbolGraphsDir: The directory containing all symbol graph JSON files.
    ///   - tempDir: The temporary directory for archives.
    /// - Returns: Array of archive directories to process.
    private func runDoccConvertForAllTargets(
        symbolGraphsDir: URL,
        tempDir: URL
    ) async throws -> [URL] {
        let fileManager = FileManager.default
        var archives: [URL] = []

        // Find all DocC catalogs
        let catalogs = findDoccCatalogs(in: configuration.packageDirectory, fileManager: fileManager)

        // Track which symbol graphs have been processed
        var processedSymbolGraphs = Set<String>()

        // Process each catalog with its matching symbol graph
        for catalog in catalogs {
            let catalogName = catalog.deletingPathExtension().lastPathComponent

            // Find matching symbol graph file
            let matchingSymbolGraph = findMatchingSymbolGraph(
                for: catalogName,
                in: symbolGraphsDir,
                fileManager: fileManager
            )

            // Create a temporary directory with just this symbol graph
            let catalogSymbolGraphsDir = tempDir.appendingPathComponent("sg-\(catalogName)")
            try fileManager.createDirectory(at: catalogSymbolGraphsDir, withIntermediateDirectories: true)

            if let symbolGraph = matchingSymbolGraph {
                let destPath = catalogSymbolGraphsDir.appendingPathComponent(symbolGraph.lastPathComponent)
                try fileManager.copyItem(at: symbolGraph, to: destPath)
                processedSymbolGraphs.insert(symbolGraph.lastPathComponent)
            }

            // Run docc convert for this catalog
            let archiveDir = tempDir.appendingPathComponent("archive-\(catalogName).doccarchive")
            try await runDoccConvert(
                symbolGraphsDir: catalogSymbolGraphsDir,
                outputDir: archiveDir,
                catalog: catalog,
                targetName: catalogName
            )
            archives.append(archiveDir)
        }

        // Find remaining symbol graphs that weren't matched to catalogs
        let allSymbolGraphs = try fileManager.contentsOfDirectory(atPath: symbolGraphsDir.path)
            .filter { $0.hasSuffix(".symbols.json") }

        let remainingSymbolGraphs = allSymbolGraphs.filter { !processedSymbolGraphs.contains($0) }

        if !remainingSymbolGraphs.isEmpty {
            // Create temp directory for remaining symbol graphs
            let remainingSymbolGraphsDir = tempDir.appendingPathComponent("sg-remaining")
            try fileManager.createDirectory(at: remainingSymbolGraphsDir, withIntermediateDirectories: true)

            for symbolGraph in remainingSymbolGraphs {
                let sourcePath = symbolGraphsDir.appendingPathComponent(symbolGraph)
                let destPath = remainingSymbolGraphsDir.appendingPathComponent(symbolGraph)
                try fileManager.copyItem(at: sourcePath, to: destPath)
            }

            // Run docc convert for remaining symbol graphs (no catalog)
            let archiveDir = tempDir.appendingPathComponent("archive-remaining.doccarchive")
            try await runDoccConvert(
                symbolGraphsDir: remainingSymbolGraphsDir,
                outputDir: archiveDir,
                catalog: nil,
                targetName: nil
            )
            archives.append(archiveDir)
        }

        return archives
    }

    /// Finds a symbol graph file matching the given catalog name.
    private func findMatchingSymbolGraph(
        for catalogName: String,
        in symbolGraphsDir: URL,
        fileManager: FileManager
    ) -> URL? {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: symbolGraphsDir.path) else {
            return nil
        }

        // Try exact match first (e.g., "SwiftModelling" -> "SwiftModelling.symbols.json")
        let exactMatch = "\(catalogName).symbols.json"
        if contents.contains(exactMatch) {
            return symbolGraphsDir.appendingPathComponent(exactMatch)
        }

        // Try with underscores replacing hyphens (e.g., "swift-atl" -> "swift_atl.symbols.json")
        let underscoreMatch = catalogName.replacingOccurrences(of: "-", with: "_") + ".symbols.json"
        if contents.contains(underscoreMatch) {
            return symbolGraphsDir.appendingPathComponent(underscoreMatch)
        }

        // Try case-insensitive match
        let lowercaseName = catalogName.lowercased()
        for file in contents where file.hasSuffix(".symbols.json") {
            let baseName = String(file.dropLast(".symbols.json".count))
            if baseName.lowercased() == lowercaseName ||
               baseName.lowercased().replacingOccurrences(of: "_", with: "-") == lowercaseName {
                return symbolGraphsDir.appendingPathComponent(file)
            }
        }

        return nil
    }

    private func findDoccExecutable() async throws -> String {
        let fileManager = FileManager.default

#if os(macOS)
        // On macOS, prefer Xcode's docc via xcrun for stable navigation ordering
        // (The swift-latest toolchain's docc has a bug that reorders navigation items)
        if fileManager.fileExists(atPath: "/usr/bin/xcrun") {
            let result = try await run(
                .path(FilePath("/usr/bin/xcrun")),
                arguments: Arguments(["--find", "docc"]),
                output: .string(limit: 4096)
            )

            if result.terminationStatus.isSuccess {
                if let output = result.standardOutput {
                    let path = output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if !path.isEmpty && fileManager.fileExists(atPath: path) {
                        return path
                    }
                }
            }
        }

        // Fall back to common macOS locations
        let macOSPaths = [
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/docc",
            "/Applications/Developer/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/docc",
            "/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin/docc"
        ]

        for path in macOSPaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }
#endif

        // Cross-platform: try 'which docc' to find docc in PATH
        let whichResult = try await run(
            .path(FilePath("/usr/bin/which")),
            arguments: Arguments(["docc"]),
            output: .string(limit: 4096)
        )

        if whichResult.terminationStatus.isSuccess {
            if let output = whichResult.standardOutput {
                let path = output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !path.isEmpty && fileManager.fileExists(atPath: path) {
                    return path
                }
            }
        }

        // Linux: check common Swift toolchain locations
        let linuxPaths = [
            "/usr/bin/docc",
            "/usr/local/bin/docc"
        ]

        // Also check SWIFT_PATH environment variable
        if let swiftPath = ProcessInfo.processInfo.environment["SWIFT_PATH"] {
            let doccInSwift = (swiftPath as NSString).appendingPathComponent("docc")
            if fileManager.fileExists(atPath: doccInSwift) {
                return doccInSwift
            }
        }

        for path in linuxPaths {
            if fileManager.fileExists(atPath: path) {
                return path
            }
        }

        throw GenerationError.doccNotFound
    }

    /// Finds all DocC catalogs (.docc directories) in a package.
    ///
    /// - Parameters:
    ///   - packageDirectory: The root directory of the Swift package.
    ///   - fileManager: The file manager to use for directory enumeration.
    /// - Returns: An array of URLs pointing to DocC catalog directories.
    private func findDoccCatalogs(in packageDirectory: URL, fileManager: FileManager) -> [URL] {
        let sourcesDir = packageDirectory.appendingPathComponent("Sources")
        var catalogs: [URL] = []

        // Check if Sources directory exists
        guard fileManager.fileExists(atPath: sourcesDir.path) else {
            return catalogs
        }

        // Enumerate all items in Sources directory
        guard let enumerator = fileManager.enumerator(
            at: sourcesDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return catalogs
        }

        while let url = enumerator.nextObject() as? URL {
            // Check if this is a .docc directory
            if url.pathExtension == "docc" {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    catalogs.append(url)
                    // Don't descend into .docc directories
                    enumerator.skipDescendants()
                }
            }
        }

        // Sort catalogs by name for deterministic ordering
        return catalogs.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Archive Rendering

    private func renderFromArchive(
        _ archiveDir: URL,
        consumer: StaticHTMLConsumer,
        searchIndexBuilder: inout SearchIndexBuilder?,
        packageTargets: Set<String>
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

        // Track which modules have been skipped
        var skippedModules = Set<String>()

        let decoder = JSONDecoder()

        // Process both documentation and tutorials directories
        let tutorialsDir = dataDir.appendingPathComponent("tutorials")
        let dirsToProcess = [documentationDir, tutorialsDir].filter {
            fileManager.fileExists(atPath: $0.path)
        }

        for dir in dirsToProcess {
            // Find all JSON files in the directory
            let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                guard fileURL.pathExtension == "json" else { continue }

                do {
                    let data = try Data(contentsOf: fileURL)
                    let renderNode = try decoder.decode(RenderNode.self, from: data)

                    // Extract module name from the identifier path
                    // Path format: /documentation/ModuleName/... or /tutorials/ModuleName/...
                    let moduleName = extractModuleName(from: renderNode.identifier.path)

                    // Check if this module should be included
                    guard shouldIncludeModule(moduleName, packageTargets: packageTargets) else {
                        if !skippedModules.contains(moduleName) {
                            skippedModules.insert(moduleName)
                            if configuration.isVerbose {
                                log("Skipping dependency: \(moduleName)")
                            }
                        }
                        continue
                    }

                    try consumer.consume(renderNode: renderNode)

                    // Add to search index if enabled
                    searchIndexBuilder?.addToIndex(renderNode)
                } catch {
                    if configuration.isVerbose {
                        log("Warning: Failed to process \(fileURL.lastPathComponent): \(error)")
                    }
                }
            }
        }

        if configuration.isVerbose {
            log("Finished rendering pages")
        }
    }

    /// Renders documentation from an existing DocC archive to static HTML.
    ///
    /// This method allows rendering from a pre-generated `.doccarchive` without
    /// needing to build symbol graphs, which is useful for testing and quick iterations.
    ///
    /// - Parameter archiveURL: Path to the `.doccarchive` directory.
    /// - Returns: The generation result with statistics.
    public func renderFromArchive(_ archiveURL: URL) async throws -> GenerationResult {
        // Create output directory structure (including css/ and js/ subdirectories)
        try createOutputDirectory()

        // Write static assets (CSS, JS)
        try writeAssets()

        // Create the consumer
        let consumer = StaticHTMLConsumer(
            outputDirectory: configuration.outputDirectory,
            configuration: configuration
        )

        // Render from archive (include all modules since we don't know package targets)
        var searchBuilder: SearchIndexBuilder? = configuration.includeSearch ?
            SearchIndexBuilder(configuration: configuration) : nil
        try await renderFromArchive(
            archiveURL,
            consumer: consumer,
            searchIndexBuilder: &searchBuilder,
            packageTargets: []  // Empty means include all
        )

        // Copy images and other assets from the archive
        try copyArchiveAssets(from: archiveURL)

        // Generate tutorial overview pages
        try generateTutorialOverviewPages()

        // Generate index page
        try generateIndexPage(consumer: consumer)

        // Write search index if enabled
        if let builder = searchBuilder {
            try writeSearchIndex(builder)
        }

        return consumer.result()
    }

    /// Extracts the module name from a documentation or tutorial path.
    ///
    /// - Parameter path: The identifier path (e.g., "/documentation/ModuleName/Symbol" or "/tutorials/ModuleName/Tutorial").
    /// - Returns: The module name, or an empty string if not found.
    private func extractModuleName(from path: String) -> String {
        // Path format: /documentation/ModuleName/... or /tutorials/ModuleName/...
        let components = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .components(separatedBy: "/")
            .filter { !$0.isEmpty }

        // Module name is the second component after "documentation" or "tutorials"
        if components.count >= 2 {
            let firstComponent = components[0].lowercased()
            if firstComponent == "documentation" || firstComponent == "tutorials" {
                return components[1]
            }
        }

        return ""
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

    // MARK: - Tutorial Overview Page Generation

    /// Generates tutorial overview (landing) pages for each module that has tutorials.
    ///
    /// This scans the generated tutorials directory and creates an overview page
    /// listing all tutorials for each module.
    private func generateTutorialOverviewPages() throws {
        let fileManager = FileManager.default
        let tutorialsRoot = configuration.outputDirectory.appendingPathComponent("tutorials")

        guard fileManager.fileExists(atPath: tutorialsRoot.path) else {
            return // No tutorials to generate overview for
        }

        // Get all module directories under tutorials/
        guard let moduleDirectories = try? fileManager.contentsOfDirectory(
            at: tutorialsRoot,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return
        }

        for moduleDir in moduleDirectories {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: moduleDir.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            let moduleName = moduleDir.lastPathComponent

            // Skip if overview already exists
            let overviewPath = moduleDir.appendingPathComponent("index.html")
            if fileManager.fileExists(atPath: overviewPath.path) {
                continue
            }

            // Collect all tutorials in this module
            guard let tutorialDirs = try? fileManager.contentsOfDirectory(
                at: moduleDir,
                includingPropertiesForKeys: [.isDirectoryKey]
            ) else {
                continue
            }

            // Find any tutorial page to extract the hierarchy order
            var orderedTutorialPaths: [String] = []
            var overviewTitle = moduleName.capitalized + " Tutorials"

            // Read hierarchy from first tutorial to get correct order
            for tutorialDir in tutorialDirs {
                var isTutorialDir: ObjCBool = false
                guard fileManager.fileExists(atPath: tutorialDir.path, isDirectory: &isTutorialDir),
                      isTutorialDir.boolValue else {
                    continue
                }

                let tutorialIndexPath = tutorialDir.appendingPathComponent("index.html")
                guard let html = try? String(contentsOf: tutorialIndexPath, encoding: .utf8) else {
                    continue
                }

                // Extract overview title
                if let titleStart = html.range(of: "class=\"tutorial-nav-title\">"),
                   let titleEnd = html.range(of: "</a>", range: titleStart.upperBound..<html.endIndex) {
                    overviewTitle = String(html[titleStart.upperBound..<titleEnd.lowerBound])
                }

                // Extract tutorial order from dropdown - all href links in dropdown-chapter or dropdown-item
                let pattern = "href=\"[^\"]*\(moduleName)/([^/\"]+)/index\\.html\""
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(html.startIndex..<html.endIndex, in: html)
                    let matches = regex.matches(in: html, options: [], range: range)
                    for match in matches {
                        if let pathRange = Range(match.range(at: 1), in: html) {
                            let path = String(html[pathRange])
                            if !orderedTutorialPaths.contains(path) {
                                orderedTutorialPaths.append(path)
                            }
                        }
                    }
                }

                // We only need to process one tutorial to get the hierarchy
                if !orderedTutorialPaths.isEmpty {
                    break
                }
            }

            // Build tutorials list in correct order
            var tutorials: [(title: String, abstract: String, path: String)] = []

            for tutorialPath in orderedTutorialPaths {
                let tutorialDir = moduleDir.appendingPathComponent(tutorialPath)
                let tutorialIndexPath = tutorialDir.appendingPathComponent("index.html")

                guard let tutorialHTML = try? String(contentsOf: tutorialIndexPath, encoding: .utf8) else {
                    continue
                }

                let info = extractTutorialInfo(from: tutorialHTML, fallbackName: tutorialPath)
                tutorials.append((
                    title: info.title,
                    abstract: info.abstract,
                    path: "\(tutorialPath)/index.html"
                ))
            }

            guard !tutorials.isEmpty else {
                continue
            }

            // Generate the overview page HTML
            let overviewHTML = buildTutorialOverviewHTML(
                title: overviewTitle,
                moduleName: moduleName,
                tutorials: tutorials
            )

            // Create the tutorials/tutorials directory if needed (for the general landing)
            let tutorialsTutorialsDir = tutorialsRoot.appendingPathComponent("tutorials")
            try fileManager.createDirectory(at: tutorialsTutorialsDir, withIntermediateDirectories: true)

            // Write to tutorials/tutorials/index.html (the general tutorials landing page)
            let generalOverviewPath = tutorialsTutorialsDir.appendingPathComponent("index.html")
            try overviewHTML.write(to: generalOverviewPath, atomically: true, encoding: .utf8)

            if configuration.isVerbose {
                log("Generated tutorial overview: \(generalOverviewPath.path)")
            }
        }
    }

    /// Extracts title and abstract from tutorial HTML.
    private func extractTutorialInfo(from html: String, fallbackName: String) -> (title: String, abstract: String) {
        var title = fallbackName.replacingOccurrences(of: "-", with: " ").capitalized

        // Extract from <title> tag
        if let titleStart = html.range(of: "<title>"),
           let titleEnd = html.range(of: "</title>", range: titleStart.upperBound..<html.endIndex) {
            title = String(html[titleStart.upperBound..<titleEnd.lowerBound])
        }

        // Extract abstract from tutorial-abstract div
        var abstract = ""
        if let abstractStart = html.range(of: "<div class=\"tutorial-abstract\">"),
           let pStart = html.range(of: "<p>", range: abstractStart.upperBound..<html.endIndex),
           let pEnd = html.range(of: "</p>", range: pStart.upperBound..<html.endIndex) {
            abstract = String(html[pStart.upperBound..<pEnd.lowerBound])
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }

        return (title: title, abstract: abstract)
    }

    /// Builds the HTML for a tutorial overview page.
    private func buildTutorialOverviewHTML(
        title: String,
        moduleName: String,
        tutorials: [(title: String, abstract: String, path: String)]
    ) -> String {
        var tutorialCards = ""
        for tutorial in tutorials {
            tutorialCards += """

                    <a href="../\(moduleName)/\(escapeHTML(tutorial.path))" class="tutorial-card">
                        <h3 class="tutorial-card-title">\(escapeHTML(tutorial.title))</h3>
                        <p class="tutorial-card-abstract">\(escapeHTML(tutorial.abstract))</p>
                    </a>
            """
        }

        let footerContent = configuration.footerHTML ?? Configuration.defaultFooter

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(title))</title>
            <link rel="stylesheet" href="../../css/main.css">
        </head>
        <body class="tutorial-overview-page">
            <main class="tutorial-overview-main">
                <section class="overview-hero">
                    <div class="overview-hero-content">
                        <h1 class="overview-title">\(escapeHTML(title))</h1>
                        <p>Learn through hands-on tutorials covering all aspects of the framework.</p>
                    </div>
                </section>
                <section class="overview-tutorials">
                    <div class="tutorial-grid">
        \(tutorialCards)
                    </div>
                </section>
            </main>
            <footer class="doc-footer">
                <div class="footer-content">\(footerContent)</div>
                <div class="appearance-selector" id="appearance-selector">
                    <button type="button" class="appearance-btn" data-theme="light" aria-label="Light mode">Light</button>
                    <button type="button" class="appearance-btn" data-theme="dark" aria-label="Dark mode">Dark</button>
                    <button type="button" class="appearance-btn active" data-theme="auto" aria-label="Auto mode">Auto</button>
                </div>
            </footer>
            <script>
            (function() {
                const selector = document.getElementById('appearance-selector');
                if (!selector) return;

                // Show the selector (hidden by default for no-JS fallback)
                selector.style.visibility = 'visible';

                const buttons = selector.querySelectorAll('.appearance-btn');
                const html = document.documentElement;

                // Load saved preference
                const saved = localStorage.getItem('docc-theme') || 'auto';
                applyTheme(saved);
                updateButtons(saved);

                // Add click handlers
                buttons.forEach(btn => {
                    btn.addEventListener('click', () => {
                        const theme = btn.dataset.theme;
                        localStorage.setItem('docc-theme', theme);
                        applyTheme(theme);
                        updateButtons(theme);
                    });
                });

                function applyTheme(theme) {
                    if (theme === 'auto') {
                        html.removeAttribute('data-theme');
                    } else {
                        html.setAttribute('data-theme', theme);
                    }
                }

                function updateButtons(theme) {
                    buttons.forEach(btn => {
                        btn.classList.toggle('active', btn.dataset.theme === theme);
                    });
                }
            })();
            </script>
        </body>
        </html>
        """
    }

    /// Escapes HTML special characters.
    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
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

        // Collect tutorial collections
        var tutorials: [IndexPageBuilder.TutorialEntry] = []
        let tutorialsOverviewDir = configuration.outputDirectory
            .appendingPathComponent("tutorials")
            .appendingPathComponent("tutorials")
        if fileManager.fileExists(atPath: tutorialsOverviewDir.path) {
            // Count tutorials by scanning the tutorials/swiftmodelling/ etc. directories
            let tutorialsRoot = configuration.outputDirectory.appendingPathComponent("tutorials")
            if let tutorialModuleDirs = try? fileManager.contentsOfDirectory(
                at: tutorialsRoot,
                includingPropertiesForKeys: [.isDirectoryKey]
            ) {
                for moduleDir in tutorialModuleDirs {
                    let moduleName = moduleDir.lastPathComponent
                    // Skip the "tutorials" directory itself (that's the overview)
                    guard moduleName != "tutorials" else { continue }
                    var isDir: ObjCBool = false
                    guard fileManager.fileExists(atPath: moduleDir.path, isDirectory: &isDir),
                          isDir.boolValue else { continue }

                    // Count tutorials in this module
                    if let tutorialDirs = try? fileManager.contentsOfDirectory(
                        at: moduleDir,
                        includingPropertiesForKeys: [.isDirectoryKey]
                    ) {
                        let tutorialCount = tutorialDirs.filter { dir in
                            var isDirCheck: ObjCBool = false
                            return fileManager.fileExists(atPath: dir.path, isDirectory: &isDirCheck) && isDirCheck.boolValue
                        }.count

                        if tutorialCount > 0 {
                            // Extract title from overview page
                            let overviewPath = tutorialsOverviewDir.appendingPathComponent("index.html")
                            var title = moduleName.capitalized + " Tutorials"
                            if let html = try? String(contentsOf: overviewPath, encoding: .utf8),
                               let titleStart = html.range(of: "<h1 class=\"overview-title\">"),
                               let titleEnd = html.range(of: "</h1>", range: titleStart.upperBound..<html.endIndex) {
                                title = String(html[titleStart.upperBound..<titleEnd.lowerBound])
                            }

                            tutorials.append(IndexPageBuilder.TutorialEntry(
                                title: title,
                                path: "tutorials/tutorials/index.html",
                                tutorialCount: tutorialCount
                            ))
                        }
                    }
                }
            }
        }

        let html = indexBuilder.buildIndexPage(modules: modules, tutorials: tutorials)
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

    /// Copies images and other assets from a DocC archive to the output directory.
    ///
    /// - Parameter archiveDir: The path to the `.doccarchive` directory.
    private func copyArchiveAssets(from archiveDir: URL) throws {
        let fileManager = FileManager.default

        // Copy images directory if it exists
        let imagesSource = archiveDir.appendingPathComponent("images")
        if fileManager.fileExists(atPath: imagesSource.path) {
            let imagesDestination = configuration.outputDirectory.appendingPathComponent("images")

            // Copy each subdirectory/file, merging with existing content
            if let contents = try? fileManager.contentsOfDirectory(
                at: imagesSource,
                includingPropertiesForKeys: [.isDirectoryKey]
            ) {
                try fileManager.createDirectory(at: imagesDestination, withIntermediateDirectories: true)

                for item in contents {
                    let destItem = imagesDestination.appendingPathComponent(item.lastPathComponent)

                    // If it's a directory, copy recursively
                    var isDirectory: ObjCBool = false
                    if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) {
                        if isDirectory.boolValue {
                            // Create destination directory and copy contents
                            try fileManager.createDirectory(at: destItem, withIntermediateDirectories: true)
                            try copyDirectoryContents(from: item, to: destItem)
                        } else {
                            // Copy file, overwriting if exists
                            if fileManager.fileExists(atPath: destItem.path) {
                                try fileManager.removeItem(at: destItem)
                            }
                            try fileManager.copyItem(at: item, to: destItem)
                        }
                    }
                }

                if configuration.isVerbose {
                    log("Copied images from: \(imagesSource.path)")
                }
            }
        }

        // Copy downloads directory if it exists
        let downloadsSource = archiveDir.appendingPathComponent("downloads")
        if fileManager.fileExists(atPath: downloadsSource.path) {
            let downloadsDestination = configuration.outputDirectory.appendingPathComponent("downloads")
            try fileManager.createDirectory(at: downloadsDestination, withIntermediateDirectories: true)
            try copyDirectoryContents(from: downloadsSource, to: downloadsDestination)

            if configuration.isVerbose {
                log("Copied downloads from: \(downloadsSource.path)")
            }
        }

        // Copy videos directory if it exists
        let videosSource = archiveDir.appendingPathComponent("videos")
        if fileManager.fileExists(atPath: videosSource.path) {
            let videosDestination = configuration.outputDirectory.appendingPathComponent("videos")
            try fileManager.createDirectory(at: videosDestination, withIntermediateDirectories: true)
            try copyDirectoryContents(from: videosSource, to: videosDestination)

            if configuration.isVerbose {
                log("Copied videos from: \(videosSource.path)")
            }
        }
    }

    /// Recursively copies the contents of a directory.
    private func copyDirectoryContents(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return }

        for item in contents {
            let destItem = destination.appendingPathComponent(item.lastPathComponent)

            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    try fileManager.createDirectory(at: destItem, withIntermediateDirectories: true)
                    try copyDirectoryContents(from: item, to: destItem)
                } else {
                    if fileManager.fileExists(atPath: destItem.path) {
                        try fileManager.removeItem(at: destItem)
                    }
                    try fileManager.copyItem(at: item, to: destItem)
                }
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
            display: flex;
            flex-direction: column;
            transition: transform 0.3s ease, width 0.3s ease;
            will-change: transform;
        }

        /* Sidebar collapsed state */
        .sidebar-toggle-checkbox:checked ~ .doc-layout .doc-sidebar {
            transform: translateX(-100%);
        }

        .sidebar-content {
            flex: 1;
            overflow-y: auto;
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

        /* Collapsible group headers with disclosure */
        .nav-group-header.expandable {
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            gap: 0.25rem;
            padding: 0.375rem 0 0.25rem;
        }

        .nav-group-header.expandable .disclosure-checkbox {
            position: absolute;
            opacity: 0;
            pointer-events: none;
        }

        .nav-group-header.expandable > .disclosure-chevron {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 16px;
            height: 16px;
            cursor: pointer;
            flex-shrink: 0;
        }

        .nav-group-header.expandable > .disclosure-chevron svg {
            width: 10px;
            height: 10px;
            transition: transform 0.15s ease;
            transform-origin: center;
        }

        .nav-group-header.expandable > .disclosure-checkbox:checked + .disclosure-chevron svg {
            transform: rotate(90deg);
        }

        .nav-group-header.expandable .group-title,
        .nav-group-header.expandable .nav-link.group-link {
            font-size: 0.75rem;
            font-weight: 600;
            color: var(--docc-fg-secondary);
            text-decoration: none;
        }

        .nav-group-header.expandable .nav-link.group-link:hover {
            color: var(--docc-accent);
        }

        .nav-group-header.expandable .nav-children {
            flex-basis: 100%;
            max-height: 0;
            overflow: hidden;
            opacity: 0;
            transition: max-height 0.2s ease, opacity 0.15s ease;
            padding-left: 0.5rem;
            margin-top: 0.25rem;
        }

        .nav-group-header.expandable .disclosure-checkbox:checked ~ .nav-children {
            max-height: 2000px;
            opacity: 1;
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

        /* Filter with shortcut indicator - hidden by default, shown via JS */
        .sidebar-filter {
            display: none;  /* JS sets to flex when available */
            align-items: center;
            gap: 0.5rem;
            padding: 0.75rem 1rem;
            border-top: 1px solid var(--docc-border);
            background: var(--docc-bg);
            flex-shrink: 0;
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

        .filter-input:focus {
            outline: none;
            border-color: var(--docc-accent);
            box-shadow: 0 0 0 3px rgba(0, 102, 204, 0.15);
        }

        /* Filter hidden state for navigation items */
        .filter-hidden {
            display: none !important;
        }

        /* Highlight matching items during filter */
        .filter-match > a,
        .filter-match > .nav-link {
            background: rgba(0, 102, 204, 0.1);
            border-radius: 4px;
        }

        /* Search results sections in sidebar */
        .search-results-sections {
            margin-bottom: 1rem;
            padding-bottom: 1rem;
            border-bottom: 1px solid var(--docc-border);
        }

        .search-result-section {
            margin-bottom: 0.75rem;
        }

        .search-result-heading {
            font-size: 0.75rem;
            font-weight: 600;
            color: var(--docc-fg-secondary);
            text-transform: uppercase;
            letter-spacing: 0.05em;
            margin: 0 0 0.5rem 0;
            padding: 0.5rem 0.75rem 0;
        }

        .search-result-subheading {
            font-size: 0.6875rem;
            font-weight: 600;
            color: var(--docc-fg-secondary);
            text-transform: uppercase;
            letter-spacing: 0.04em;
            margin: 0.5rem 0 0.25rem 0;
            padding: 0 0.75rem;
        }

        .search-result-list {
            list-style: none;
            margin: 0;
            padding: 0;
        }

        .search-result-item {
            padding: 0.375rem 0.75rem;
            border-radius: 4px;
            margin-bottom: 2px;
        }

        .search-result-item:hover {
            background: var(--docc-bg-secondary);
        }

        .search-result-link {
            display: block;
            color: var(--docc-fg);
            text-decoration: none;
            font-size: 0.875rem;
        }

        .search-result-link:hover {
            color: var(--docc-accent);
        }

        .search-result-title {
            display: block;
            font-weight: 500;
        }

        .search-result-summary {
            margin: 0.25rem 0 0 0;
            font-size: 0.75rem;
            color: var(--docc-fg-secondary);
            line-height: 1.4;
            overflow: hidden;
            text-overflow: ellipsis;
            display: -webkit-box;
            -webkit-line-clamp: 2;
            -webkit-box-orient: vertical;
        }

        /* Footer - accounts for fixed sidebar */
        .doc-footer {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 1rem 1.5rem;
            margin-left: var(--sidebar-width);
            border-top: 1px solid var(--docc-border);
            background: var(--docc-bg);
            font-size: 0.8125rem;
            color: var(--docc-fg-secondary);
            transition: margin-left 0.3s ease;
        }

        /* Footer expands when sidebar is collapsed */
        .sidebar-toggle-checkbox:checked ~ .doc-footer {
            margin-left: 0;
        }

        .footer-content {
            flex: 1;
        }

        .footer-content a {
            color: var(--docc-accent);
        }

        /* Appearance selector */
        .appearance-selector {
            display: inline-flex;
            border: 1px solid var(--docc-accent);
            border-radius: 6px;
            overflow: hidden;
        }

        .appearance-btn {
            padding: 0.25rem 0.75rem;
            font-size: 0.75rem;
            font-weight: 500;
            border: none;
            background: transparent;
            color: var(--docc-accent);
            cursor: pointer;
            transition: background-color 0.15s ease, color 0.15s ease;
        }

        .appearance-btn:not(:last-child) {
            border-right: 1px solid var(--docc-accent);
        }

        .appearance-btn:hover {
            background: rgba(0, 102, 204, 0.1);
        }

        .appearance-btn.active {
            background: var(--docc-accent);
            color: white;
        }

        /* Hide appearance selector until JS runs (shows noscript fallback) */
        .appearance-selector {
            visibility: hidden;
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

        /* Tutorials section on index page */
        .tutorials-section {
            margin-top: 2.5rem;
            padding-top: 2rem;
            border-top: 1px solid var(--docc-border);
        }

        .tutorials-section h2 {
            font-size: 1.5rem;
            margin-bottom: 1.5rem;
            border-bottom: none;
            padding-bottom: 0;
        }

        .tutorial-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 1rem;
        }

        .tutorial-collection-card {
            padding: 1.25rem;
            border: 1px solid var(--docc-border);
            border-radius: 12px;
            background: var(--docc-bg);
            transition: box-shadow 0.2s, border-color 0.2s;
        }

        .tutorial-collection-card:hover {
            border-color: var(--docc-accent);
            box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
        }

        .tutorial-collection-name {
            font-size: 1.0625rem;
            font-weight: 600;
            display: block;
            margin-bottom: 0.5rem;
        }

        .tutorial-collection-stats {
            color: var(--docc-fg-secondary);
            font-size: 0.8rem;
        }

        /* ========================================
           Tutorial Page Styles
           Based on swift-docc-render structure
           ======================================== */

        /* Tutorial pages have no sidebar */
        body.tutorial-page {
            --sidebar-width: 0px;
        }

        body.tutorial-page .doc-sidebar {
            display: none;
        }

        body.tutorial-page .doc-main {
            margin-left: 0;
            max-width: 100%;
            padding: 0;
        }

        body.tutorial-page .doc-footer,
        body.tutorial-overview-page .doc-footer,
        body.index-page .doc-footer {
            margin-left: 0;
        }

        body.tutorial-page .doc-layout {
            padding-top: var(--header-height);
        }

        /* Tutorial Navigation Bar */
        .tutorial-nav {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            height: var(--header-height);
            background: var(--docc-bg);
            border-bottom: 1px solid var(--docc-border);
            z-index: 100;
            display: flex;
            align-items: center;
        }

        .tutorial-nav-content {
            display: flex;
            align-items: center;
            width: 100%;
            padding: 0 1.5rem;
            gap: 1rem;
        }

        .tutorial-nav-title {
            font-size: 0.9375rem;
            font-weight: 600;
            color: var(--docc-fg);
            text-decoration: none;
            white-space: nowrap;
        }

        .tutorial-nav-title:hover {
            color: var(--docc-accent);
            text-decoration: none;
        }

        .nav-separator {
            color: var(--docc-fg-secondary);
            font-size: 0.875rem;
        }

        .tutorial-nav-dropdowns {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            margin-left: auto;
        }

        /* Tutorial dropdowns - pure CSS using details/summary */
        details.tutorial-dropdown {
            position: relative;
        }

        /* Hide the default disclosure triangle */
        details.tutorial-dropdown > summary {
            list-style: none;
        }
        details.tutorial-dropdown > summary::-webkit-details-marker {
            display: none;
        }
        details.tutorial-dropdown > summary::marker {
            display: none;
        }

        .tutorial-dropdown-toggle {
            background: var(--docc-bg);
            border: 1px solid var(--docc-border);
            border-radius: 6px;
            padding: 0.5rem 0.75rem;
            font-size: 0.8125rem;
            font-weight: 500;
            color: var(--docc-fg);
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 0.5rem;
            min-width: 180px;
            max-width: 280px;
        }

        .tutorial-dropdown-toggle:hover {
            background: var(--docc-bg-secondary);
        }

        .dropdown-label {
            flex: 1;
            text-align: left;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }

        .dropdown-chevron {
            flex-shrink: 0;
            transition: transform 0.2s ease;
        }

        details.tutorial-dropdown[open] .dropdown-chevron {
            transform: rotate(180deg);
        }

        .tutorial-dropdown-menu {
            position: absolute;
            top: calc(100% + 4px);
            left: 0;
            min-width: 100%;
            max-width: 320px;
            background: var(--docc-bg);
            border: 1px solid var(--docc-border);
            border-radius: 8px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15);
            padding: 0.5rem 0;
            z-index: 200;
            max-height: 400px;
            overflow-y: auto;
        }

        .dropdown-item {
            display: block;
            padding: 0.625rem 1rem;
            font-size: 0.8125rem;
            color: var(--docc-fg);
            text-decoration: none;
        }

        .dropdown-item:hover {
            background: var(--docc-bg-secondary);
            text-decoration: none;
        }

        .dropdown-item.selected {
            font-weight: 600;
            color: var(--docc-accent);
        }

        /* Dropdown chapter grouping */
        .dropdown-chapter {
            padding: 0.25rem 0;
        }

        .dropdown-chapter:not(:first-child) {
            border-top: 1px solid var(--docc-border);
            margin-top: 0.5rem;
            padding-top: 0.75rem;
        }

        .dropdown-chapter-title {
            display: block;
            padding: 0.375rem 1rem;
            font-size: 0.6875rem;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--docc-fg-secondary);
        }

        .dropdown-chapter .dropdown-item {
            padding-left: 1.25rem;
        }

        /* ========================================
           Tutorial Hero Section
           Large dark section with left-aligned content
           ======================================== */
        .tutorial-hero {
            background: #1d1d1f;
            color: #ffffff;
            min-height: 420px;
            padding: 3rem 2rem;
            position: relative;
            display: flex;
            align-items: center;
        }

        .tutorial-hero-content {
            position: relative;
            z-index: 2;
            max-width: 600px;
            padding-left: 2rem;
        }

        .tutorial-chapter {
            font-size: 1.0625rem;
            font-weight: 400;
            color: rgba(255, 255, 255, 0.9);
            margin: 0 0 0.5rem 0;
            padding-top: 0.5rem;
        }

        .tutorial-hero h1,
        .tutorial-hero .tutorial-title {
            font-size: 2.5rem;
            font-weight: 700;
            line-height: 1.1;
            margin: 0 0 1.25rem 0;
            color: #ffffff;
        }

        .tutorial-hero .tutorial-abstract {
            font-size: 1.0625rem;
            line-height: 1.5;
            color: rgba(255, 255, 255, 0.85);
            margin-bottom: 2rem;
        }

        .tutorial-hero .tutorial-time {
            display: flex;
            flex-direction: column;
            gap: 0.125rem;
        }

        .tutorial-hero .time-value {
            font-size: 1.5rem;
            font-weight: 600;
        }

        .tutorial-hero .time-label {
            font-size: 0.8125rem;
            color: rgba(255, 255, 255, 0.7);
        }

        .tutorial-hero-background {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            z-index: 1;
            overflow: hidden;
        }

        .tutorial-hero-background picture {
            display: block;
            width: 100%;
            height: 100%;
        }

        .tutorial-hero-background img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            object-position: right center;
            opacity: 0.5;
        }

        /* ========================================
           Tutorial Intro Section
           ======================================== */
        .tutorial-intro-section {
            padding: 3rem 4rem;
            max-width: 900px;
        }

        .tutorial-intro-section p {
            font-size: 1.0625rem;
            line-height: 1.6;
            margin-bottom: 1rem;
        }

        .intro-media {
            margin-top: 2rem;
        }

        .intro-media img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
        }

        /* ========================================
           Tutorial Section with Steps
           Two-column layout: steps left, sticky asset right
           ======================================== */
        .tutorial-section {
            border-top: 1px solid var(--docc-border);
            padding: 0;
        }

        .section-header {
            padding: 3rem 4rem 2rem;
            max-width: 900px;
        }

        .section-number {
            font-size: 0.9375rem;
            font-weight: 400;
            color: var(--docc-fg-secondary);
            margin-bottom: 0.5rem;
        }

        .section-title {
            font-size: 1.75rem;
            font-weight: 600;
            margin: 0;
            border-bottom: none;
            padding-bottom: 0;
        }

        /* Section intro content row */
        .section-content-row {
            display: flex;
            gap: 3rem;
            padding: 0 4rem 2rem;
            align-items: flex-start;
        }

        .section-text {
            flex: 0 0 auto;
            width: 40%;
            min-width: 300px;
            max-width: 450px;
        }

        .section-text p {
            font-size: 1rem;
            line-height: 1.6;
        }

        .section-media {
            flex: 1 1 auto;
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 12px;
            min-height: 250px;
        }

        .section-media picture {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 100%;
            height: 100%;
        }

        .section-media img {
            width: 100%;
            height: auto;
            max-height: 400px;
            object-fit: contain;
        }

        /* ========================================
           Steps Layout (Two-Column with Sticky Asset)
           ======================================== */
        .tutorial-steps-wrapper {
            display: flex;
            position: relative;
        }

        .steps-content {
            flex: 0 0 45%;
            max-width: 500px;
            padding: 0 2rem 0 4rem;
        }

        .steps-asset-container {
            flex: 1;
            position: sticky;
            top: calc(var(--header-height) + 1rem);
            height: calc(100vh - var(--header-height) - 2rem);
            display: flex;
            align-items: flex-start;
            justify-content: center;
            padding: 0 2rem;
        }

        /* Individual Step */
        .tutorial-step {
            padding: 1.5rem 0;
            border-left: 3px solid transparent;
            padding-left: 1.5rem;
            margin-left: -1.5rem;
        }

        .tutorial-step.active {
            border-left-color: var(--docc-accent);
        }

        .step-label {
            font-size: 0.875rem;
            font-weight: 600;
            color: var(--docc-accent);
            margin-bottom: 0.75rem;
        }

        .step-content {
            font-size: 1rem;
            line-height: 1.6;
        }

        .step-content p {
            margin: 0 0 1rem 0;
        }

        .step-content p:last-child {
            margin-bottom: 0;
        }

        .step-caption {
            margin-top: 1.25rem;
            padding-top: 1.25rem;
            border-top: 1px solid var(--docc-border);
            font-size: 0.9375rem;
            color: var(--docc-fg-secondary);
        }

        /* ========================================
           Code Preview Panel (Right Side)
           ======================================== */
        .code-preview {
            background: #1d1d1f;
            border-radius: 12px;
            overflow: hidden;
            width: 100%;
            max-width: 600px;
            display: flex;
            flex-direction: column;
            max-height: calc(100vh - var(--header-height) - 4rem);
        }

        .code-preview-header {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.875rem 1rem;
            background: #2d2d2f;
            border-bottom: 1px solid #3d3d3f;
        }

        .file-icon {
            color: #8e8e93;
        }

        .file-icon svg {
            width: 16px;
            height: 16px;
            display: block;
        }

        .file-name {
            font-family: var(--typeface-mono);
            font-size: 0.8125rem;
            font-weight: 500;
            color: #ffffff;
        }

        .code-preview-content {
            flex: 1;
            overflow: auto;
            padding: 1rem 0;
        }

        .code-preview-content pre {
            margin: 0;
            padding: 0;
            background: transparent;
            font-size: 0.8125rem;
            line-height: 1.7;
        }

        .code-preview-content code {
            display: block;
            background: transparent;
            padding: 0;
            color: #ffffff;
        }

        .code-line {
            display: flex;
            padding: 0 1rem;
        }

        .code-line:hover {
            background: rgba(255, 255, 255, 0.05);
        }

        .line-number {
            flex-shrink: 0;
            width: 3rem;
            text-align: right;
            padding-right: 1rem;
            color: #5d5d5f;
            user-select: none;
        }

        .line-content {
            flex: 1;
            white-space: pre;
        }

        /* Code syntax highlighting for dark theme */
        .code-preview .syntax-keyword { color: #ff7ab2; }
        .code-preview .syntax-type { color: #dabaff; }
        .code-preview .syntax-string { color: #ff8170; }
        .code-preview .syntax-number { color: #d9c97c; }
        .code-preview .syntax-comment { color: #7f8c8d; }

        /* ========================================
           Media Preview Panel
           ======================================== */
        .media-preview {
            background: var(--docc-bg-secondary);
            border-radius: 12px;
            overflow: hidden;
            width: 100%;
            max-width: 600px;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 2rem;
        }

        .media-preview img,
        .media-preview video {
            max-width: 100%;
            max-height: calc(100vh - var(--header-height) - 8rem);
            height: auto;
            border-radius: 8px;
        }

        /* ========================================
           Fallback: Simple Step Row Layout
           Used when steps don't have associated media
           ======================================== */
        .tutorial-steps-container {
            padding: 0 4rem 2rem;
        }

        .tutorial-step-row {
            display: flex;
            gap: 3rem;
            margin-bottom: 2rem;
            align-items: flex-start;
        }

        .step-card {
            flex: 0 0 auto;
            width: 40%;
            min-width: 300px;
            max-width: 450px;
        }

        .step-code-panel {
            flex: 1;
            background: var(--docc-bg-secondary);
            border-radius: 12px;
            overflow: hidden;
            max-height: 500px;
            display: flex;
            flex-direction: column;
            border: 1px solid var(--docc-border);
        }

        .code-panel-header {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.875rem 1rem;
            background: var(--docc-bg);
            border-bottom: 1px solid var(--docc-border);
        }

        .code-panel-header .file-icon {
            color: var(--docc-fg-secondary);
        }

        .code-panel-header .file-name {
            font-family: var(--typeface-mono);
            font-size: 0.8125rem;
            font-weight: 500;
            color: var(--docc-fg);
        }

        .code-panel-content {
            flex: 1;
            overflow: auto;
            padding: 1rem 0;
        }

        .code-panel-content pre {
            margin: 0;
            padding: 0;
            background: transparent;
            font-size: 0.8125rem;
            line-height: 1.4;
        }

        .code-panel-content code {
            display: block;
            background: transparent;
            padding: 0;
            color: var(--docc-fg);
        }

        .code-panel-content .line {
            display: flex;
            padding: 0 1rem;
            margin: 0;
            line-height: 1.4;
        }

        .code-panel-content .line:hover {
            background: var(--docc-bg);
        }

        .code-panel-content .line-number {
            flex-shrink: 0;
            width: 3rem;
            text-align: right;
            padding-right: 1rem;
            color: var(--docc-fg-secondary);
            user-select: none;
        }

        .code-panel-content .line-content {
            flex: 1;
            white-space: pre;
        }

        /* Step media panel */
        .step-media-panel {
            flex: 1;
            background: var(--docc-bg-secondary);
            border-radius: 12px;
            overflow: hidden;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 2rem;
            max-height: 500px;
        }

        .step-media-panel img {
            max-width: 100%;
            max-height: 100%;
            height: auto;
            object-fit: contain;
        }

        /* ========================================
           Tutorial Assessments
           ======================================== */
        .tutorial-assessments {
            padding: 3rem 4rem;
            max-width: 900px;
        }

        .tutorial-assessments h3 {
            font-size: 1.5rem;
            margin: 0 0 2rem 0;
        }

        .assessment {
            background: var(--docc-bg-secondary);
            border-radius: 12px;
            padding: 2rem;
            margin-bottom: 1.5rem;
        }

        .question-number {
            font-size: 0.875rem;
            color: var(--docc-fg-secondary);
            margin-bottom: 1rem;
        }

        .question {
            font-size: 1.0625rem;
            margin-bottom: 1.5rem;
        }

        .choices {
            border: none;
            padding: 0;
            margin: 0;
        }

        .choice {
            display: flex;
            align-items: flex-start;
            padding: 1rem 1rem 1rem 3rem;
            border: 2px solid var(--docc-border);
            border-radius: 8px;
            margin-bottom: 0.75rem;
            cursor: pointer;
            transition: border-color 0.15s ease, background-color 0.15s ease;
            position: relative;
        }

        .choice:hover {
            border-color: var(--docc-accent);
            background: rgba(0, 102, 204, 0.05);
        }

        /* Hide the radio input but keep it accessible */
        .choice-input {
            position: absolute;
            opacity: 0;
            width: 100%;
            height: 100%;
            left: 0;
            top: 0;
            cursor: pointer;
            margin: 0;
            z-index: 1;
        }

        /* Choice indicator (circle/checkmark area) */
        .choice-indicator {
            position: absolute;
            left: 1rem;
            top: 1.25rem;
            width: 18px;
            height: 18px;
            border: 2px solid var(--docc-border);
            border-radius: 50%;
            background: var(--docc-bg);
            transition: all 0.15s ease;
        }

        .choice-indicator::after {
            content: '';
            position: absolute;
            display: none;
        }

        .choice-content {
            flex: 1;
        }

        .choice-content p {
            margin: 0;
        }

        /* Hide justification by default */
        .choice-justification {
            display: none;
            margin-top: 0.75rem;
            padding-top: 0.75rem;
            border-top: 1px solid currentColor;
            opacity: 0.9;
            font-size: 0.9rem;
        }

        /* Correct answer styling when selected */
        .choice.correct-answer:has(.choice-input:checked) {
            border-color: #34c759;
            background: rgba(52, 199, 89, 0.1);
        }

        .choice.correct-answer:has(.choice-input:checked) .choice-indicator {
            border-color: #34c759;
            background: #34c759;
        }

        .choice.correct-answer:has(.choice-input:checked) .choice-indicator::after {
            display: block;
            left: 5px;
            top: 2px;
            width: 4px;
            height: 8px;
            border: solid white;
            border-width: 0 2px 2px 0;
            transform: rotate(45deg);
        }

        .choice.correct-answer:has(.choice-input:checked) .choice-justification {
            display: block;
            border-color: rgba(52, 199, 89, 0.3);
        }

        /* Incorrect answer styling when selected */
        .choice.incorrect-answer:has(.choice-input:checked) {
            border-color: #ff3b30;
            background: rgba(255, 59, 48, 0.1);
        }

        .choice.incorrect-answer:has(.choice-input:checked) .choice-indicator {
            border-color: #ff3b30;
            background: #ff3b30;
        }

        .choice.incorrect-answer:has(.choice-input:checked) .choice-indicator::after {
            display: block;
            left: 3px;
            top: 3px;
            width: 8px;
            height: 8px;
            background: white;
            clip-path: polygon(20% 0%, 0% 20%, 30% 50%, 0% 80%, 20% 100%, 50% 70%, 80% 100%, 100% 80%, 70% 50%, 100% 20%, 80% 0%, 50% 30%);
        }

        .choice.incorrect-answer:has(.choice-input:checked) .choice-justification {
            display: block;
            border-color: rgba(255, 59, 48, 0.3);
        }

        /* Disable pointer events on other choices once one is selected */
        .choices:has(.choice-input:checked) .choice:not(:has(.choice-input:checked)) {
            pointer-events: none;
            opacity: 0.6;
        }

        /* ========================================
           Tutorial Call-to-Action (Next Tutorial)
           ======================================== */
        .tutorial-cta {
            padding: 3rem 4rem 4rem;
            border-top: 1px solid var(--docc-border);
            max-width: 900px;
        }

        .tutorial-cta h3 {
            font-size: 1.5rem;
            font-weight: 600;
            margin: 0 0 0.75rem 0;
        }

        .tutorial-cta .cta-abstract {
            font-size: 1rem;
            line-height: 1.5;
            color: var(--docc-fg-secondary);
            margin: 0 0 1.5rem 0;
        }

        .tutorial-cta .cta-action a {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            font-size: 1rem;
            font-weight: 500;
            color: var(--docc-accent);
            text-decoration: none;
        }

        .tutorial-cta .cta-action a:hover {
            text-decoration: underline;
        }

        .tutorial-cta .cta-action a::after {
            content: '→';
        }

        /* ========================================
           Tutorial Overview Page
           ======================================== */
        .tutorial-overview-page {
            background: var(--docc-bg);
            color: var(--docc-fg);
            min-height: 100vh;
        }

        .tutorial-overview-main {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 2rem;
        }

        .overview-hero {
            text-align: center;
            padding: 4rem 2rem;
            border-bottom: 1px solid var(--docc-border);
        }

        .overview-hero-content {
            max-width: 800px;
            margin: 0 auto;
        }

        .overview-title {
            font-size: 2.5rem;
            font-weight: 700;
            margin: 0 0 1.5rem 0;
            color: var(--docc-fg);
        }

        .overview-hero p {
            font-size: 1.125rem;
            line-height: 1.6;
            color: var(--docc-fg-secondary);
            margin-bottom: 1rem;
        }

        .overview-volume {
            padding: 3rem 0;
        }

        .overview-chapter {
            margin-bottom: 3rem;
        }

        .chapter-title {
            font-size: 1.5rem;
            font-weight: 600;
            margin: 0 0 1rem 0;
            padding-bottom: 0.5rem;
            border-bottom: 2px solid var(--docc-accent);
        }

        .chapter-description {
            color: var(--docc-fg-secondary);
            margin-bottom: 1.5rem;
        }

        .chapter-tutorials,
        .tutorial-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 1.5rem;
        }

        .overview-tutorials {
            padding: 3rem 4rem;
            max-width: 1200px;
            margin: 0 auto;
        }

        .tutorial-card {
            display: flex;
            flex-direction: column;
            padding: 1.5rem;
            background: var(--docc-bg-secondary);
            border-radius: 12px;
            text-decoration: none;
            transition: transform 0.15s ease, box-shadow 0.15s ease;
        }

        .tutorial-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
        }

        .tutorial-card-title {
            font-size: 1.0625rem;
            font-weight: 600;
            color: var(--docc-fg);
            margin-bottom: 0.5rem;
        }

        .tutorial-card-abstract {
            font-size: 0.875rem;
            color: var(--docc-fg-secondary);
            line-height: 1.5;
        }

        /* ========================================
           Responsive Adjustments
           ======================================== */
        @media (max-width: 1024px) {
            .tutorial-hero-content {
                max-width: 500px;
            }

            .tutorial-hero-background {
                opacity: 0.3;
            }

            .section-content-row {
                flex-direction: column;
                padding: 0 2rem 2rem;
            }

            .section-text {
                flex: none;
                min-width: auto;
                max-width: none;
                margin-bottom: 2rem;
            }

            .section-media {
                width: 100%;
            }

            .tutorial-steps-wrapper {
                flex-direction: column;
            }

            .steps-content {
                flex: none;
                max-width: none;
                padding: 0 2rem;
            }

            .steps-asset-container {
                position: relative;
                top: auto;
                height: auto;
                padding: 2rem;
            }

            .tutorial-step-row {
                flex-direction: column;
            }

            .step-card {
                flex: none;
                max-width: none;
            }

            .step-code-panel,
            .step-media-panel {
                max-height: 400px;
            }
        }

        @media (max-width: 768px) {
            .tutorial-nav-content {
                padding: 0 1rem;
            }

            .tutorial-nav-title {
                font-size: 0.8125rem;
            }

            .tutorial-dropdown-toggle {
                min-width: 120px;
                padding: 0.375rem 0.5rem;
                font-size: 0.75rem;
            }

            .tutorial-hero {
                min-height: 320px;
                padding: 2rem 1rem;
            }

            .tutorial-hero-content {
                padding-left: 1rem;
                max-width: 100%;
            }

            .tutorial-hero h1,
            .tutorial-hero .tutorial-title {
                font-size: 1.75rem;
            }

            .tutorial-hero-background {
                display: none;
            }

            .tutorial-intro-section,
            .section-header,
            .tutorial-steps-container,
            .tutorial-assessments,
            .tutorial-cta {
                padding-left: 1.5rem;
                padding-right: 1.5rem;
            }
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

        /* Explicit theme selection via data-theme attribute */
        html[data-theme="light"] {
            --docc-bg: #ffffff;
            --docc-bg-secondary: #f5f5f7;
            --docc-fg: #1d1d1f;
            --docc-fg-secondary: #6e6e73;
            --docc-border: #d2d2d7;
            --swift-keyword: #ad3da4;
            --swift-type: #703daa;
            --swift-literal: #d12f1b;
            --swift-comment: #707f8c;
            --swift-string: #d12f1b;
            --swift-number: #272ad8;
            --badge-bg: #f5f5f7;
            --badge-fg: #6e6e73;
            --badge-border: #d2d2d7;
            --hero-decoration: #d2d2d7;
        }

        html[data-theme="dark"] {
            --docc-bg: #1d1d1f;
            --docc-bg-secondary: #2c2c2e;
            --docc-fg: #f5f5f7;
            --docc-fg-secondary: #a1a1a6;
            --docc-border: #424245;
            --swift-keyword: #ff7ab2;
            --swift-type: #dabaff;
            --swift-literal: #ff8170;
            --swift-comment: #7f8c8d;
            --swift-string: #ff8170;
            --swift-number: #d9c97c;
            --badge-bg: #2c2c2e;
            --badge-fg: #a1a1a6;
            --badge-border: #424245;
            --hero-decoration: #4a4a4a;
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

            // Get sidebar elements
            const filterInput = document.querySelector('.filter-input');
            const sidebarContent = document.querySelector('.sidebar-content');

            // Search state
            let searchIndex = null;
            let searchData = null;
            let searchResultsContainer = null;
            let originalExpandedStates = new Map();

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

                    // Build the Lunr.js index with content field
                    searchIndex = lunr(function() {
                        this.ref('id');
                        this.field('title', { boost: 10 });
                        this.field('summary', { boost: 5 });
                        this.field('keywords', { boost: 3 });
                        this.field('content', { boost: 1 });
                        this.field('module', { boost: 2 });

                        data.documents.forEach(doc => {
                            this.add({
                                id: doc.id,
                                title: doc.title,
                                summary: doc.summary,
                                keywords: doc.keywords.join(' '),
                                content: doc.content || '',
                                module: doc.module || ''
                            });
                        });
                    });

                    console.log('Search index loaded with ' + data.documents.length + ' documents');
                } catch (error) {
                    console.warn('Search not available:', error.message);
                }
            }

            // Save the current expanded states of disclosure checkboxes
            function saveExpandedStates() {
                if (originalExpandedStates.size > 0) return; // Already saved
                const checkboxes = document.querySelectorAll('.disclosure-checkbox');
                checkboxes.forEach(cb => {
                    originalExpandedStates.set(cb.id, cb.checked);
                });
            }

            // Restore the original expanded states
            function restoreExpandedStates() {
                originalExpandedStates.forEach((wasChecked, id) => {
                    const cb = document.getElementById(id);
                    if (cb) cb.checked = wasChecked;
                });
                originalExpandedStates.clear();
            }

            // Filter navigation items based on query (title-only filtering)
            function filterNavigation(query) {
                if (!sidebarContent) return;

                const normalizedQuery = query.toLowerCase().trim();

                // Get all navigation items
                const allItems = sidebarContent.querySelectorAll('.sidebar-item, .nav-child-item');

                if (!normalizedQuery) {
                    // No query - show everything and restore original states
                    allItems.forEach(item => {
                        item.classList.remove('filter-hidden', 'filter-match');
                    });
                    restoreExpandedStates();
                    return;
                }

                // Save current states before filtering
                saveExpandedStates();

                // First pass: mark items that match directly
                const matchingItems = new Set();
                allItems.forEach(item => {
                    const link = item.querySelector('a, .nav-link');
                    const text = link ? link.textContent.toLowerCase() : '';
                    if (text.includes(normalizedQuery)) {
                        matchingItems.add(item);
                        item.classList.add('filter-match');
                        item.classList.remove('filter-hidden');
                    } else {
                        item.classList.remove('filter-match');
                    }
                });

                // Second pass: show parents of matching items and expand them
                allItems.forEach(item => {
                    if (matchingItems.has(item)) {
                        // Show all ancestors
                        let parent = item.parentElement;
                        while (parent && parent !== sidebarContent) {
                            // Show parent list items
                            if (parent.classList.contains('sidebar-item') || parent.classList.contains('nav-child-item')) {
                                parent.classList.remove('filter-hidden');
                                matchingItems.add(parent);
                            }
                            // Expand disclosure checkboxes in the path
                            const checkbox = parent.querySelector(':scope > .disclosure-checkbox');
                            if (checkbox) {
                                checkbox.checked = true;
                            }
                            parent = parent.parentElement;
                        }
                    }
                });

                // Third pass: hide non-matching items that aren't parents of matches
                allItems.forEach(item => {
                    if (!matchingItems.has(item)) {
                        item.classList.add('filter-hidden');
                    }
                });
            }

            // Search content using Lunr.js and display results
            function searchContent(query) {
                removeSearchResults();

                if (!searchIndex || !query.trim()) {
                    return;
                }

                let results;
                try {
                    results = searchIndex.search(query + '*');
                } catch (e) {
                    try {
                        results = searchIndex.search(query);
                    } catch (e2) {
                        return;
                    }
                }

                if (results.length === 0) {
                    return;
                }

                // Filter and group results by type
                const grouped = {
                    tutorial: [],
                    article: [],
                    symbol: []
                };

                results.forEach(result => {
                    const doc = searchData[result.ref];
                    if (doc) {
                        // Skip overview/index pages that aren't real content
                        if (doc.title === 'Tutorials' && doc.type === 'article') return;
                        if (doc.type === 'section') return;

                        const type = doc.type || 'symbol';
                        if (grouped[type]) {
                            grouped[type].push(doc);
                        }
                    }
                });

                displaySearchResults(grouped);
            }

            // Display grouped search results in the sidebar
            function displaySearchResults(grouped) {
                if (!sidebarContent) return;

                const basePath = getBasePath();

                // Check if we have any results to show
                const hasResults = Object.values(grouped).some(arr => arr.length > 0);
                if (!hasResults) return;

                searchResultsContainer = document.createElement('div');
                searchResultsContainer.className = 'search-results-sections';

                const headerDiv = document.createElement('div');
                headerDiv.className = 'search-results-header';
                headerDiv.innerHTML = '<h3 class="search-result-heading">Content Matches</h3>';
                searchResultsContainer.appendChild(headerDiv);

                const typeLabels = {
                    tutorial: 'Tutorials',
                    article: 'Articles',
                    symbol: 'API'
                };

                const typeOrder = ['tutorial', 'article', 'symbol'];

                typeOrder.forEach(type => {
                    const docs = grouped[type];
                    if (docs && docs.length > 0) {
                        const section = document.createElement('div');
                        section.className = 'search-result-section';

                        const heading = document.createElement('h4');
                        heading.className = 'search-result-subheading';
                        heading.textContent = typeLabels[type] || type;
                        section.appendChild(heading);

                        const list = document.createElement('ul');
                        list.className = 'search-result-list';

                        docs.slice(0, 5).forEach(doc => {
                            const item = document.createElement('li');
                            item.className = 'search-result-item';

                            const link = document.createElement('a');
                            link.href = basePath + doc.path;
                            link.className = 'search-result-link';
                            link.textContent = doc.title;

                            item.appendChild(link);
                            list.appendChild(item);
                        });

                        section.appendChild(list);
                        searchResultsContainer.appendChild(section);
                    }
                });

                // Insert after existing navigation sections
                sidebarContent.appendChild(searchResultsContainer);
            }

            // Remove search results sections
            function removeSearchResults() {
                if (searchResultsContainer) {
                    searchResultsContainer.remove();
                    searchResultsContainer = null;
                }
            }

            // Combined filter and search
            function performFilterAndSearch(query) {
                filterNavigation(query);
                searchContent(query);
            }

            // Event listeners for filter input
            if (filterInput) {
                let debounceTimer;
                filterInput.addEventListener('input', (e) => {
                    clearTimeout(debounceTimer);
                    debounceTimer = setTimeout(() => {
                        performFilterAndSearch(e.target.value);
                    }, 150);
                });

                filterInput.addEventListener('keydown', (e) => {
                    if (e.key === 'Escape') {
                        filterInput.value = '';
                        performFilterAndSearch('');
                        filterInput.blur();
                    }
                });

                // Keyboard shortcut: "/" to focus filter
                document.addEventListener('keydown', (e) => {
                    if (e.key === '/' && document.activeElement !== filterInput) {
                        e.preventDefault();
                        filterInput.focus();
                    }
                });
            }

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
