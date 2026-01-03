//
// StaticHTMLConsumer.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import SwiftDocC

/// A consumer that writes documentation to static HTML files.
///
/// This type implements the `ConvertOutputConsumer` protocol from SwiftDocC,
/// receiving render nodes and writing them as static HTML pages.
public final class StaticHTMLConsumer: ConvertOutputConsumer, @unchecked Sendable {
    /// The output directory for generated documentation.
    public let outputDirectory: URL

    /// The configuration for HTML generation.
    public let configuration: Configuration

    /// The navigation index for building the sidebar.
    public var navigationIndex: NavigationIndex?

    /// Statistics about generated content.
    private var stats = GenerationStats()

    /// Warnings encountered during generation.
    private var warnings: [Warning] = []

    /// Lock for thread-safe access to mutable state.
    private let lock = NSLock()

    /// The HTML page builder.
    private var pageBuilder: HTMLPageBuilder

    /// Collected references for cross-linking.
    private var collectedReferences: [String: any RenderReference] = [:]

    /// Creates a new static HTML consumer.
    ///
    /// - Parameters:
    ///   - outputDirectory: The directory where HTML files will be written.
    ///   - configuration: The generation configuration.
    public init(outputDirectory: URL, configuration: Configuration) {
        self.outputDirectory = outputDirectory
        self.configuration = configuration
        self.pageBuilder = HTMLPageBuilder(configuration: configuration, navigationIndex: nil)
    }
}

// MARK: - ConvertOutputConsumer

public extension StaticHTMLConsumer {
    func consume(renderNode: RenderNode) throws {
        // Update page builder with navigation index if available
        if pageBuilder.navigationIndex == nil, let navIndex = navigationIndex {
            pageBuilder = HTMLPageBuilder(configuration: configuration, navigationIndex: navIndex)
        }

        let html = try pageBuilder.buildPage(from: renderNode, references: renderNode.references)
        let outputPath = self.outputPath(for: renderNode)

        // Ensure parent directory exists
        let parentDir = outputPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // Write the HTML file
        try html.write(to: outputPath, atomically: true, encoding: .utf8)

        // Update statistics
        lock.lock()
        defer { lock.unlock() }

        stats.pagesGenerated += 1

        switch renderNode.kind {
        case .symbol:
            stats.symbolsDocumented += 1
        case .article:
            stats.articlesGenerated += 1
        case .tutorial:
            stats.tutorialsGenerated += 1
        case .section, .overview:
            break
        @unknown default:
            break
        }

        // Collect references for cross-linking
        for (key, reference) in renderNode.references {
            collectedReferences[key] = reference
        }

        if configuration.isVerbose {
            print("[DocCStatic] Generated: \(outputPath.path)")
        }
    }

    func consume(assetsInBundle bundle: DocumentationBundle) throws {
        // Copy assets from the bundle to the output directory
        let assetsDir = outputDirectory.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)

        // Bundle assets are handled separately - this is called to inform us about the bundle
        if configuration.isVerbose {
            print("[DocCStatic] Processing assets from bundle: \(bundle.displayName)")
        }
    }

    func consume(linkableElementSummaries: [LinkDestinationSummary]) throws {
        // Store link summaries for cross-linking
        lock.lock()
        defer { lock.unlock() }

        if configuration.isVerbose {
            print("[DocCStatic] Received \(linkableElementSummaries.count) linkable element summaries")
        }
    }

    func consume(indexingRecords: [IndexingRecord]) throws {
        // Store indexing records for search functionality
        lock.lock()
        defer { lock.unlock() }

        if configuration.isVerbose {
            print("[DocCStatic] Received \(indexingRecords.count) indexing records")
        }
    }

    func consume(assets: [RenderReferenceType: [any RenderReference]]) throws {
        // Process asset references
        if configuration.isVerbose {
            let totalAssets = assets.values.reduce(0) { $0 + $1.count }
            print("[DocCStatic] Received \(totalAssets) asset references")
        }
    }

    func consume(benchmarks: Benchmark) throws {
        // We don't need benchmark data for static generation
    }

    func consume(documentationCoverageInfo: [CoverageDataEntry]) throws {
        // Store coverage info if needed
        if configuration.isVerbose {
            print("[DocCStatic] Documentation coverage: \(documentationCoverageInfo.count) entries")
        }
    }

    // MARK: - Results

    /// Returns the generation result after all content has been consumed.
    func result() -> GenerationResult {
        lock.lock()
        defer { lock.unlock() }

        return GenerationResult(
            outputDirectory: outputDirectory,
            generatedPages: stats.pagesGenerated,
            modulesDocumented: stats.modulesDocumented,
            symbolsDocumented: stats.symbolsDocumented,
            articlesGenerated: stats.articlesGenerated,
            tutorialsGenerated: stats.tutorialsGenerated,
            warnings: warnings,
            searchIndexPath: configuration.includeSearch
            ? outputDirectory.appendingPathComponent("search-index.json")
            : nil
        )
    }
}

// MARK: - Private

private extension StaticHTMLConsumer {
    func outputPath(for renderNode: RenderNode) -> URL {
        // Convert the reference path to a file system path
        let referencePath = renderNode.identifier.path
        let components = referencePath
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .components(separatedBy: "/")
            .filter { !$0.isEmpty }

        var path = outputDirectory
        for component in components {
            path = path.appendingPathComponent(component.lowercased())
        }
        path = path.appendingPathComponent("index.html")

        return path
    }

    func addWarning(_ warning: Warning) {
        lock.lock()
        defer { lock.unlock() }
        warnings.append(warning)
    }
}

// MARK: - Generation Statistics

private struct GenerationStats {
    var pagesGenerated = 0
    var modulesDocumented = 0
    var symbolsDocumented = 0
    var articlesGenerated = 0
    var tutorialsGenerated = 0
}
