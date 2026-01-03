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

        // Extract output directory option
        let outputDir = argumentExtractor.extractOption(named: "output")
            ?? context.pluginWorkDirectoryURL.appending(path: "documentation").path()

        // Extract other options
        let targets = argumentExtractor.extractOption(named: "target", allowMultiple: true)
        let includeAllDeps = argumentExtractor.extractFlag(named: "include-all-dependencies")
        let includeDeps = argumentExtractor.extractOption(named: "include-dependency", allowMultiple: true)
        let excludeDeps = argumentExtractor.extractOption(named: "exclude-dependency", allowMultiple: true)
        let externalDocs = argumentExtractor.extractOption(named: "external-docs", allowMultiple: true)
        let includeSearch = argumentExtractor.extractFlag(named: "include-search")
        let verbose = argumentExtractor.extractFlag(named: "verbose")

        // Build the command arguments
        var processArgs = [
            "generate",
            "--package-path", context.package.directoryURL.path(),
            "--output", outputDir,
        ]

        for target in targets {
            processArgs.append(contentsOf: ["--target", target])
        }

        // Handle dependency inclusion options
        if includeAllDeps {
            processArgs.append("--include-all-dependencies")
            // Exclusions only apply when including all dependencies
            for dep in excludeDeps {
                processArgs.append(contentsOf: ["--exclude-dependency", dep])
            }
        } else {
            // Include specific dependencies
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
        let process = Process()
        process.executableURL = tool.url
        process.arguments = processArgs

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            Diagnostics.error("Documentation generation failed with exit code \(process.terminationStatus)")
            return
        }

        if verbose {
            print("""

                Documentation generated successfully!
                Output: \(outputDir)

                To view locally, open in a browser:
                  open \(outputDir)/index.html

                """)
        }
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
