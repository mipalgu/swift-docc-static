//
// theme_codegen.swift
// theme-codegen
//
//  Created by Rene Hexel on 22/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import ArgumentParser
import DocCStaticThemes
import Foundation

/// Theme code generator that converts JSON theme files to Swift constants.
///
/// This build tool reads `*.theme-settings.json` files from a themes directory
/// and generates Swift code that can be compiled directly into the binary,
/// eliminating the need for runtime file loading.
@main
struct ThemeCodeGeneratorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "theme-codegen",
        abstract: "Generate Swift code from JSON theme files.",
        discussion: """
            Reads all *.theme-settings.json files from the themes directory
            and generates Swift code containing the theme data as constants.
            This allows themes to be compiled directly into the binary.
            """
    )

    @Argument(help: "Directory containing theme-settings.json files.")
    var themesDirectory: String

    @Argument(help: "Output Swift file path.")
    var outputFile: String

    @Flag(name: .shortAndLong, help: "Enable verbose output.")
    var verbose: Bool = false

    func run() async throws {
        let themesURL = URL(fileURLWithPath: themesDirectory)
        let outputURL = URL(fileURLWithPath: outputFile)

        // Read all theme JSON files
        let fileManager = FileManager.default
        let themeFiles = try fileManager.contentsOfDirectory(
            at: themesURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" && $0.lastPathComponent.contains("theme-settings") }

        guard !themeFiles.isEmpty else {
            throw ValidationError("No theme-settings.json files found in \(themesURL.path)")
        }

        if verbose {
            print("Found \(themeFiles.count) theme file(s):")
            for file in themeFiles {
                print("  - \(file.lastPathComponent)")
            }
        }

        // Parse all theme files
        var themes: [(name: String, settings: ThemeSettingsInput)] = []
        let warningHandler = StderrWarningHandler()

        for themeFile in themeFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let themeName = themeFile.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: ".theme-settings", with: "")

            do {
                let settings = try ThemeSettingsInput.parse(
                    contentsOf: themeFile,
                    warningHandler: warningHandler
                )
                themes.append((name: themeName, settings: settings))

                if verbose {
                    print("Parsed theme: \(themeName)")
                }
            } catch {
                throw ValidationError("Failed to parse \(themeFile.lastPathComponent): \(error)")
            }
        }

        // Generate Swift code
        let generator = ThemeCodeGenerator()
        let swiftCode = generator.generateFile(themes: themes)

        // Create output directory if needed
        let outputDir = outputURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Write the output file
        try swiftCode.write(to: outputURL, atomically: true, encoding: .utf8)

        if verbose {
            print("Generated \(outputURL.path)")
        } else {
            print("Generated \(outputURL.lastPathComponent)")
        }
    }
}
