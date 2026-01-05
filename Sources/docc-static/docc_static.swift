//
// docc_static.swift
// docc-static
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import ArgumentParser
import DocCStatic

@main
struct DocCStaticCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "docc-static",
        abstract: "Generate static HTML documentation for Swift packages.",
        discussion: """
            DocCStatic generates pure HTML/CSS documentation that works without
            JavaScript. The output can be viewed locally as file:// URLs or
            hosted on any static web server.
            """,
        version: "0.1.0",
        subcommands: [
            Generate.self,
            Render.self,
            Preview.self,
        ],
        defaultSubcommand: Generate.self
    )
}

// MARK: - Generate Command

struct Generate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate static documentation for a Swift package."
    )

    @Option(name: .shortAndLong, help: "Path to the package directory.")
    var packagePath: String = "."

    @Option(name: .shortAndLong, help: "Output directory for generated documentation.")
    var output: String = ".build/documentation"

    @Option(name: .long, help: "Scratch path for Swift build operations.")
    var scratchPath: String?

    @Option(name: .long, help: "Pre-generated symbol graph directory (skips build step).")
    var symbolGraphDir: String?

    @Option(name: .shortAndLong, help: "Specific targets to document (can be repeated).")
    var target: [String] = []

    @Flag(name: [.customShort("I"), .long], help: "Include documentation for all dependencies.")
    var includeAllDependencies: Bool = false

    @Option(name: [.customShort("i"), .long], help: "Include a specific dependency (can be repeated).")
    var includeDependency: [String] = []

    @Option(name: [.customShort("x"), .customLong("exclude-dependency")], help: "Exclude a specific dependency (can be repeated). Only used with -I.")
    var excludeDependency: [String] = []

    @Option(name: .shortAndLong, help: "External documentation URL for a dependency (format: PackageName=URL).")
    var externalDocs: [String] = []

    @Flag(name: [.customShort("D"), .customLong("disable-search")], help: "Disable client-side search functionality.")
    var disableSearch: Bool = false

    @Flag(name: [.customShort("v"), .customLong("verbose")], help: "Enable verbose output.")
    var isVerbose: Bool = false

    @Option(name: .long, help: "Custom HTML for the page footer.")
    var footer: String?

    mutating func run() async throws {
        let packageDirectory = URL(fileURLWithPath: packagePath).standardizedFileURL
        let outputDirectory = URL(fileURLWithPath: output).standardizedFileURL

        // Parse external documentation URLs
        var externalURLs: [String: URL] = [:]
        for mapping in externalDocs {
            let parts = mapping.split(separator: "=", maxSplits: 1)
            guard parts.count == 2, let url = URL(string: String(parts[1])) else {
                throw ValidationError("Invalid external-docs format: \(mapping). Expected: PackageName=URL")
            }
            externalURLs[String(parts[0])] = url
        }

        // Determine dependency policy
        // Default: exclude all dependencies (only document current package targets)
        // -I: include all dependencies
        // -i: include specific dependencies
        // -x: exclude specific dependencies (only with -I)
        let dependencyPolicy: DependencyInclusionPolicy
        if includeAllDependencies {
            if !excludeDependency.isEmpty {
                dependencyPolicy = .exclude(excludeDependency)
            } else {
                dependencyPolicy = .all
            }
        } else if !includeDependency.isEmpty {
            dependencyPolicy = .includeOnly(includeDependency)
        } else {
            dependencyPolicy = .none
        }

        let configuration = Configuration(
            packageDirectory: packageDirectory,
            outputDirectory: outputDirectory,
            targets: target,
            dependencyPolicy: dependencyPolicy,
            externalDocumentationURLs: externalURLs,
            includeSearch: !disableSearch,
            isVerbose: isVerbose,
            scratchPath: scratchPath.map { URL(fileURLWithPath: $0).standardizedFileURL },
            symbolGraphDir: symbolGraphDir.map { URL(fileURLWithPath: $0).standardizedFileURL },
            footerHTML: footer
        )

        let generator = StaticDocumentationGenerator(configuration: configuration)

        do {
            let result = try await generator.generate()

            print("""
                Documentation generated successfully!
                  Output: \(result.outputDirectory.path)
                  Pages: \(result.generatedPages)
                  Modules: \(result.modulesDocumented)
                  Symbols: \(result.symbolsDocumented)
                """)

            if !result.warnings.isEmpty {
                print("\nWarnings:")
                for warning in result.warnings {
                    print("  \(warning)")
                }
            }

            if let searchPath = result.searchIndexPath {
                print("\nSearch index: \(searchPath.path)")
            }
        } catch {
            throw CleanExit.message("Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Render Command

struct Render: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Render static HTML from an existing DocC archive."
    )

    @Argument(help: "Path to the .doccarchive directory.")
    var archivePath: String

    @Option(name: .shortAndLong, help: "Output directory for generated documentation.")
    var output: String = ".build/documentation"

    @Flag(name: [.customShort("D"), .customLong("disable-search")], help: "Disable client-side search functionality.")
    var disableSearch: Bool = false

    @Flag(name: [.customShort("v"), .customLong("verbose")], help: "Enable verbose output.")
    var isVerbose: Bool = false

    @Option(name: .long, help: "Custom HTML for the page footer.")
    var footer: String?

    mutating func run() async throws {
        let archiveURL = URL(fileURLWithPath: archivePath).standardizedFileURL
        let outputDirectory = URL(fileURLWithPath: output).standardizedFileURL

        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw ValidationError("Archive does not exist: \(archiveURL.path)")
        }

        let configuration = Configuration(
            packageDirectory: archiveURL,  // Not used for render
            outputDirectory: outputDirectory,
            targets: [],
            dependencyPolicy: .none,
            externalDocumentationURLs: [:],
            includeSearch: !disableSearch,
            isVerbose: isVerbose,
            scratchPath: nil,
            symbolGraphDir: nil,
            footerHTML: footer
        )

        let generator = StaticDocumentationGenerator(configuration: configuration)

        do {
            let result = try await generator.renderFromArchive(archiveURL)

            print("""
                Documentation rendered successfully!
                  Output: \(result.outputDirectory.path)
                  Pages: \(result.generatedPages)
                """)

            if !result.warnings.isEmpty {
                print("\nWarnings:")
                for warning in result.warnings {
                    print("  \(warning)")
                }
            }
        } catch {
            throw CleanExit.message("Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview Command

struct Preview: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start a local preview server for generated documentation."
    )

    @Option(name: .shortAndLong, help: "Directory containing generated documentation.")
    var output: String = ".build/documentation"

    @Option(name: .shortAndLong, help: "Port to run the preview server on.")
    var port: Int = 8080

    mutating func run() async throws {
        let docDirectory = URL(fileURLWithPath: output).standardizedFileURL

        guard FileManager.default.fileExists(atPath: docDirectory.path) else {
            throw ValidationError("Documentation directory does not exist: \(docDirectory.path)")
        }

        print("""
            Starting preview server...
              Directory: \(docDirectory.path)
              URL: http://localhost:\(port)/

            Press Ctrl+C to stop.
            """)

        // TODO: Implement simple HTTP server using SwiftNIO
        // For now, suggest using Python's built-in server
        print("""

            Tip: You can also use Python's built-in server:
              cd \(docDirectory.path) && python3 -m http.server \(port)
            """)
    }
}
