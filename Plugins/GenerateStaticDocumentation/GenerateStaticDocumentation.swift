//
// GenerateStaticDocumentation.swift
// GenerateStaticDocumentation
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import PackagePlugin

@main
struct GenerateStaticDocumentation: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        // Locate the docc-static executable
        let tool = try context.tool(named: "docc-static")

        // Parse arguments to extract our options
        var argumentExtractor = ArgumentExtractor(arguments)

        // Extract output directory option (default to plugin work directory)
        let outputDir = argumentExtractor.extractOption(named: "output")
            ?? context.pluginWorkDirectoryURL.appending(path: "documentation").path()

        // Extract other options
        let specifiedTargets = argumentExtractor.extractOption(named: "target", allowMultiple: true)
        let includeAllDeps = argumentExtractor.extractFlag(named: "include-all-dependencies")
        let includeDeps = argumentExtractor.extractOption(named: "include-dependency", allowMultiple: true)
        let excludeDeps = argumentExtractor.extractOption(named: "exclude-dependency", allowMultiple: true)
        let externalDocs = argumentExtractor.extractOption(named: "external-docs", allowMultiple: true)
        let includeSearch = argumentExtractor.extractFlag(named: "include-search")
        let verbose = argumentExtractor.extractFlag(named: "verbose")

        // Determine which targets to document
        let sourceModuleTargets: [SourceModuleTarget]
        if specifiedTargets.isEmpty {
            // Document all library and executable targets
            sourceModuleTargets = context.package.targets.compactMap { $0 as? SourceModuleTarget }
                .filter { $0.kind == .generic || $0.kind == .executable }
        } else {
            sourceModuleTargets = context.package.targets.compactMap { target -> SourceModuleTarget? in
                guard let sourceTarget = target as? SourceModuleTarget,
                      specifiedTargets.contains(target.name) else {
                    return nil
                }
                return sourceTarget
            }
        }

        guard !sourceModuleTargets.isEmpty else {
            Diagnostics.error("No documentable targets found in package")
            return
        }

        // Generate symbol graphs for each target using PackageManager API
        let symbolGraphsDir = URL(fileURLWithPath: context.pluginWorkDirectoryURL
            .appending(path: "symbol-graphs").path())

        try? FileManager.default.removeItem(at: symbolGraphsDir)
        try FileManager.default.createDirectory(at: symbolGraphsDir, withIntermediateDirectories: true)

        for target in sourceModuleTargets {
            if verbose {
                print("Generating symbol graph for '\(target.name)'...")
            }

            let symbolGraphResult = try packageManager.getSymbolGraph(
                for: target,
                options: target.defaultSymbolGraphOptions(in: context.package)
            )

            let targetSymbolGraphDir = symbolGraphResult.directoryURL

            // Copy symbol graphs to unified directory
            let contents = try FileManager.default.contentsOfDirectory(atPath: targetSymbolGraphDir.path)
            for file in contents {
                let sourceFile = targetSymbolGraphDir.appendingPathComponent(file)
                let destFile = symbolGraphsDir.appendingPathComponent(file)
                try? FileManager.default.removeItem(at: destFile)
                try FileManager.default.copyItem(at: sourceFile, to: destFile)
            }

            if verbose {
                print("Symbol graph for '\(target.name)' generated.")
            }
        }

        // Build the command arguments
        var processArgs = [
            "generate",
            "--package-path", context.package.directoryURL.path(),
            "--output", outputDir,
            "--symbol-graph-dir", symbolGraphsDir.path,
        ]

        for target in specifiedTargets {
            processArgs.append(contentsOf: ["--target", target])
        }

        // Handle dependency inclusion options
        if includeAllDeps {
            processArgs.append("--include-all-dependencies")
            for dep in excludeDeps {
                processArgs.append(contentsOf: ["--exclude-dependency", dep])
            }
        } else {
            for dep in includeDeps {
                processArgs.append(contentsOf: ["--include-dependency", dep])
            }
        }

        for ext in externalDocs {
            processArgs.append(contentsOf: ["--external-docs", ext])
        }

        if includeSearch {
            processArgs.append("--include-search")
        }

        if verbose {
            processArgs.append("--verbose")
        }

        // Run the tool
        let process = try Process.run(tool.url, arguments: processArgs)
        process.waitUntilExit()

        guard process.terminationReason == .exit && process.terminationStatus == 0 else {
            Diagnostics.error("Documentation generation failed with exit code \(process.terminationStatus)")
            return
        }

        print("""
            Generated documentation at:
              \(outputDir)
            """)
    }
}

// MARK: - Symbol Graph Options Extension

extension SourceModuleTarget {
    /// Returns default symbol graph options for this target.
    func defaultSymbolGraphOptions(in package: Package) -> PackageManager.SymbolGraphOptions {
        let minimumAccessLevel: PackageManager.SymbolGraphOptions.AccessLevel
        if kind == .executable {
            minimumAccessLevel = .internal
        } else {
            minimumAccessLevel = .public
        }

        var options = PackageManager.SymbolGraphOptions()
        options.minimumAccessLevel = minimumAccessLevel
        options.includeSynthesized = true
        return options
    }
}

// MARK: - Argument Extraction Helpers

struct ArgumentExtractor {
    private var arguments: [String]

    init(_ arguments: [String]) {
        self.arguments = arguments
    }

    mutating func extractOption(named name: String) -> String? {
        let longForm = "--\(name)"
        guard let index = arguments.firstIndex(of: longForm),
              index + 1 < arguments.count
        else {
            return nil
        }
        let value = arguments[index + 1]
        arguments.remove(at: index + 1)
        arguments.remove(at: index)
        return value
    }

    mutating func extractOption(named name: String, allowMultiple: Bool) -> [String] {
        guard allowMultiple else {
            return extractOption(named: name).map { [$0] } ?? []
        }

        var values: [String] = []
        while let value = extractOption(named: name) {
            values.append(value)
        }
        return values
    }

    mutating func extractFlag(named name: String) -> Bool {
        let longForm = "--\(name)"
        guard let index = arguments.firstIndex(of: longForm) else {
            return false
        }
        arguments.remove(at: index)
        return true
    }
}
