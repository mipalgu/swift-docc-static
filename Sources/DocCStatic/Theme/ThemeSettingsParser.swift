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
/// :root, body {
///     --color-fill: #ffffff;
/// }
/// @supports (color: light-dark(#000, #fff)) {
///     :root, body {
///         --color-fill: light-dark(#ffffff, #1d1d1f);
///     }
/// }
/// ```
///
/// The properties are defined on the body element, like the colour palette of the
/// base stylesheet, so that they replace the palette's values.  They are also
/// defined on the root element, whose rule reads the root font size
/// (`--spacing-html-font-size`) that `rem` values are based on.  A value that differs
/// between the light and the dark appearance becomes a `light-dark()` pair, which
/// follows the colour scheme of the body (the reader's system setting, or the scheme
/// chosen with ``ColourSchemeToggle``).
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
        var css = generateLightModeCSS(from: settings)
        if includeDarkMode {
            css += generateDarkModeCSS(from: settings)
        }
        return css
    }

    /// Generates light mode CSS variables.
    ///
    /// The variables are defined on the body element, where the base stylesheet
    /// defines its colour palette, and on the root element, whose font size the
    /// settings can also set.
    ///
    /// - Parameter settings: The theme settings.
    /// - Returns: CSS for light mode variables, or an empty string if the settings
    ///   define none.
    public static func generateLightModeCSS(from settings: ThemeSettings.Root) -> String {
        let variables = customProperties(from: settings, dark: false).map { "    \($0.name): \($0.value);" }

        guard !variables.isEmpty else { return "" }

        return """

            /* Theme settings overrides - light mode */
            :root, body {
            \(variables.joined(separator: "\n"))
            }

            """
    }

    /// Generates dark mode CSS variables.
    ///
    /// Every property whose dark value differs from its light value is redefined as a
    /// `light-dark()` pair of both values, so the colour scheme of the body selects
    /// the value.  The rule is guarded by `@supports`, so browsers without
    /// `light-dark()` keep the light values.
    ///
    /// - Parameter settings: The theme settings.
    /// - Returns: CSS for dark mode variables, or an empty string if no value differs.
    public static func generateDarkModeCSS(from settings: ThemeSettings.Root) -> String {
        let light = customProperties(from: settings, dark: false)
        let dark = customProperties(from: settings, dark: true)
        let variables = zip(light, dark)
            .filter { $0.value != $1.value }
            .map { "        \($1.name): light-dark(\($0.value), \($1.value));" }

        guard !variables.isEmpty else { return "" }

        return """

            /* Theme settings overrides - dark mode */
            @supports (color: light-dark(#000, #fff)) {
                :root, body {
            \(variables.joined(separator: "\n"))
                }
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
