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
            return
                "Could not find the docc executable. Ensure Xcode or the Swift toolchain is installed."
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
/// ## Usage
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
/// ├── sidebar.html            # Navigation tree shared by all documentation pages
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

        // Discover package targets for dependency filtering (preserving order from Package.swift)
        // When using pre-generated symbol graphs, include all modules since the plugin
        // already filtered what to generate symbol graphs for
        let packageTargets: [String]
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

        // First pass: Load all navigation indices and merge them
        var mergedNavigationIndex = try loadAndMergeNavigationIndices(from: archives)

        // Filter to only include package targets (not dependencies)
        if !packageTargets.isEmpty, let merged = mergedNavigationIndex {
            mergedNavigationIndex = filterNavigationIndex(merged, packageTargets: packageTargets)
        }

        consumer.navigationIndex = mergedNavigationIndex

        if configuration.isVerbose {
            let moduleCount = mergedNavigationIndex?.allModules().count ?? 0
            log("Merged navigation index with \(moduleCount) modules")
        }

        // Second pass: Render pages from all archives using the merged index
        var deprecatedPagePaths: Set<String> = []
        for archiveDir in archives {
            deprecatedPagePaths.formUnion(try await renderFromArchive(
                archiveDir,
                consumer: consumer,
                searchIndexBuilder: &searchIndexBuilder,
                packageTargets: packageTargets
            ))
            // Copy images and other assets from this archive
            try copyArchiveAssets(from: archiveDir)
        }

        // Write the navigation tree once; pages embed it rather than repeating it
        try writeSidebarDocument(for: mergedNavigationIndex, deprecatedPagePaths: deprecatedPagePaths)

        // Write assets
        try writeAssets()

        // Generate tutorial overview pages (landing pages for tutorials)
        try generateTutorialOverviewPages()

        // Generate combined index page
        try generateIndexPage(consumer: consumer)

        // Post-process HTML files to resolve doc:// links
        try await postProcessDocLinks(navigationIndex: mergedNavigationIndex)

        // Write search index if enabled
        if configuration.includeSearch, let builder = searchIndexBuilder {
            try writeSearchIndex(builder)
        }

        return consumer.result()
    }

    // MARK: - Package Target Discovery

    /// Returns the target names defined in the current package, in the order they appear in Package.swift.
    ///
    /// This distinguishes between the package's own targets and external dependencies.
    /// The order is preserved to maintain consistent ordering in the documentation.
    private func getPackageTargets() async throws -> [String] {
        // Use dump-package instead of describe to get Package.swift order
        var arguments = ["package", "--package-path", configuration.packageDirectory.path]
        if let scratchPath = configuration.scratchPath {
            arguments += ["--scratch-path", scratchPath.path]
        }
        arguments.append("dump-package")
        let result = try await run(
            .name("swift"),
            arguments: Arguments(arguments),
            output: .string(limit: 10 * 1024 * 1024)  // 10MB limit
        )

        guard result.terminationStatus.isSuccess else {
            // If we can't get package info, fall back to empty array
            // which means we'll include everything
            if configuration.isVerbose {
                log("Warning: Could not determine package targets, including all modules")
            }
            return []
        }

        // Parse the JSON to extract target names (preserving Package.swift order)
        guard let data = result.standardOutput.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let targets = json["targets"] as? [[String: Any]]
        else {
            return []
        }

        var targetNames: [String] = []
        for target in targets {
            if let name = target["name"] as? String {
                targetNames.append(name)
            }
        }

        if configuration.isVerbose {
            log("Package targets: \(targetNames.joined(separator: ", "))")
        }

        return targetNames
    }

    /// Converts a target name to its Swift module name equivalent.
    ///
    /// Swift automatically converts hyphens to underscores in module names,
    /// so a target named "docc-static" becomes module "docc_static".
    private func normalizeModuleName(_ name: String) -> String {
        name.replacingOccurrences(of: "-", with: "_")
    }

    /// Determines if a module should be included based on the dependency policy.
    ///
    /// - Parameters:
    ///   - moduleName: The name of the module to check (from the archive).
    ///   - packageTargets: The target names from the current package (in Package.swift order).
    /// - Returns: `true` if the module should be included, `false` otherwise.
    private func shouldIncludeModule(_ moduleName: String, packageTargets: [String]) -> Bool {
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
        // Normalize names because Swift converts hyphens to underscores in module names
        let normalizedModuleName = normalizeModuleName(moduleName)
        let normalizedTargets = packageTargets.map { normalizeModuleName($0) }
        if normalizedTargets.contains(normalizedModuleName) {
            return true
        }

        // Apply dependency policy for external modules
        switch configuration.dependencyPolicy {
        case .all:
            return true
        case .none:
            return false
        case .exclude(let excluded):
            let normalizedExcluded = Set(excluded.map { normalizeModuleName($0) })
            return !normalizedExcluded.contains(normalizedModuleName)
        case .includeOnly(let included):
            let normalizedIncluded = Set(included.map { normalizeModuleName($0) })
            return normalizedIncluded.contains(normalizedModuleName)
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
            "-Xswiftc", outputDir.path,
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
            arguments: Arguments(arguments),
            input: .none,
            output: .sequence,
            error: .discarded
        ) { execution in
            // Stream stdout lines as they arrive
            for try await line in execution.standardOutput.strings() {
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
            "--fallback-bundle-identifier", moduleName,
            // Always enable external link support so generated docs can be used as dependencies
            "--enable-experimental-external-link-support",
        ]

        // Add dependency archives for resolving external links
        for archive in configuration.dependencyArchives {
            arguments.append("--dependency")
            arguments.append(archive.path)
        }

        // Add catalog as the main input if provided
        if let catalogURL = catalog {
            arguments.insert(catalogURL.path, at: 1)
            if configuration.isVerbose {
                log("Using DocC catalog: \(catalogURL.path)")
            }
        }

        // Use streaming API to show output as it arrives
        // Note: swift-subprocess requires discarding stderr when streaming stdout
        // docc convert only outputs warnings/errors, so always show them to stderr
        let result = try await run(
            .path(FilePath(doccPath)),
            arguments: Arguments(arguments),
            input: .none,
            output: .sequence,
            error: .discarded
        ) { execution in
            // Stream stdout bytes directly to stderr - docc only outputs diagnostics
            for try await chunk in execution.standardOutput {
                FileHandle.standardError.write(Data(buffer: chunk))
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
    /// symbol graphs are present.  Modules without a catalog whose symbol graphs
    /// declare no symbols are left out, as they have nothing to document.
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
        let catalogs = findDoccCatalogs(
            in: configuration.packageDirectory, fileManager: fileManager)

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
            try fileManager.createDirectory(
                at: catalogSymbolGraphsDir, withIntermediateDirectories: true)

            if let symbolGraph = matchingSymbolGraph {
                let destPath = catalogSymbolGraphsDir.appendingPathComponent(
                    symbolGraph.lastPathComponent)
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
            .filter { $0.hasSuffix(DocumentableSymbolGraphs.fileSuffix) }

        // Leave out modules without a catalogue that have nothing to document
        let remainingSymbolGraphs = DocumentableSymbolGraphs.documentableFiles(
            allSymbolGraphs.filter { !processedSymbolGraphs.contains($0) },
            in: symbolGraphsDir
        )

        if !remainingSymbolGraphs.isEmpty {
            // Create temp directory for remaining symbol graphs
            let remainingSymbolGraphsDir = tempDir.appendingPathComponent("sg-remaining")
            try fileManager.createDirectory(
                at: remainingSymbolGraphsDir, withIntermediateDirectories: true)

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
        guard let contents = try? fileManager.contentsOfDirectory(atPath: symbolGraphsDir.path)
        else {
            return nil
        }

        // Try exact match first (e.g., "SwiftModelling" -> "SwiftModelling.symbols.json")
        let exactMatch = catalogName + DocumentableSymbolGraphs.fileSuffix
        if contents.contains(exactMatch) {
            return symbolGraphsDir.appendingPathComponent(exactMatch)
        }

        // Try with underscores replacing hyphens (e.g., "swift-atl" -> "swift_atl.symbols.json")
        let underscoreMatch = catalogName.replacingOccurrences(of: "-", with: "_") + DocumentableSymbolGraphs.fileSuffix
        if contents.contains(underscoreMatch) {
            return symbolGraphsDir.appendingPathComponent(underscoreMatch)
        }

        // Try case-insensitive match
        let lowercaseName = catalogName.lowercased()
        for file in contents where file.hasSuffix(DocumentableSymbolGraphs.fileSuffix) {
            let baseName = String(file.dropLast(DocumentableSymbolGraphs.fileSuffix.count))
            if baseName.lowercased() == lowercaseName
                || baseName.lowercased().replacingOccurrences(of: "_", with: "-") == lowercaseName
            {
                return symbolGraphsDir.appendingPathComponent(file)
            }
        }

        return nil
    }

    /// The separator between the directories of the executable search path.
    #if os(Windows)
        static let searchPathSeparator: Character = ";"
    #else
        static let searchPathSeparator: Character = ":"
    #endif

    /// The file name extensions an executable may have.
    #if os(Windows)
        static let executableExtensions = [".exe", ""]
    #else
        static let executableExtensions = [""]
    #endif

    /// Returns the first executable with a name in the directories of a search path.
    ///
    /// - Parameters:
    ///   - name: The name of the executable, without a file name extension.
    ///   - searchPath: The directories to search, separated by
    ///     ``searchPathSeparator``, such as the value of `PATH`.
    /// - Returns: The path of the executable, or `nil` if no directory contains it.
    static func executable(named name: String, searchPath: String?) -> String? {
        guard let searchPath else { return nil }
        let fileManager = FileManager.default
        for directory in searchPath.split(separator: searchPathSeparator) where !directory.isEmpty {
            for fileExtension in executableExtensions {
                let candidate = URL(fileURLWithPath: String(directory), isDirectory: true)
                    .appendingPathComponent(name + fileExtension).path
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: candidate, isDirectory: &isDirectory), !isDirectory.boolValue,
                   fileManager.isExecutableFile(atPath: candidate) {
                    return candidate
                }
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
                    let path = result.standardOutput.trimmingCharacters(
                        in: CharacterSet.whitespacesAndNewlines)
                    if !path.isEmpty && fileManager.fileExists(atPath: path) {
                        return path
                    }
                }
            }

            // Fall back to common macOS locations
            let macOSPaths = [
                "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/docc",
                "/Applications/Developer/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/docc",
                "/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin/docc",
            ]

            for path in macOSPaths {
                if fileManager.fileExists(atPath: path) {
                    return path
                }
            }
        #endif

        // Cross-platform: find docc on the search path
        if let path = Self.executable(
            named: "docc",
            searchPath: ProcessInfo.processInfo.environment["PATH"] ?? ProcessInfo.processInfo.environment["Path"]
        ) {
            return path
        }

        // Linux: check common Swift toolchain locations
        let linuxPaths = [
            "/usr/bin/docc",
            "/usr/local/bin/docc",
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
        var catalogs: [URL] = []

        // Search in both Sources and Plugins directories
        let searchDirs = [
            packageDirectory.appendingPathComponent("Sources"),
            packageDirectory.appendingPathComponent("Plugins"),
        ]

        for searchDir in searchDirs {
            // Check if directory exists
            guard fileManager.fileExists(atPath: searchDir.path) else {
                continue
            }

            // Enumerate all items in directory
            guard
                let enumerator = fileManager.enumerator(
                    at: searchDir,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
            else {
                continue
            }

            while let url = enumerator.nextObject() as? URL {
                // Check if this is a .docc directory
                if url.pathExtension == "docc" {
                    var isDirectory: ObjCBool = false
                    if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                        isDirectory.boolValue
                    {
                        catalogs.append(url)
                        // Don't descend into .docc directories
                        enumerator.skipDescendants()
                    }
                }
            }
        }

        // Sort catalogs by name for deterministic ordering
        return catalogs.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - Navigation Index

    /// Filters a navigation index to only include modules that are package targets.
    ///
    /// This excludes dependencies from the sidebar navigation.
    ///
    /// - Parameters:
    ///   - index: The navigation index to filter.
    ///   - packageTargets: The set of target names from the current package.
    /// - Returns: A filtered navigation index containing only package targets.
    /// Filters and sorts a navigation index to only include package targets in their defined order.
    private func filterNavigationIndex(_ index: NavigationIndex, packageTargets: [String])
        -> NavigationIndex
    {
        var filteredLanguages: [String: [NavigationNode]] = [:]

        // Create ordered list of normalised target names for filtering and sorting
        let normalizedTargetOrder = packageTargets.map {
            normalizeModuleName($0).lowercased()
        }
        let normalizedTargetSet = Set(normalizedTargetOrder)

        for (language, nodes) in index.interfaceLanguages {
            // Filter nodes to only include package targets
            let filteredNodes = nodes.filter { node in
                guard let path = node.path else { return false }
                let pathComponents =
                    path
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    .lowercased()
                    .components(separatedBy: "/")

                guard pathComponents.count >= 2,
                    pathComponents[0] == "documentation"
                else {
                    return false
                }

                let moduleName = normalizeModuleName(pathComponents[1])
                return normalizedTargetSet.contains(moduleName)
            }

            // Sort nodes by their order in Package.swift
            let sortedNodes = filteredNodes.sorted { a, b in
                let aIndex = targetOrderIndex(for: a, in: normalizedTargetOrder)
                let bIndex = targetOrderIndex(for: b, in: normalizedTargetOrder)
                return aIndex < bIndex
            }

            filteredLanguages[language] = sortedNodes
        }

        return NavigationIndex(
            schemaVersion: index.schemaVersion,
            includedArchiveIdentifiers: index.includedArchiveIdentifiers,
            interfaceLanguages: filteredLanguages
        )
    }

    /// Returns the index of a navigation node in the target order list.
    private func targetOrderIndex(for node: NavigationNode, in targetOrder: [String]) -> Int {
        guard let path = node.path else { return Int.max }
        let pathComponents =
            path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
            .components(separatedBy: "/")

        guard pathComponents.count >= 2,
            pathComponents[0] == "documentation"
        else {
            return Int.max
        }

        let moduleName = normalizeModuleName(pathComponents[1])
        return targetOrder.firstIndex(of: moduleName) ?? Int.max
    }

    /// Loads navigation indices from all archives and merges them into a single index.
    ///
    /// This allows the sidebar to show all modules, not just the current one.
    ///
    /// - Parameter archives: The archive directories to load indices from.
    /// - Returns: A merged navigation index, or nil if no indices could be loaded.
    private func loadAndMergeNavigationIndices(from archives: [URL]) throws -> NavigationIndex? {
        let fileManager = FileManager.default
        var indices: [NavigationIndex] = []

        for archiveDir in archives {
            let indexPath =
                archiveDir
                .appendingPathComponent("index")
                .appendingPathComponent("index.json")

            guard fileManager.fileExists(atPath: indexPath.path) else { continue }

            do {
                let index = try NavigationIndex.load(from: indexPath)
                indices.append(index)
                if configuration.isVerbose {
                    log("Loaded navigation index from: \(indexPath.path)")
                }
            } catch {
                if configuration.isVerbose {
                    log("Warning: Failed to load navigation index from \(indexPath.path): \(error)")
                }
            }
        }

        guard !indices.isEmpty else { return nil }
        return NavigationIndex.merge(indices)
    }

    // MARK: - Archive Rendering

    /// Renders the documentation and tutorial pages of one archive.
    ///
    /// - Parameters:
    ///   - archiveDir: The archive to render.
    ///   - consumer: The consumer that writes each page.
    ///   - searchIndexBuilder: The search index to add the pages to, if any.
    ///   - packageTargets: The modules to include, or all modules if empty.
    /// - Returns: The normalised paths of the rendered pages that are deprecated.
    /// - Throws: An error if the archive cannot be read.
    private func renderFromArchive(
        _ archiveDir: URL,
        consumer: StaticHTMLConsumer,
        searchIndexBuilder: inout SearchIndexBuilder?,
        packageTargets: [String]
    ) async throws -> Set<String> {
        if configuration.isVerbose {
            log("Rendering pages from archive...")
        }

        let dataDir = archiveDir.appendingPathComponent("data")
        let documentationDir = dataDir.appendingPathComponent("documentation")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: documentationDir.path) else {
            if configuration.isVerbose {
                log("Warning: Archive has no documentation data, skipping: \(archiveDir.path)")
            }
            return []  // Skip this archive instead of failing
        }

        // Note: Navigation index is already loaded and merged upfront in generate()
        // The consumer already has the merged navigation index set

        // Track which modules have been skipped
        var skippedModules = Set<String>()

        // Track which rendered pages are deprecated
        var deprecatedPagePaths = Set<String>()

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

                    // Check if this module should be included; a tutorials overview is
                    // named after its file, so it belongs to the modules of its tutorials
                    let tutorialModules = renderNode.kind == .overview
                        ? renderNode.references.values.compactMap { ($0 as? TopicRenderReference)?.identifier.identifier }
                            .compactMap { URL(string: $0)?.path }.filter { $0.hasPrefix("/tutorials/") }
                            .map(extractModuleName(from:))
                        : []
                    let isIncluded = shouldIncludeModule(moduleName, packageTargets: packageTargets)
                        || tutorialModules.contains { shouldIncludeModule($0, packageTargets: packageTargets) }
                    guard isIncluded else {
                        if !skippedModules.contains(moduleName) {
                            skippedModules.insert(moduleName)
                            if configuration.isVerbose {
                                log("Skipping dependency: \(moduleName)")
                            }
                        }
                        continue
                    }

                    try consumer.consume(renderNode: renderNode)
                    if Badge.statuses(of: renderNode).contains(.deprecated) {
                        deprecatedPagePaths.insert(SidebarDocument.pagePathKey(of: renderNode.identifier))
                    }

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
        return deprecatedPagePaths
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
        var searchBuilder: SearchIndexBuilder? =
            configuration.includeSearch ? SearchIndexBuilder(configuration: configuration) : nil
        _ = try await renderFromArchive(
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

    /// Writes the shared sidebar document to the root of the output directory.
    ///
    /// Nothing is written if the navigation index lists no modules; pages then fall
    /// back to an inline sidebar.
    ///
    /// - Parameters:
    ///   - navigationIndex: The merged navigation index of all modules.
    ///   - deprecatedPagePaths: The normalised paths of the rendered pages that are
    ///     deprecated.
    /// - Throws: An error if the document cannot be written.
    private func writeSidebarDocument(
        for navigationIndex: NavigationIndex?,
        deprecatedPagePaths: Set<String>
    ) throws {
        guard let navigationIndex, SidebarDocument.isAvailable(for: navigationIndex) else { return }
        var builder = NavigationSidebarBuilder(
            navigationIndex: navigationIndex,
            deprecatedPagePaths: deprecatedPagePaths
        )
        let html = builder.buildSidebarDocument(includeSearch: configuration.includeSearch)
        let path = configuration.outputDirectory.appendingPathComponent(SidebarDocument.fileName)
        try html.write(to: path, atomically: true, encoding: .utf8)

        if configuration.isVerbose {
            log("Wrote shared sidebar: \(path.path) (\(html.utf8.count) bytes)")
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

    // MARK: - Tutorial Overview Page Generation

    /// Generates a tutorials overview page when the tutorials have none.
    ///
    /// DocC renders a tutorials overview for every `@Tutorials` page.  When the
    /// generated tutorials have no overview page, this writes one to
    /// `tutorials/tutorials/index.html` that lists the tutorials of each module in the
    /// order of their tutorial menu.  An existing overview page is never replaced.
    private func generateTutorialOverviewPages() throws {
        let fileManager = FileManager.default
        let tutorialsRoot = configuration.outputDirectory.appendingPathComponent("tutorials")
        guard let moduleDirectories = try? fileManager.contentsOfDirectory(
            at: tutorialsRoot,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return  // No tutorials to generate an overview for
        }
        let overviewMarker = "<body class=\"\(TutorialDocument.overviewPageClass)\""
        let hasOverview = moduleDirectories.contains { directory in
            let index = directory.appendingPathComponent("index.html")
            return (try? String(contentsOf: index, encoding: .utf8))?.contains(overviewMarker) ?? false
        }
        guard !hasOverview else { return }

        let builder = HTMLPageBuilder(configuration: configuration)
        let depth = 2
        for moduleDir in moduleDirectories.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: moduleDir.path, isDirectory: &isDirectory), isDirectory.boolValue,
                  !fileManager.fileExists(atPath: moduleDir.appendingPathComponent("index.html").path),
                  let tutorialDirs = try? fileManager.contentsOfDirectory(at: moduleDir, includingPropertiesForKeys: nil)
            else {
                continue
            }
            let moduleName = moduleDir.lastPathComponent

            // The tutorial menu of any tutorial page lists the tutorials in order
            var orderedTutorialPaths: [String] = []
            var technology = moduleName.capitalized
            for tutorialDir in tutorialDirs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard let html = try? String(contentsOf: tutorialDir.appendingPathComponent("index.html"), encoding: .utf8) else {
                    continue
                }
                if let title = Self.text(in: html, after: "class=\"\(TutorialDocument.navigationTitleClass)\"><span class=\"title\">", before: "</span>") {
                    technology = title
                }
                let pattern = #"href="[^"]*"# + moduleName + #"/([^/"]+)/index\.html""#
                if let regex = try? Regex(pattern) {
                    for match in html.matches(of: regex) {
                        if let path = match.output[1].substring.map(String.init), !orderedTutorialPaths.contains(path) {
                            orderedTutorialPaths.append(path)
                        }
                    }
                }
                if !orderedTutorialPaths.isEmpty { break }
            }

            let topics = orderedTutorialPaths.compactMap { path -> TutorialsOverview.Topic? in
                let page = moduleDir.appendingPathComponent(path).appendingPathComponent("index.html")
                guard let html = try? String(contentsOf: page, encoding: .utf8) else { return nil }
                let title = Self.text(in: html, after: "<title>", before: "</title>")
                    ?? path.replacingOccurrences(of: "-", with: " ").capitalized
                return TutorialsOverview.Topic(title: title, url: "../\(moduleName)/\(path)/index.html")
            }
            guard !topics.isEmpty else { continue }

            let overview = TutorialsOverview(
                technology: technology,
                title: technology,
                volumes: [.init(chapters: [.init(name: technology, topics: topics)])]
            )
            let html = builder.buildTutorialsOverviewPage(overview, pageTitle: technology, description: nil, depth: depth)
            let overviewDirectory = tutorialsRoot.appendingPathComponent("tutorials")
            try fileManager.createDirectory(at: overviewDirectory, withIntermediateDirectories: true)
            let overviewPath = overviewDirectory.appendingPathComponent("index.html")
            try html.write(to: overviewPath, atomically: true, encoding: .utf8)
            if configuration.isVerbose {
                log("Generated tutorial overview: \(overviewPath.path)")
            }
            return
        }
    }

    /// Returns the text between two markers in an HTML document, with tags removed.
    ///
    /// - Parameters:
    ///   - html: The document.
    ///   - start: The marker before the text.
    ///   - end: The marker after the text.
    /// - Returns: The text, or `nil` if a marker is missing.
    private static func text(in html: String, after start: String, before end: String) -> String? {
        guard let startRange = html.range(of: start),
              let endRange = html.range(of: end, range: startRange.upperBound..<html.endIndex)
        else { return nil }
        return String(html[startRange.upperBound..<endRange.lowerBound])
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    // MARK: - Index Page Generation

    private func generateIndexPage(consumer: StaticHTMLConsumer) throws {
        if configuration.isVerbose {
            log("Generating index page...")
        }

        let indexBuilder = IndexPageBuilder(
            configuration: configuration,
            embedsSidebar: SidebarDocument.isAvailable(for: consumer.navigationIndex)
        )

        // Collect module information from the consumer's generated pages
        var modules: [IndexPageBuilder.ModuleEntry] = []

        // Scan the output directory for module directories
        let docRoot = configuration.outputDirectory.appendingPathComponent("documentation")
        let fileManager = FileManager.default

        // Track which normalized module names we've already added to avoid duplicates
        // (e.g., docc_static and docc-static should only appear once)
        var seenModules: Set<String> = []

        if fileManager.fileExists(atPath: docRoot.path),
            let contents = try? fileManager.contentsOfDirectory(
                at: docRoot,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
        {
            for item in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory),
                    isDirectory.boolValue
                {
                    let modulePath = item.lastPathComponent

                    // Normalize the module name for deduplication
                    let normalizedName = normalizeModuleName(modulePath.lowercased())

                    // Skip if we've already seen this module (handles docc-static vs docc_static)
                    guard !seenModules.contains(normalizedName) else {
                        continue
                    }

                    // Only include directories that have an index.html (actual module pages)
                    let indexPath = item.appendingPathComponent("index.html")
                    guard fileManager.fileExists(atPath: indexPath.path) else {
                        continue
                    }

                    seenModules.insert(normalizedName)

                    // Extract the actual title from the generated HTML
                    let moduleInfo = extractModuleInfo(from: item)
                    modules.append(
                        IndexPageBuilder.ModuleEntry(
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
                modules.append(
                    IndexPageBuilder.ModuleEntry(
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
                        isDir.boolValue
                    else { continue }

                    // Count tutorials in this module
                    if let tutorialDirs = try? fileManager.contentsOfDirectory(
                        at: moduleDir,
                        includingPropertiesForKeys: [.isDirectoryKey]
                    ) {
                        let tutorialCount = tutorialDirs.filter { dir in
                            var isDirCheck: ObjCBool = false
                            return fileManager.fileExists(
                                atPath: dir.path, isDirectory: &isDirCheck) && isDirCheck.boolValue
                        }.count

                        if tutorialCount > 0 {
                            // Extract title from overview page
                            let overviewPath = tutorialsOverviewDir.appendingPathComponent(
                                "index.html")
                            var title = moduleName.capitalized + " Tutorials"
                            if let html = try? String(contentsOf: overviewPath, encoding: .utf8),
                                let titleStart = html.range(of: "<h1 class=\"overview-title\">"),
                                let titleEnd = html.range(
                                    of: "</h1>", range: titleStart.upperBound..<html.endIndex)
                            {
                                title = String(html[titleStart.upperBound..<titleEnd.lowerBound])
                            }

                            tutorials.append(
                                IndexPageBuilder.TutorialEntry(
                                    title: title,
                                    path: "tutorials/tutorials/index.html",
                                    tutorialCount: tutorialCount
                                ))
                        }
                    }
                }
            }
        }

        // Load optional INDEX.md content
        let indexContent = indexBuilder.loadIndexContent(from: configuration.packageDirectory)
        if configuration.isVerbose {
            if let content = indexContent {
                if content.title != nil {
                    log(
                        "Loaded custom index from \(IndexPageBuilder.indexMarkdownFilename) with title"
                    )
                } else {
                    log("Loaded custom index from \(IndexPageBuilder.indexMarkdownFilename)")
                }
            }
        }

        let html = indexBuilder.buildIndexPage(
            modules: modules,
            tutorials: tutorials,
            indexContent: indexContent
        )
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
            let titleEnd = html.range(of: "</title>", range: titleStart.upperBound..<html.endIndex)
        {
            title = String(html[titleStart.upperBound..<titleEnd.lowerBound])
        }

        // Extract the abstract from the hero's abstract wrapper
        var abstract = "Documentation for \(title)"
        if let abstractStart = html.range(of: "<div class=\"\(HTMLPageBuilder.heroAbstractClass)\"><p>"),
            let abstractEnd = html.range(
                of: "</p>", range: abstractStart.upperBound..<html.endIndex)
        {
            let rawAbstract = String(html[abstractStart.upperBound..<abstractEnd.lowerBound])
            // Strip HTML tags from abstract
            abstract = rawAbstract.replacingOccurrences(
                of: "<[^>]+>", with: "", options: .regularExpression)
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
        return max(0, count - 1)  // Subtract 1 for the module index itself
    }

    // MARK: - Doc Link Post-Processing

    /// Post-processes all generated HTML files to resolve `doc://` URLs.
    ///
    /// This scans all HTML files in the output directory and replaces any unresolved
    /// `doc://BUNDLE_ID/path` URLs with proper `<a href="...">` links.
    ///
    /// - Parameter navigationIndex: The merged navigation index containing module information.
    private func postProcessDocLinks(navigationIndex: NavigationIndex?) async throws {
        let fileManager = FileManager.default

        // Build map of documented modules (module name -> bundle ID)
        // For simplicity, we use module name as bundle ID since DocC typically uses module names
        var documentedModules: [String: String] = [:]
        if let navIndex = navigationIndex {
            for module in navIndex.allModules() {
                // Use the module title as both name and bundle ID
                // The post-processor will match case-insensitively
                documentedModules[module.title] = module.title
            }
            // Also add any included archive identifiers
            if let archiveIDs = navIndex.includedArchiveIdentifiers {
                for id in archiveIDs {
                    documentedModules[id] = id
                }
            }
        }

        // Create the post-processor
        let postProcessor = DocLinkPostProcessor(
            documentedModules: documentedModules,
            externalURLs: configuration.externalDocumentationURLs
        )

        // Find all HTML files in the output directory
        guard let enumerator = fileManager.enumerator(
            at: configuration.outputDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        // Collect all HTML files with their depths
        var htmlFiles: [(url: URL, depth: Int)] = []
        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "html" else { continue }

            // Calculate depth from output directory
            let relativePath = fileURL.path.replacingOccurrences(
                of: configuration.outputDirectory.path + "/",
                with: ""
            )
            guard DocLinkPostProcessor.shouldProcess(relativePath: relativePath) else { continue }
            let depth = relativePath.components(separatedBy: "/").count - 1
            htmlFiles.append((fileURL, depth))
        }

        // Process files in parallel
        let isVerbose = configuration.isVerbose
        let processedCount = try await withThrowingTaskGroup(of: Bool.self) { group in
            for (fileURL, depth) in htmlFiles {
                group.addTask {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let processed = postProcessor.process(content, currentDepth: depth)

                    // Only write if content changed
                    if processed != content {
                        try processed.write(to: fileURL, atomically: true, encoding: .utf8)
                        return true
                    }
                    return false
                }
            }

            var count = 0
            for try await wasModified in group {
                if wasModified {
                    count += 1
                }
            }
            return count
        }

        if isVerbose && processedCount > 0 {
            log("Post-processed \(processedCount) HTML files for doc:// links")
        }
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
                try fileManager.createDirectory(
                    at: imagesDestination, withIntermediateDirectories: true)

                for item in contents {
                    let destItem = imagesDestination.appendingPathComponent(item.lastPathComponent)

                    // If it's a directory, copy recursively
                    var isDirectory: ObjCBool = false
                    if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) {
                        if isDirectory.boolValue {
                            // Create destination directory and copy contents
                            try fileManager.createDirectory(
                                at: destItem, withIntermediateDirectories: true)
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
            let downloadsDestination = configuration.outputDirectory.appendingPathComponent(
                "downloads")
            try fileManager.createDirectory(
                at: downloadsDestination, withIntermediateDirectories: true)
            try copyDirectoryContents(from: downloadsSource, to: downloadsDestination)

            if configuration.isVerbose {
                log("Copied downloads from: \(downloadsSource.path)")
            }
        }

        // Copy videos directory if it exists
        let videosSource = archiveDir.appendingPathComponent("videos")
        if fileManager.fileExists(atPath: videosSource.path) {
            let videosDestination = configuration.outputDirectory.appendingPathComponent("videos")
            try fileManager.createDirectory(
                at: videosDestination, withIntermediateDirectories: true)
            try copyDirectoryContents(from: videosSource, to: videosDestination)

            if configuration.isVerbose {
                log("Copied videos from: \(videosSource.path)")
            }
        }
    }

    /// Recursively copies the contents of a directory.
    private func copyDirectoryContents(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default

        guard
            let contents = try? fileManager.contentsOfDirectory(
                at: source,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
        else { return }

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

// MARK: - Client-side Search Script

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

            // Calculate the base path for relative URLs by examining the CSS link
            function getBasePath() {
                // Find the CSS link to determine the base path
                const cssLink = document.querySelector('link[rel="stylesheet"][href*="css/main.css"]');
                if (cssLink) {
                    const href = cssLink.getAttribute('href');
                    // Extract base path from href like "../../css/main.css" -> "../../"
                    const match = href.match(/^((?:\\.\\.\\/)*)/);
                    if (match) {
                        return match[1];
                    }
                }
                // Fallback: empty base path (assume at root)
                return '';
            }

            // Load and build the search index
            async function loadSearchIndex() {
                try {
                    const basePath = getBasePath();
                    const response = await fetch(basePath + 'search-index.json');
                    if (!response.ok) throw new Error('Failed to load search index: ' + response.status);

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
                } catch (error) {
                    console.warn('Search not available:', error.message);
                }
            }

            // Search content using Lunr.js and display results
            function searchContent(query) {
                removeSearchResults();

                if (!searchIndex || !query.trim()) {
                    return;
                }

                let results = [];
                try {
                    // First try exact/stemmed search (uses Lunr's stemmer)
                    results = searchIndex.search(query);
                } catch (e) {
                    // Stemmed search failed, will try wildcard
                }

                // If no results, try wildcard search for partial matches
                if (results.length === 0) {
                    try {
                        results = searchIndex.search(query + '*');
                    } catch (e) {
                        // Wildcard search also failed
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

            // Show content matches below the navigation tree while the sidebar filter
            // is in use; filtering the tree itself is done by the sidebar's own script,
            // which also handles the keyboard shortcuts of the filter field.
            if (filterInput && sidebarContent) {
                let debounceTimer;
                filterInput.addEventListener('input', (e) => {
                    clearTimeout(debounceTimer);
                    debounceTimer = setTimeout(() => {
                        searchContent(e.target.value);
                    }, 150);
                });
            }

            // Spotlight overlay search (for pages without sidebar)
            let spotlightOverlay = null;
            let spotlightInput = null;
            let spotlightResults = null;
            let selectedIndex = -1;
            let currentResults = [];

            function createSpotlightOverlay() {
                if (spotlightOverlay) return;

                spotlightOverlay = document.createElement('div');
                spotlightOverlay.className = 'search-overlay';
                spotlightOverlay.innerHTML = `
                    <div class="search-overlay-container">
                        <div class="search-overlay-input-wrapper">
                            <input type="text" class="search-overlay-input" placeholder="Search documentation..." autocomplete="off">
                        </div>
                        <div class="search-overlay-results"></div>
                        <div class="search-overlay-hint">
                            <span><kbd>↑</kbd><kbd>↓</kbd> Navigate</span>
                            <span><kbd>Enter</kbd> Open</span>
                            <span><kbd>Esc</kbd> Close</span>
                        </div>
                    </div>
                `;

                document.body.appendChild(spotlightOverlay);
                spotlightInput = spotlightOverlay.querySelector('.search-overlay-input');
                spotlightResults = spotlightOverlay.querySelector('.search-overlay-results');

                // Close on backdrop click
                spotlightOverlay.addEventListener('click', (e) => {
                    if (e.target === spotlightOverlay) {
                        closeSpotlight();
                    }
                });

                // Input handling
                let debounceTimer;
                spotlightInput.addEventListener('input', (e) => {
                    clearTimeout(debounceTimer);
                    debounceTimer = setTimeout(() => {
                        performSpotlightSearch(e.target.value);
                    }, 150);
                });

            }

            function isSpotlightActive() {
                return spotlightOverlay && spotlightOverlay.classList.contains('active');
            }

            function openSpotlight() {
                if (!spotlightOverlay) createSpotlightOverlay();
                spotlightOverlay.classList.add('active');
                spotlightInput.value = '';
                spotlightResults.innerHTML = '';
                selectedIndex = -1;
                currentResults = [];
                // Prevent page scrolling when overlay is open
                document.body.style.overflow = 'hidden';
                setTimeout(() => spotlightInput.focus(), 50);
            }

            function closeSpotlight() {
                if (spotlightOverlay) {
                    spotlightOverlay.classList.remove('active');
                    document.body.style.overflow = '';
                }
            }

            function performSpotlightSearch(query) {
                if (!searchIndex || !query.trim()) {
                    spotlightResults.innerHTML = '';
                    currentResults = [];
                    selectedIndex = -1;
                    return;
                }

                let results = [];
                try {
                    results = searchIndex.search(query);
                } catch (e) {
                    // Try wildcard
                }

                if (results.length === 0) {
                    try {
                        results = searchIndex.search(query + '*');
                    } catch (e) {
                        // Wildcard also failed
                    }
                }

                if (results.length === 0) {
                    spotlightResults.innerHTML = '<div class="search-overlay-empty">No results found</div>';
                    currentResults = [];
                    selectedIndex = -1;
                    return;
                }

                // Group results by type
                const grouped = { tutorial: [], article: [], symbol: [] };
                results.forEach(result => {
                    const doc = searchData[result.ref];
                    if (doc) {
                        if (doc.title === 'Tutorials' && doc.type === 'article') return;
                        if (doc.type === 'section') return;
                        const type = doc.type || 'symbol';
                        if (grouped[type]) grouped[type].push(doc);
                    }
                });

                displaySpotlightResults(grouped);
            }

            function displaySpotlightResults(grouped) {
                const basePath = getBasePath();
                const typeLabels = { tutorial: 'Tutorials', article: 'Articles', symbol: 'API' };
                const typeOrder = ['tutorial', 'article', 'symbol'];

                let html = '';
                currentResults = [];

                typeOrder.forEach(type => {
                    const docs = grouped[type];
                    if (docs && docs.length > 0) {
                        html += '<div class="search-overlay-section">';
                        html += '<div class="search-overlay-section-title">' + (typeLabels[type] || type) + '</div>';
                        docs.slice(0, 5).forEach(doc => {
                            const resultIndex = currentResults.length;
                            currentResults.push(doc);
                            html += '<a href="' + basePath + doc.path + '" class="search-overlay-item" data-index="' + resultIndex + '">';
                            html += '<span class="search-overlay-item-title">' + escapeHtml(doc.title) + '</span>';
                            if (doc.module) {
                                html += '<span class="search-overlay-item-path">' + escapeHtml(doc.module) + '</span>';
                            }
                            html += '</a>';
                        });
                        html += '</div>';
                    }
                });

                spotlightResults.innerHTML = html;

                // Add hover handlers
                spotlightResults.querySelectorAll('.search-overlay-item').forEach(item => {
                    item.addEventListener('mouseenter', (e) => {
                        const index = parseInt(item.getAttribute('data-index'), 10);
                        updateSelection(index);
                    });
                });

                // Auto-select first result so Enter works immediately
                if (currentResults.length > 0) {
                    updateSelection(0);
                } else {
                    selectedIndex = -1;
                }
            }

            function escapeHtml(text) {
                const div = document.createElement('div');
                div.textContent = text;
                return div.innerHTML;
            }

            function selectNext() {
                if (currentResults.length === 0) return;
                updateSelection(selectedIndex < currentResults.length - 1 ? selectedIndex + 1 : 0);
            }

            function selectPrevious() {
                if (currentResults.length === 0) return;
                updateSelection(selectedIndex > 0 ? selectedIndex - 1 : currentResults.length - 1);
            }

            function updateSelection(newIndex) {
                const items = spotlightResults.querySelectorAll('.search-overlay-item');
                items.forEach((item, i) => {
                    item.classList.toggle('selected', i === newIndex);
                });
                selectedIndex = newIndex;

                // Scroll into view
                if (items[newIndex]) {
                    items[newIndex].scrollIntoView({ block: 'nearest' });
                }
            }

            function navigateToSelected() {
                if (selectedIndex >= 0 && selectedIndex < currentResults.length) {
                    const doc = currentResults[selectedIndex];
                    const basePath = getBasePath();
                    window.location.href = basePath + doc.path;
                }
            }

            // Keyboard shortcut: "/" to open spotlight (only on pages without a sidebar)
            if (!filterInput && !document.querySelector('iframe.\(SidebarDocument.frameClass)')) {
                document.addEventListener('keydown', (e) => {
                    // Handle Escape and navigation when overlay is active
                    if (isSpotlightActive()) {
                        if (e.key === 'Escape') {
                            e.preventDefault();
                            closeSpotlight();
                            return;
                        }
                        // Handle arrow keys even if input doesn't have focus
                        if (e.key === 'ArrowDown') {
                            e.preventDefault();
                            selectNext();
                            return;
                        }
                        if (e.key === 'ArrowUp') {
                            e.preventDefault();
                            selectPrevious();
                            return;
                        }
                        if (e.key === 'Enter') {
                            e.preventDefault();
                            navigateToSelected();
                            return;
                        }
                    }

                    // Open spotlight with "/"
                    if (e.key === '/' &&
                        document.activeElement.tagName !== 'INPUT' &&
                        document.activeElement.tagName !== 'TEXTAREA') {
                        e.preventDefault();
                        openSpotlight();
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
        ##"""
        /**
        * lunr - http://lunrjs.com - A bit like Solr, but much smaller and not as bright - 2.3.9
        * Copyright (C) 2020 Oliver Nightingale
        * @license MIT
        */
        !function(){var e=function(t){var r=new e.Builder;return r.pipeline.add(e.trimmer,e.stopWordFilter,e.stemmer),r.searchPipeline.add(e.stemmer),t.call(r,r),r.build()};e.version="2.3.9",e.utils={},e.utils.warn=function(e){return function(t){e.console&&console.warn&&console.warn(t)}}(this),e.utils.asString=function(e){return void 0===e||null===e?"":e.toString()},e.utils.clone=function(e){if(null===e||void 0===e)return e;for(var t=Object.create(null),r=Object.keys(e),i=0;i<r.length;i++){var n=r[i],s=e[n];if(Array.isArray(s))t[n]=s.slice();else{if("string"!=typeof s&&"number"!=typeof s&&"boolean"!=typeof s)throw new TypeError("clone is not deep and does not support nested objects");t[n]=s}}return t},e.FieldRef=function(e,t,r){this.docRef=e,this.fieldName=t,this._stringValue=r},e.FieldRef.joiner="/",e.FieldRef.fromString=function(t){var r=t.indexOf(e.FieldRef.joiner);if(r===-1)throw"malformed field ref string";var i=t.slice(0,r),n=t.slice(r+1);return new e.FieldRef(n,i,t)},e.FieldRef.prototype.toString=function(){return void 0==this._stringValue&&(this._stringValue=this.fieldName+e.FieldRef.joiner+this.docRef),this._stringValue},e.Set=function(e){if(this.elements=Object.create(null),e){this.length=e.length;for(var t=0;t<this.length;t++)this.elements[e[t]]=!0}else this.length=0},e.Set.complete={intersect:function(e){return e},union:function(){return this},contains:function(){return!0}},e.Set.empty={intersect:function(){return this},union:function(e){return e},contains:function(){return!1}},e.Set.prototype.contains=function(e){return!!this.elements[e]},e.Set.prototype.intersect=function(t){var r,i,n,s=[];if(t===e.Set.complete)return this;if(t===e.Set.empty)return t;this.length<t.length?(r=this,i=t):(r=t,i=this),n=Object.keys(r.elements);for(var o=0;o<n.length;o++){var a=n[o];a in i.elements&&s.push(a)}return new e.Set(s)},e.Set.prototype.union=function(t){return t===e.Set.complete?e.Set.complete:t===e.Set.empty?this:new e.Set(Object.keys(this.elements).concat(Object.keys(t.elements)))},e.idf=function(e,t){var r=0;for(var i in e)"_index"!=i&&(r+=Object.keys(e[i]).length);var n=(t-r+.5)/(r+.5);return Math.log(1+Math.abs(n))},e.Token=function(e,t){this.str=e||"",this.metadata=t||{}},e.Token.prototype.toString=function(){return this.str},e.Token.prototype.update=function(e){return this.str=e(this.str,this.metadata),this},e.Token.prototype.clone=function(t){return t=t||function(e){return e},new e.Token(t(this.str,this.metadata),this.metadata)},e.tokenizer=function(t,r){if(null==t||void 0==t)return[];if(Array.isArray(t))return t.map(function(t){return new e.Token(e.utils.asString(t).toLowerCase(),e.utils.clone(r))});for(var i=t.toString().toLowerCase(),n=i.length,s=[],o=0,a=0;o<=n;o++){var u=i.charAt(o),l=o-a;if(u.match(e.tokenizer.separator)||o==n){if(l>0){var c=e.utils.clone(r)||{};c.position=[a,l],c.index=s.length,s.push(new e.Token(i.slice(a,o),c))}a=o+1}}return s},e.tokenizer.separator=/[\s\-]+/,e.Pipeline=function(){this._stack=[]},e.Pipeline.registeredFunctions=Object.create(null),e.Pipeline.registerFunction=function(t,r){r in this.registeredFunctions&&e.utils.warn("Overwriting existing registered function: "+r),t.label=r,e.Pipeline.registeredFunctions[t.label]=t},e.Pipeline.warnIfFunctionNotRegistered=function(t){var r=t.label&&t.label in this.registeredFunctions;r||e.utils.warn("Function is not registered with pipeline. This may cause problems when serialising the index.\n",t)},e.Pipeline.load=function(t){var r=new e.Pipeline;return t.forEach(function(t){var i=e.Pipeline.registeredFunctions[t];if(!i)throw new Error("Cannot load unregistered function: "+t);r.add(i)}),r},e.Pipeline.prototype.add=function(){var t=Array.prototype.slice.call(arguments);t.forEach(function(t){e.Pipeline.warnIfFunctionNotRegistered(t),this._stack.push(t)},this)},e.Pipeline.prototype.after=function(t,r){e.Pipeline.warnIfFunctionNotRegistered(r);var i=this._stack.indexOf(t);if(i==-1)throw new Error("Cannot find existingFn");i+=1,this._stack.splice(i,0,r)},e.Pipeline.prototype.before=function(t,r){e.Pipeline.warnIfFunctionNotRegistered(r);var i=this._stack.indexOf(t);if(i==-1)throw new Error("Cannot find existingFn");this._stack.splice(i,0,r)},e.Pipeline.prototype.remove=function(e){var t=this._stack.indexOf(e);t!=-1&&this._stack.splice(t,1)},e.Pipeline.prototype.run=function(e){for(var t=this._stack.length,r=0;r<t;r++){for(var i=this._stack[r],n=[],s=0;s<e.length;s++){var o=i(e[s],s,e);if(null!==o&&void 0!==o&&""!==o)if(Array.isArray(o))for(var a=0;a<o.length;a++)n.push(o[a]);else n.push(o)}e=n}return e},e.Pipeline.prototype.runString=function(t,r){var i=new e.Token(t,r);return this.run([i]).map(function(e){return e.toString()})},e.Pipeline.prototype.reset=function(){this._stack=[]},e.Pipeline.prototype.toJSON=function(){return this._stack.map(function(t){return e.Pipeline.warnIfFunctionNotRegistered(t),t.label})},e.Vector=function(e){this._magnitude=0,this.elements=e||[]},e.Vector.prototype.positionForIndex=function(e){if(0==this.elements.length)return 0;for(var t=0,r=this.elements.length/2,i=r-t,n=Math.floor(i/2),s=this.elements[2*n];i>1&&(s<e&&(t=n),s>e&&(r=n),s!=e);)i=r-t,n=t+Math.floor(i/2),s=this.elements[2*n];return s==e?2*n:s>e?2*n:s<e?2*(n+1):void 0},e.Vector.prototype.insert=function(e,t){this.upsert(e,t,function(){throw"duplicate index"})},e.Vector.prototype.upsert=function(e,t,r){this._magnitude=0;var i=this.positionForIndex(e);this.elements[i]==e?this.elements[i+1]=r(this.elements[i+1],t):this.elements.splice(i,0,e,t)},e.Vector.prototype.magnitude=function(){if(this._magnitude)return this._magnitude;for(var e=0,t=this.elements.length,r=1;r<t;r+=2){var i=this.elements[r];e+=i*i}return this._magnitude=Math.sqrt(e)},e.Vector.prototype.dot=function(e){for(var t=0,r=this.elements,i=e.elements,n=r.length,s=i.length,o=0,a=0,u=0,l=0;u<n&&l<s;)o=r[u],a=i[l],o<a?u+=2:o>a?l+=2:o==a&&(t+=r[u+1]*i[l+1],u+=2,l+=2);return t},e.Vector.prototype.similarity=function(e){return this.dot(e)/this.magnitude()||0},e.Vector.prototype.toArray=function(){for(var e=new Array(this.elements.length/2),t=1,r=0;t<this.elements.length;t+=2,r++)e[r]=this.elements[t];return e},e.Vector.prototype.toJSON=function(){return this.elements},e.stemmer=function(){var e={ational:"ate",tional:"tion",enci:"ence",anci:"ance",izer:"ize",bli:"ble",alli:"al",entli:"ent",eli:"e",ousli:"ous",ization:"ize",ation:"ate",ator:"ate",alism:"al",iveness:"ive",fulness:"ful",ousness:"ous",aliti:"al",iviti:"ive",biliti:"ble",logi:"log"},t={icate:"ic",ative:"",alize:"al",iciti:"ic",ical:"ic",ful:"",ness:""},r="[^aeiou]",i="[aeiouy]",n=r+"[^aeiouy]*",s=i+"[aeiou]*",o="^("+n+")?"+s+n,a="^("+n+")?"+s+n+"("+s+")?$",u="^("+n+")?"+s+n+s+n,l="^("+n+")?"+i,c=new RegExp(o),h=new RegExp(u),d=new RegExp(a),f=new RegExp(l),p=/^(.+?)(ss|i)es$/,y=/^(.+?)([^s])s$/,m=/^(.+?)eed$/,v=/^(.+?)(ed|ing)$/,g=/.$/,x=/(at|bl|iz)$/,w=new RegExp("([^aeiouylsz])\\1$"),Q=new RegExp("^"+n+i+"[^aeiouwxy]$"),k=/^(.+?[^aeiou])y$/,S=/^(.+?)(ational|tional|enci|anci|izer|bli|alli|entli|eli|ousli|ization|ation|ator|alism|iveness|fulness|ousness|aliti|iviti|biliti|logi)$/,E=/^(.+?)(icate|ative|alize|iciti|ical|ful|ness)$/,L=/^(.+?)(al|ance|ence|er|ic|able|ible|ant|ement|ment|ent|ou|ism|ate|iti|ous|ive|ize)$/,b=/^(.+?)(s|t)(ion)$/,P=/^(.+?)e$/,T=/ll$/,O=new RegExp("^"+n+i+"[^aeiouwxy]$"),I=function(r){var i,n,s,o,a,u,l;if(r.length<3)return r;if(s=r.substr(0,1),"y"==s&&(r=s.toUpperCase()+r.substr(1)),o=p,a=y,o.test(r)?r=r.replace(o,"$1$2"):a.test(r)&&(r=r.replace(a,"$1$2")),o=m,a=v,o.test(r)){var I=o.exec(r);o=c,o.test(I[1])&&(o=g,r=r.replace(o,""))}else if(a.test(r)){var I=a.exec(r);i=I[1],a=f,a.test(i)&&(r=i,a=x,u=w,l=Q,a.test(r)?r+="e":u.test(r)?(o=g,r=r.replace(o,"")):l.test(r)&&(r+="e"))}if(o=k,o.test(r)){var I=o.exec(r);i=I[1],r=i+"i"}if(o=S,o.test(r)){var I=o.exec(r);i=I[1],n=I[2],o=c,o.test(i)&&(r=i+e[n])}if(o=E,o.test(r)){var I=o.exec(r);i=I[1],n=I[2],o=c,o.test(i)&&(r=i+t[n])}if(o=L,a=b,o.test(r)){var I=o.exec(r);i=I[1],o=h,o.test(i)&&(r=i)}else if(a.test(r)){var I=a.exec(r);i=I[1]+I[2],a=h,a.test(i)&&(r=i)}if(o=P,o.test(r)){var I=o.exec(r);i=I[1],o=h,a=d,u=O,(o.test(i)||a.test(i)&&!u.test(i))&&(r=i)}return o=T,a=h,o.test(r)&&a.test(r)&&(o=g,r=r.replace(o,"")),"y"==s&&(r=s.toLowerCase()+r.substr(1)),r};return function(e){return e.update(I)}}(),e.Pipeline.registerFunction(e.stemmer,"stemmer"),e.generateStopWordFilter=function(e){var t=e.reduce(function(e,t){return e[t]=t,e},{});return function(e){if(e&&t[e.toString()]!==e.toString())return e}},e.stopWordFilter=e.generateStopWordFilter(["a","able","about","across","after","all","almost","also","am","among","an","and","any","are","as","at","be","because","been","but","by","can","cannot","could","dear","did","do","does","either","else","ever","every","for","from","get","got","had","has","have","he","her","hers","him","his","how","however","i","if","in","into","is","it","its","just","least","let","like","likely","may","me","might","most","must","my","neither","no","nor","not","of","off","often","on","only","or","other","our","own","rather","said","say","says","she","should","since","so","some","than","that","the","their","them","then","there","these","they","this","tis","to","too","twas","us","wants","was","we","were","what","when","where","which","while","who","whom","why","will","with","would","yet","you","your"]),e.Pipeline.registerFunction(e.stopWordFilter,"stopWordFilter"),e.trimmer=function(e){return e.update(function(e){return e.replace(/^\W+/,"").replace(/\W+$/,"")})},e.Pipeline.registerFunction(e.trimmer,"trimmer"),e.TokenSet=function(){this["final"]=!1,this.edges={},this.id=e.TokenSet._nextId,e.TokenSet._nextId+=1},e.TokenSet._nextId=1,e.TokenSet.fromArray=function(t){for(var r=new e.TokenSet.Builder,i=0,n=t.length;i<n;i++)r.insert(t[i]);return r.finish(),r.root},e.TokenSet.fromClause=function(t){return"editDistance"in t?e.TokenSet.fromFuzzyString(t.term,t.editDistance):e.TokenSet.fromString(t.term)},e.TokenSet.fromFuzzyString=function(t,r){for(var i=new e.TokenSet,n=[{node:i,editsRemaining:r,str:t}];n.length;){var s=n.pop();if(s.str.length>0){var o,a=s.str.charAt(0);a in s.node.edges?o=s.node.edges[a]:(o=new e.TokenSet,s.node.edges[a]=o),1==s.str.length&&(o["final"]=!0),n.push({node:o,editsRemaining:s.editsRemaining,str:s.str.slice(1)})}if(0!=s.editsRemaining){if("*"in s.node.edges)var u=s.node.edges["*"];else{var u=new e.TokenSet;s.node.edges["*"]=u}if(0==s.str.length&&(u["final"]=!0),n.push({node:u,editsRemaining:s.editsRemaining-1,str:s.str}),s.str.length>1&&n.push({node:s.node,editsRemaining:s.editsRemaining-1,str:s.str.slice(1)}),1==s.str.length&&(s.node["final"]=!0),s.str.length>=1){if("*"in s.node.edges)var l=s.node.edges["*"];else{var l=new e.TokenSet;s.node.edges["*"]=l}1==s.str.length&&(l["final"]=!0),n.push({node:l,editsRemaining:s.editsRemaining-1,str:s.str.slice(1)})}if(s.str.length>1){var c,h=s.str.charAt(0),d=s.str.charAt(1);d in s.node.edges?c=s.node.edges[d]:(c=new e.TokenSet,s.node.edges[d]=c),1==s.str.length&&(c["final"]=!0),n.push({node:c,editsRemaining:s.editsRemaining-1,str:h+s.str.slice(2)})}}}return i},e.TokenSet.fromString=function(t){for(var r=new e.TokenSet,i=r,n=0,s=t.length;n<s;n++){var o=t[n],a=n==s-1;if("*"==o)r.edges[o]=r,r["final"]=a;else{var u=new e.TokenSet;u["final"]=a,r.edges[o]=u,r=u}}return i},e.TokenSet.prototype.toArray=function(){for(var e=[],t=[{prefix:"",node:this}];t.length;){var r=t.pop(),i=Object.keys(r.node.edges),n=i.length;r.node["final"]&&(r.prefix.charAt(0),e.push(r.prefix));for(var s=0;s<n;s++){var o=i[s];t.push({prefix:r.prefix.concat(o),node:r.node.edges[o]})}}return e},e.TokenSet.prototype.toString=function(){if(this._str)return this._str;for(var e=this["final"]?"1":"0",t=Object.keys(this.edges).sort(),r=t.length,i=0;i<r;i++){var n=t[i],s=this.edges[n];e=e+n+s.id}return e},e.TokenSet.prototype.intersect=function(t){for(var r=new e.TokenSet,i=void 0,n=[{qNode:t,output:r,node:this}];n.length;){i=n.pop();for(var s=Object.keys(i.qNode.edges),o=s.length,a=Object.keys(i.node.edges),u=a.length,l=0;l<o;l++)for(var c=s[l],h=0;h<u;h++){var d=a[h];if(d==c||"*"==c){var f=i.node.edges[d],p=i.qNode.edges[c],y=f["final"]&&p["final"],m=void 0;d in i.output.edges?(m=i.output.edges[d],m["final"]=m["final"]||y):(m=new e.TokenSet,m["final"]=y,i.output.edges[d]=m),n.push({qNode:p,output:m,node:f})}}}return r},e.TokenSet.Builder=function(){this.previousWord="",this.root=new e.TokenSet,this.uncheckedNodes=[],this.minimizedNodes={}},e.TokenSet.Builder.prototype.insert=function(t){var r,i=0;if(t<this.previousWord)throw new Error("Out of order word insertion");for(var n=0;n<t.length&&n<this.previousWord.length&&t[n]==this.previousWord[n];n++)i++;this.minimize(i),r=0==this.uncheckedNodes.length?this.root:this.uncheckedNodes[this.uncheckedNodes.length-1].child;for(var n=i;n<t.length;n++){var s=new e.TokenSet,o=t[n];r.edges[o]=s,this.uncheckedNodes.push({parent:r,"char":o,child:s}),r=s}r["final"]=!0,this.previousWord=t},e.TokenSet.Builder.prototype.finish=function(){this.minimize(0)},e.TokenSet.Builder.prototype.minimize=function(e){for(var t=this.uncheckedNodes.length-1;t>=e;t--){var r=this.uncheckedNodes[t],i=r.child.toString();i in this.minimizedNodes?r.parent.edges[r["char"]]=this.minimizedNodes[i]:(r.child._str=i,this.minimizedNodes[i]=r.child),this.uncheckedNodes.pop()}},e.Index=function(e){this.invertedIndex=e.invertedIndex,this.fieldVectors=e.fieldVectors,this.tokenSet=e.tokenSet,this.fields=e.fields,this.pipeline=e.pipeline},e.Index.prototype.search=function(t){return this.query(function(r){var i=new e.QueryParser(t,r);i.parse()})},e.Index.prototype.query=function(t){for(var r=new e.Query(this.fields),i=Object.create(null),n=Object.create(null),s=Object.create(null),o=Object.create(null),a=Object.create(null),u=0;u<this.fields.length;u++)n[this.fields[u]]=new e.Vector;t.call(r,r);for(var u=0;u<r.clauses.length;u++){var l=r.clauses[u],c=null,h=e.Set.empty;c=l.usePipeline?this.pipeline.runString(l.term,{fields:l.fields}):[l.term];for(var d=0;d<c.length;d++){var f=c[d];l.term=f;var p=e.TokenSet.fromClause(l),y=this.tokenSet.intersect(p).toArray();if(0===y.length&&l.presence===e.Query.presence.REQUIRED){for(var m=0;m<l.fields.length;m++){var v=l.fields[m];o[v]=e.Set.empty}break}for(var g=0;g<y.length;g++)for(var x=y[g],w=this.invertedIndex[x],Q=w._index,m=0;m<l.fields.length;m++){var v=l.fields[m],k=w[v],S=Object.keys(k),E=x+"/"+v,L=new e.Set(S);if(l.presence==e.Query.presence.REQUIRED&&(h=h.union(L),void 0===o[v]&&(o[v]=e.Set.complete)),l.presence!=e.Query.presence.PROHIBITED){if(n[v].upsert(Q,l.boost,function(e,t){return e+t}),!s[E]){for(var b=0;b<S.length;b++){var P,T=S[b],O=new e.FieldRef(T,v),I=k[T];void 0===(P=i[O])?i[O]=new e.MatchData(x,v,I):P.add(x,v,I)}s[E]=!0}}else void 0===a[v]&&(a[v]=e.Set.empty),a[v]=a[v].union(L)}}if(l.presence===e.Query.presence.REQUIRED)for(var m=0;m<l.fields.length;m++){var v=l.fields[m];o[v]=o[v].intersect(h)}}for(var R=e.Set.complete,F=e.Set.empty,u=0;u<this.fields.length;u++){var v=this.fields[u];o[v]&&(R=R.intersect(o[v])),a[v]&&(F=F.union(a[v]))}var C=Object.keys(i),N=[],_=Object.create(null);if(r.isNegated()){C=Object.keys(this.fieldVectors);for(var u=0;u<C.length;u++){var O=C[u],j=e.FieldRef.fromString(O);i[O]=new e.MatchData}}for(var u=0;u<C.length;u++){var j=e.FieldRef.fromString(C[u]),D=j.docRef;if(R.contains(D)&&!F.contains(D)){var A,B=this.fieldVectors[j],V=n[j.fieldName].similarity(B);if(void 0!==(A=_[D]))A.score+=V,A.matchData.combine(i[j]);else{var z={ref:D,score:V,matchData:i[j]};_[D]=z,N.push(z)}}}return N.sort(function(e,t){return t.score-e.score})},e.Index.prototype.toJSON=function(){var t=Object.keys(this.invertedIndex).sort().map(function(e){return[e,this.invertedIndex[e]]},this),r=Object.keys(this.fieldVectors).map(function(e){return[e,this.fieldVectors[e].toJSON()]},this);return{version:e.version,fields:this.fields,fieldVectors:r,invertedIndex:t,pipeline:this.pipeline.toJSON()}},e.Index.load=function(t){var r={},i={},n=t.fieldVectors,s=Object.create(null),o=t.invertedIndex,a=new e.TokenSet.Builder,u=e.Pipeline.load(t.pipeline);t.version!=e.version&&e.utils.warn("Version mismatch when loading serialised index. Current version of lunr '"+e.version+"' does not match serialized index '"+t.version+"'");for(var l=0;l<n.length;l++){var c=n[l],h=c[0],d=c[1];i[h]=new e.Vector(d)}for(var l=0;l<o.length;l++){var c=o[l],f=c[0],p=c[1];a.insert(f),s[f]=p}return a.finish(),r.fields=t.fields,r.fieldVectors=i,r.invertedIndex=s,r.tokenSet=a.root,r.pipeline=u,new e.Index(r)},e.Builder=function(){this._ref="id",this._fields=Object.create(null),this._documents=Object.create(null),this.invertedIndex=Object.create(null),this.fieldTermFrequencies={},this.fieldLengths={},this.tokenizer=e.tokenizer,this.pipeline=new e.Pipeline,this.searchPipeline=new e.Pipeline,this.documentCount=0,this._b=.75,this._k1=1.2,this.termIndex=0,this.metadataWhitelist=[]},e.Builder.prototype.ref=function(e){this._ref=e},e.Builder.prototype.field=function(e,t){if(/\//.test(e))throw new RangeError("Field '"+e+"' contains illegal character '/'");this._fields[e]=t||{}},e.Builder.prototype.b=function(e){e<0?this._b=0:e>1?this._b=1:this._b=e},e.Builder.prototype.k1=function(e){this._k1=e},e.Builder.prototype.add=function(t,r){var i=t[this._ref],n=Object.keys(this._fields);this._documents[i]=r||{},this.documentCount+=1;for(var s=0;s<n.length;s++){var o=n[s],a=this._fields[o].extractor,u=a?a(t):t[o],l=this.tokenizer(u,{fields:[o]}),c=this.pipeline.run(l),h=new e.FieldRef(i,o),d=Object.create(null);this.fieldTermFrequencies[h]=d,this.fieldLengths[h]=0,this.fieldLengths[h]+=c.length;for(var f=0;f<c.length;f++){var p=c[f];if(void 0==d[p]&&(d[p]=0),d[p]+=1,void 0==this.invertedIndex[p]){var y=Object.create(null);y._index=this.termIndex,this.termIndex+=1;for(var m=0;m<n.length;m++)y[n[m]]=Object.create(null);this.invertedIndex[p]=y}void 0==this.invertedIndex[p][o][i]&&(this.invertedIndex[p][o][i]=Object.create(null));for(var v=0;v<this.metadataWhitelist.length;v++){var g=this.metadataWhitelist[v],x=p.metadata[g];void 0==this.invertedIndex[p][o][i][g]&&(this.invertedIndex[p][o][i][g]=[]),this.invertedIndex[p][o][i][g].push(x)}}}},e.Builder.prototype.calculateAverageFieldLengths=function(){for(var t=Object.keys(this.fieldLengths),r=t.length,i={},n={},s=0;s<r;s++){var o=e.FieldRef.fromString(t[s]),a=o.fieldName;n[a]||(n[a]=0),n[a]+=1,i[a]||(i[a]=0),i[a]+=this.fieldLengths[o]}for(var u=Object.keys(this._fields),s=0;s<u.length;s++){var l=u[s];i[l]=i[l]/n[l]}this.averageFieldLength=i},e.Builder.prototype.createFieldVectors=function(){for(var t={},r=Object.keys(this.fieldTermFrequencies),i=r.length,n=Object.create(null),s=0;s<i;s++){for(var o=e.FieldRef.fromString(r[s]),a=o.fieldName,u=this.fieldLengths[o],l=new e.Vector,c=this.fieldTermFrequencies[o],h=Object.keys(c),d=h.length,f=this._fields[a].boost||1,p=this._documents[o.docRef].boost||1,y=0;y<d;y++){var m,v,g,x=h[y],w=c[x],Q=this.invertedIndex[x]._index;void 0===n[x]?(m=e.idf(this.invertedIndex[x],this.documentCount),n[x]=m):m=n[x],v=m*((this._k1+1)*w)/(this._k1*(1-this._b+this._b*(u/this.averageFieldLength[a]))+w),v*=f,v*=p,g=Math.round(1e3*v)/1e3,l.insert(Q,g)}t[o]=l}this.fieldVectors=t},e.Builder.prototype.createTokenSet=function(){this.tokenSet=e.TokenSet.fromArray(Object.keys(this.invertedIndex).sort())},e.Builder.prototype.build=function(){return this.calculateAverageFieldLengths(),this.createFieldVectors(),this.createTokenSet(),new e.Index({invertedIndex:this.invertedIndex,fieldVectors:this.fieldVectors,tokenSet:this.tokenSet,fields:Object.keys(this._fields),pipeline:this.searchPipeline})},e.Builder.prototype.use=function(e){var t=Array.prototype.slice.call(arguments,1);t.unshift(this),e.apply(this,t)},e.MatchData=function(e,t,r){for(var i=Object.create(null),n=Object.keys(r||{}),s=0;s<n.length;s++){var o=n[s];i[o]=r[o].slice()}this.metadata=Object.create(null),void 0!==e&&(this.metadata[e]=Object.create(null),this.metadata[e][t]=i)},e.MatchData.prototype.combine=function(e){for(var t=Object.keys(e.metadata),r=0;r<t.length;r++){var i=t[r],n=Object.keys(e.metadata[i]);void 0==this.metadata[i]&&(this.metadata[i]=Object.create(null));for(var s=0;s<n.length;s++){var o=n[s],a=Object.keys(e.metadata[i][o]);void 0==this.metadata[i][o]&&(this.metadata[i][o]=Object.create(null));for(var u=0;u<a.length;u++){var l=a[u];void 0==this.metadata[i][o][l]?this.metadata[i][o][l]=e.metadata[i][o][l]:this.metadata[i][o][l]=this.metadata[i][o][l].concat(e.metadata[i][o][l])}}}},e.MatchData.prototype.add=function(e,t,r){if(!(e in this.metadata))return this.metadata[e]=Object.create(null),void(this.metadata[e][t]=r);if(!(t in this.metadata[e]))return void(this.metadata[e][t]=r);for(var i=Object.keys(r),n=0;n<i.length;n++){var s=i[n];s in this.metadata[e][t]?this.metadata[e][t][s]=this.metadata[e][t][s].concat(r[s]):this.metadata[e][t][s]=r[s]}},e.Query=function(e){this.clauses=[],this.allFields=e},e.Query.wildcard=new String("*"),e.Query.wildcard.NONE=0,e.Query.wildcard.LEADING=1,e.Query.wildcard.TRAILING=2,e.Query.presence={OPTIONAL:1,REQUIRED:2,PROHIBITED:3},e.Query.prototype.clause=function(t){return"fields"in t||(t.fields=this.allFields),"boost"in t||(t.boost=1),"usePipeline"in t||(t.usePipeline=!0),"wildcard"in t||(t.wildcard=e.Query.wildcard.NONE),t.wildcard&e.Query.wildcard.LEADING&&t.term.charAt(0)!=e.Query.wildcard&&(t.term="*"+t.term),t.wildcard&e.Query.wildcard.TRAILING&&t.term.slice(-1)!=e.Query.wildcard&&(t.term=""+t.term+"*"),"presence"in t||(t.presence=e.Query.presence.OPTIONAL),this.clauses.push(t),this},e.Query.prototype.isNegated=function(){for(var t=0;t<this.clauses.length;t++)if(this.clauses[t].presence!=e.Query.presence.PROHIBITED)return!1;return!0},e.Query.prototype.term=function(t,r){if(Array.isArray(t))return t.forEach(function(t){this.term(t,e.utils.clone(r))},this),this;var i=r||{};return i.term=t.toString(),this.clause(i),this},e.QueryParseError=function(e,t,r){this.name="QueryParseError",this.message=e,this.start=t,this.end=r},e.QueryParseError.prototype=new Error,e.QueryLexer=function(e){this.lexemes=[],this.str=e,this.length=e.length,this.pos=0,this.start=0,this.escapeCharPositions=[]},e.QueryLexer.prototype.run=function(){for(var t=e.QueryLexer.lexText;t;)t=t(this)},e.QueryLexer.prototype.sliceString=function(){for(var e=[],t=this.start,r=this.pos,i=0;i<this.escapeCharPositions.length;i++)r=this.escapeCharPositions[i],e.push(this.str.slice(t,r)),t=r+1;return e.push(this.str.slice(t,this.pos)),this.escapeCharPositions.length=0,e.join("")},e.QueryLexer.prototype.emit=function(e){this.lexemes.push({type:e,str:this.sliceString(),start:this.start,end:this.pos}),this.start=this.pos},e.QueryLexer.prototype.escapeCharacter=function(){this.escapeCharPositions.push(this.pos-1),this.pos+=1},e.QueryLexer.prototype.next=function(){if(this.pos>=this.length)return e.QueryLexer.EOS;var t=this.str.charAt(this.pos);return this.pos+=1,t},e.QueryLexer.prototype.width=function(){return this.pos-this.start},e.QueryLexer.prototype.ignore=function(){this.start==this.pos&&(this.pos+=1),this.start=this.pos},e.QueryLexer.prototype.backup=function(){this.pos-=1},e.QueryLexer.prototype.acceptDigitRun=function(){var t,r;do t=this.next(),r=t.charCodeAt(0);while(r>47&&r<58);t!=e.QueryLexer.EOS&&this.backup()},e.QueryLexer.prototype.more=function(){return this.pos<this.length},e.QueryLexer.EOS="EOS",e.QueryLexer.FIELD="FIELD",e.QueryLexer.TERM="TERM",e.QueryLexer.EDIT_DISTANCE="EDIT_DISTANCE",e.QueryLexer.BOOST="BOOST",e.QueryLexer.PRESENCE="PRESENCE",e.QueryLexer.lexField=function(t){return t.backup(),t.emit(e.QueryLexer.FIELD),t.ignore(),e.QueryLexer.lexText},e.QueryLexer.lexTerm=function(t){if(t.width()>1&&(t.backup(),t.emit(e.QueryLexer.TERM)),t.ignore(),t.more())return e.QueryLexer.lexText},e.QueryLexer.lexEditDistance=function(t){return t.ignore(),t.acceptDigitRun(),t.emit(e.QueryLexer.EDIT_DISTANCE),e.QueryLexer.lexText},e.QueryLexer.lexBoost=function(t){return t.ignore(),t.acceptDigitRun(),t.emit(e.QueryLexer.BOOST),e.QueryLexer.lexText},e.QueryLexer.lexEOS=function(t){t.width()>0&&t.emit(e.QueryLexer.TERM)},e.QueryLexer.termSeparator=e.tokenizer.separator,e.QueryLexer.lexText=function(t){for(;;){var r=t.next();if(r==e.QueryLexer.EOS)return e.QueryLexer.lexEOS;if(92!=r.charCodeAt(0)){if(":"==r)return e.QueryLexer.lexField;if("~"==r)return t.backup(),t.width()>0&&t.emit(e.QueryLexer.TERM),e.QueryLexer.lexEditDistance;if("^"==r)return t.backup(),t.width()>0&&t.emit(e.QueryLexer.TERM),e.QueryLexer.lexBoost;if("+"==r&&1===t.width())return t.emit(e.QueryLexer.PRESENCE),e.QueryLexer.lexText;if("-"==r&&1===t.width())return t.emit(e.QueryLexer.PRESENCE),e.QueryLexer.lexText;if(r.match(e.QueryLexer.termSeparator))return e.QueryLexer.lexTerm}else t.escapeCharacter()}},e.QueryParser=function(t,r){this.lexer=new e.QueryLexer(t),this.query=r,this.currentClause={},this.lexemeIdx=0},e.QueryParser.prototype.parse=function(){this.lexer.run(),this.lexemes=this.lexer.lexemes;for(var t=e.QueryParser.parseClause;t;)t=t(this);return this.query},e.QueryParser.prototype.peekLexeme=function(){return this.lexemes[this.lexemeIdx]},e.QueryParser.prototype.consumeLexeme=function(){var e=this.peekLexeme();return this.lexemeIdx+=1,e},e.QueryParser.prototype.nextClause=function(){var e=this.currentClause;this.query.clause(e),this.currentClause={}},e.QueryParser.parseClause=function(t){var r=t.peekLexeme();if(void 0!=r)switch(r.type){case e.QueryLexer.PRESENCE:return e.QueryParser.parsePresence;case e.QueryLexer.FIELD:return e.QueryParser.parseField;case e.QueryLexer.TERM:return e.QueryParser.parseTerm;default:var i="expected either a field or a term, found "+r.type;throw r.str.length>=1&&(i+=" with value '"+r.str+"'"),new e.QueryParseError(i,r.start,r.end)}},e.QueryParser.parsePresence=function(t){var r=t.consumeLexeme();if(void 0!=r){switch(r.str){case"-":t.currentClause.presence=e.Query.presence.PROHIBITED;break;case"+":t.currentClause.presence=e.Query.presence.REQUIRED;break;default:var i="unrecognised presence operator'"+r.str+"'";throw new e.QueryParseError(i,r.start,r.end)}var n=t.peekLexeme();if(void 0==n){var i="expecting term or field, found nothing";throw new e.QueryParseError(i,r.start,r.end)}switch(n.type){case e.QueryLexer.FIELD:return e.QueryParser.parseField;case e.QueryLexer.TERM:return e.QueryParser.parseTerm;default:var i="expecting term or field, found '"+n.type+"'";throw new e.QueryParseError(i,n.start,n.end)}}},e.QueryParser.parseField=function(t){var r=t.consumeLexeme();if(void 0!=r){if(t.query.allFields.indexOf(r.str)==-1){var i=t.query.allFields.map(function(e){return"'"+e+"'"}).join(", "),n="unrecognised field '"+r.str+"', possible fields: "+i;throw new e.QueryParseError(n,r.start,r.end)}t.currentClause.fields=[r.str];var s=t.peekLexeme();if(void 0==s){var n="expecting term, found nothing";throw new e.QueryParseError(n,r.start,r.end)}switch(s.type){case e.QueryLexer.TERM:return e.QueryParser.parseTerm;default:var n="expecting term, found '"+s.type+"'";throw new e.QueryParseError(n,s.start,s.end)}}},e.QueryParser.parseTerm=function(t){var r=t.consumeLexeme();if(void 0!=r){t.currentClause.term=r.str.toLowerCase(),r.str.indexOf("*")!=-1&&(t.currentClause.usePipeline=!1);var i=t.peekLexeme();if(void 0==i)return void t.nextClause();switch(i.type){case e.QueryLexer.TERM:return t.nextClause(),e.QueryParser.parseTerm;case e.QueryLexer.FIELD:return t.nextClause(),e.QueryParser.parseField;case e.QueryLexer.EDIT_DISTANCE:return e.QueryParser.parseEditDistance;case e.QueryLexer.BOOST:return e.QueryParser.parseBoost;case e.QueryLexer.PRESENCE:return t.nextClause(),e.QueryParser.parsePresence;default:var n="Unexpected lexeme type '"+i.type+"'";throw new e.QueryParseError(n,i.start,i.end)}}},e.QueryParser.parseEditDistance=function(t){var r=t.consumeLexeme();if(void 0!=r){var i=parseInt(r.str,10);if(isNaN(i)){var n="edit distance must be numeric";throw new e.QueryParseError(n,r.start,r.end)}t.currentClause.editDistance=i;var s=t.peekLexeme();if(void 0==s)return void t.nextClause();switch(s.type){case e.QueryLexer.TERM:return t.nextClause(),e.QueryParser.parseTerm;case e.QueryLexer.FIELD:return t.nextClause(),e.QueryParser.parseField;case e.QueryLexer.EDIT_DISTANCE:return e.QueryParser.parseEditDistance;case e.QueryLexer.BOOST:return e.QueryParser.parseBoost;case e.QueryLexer.PRESENCE:return t.nextClause(),e.QueryParser.parsePresence;default:var n="Unexpected lexeme type '"+s.type+"'";throw new e.QueryParseError(n,s.start,s.end)}}},e.QueryParser.parseBoost=function(t){var r=t.consumeLexeme();if(void 0!=r){var i=parseInt(r.str,10);if(isNaN(i)){var n="boost must be numeric";throw new e.QueryParseError(n,r.start,r.end)}t.currentClause.boost=i;var s=t.peekLexeme();if(void 0==s)return void t.nextClause();switch(s.type){case e.QueryLexer.TERM:return t.nextClause(),e.QueryParser.parseTerm;case e.QueryLexer.FIELD:return t.nextClause(),e.QueryParser.parseField;case e.QueryLexer.EDIT_DISTANCE:return e.QueryParser.parseEditDistance;case e.QueryLexer.BOOST:return e.QueryParser.parseBoost;case e.QueryLexer.PRESENCE:return t.nextClause(),e.QueryParser.parsePresence;default:var n="Unexpected lexeme type '"+s.type+"'";throw new e.QueryParseError(n,s.start,s.end)}}},function(e,t){"function"==typeof define&&define.amd?define(t):"object"==typeof exports?module.exports=t():e.lunr=t()}(this,function(){return e})}();

        """##
    }
}
