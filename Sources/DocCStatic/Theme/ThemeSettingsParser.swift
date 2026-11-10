//
// ThemeSettingsParser.swift
// DocCStatic
//
//  Created by Claude on 21/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import DocCStaticThemes
import Foundation

/// Parses theme-settings.json files and generates CSS variable overrides.
///
/// This parser implements the same logic as swift-docc-render's `objectToCustomProperties()`
/// function, converting nested JSON objects into CSS custom properties.
///
/// ## Example
///
/// Given a theme-settings.json:
///
/// ```json
/// {
///   "theme": {
///     "color": {
///       "fill": { "light": "#ffffff", "dark": "#1d1d1f" }
///     }
///   }
/// }
/// ```
///
/// The parser generates:
///
/// ```css
/// :root {
///     --color-fill: #ffffff;
/// }
/// body[data-color-scheme="dark"] {
///     --color-fill: #1d1d1f;
/// }
/// ```
public enum ThemeSettingsParser {
    /// The color scheme for CSS variable generation.
    public enum ColorScheme: Sendable {
        case light
        case dark
        case auto
    }

    // MARK: - Parsing

    /// Parses theme settings from JSON data.
    ///
    /// This uses the same parser and validation as the build-time theme
    /// compiler: unknown keys and feature switches are reported to the warning
    /// handler.
    ///
    /// - Parameters:
    ///   - data: The JSON data to parse.
    ///   - warningHandler: Receives warnings about unknown keys, or `nil` to ignore them.
    /// - Returns: The parsed theme settings.
    /// - Throws: An error if the JSON is invalid.
    public static func parse(
        _ data: Data,
        warningHandler: (any ThemeParsingWarningHandler)? = nil
    ) throws -> ThemeSettings.Root {
        try ThemeSettingsInput.parse(data, warningHandler: warningHandler)
    }

    /// Parses theme settings from a file URL.
    ///
    /// - Parameters:
    ///   - url: The URL of the theme-settings.json file.
    ///   - warningHandler: Receives warnings about unknown keys, or `nil` to ignore them.
    /// - Returns: The parsed theme settings.
    /// - Throws: An error if the file cannot be read or parsed.
    public static func parse(
        contentsOf url: URL,
        warningHandler: (any ThemeParsingWarningHandler)? = nil
    ) throws -> ThemeSettings.Root {
        try ThemeSettingsInput.parse(contentsOf: url, warningHandler: warningHandler)
    }

    // MARK: - Custom Properties

    /// Returns the custom properties a theme defines for one colour scheme.
    ///
    /// The properties are listed section by section (`badge`, `color`,
    /// `typography`, `spacing`, then the remaining sections of the
    /// specification), each sorted by name.  Names follow swift-docc-render:
    /// nested keys are joined with `-` and prefixed with `--`.
    ///
    /// - Parameters:
    ///   - settings: The theme settings.
    ///   - dark: Whether to use the dark values of light and dark pairs.
    /// - Returns: The custom property names (including `--`) and values.
    public static func customProperties(
        from settings: ThemeSettings.Root,
        dark: Bool
    ) -> [(name: String, value: String)] {
        var properties: [(name: String, value: String)] = []
        let theme = settings.theme
        for (key, value) in (theme.badge ?? [:]).sorted(by: { $0.key < $1.key }) {
            properties.append(("--badge-\(key)", value))
        }
        for (key, value) in (theme.color ?? [:]).sorted(by: { $0.key < $1.key }) {
            properties.append(("--color-\(key)", dark ? value.dark : value.light))
        }
        for (key, value) in (theme.typography ?? [:]).sorted(by: { $0.key < $1.key }) {
            properties.append(("--typography-\(key)", value))
        }
        for (key, value) in (theme.spacing ?? [:]).sorted(by: { $0.key < $1.key }) {
            properties.append(("--spacing-\(key)", value))
        }
        for (key, value) in (theme.other ?? [:]).sorted(by: { $0.key < $1.key }) {
            for entry in value.flattened(prefix: key, dark: dark) {
                properties.append(("--\(entry.name)", entry.value))
            }
        }
        return properties
    }

    // MARK: - CSS Generation

    /// Generates CSS variables from theme settings.
    ///
    /// This method generates CSS custom properties for both light and dark modes,
    /// following the swift-docc-render naming convention.
    ///
    /// - Parameters:
    ///   - settings: The theme settings to convert.
    ///   - includeDarkMode: Whether to include dark mode styles.
    /// - Returns: A CSS string with the custom properties.
    public static func generateCSS(from settings: ThemeSettings.Root, includeDarkMode: Bool = true)
        -> String
    {
        var css = ""

        // Generate light mode (root) variables
        css += generateLightModeCSS(from: settings)

        // Generate explicit color scheme selectors if dark mode is enabled
        if includeDarkMode {
            css += generateLightModeExplicitCSS(from: settings)
            css += generateDarkModeCSS(from: settings)
        }

        return css
    }

    /// Generates light mode CSS variables.
    ///
    /// - Parameter settings: The theme settings.
    /// - Returns: CSS for light mode variables.
    public static func generateLightModeCSS(from settings: ThemeSettings.Root) -> String {
        let variables = customProperties(from: settings, dark: false).map { "    \($0.name): \($0.value);" }

        guard !variables.isEmpty else { return "" }

        return """

            /* Theme settings overrides - light mode */
            :root {
            \(variables.joined(separator: "\n"))
            }

            """
    }

    /// Generates explicit light mode CSS variables for color scheme switching.
    ///
    /// This generates the same variables as `generateLightModeCSS` but with
    /// a `body[data-color-scheme="light"]` selector to allow JavaScript theme
    /// switching to force light mode even when the system prefers dark mode.
    ///
    /// - Parameter settings: The theme settings.
    /// - Returns: CSS for explicit light mode variables.
    public static func generateLightModeExplicitCSS(from settings: ThemeSettings.Root) -> String {
        let variables = customProperties(from: settings, dark: false).map { "    \($0.name): \($0.value);" }

        guard !variables.isEmpty else { return "" }

        return """

            body[data-color-scheme="light"] {
            \(variables.joined(separator: "\n"))
            }

            """
    }

    /// Generates dark mode CSS variables.
    ///
    /// - Parameter settings: The theme settings.
    /// - Returns: CSS for dark mode variables.
    public static func generateDarkModeCSS(from settings: ThemeSettings.Root) -> String {
        // Only properties whose dark value differs from the light value
        let light = customProperties(from: settings, dark: false)
        let dark = customProperties(from: settings, dark: true)
        let variables = zip(light, dark)
            .filter { $0.value != $1.value }
            .map { "        \($1.name): \($1.value);" }

        guard !variables.isEmpty else { return "" }

        return """

            /* Theme settings overrides - dark mode */
            @media (prefers-color-scheme: dark) {
                :root {
            \(variables.joined(separator: "\n"))
                }
            }

            body[data-color-scheme="dark"] {
            \(variables.joined(separator: "\n"))
            }

            """
    }

    /// Generates CSS variables for a specific color scheme.
    ///
    /// - Parameters:
    ///   - settings: The theme settings.
    ///   - colorScheme: The color scheme to generate for.
    /// - Returns: CSS for the specified color scheme.
    public static func generateCSS(
        from settings: ThemeSettings.Root, colorScheme: ColorScheme
    ) -> String {
        switch colorScheme {
        case .light:
            return generateLightModeCSS(from: settings)
        case .dark:
            return generateDarkModeCSS(from: settings)
        case .auto:
            return generateCSS(from: settings, includeDarkMode: true)
        }
    }

    // MARK: - Variable Extraction

    /// Extracts all CSS variable definitions from theme settings.
    ///
    /// - Parameters:
    ///   - settings: The theme settings.
    ///   - colorScheme: The color scheme to extract variables for.
    /// - Returns: A dictionary mapping variable names to values.
    public static func extractVariables(
        from settings: ThemeSettings.Root, colorScheme: ColorScheme
    ) -> [String: String] {
        var variables: [String: String] = [:]

        // Badge variables
        if let badge = settings.theme.badge {
            for (key, value) in badge {
                let variableName = "--badge-\(key)"
                variables[variableName] = value
            }
        }

        // Color variables
        if let colors = settings.theme.color {
            for (key, value) in colors {
                let variableName = "--color-\(key)"
                switch colorScheme {
                case .light:
                    variables[variableName] = value.light
                case .dark, .auto:
                    variables[variableName] = value.dark
                }
            }
        }

        // Typography variables
        if let typography = settings.theme.typography {
            for (key, value) in typography {
                let variableName = "--typography-\(key)"
                variables[variableName] = value
            }
        }

        // Spacing variables (docc-static extension)
        if let spacing = settings.theme.spacing {
            for (key, value) in spacing {
                let variableName = "--spacing-\(key)"
                variables[variableName] = value
            }
        }

        // Remaining sections of the specification
        for (key, value) in settings.theme.other ?? [:] {
            for entry in value.flattened(prefix: key, dark: colorScheme != .light) {
                variables["--\(entry.name)"] = entry.value
            }
        }

        return variables
    }
}
