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

/// Theme code generator that compiles theme bundles and the base stylesheet into Swift.
///
/// This build tool reads every theme bundle (a directory containing
/// `theme-settings.json` and optional `*.css` files) from a themes directory,
/// together with the base stylesheet parts from a stylesheets directory, and
/// generates Swift code that is compiled directly into the binary, eliminating
/// the need for runtime file loading.  Any warning about a built-in theme, such
/// as an unknown key, fails the build.
@main
struct ThemeCodeGeneratorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "theme-codegen",
        abstract: "Generate Swift code from theme bundles and the base stylesheet.",
        discussion: """
            Reads every theme bundle below the themes directory and the base
            stylesheet parts in the stylesheets directory, and generates Swift
            code containing them as constants.  This allows themes to be
            compiled directly into the binary.
            """
    )

    @Argument(help: "Directory containing one theme bundle directory per built-in theme.")
    var themesDirectory: String

    /// The directory that contains the parts of the base stylesheet.
    @Argument(help: "Directory containing the base stylesheet parts (*.css).")
    var stylesheetsDirectory: String

    @Argument(help: "Output Swift file path.")
    var outputFile: String

    @Flag(name: .shortAndLong, help: "Enable verbose output.")
    var verbose: Bool = false

    func run() async throws {
        let themesURL = URL(fileURLWithPath: themesDirectory)
        let stylesheetsURL = URL(fileURLWithPath: stylesheetsDirectory)
        let outputURL = URL(fileURLWithPath: outputFile)

        let warnings = CollectingWarningHandler()
        let bundles: [ThemeBundleSource]
        do {
            bundles = try ThemeBundleSource.loadAll(in: themesURL, warningHandler: warnings)
        } catch {
            throw ValidationError("Failed to read the theme bundles in \(themesURL.path): \(error)")
        }
        guard !bundles.isEmpty else {
            throw ValidationError("No theme bundles found in \(themesURL.path)")
        }
        guard warnings.warnings.isEmpty else {
            throw ValidationError(
                "Built-in themes must not produce warnings:\n" + warnings.warnings.joined(separator: "\n")
            )
        }
        let baseStylesheets = try ThemeBundleLayout.stylesheets(in: stylesheetsURL)
        guard !baseStylesheets.isEmpty else {
            throw ValidationError("No base stylesheet parts found in \(stylesheetsURL.path)")
        }

        if verbose {
            print("Found \(bundles.count) theme bundle(s) and \(baseStylesheets.count) base stylesheet part(s):")
            for bundle in bundles {
                print("  - \(bundle.name) (\(bundle.stylesheets.count) stylesheet(s))")
            }
        }

        let swiftCode = ThemeCodeGenerator().generateFile(bundles: bundles, baseStylesheets: baseStylesheets)

        // Create the output directory if needed and write the file
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try swiftCode.write(to: outputURL, atomically: true, encoding: .utf8)

        if verbose {
            print("Generated \(outputURL.path)")
        }
    }
}
