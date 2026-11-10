//
// GenerateThemeCode.swift
// GenerateThemeCode
//
//  Created by Rene Hexel on 22/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import PackagePlugin

/// A build tool plugin that compiles the built-in themes into Swift code.
///
/// This plugin runs the `theme-codegen` tool to convert the theme bundles in
/// the package's `Themes` directory and the base stylesheet parts in its
/// `Stylesheets` directory into Swift constants that are compiled directly into
/// the binary.  Every file in both directories is an input, so editing a theme
/// or a stylesheet regenerates the code.
@main
struct GenerateThemeCode: BuildToolPlugin {
    /// The package directory holding one bundle directory per built-in theme.
    static let themesDirectoryName = "Themes"

    /// The package directory holding the base stylesheet parts.
    static let stylesheetsDirectoryName = "Stylesheets"

    /// Creates the build command that generates the theme code.
    ///
    /// - Parameters:
    ///   - context: The plugin context.
    ///   - target: The target being built; only `DocCStatic` gets a command.
    /// - Returns: The build commands.
    /// - Throws: An error if the tool or the input directories cannot be found.
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard target.name == "DocCStatic" else {
            return []
        }

        let tool = try context.tool(named: "theme-codegen")
        let themesDirectory = context.package.directoryURL.appending(path: Self.themesDirectoryName)
        let stylesheetsDirectory = context.package.directoryURL.appending(path: Self.stylesheetsDirectoryName)
        let inputFiles = files(below: themesDirectory) + files(below: stylesheetsDirectory)

        guard !inputFiles.isEmpty else {
            Diagnostics.warning("No theme bundles or stylesheets found in \(context.package.directoryURL.path())")
            return []
        }

        let outputFile = context.pluginWorkDirectoryURL.appending(path: "GeneratedThemes.swift")

        return [
            .buildCommand(
                displayName: "Generate Swift code from theme bundles and stylesheets",
                executable: tool.url,
                arguments: [
                    themesDirectory.path(),
                    stylesheetsDirectory.path(),
                    outputFile.path(),
                ],
                inputFiles: inputFiles,
                outputFiles: [outputFile]
            )
        ]
    }

    /// Lists the regular files below a directory.
    ///
    /// - Parameter directory: The directory to search.
    /// - Returns: The files, or an empty array if the directory does not exist.
    func files(below directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else {
            return []
        }
        var files: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            if isFile { files.append(url) }
        }
        return files.sorted { $0.path() < $1.path() }
    }
}
