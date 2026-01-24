//
// GenerateThemeCode.swift
// GenerateThemeCode
//
//  Created by Rene Hexel on 22/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import PackagePlugin

/// A build tool plugin that generates Swift code from JSON theme files.
///
/// This plugin runs the `theme-codegen` tool before each build to convert
/// theme-settings.json files into Swift constants that can be compiled
/// directly into the binary.
@main
struct GenerateThemeCode: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        // Only run for the DocCStatic target
        guard target.name == "DocCStatic" else {
            return []
        }

        // Locate the theme-codegen executable
        let tool = try context.tool(named: "theme-codegen")

        // Find the Themes directory in the package root
        let themesDir = context.package.directoryURL.appending(path: "Themes")

        // Check if themes directory exists
        guard FileManager.default.fileExists(atPath: themesDir.path()) else {
            Diagnostics.warning("Themes directory not found at \(themesDir.path())")
            return []
        }

        // Get list of theme files for input tracking
        let themeFiles = try FileManager.default.contentsOfDirectory(
            at: themesDir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" && $0.lastPathComponent.contains("theme-settings") }

        guard !themeFiles.isEmpty else {
            Diagnostics.warning("No theme-settings.json files found in \(themesDir.path())")
            return []
        }

        // Output file in the plugin work directory
        let outputFile = context.pluginWorkDirectoryURL.appending(path: "GeneratedThemes.swift")

        return [
            .buildCommand(
                displayName: "Generate Swift code from theme JSON files",
                executable: tool.url,
                arguments: [
                    themesDir.path(),
                    outputFile.path(),
                ],
                inputFiles: themeFiles,
                outputFiles: [outputFile]
            )
        ]
    }
}
