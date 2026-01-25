//
// ThemeCodeGenerator.swift
// DocCStaticThemes
//
//  Created by Rene Hexel on 22/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation

/// Generates Swift code from theme settings.
///
/// This type converts parsed theme settings into Swift source code that can
/// be compiled directly into the binary, eliminating the need for runtime
/// file loading.
///
/// ## Example
///
/// ```swift
/// let generator = ThemeCodeGenerator()
/// let themes = [
///     ("default", defaultThemeSettings),
///     ("classic", classicThemeSettings)
/// ]
/// let swiftCode = generator.generateFile(themes: themes)
/// try swiftCode.write(toFile: "GeneratedThemes.swift", atomically: true, encoding: .utf8)
/// ```
public struct ThemeCodeGenerator: Sendable {
    /// The indentation string to use (default: 4 spaces).
    public let indentation: String

    /// Creates a new theme code generator.
    ///
    /// - Parameter indentation: The indentation string to use.
    public init(indentation: String = "    ") {
        self.indentation = indentation
    }

    // MARK: - File Generation

    /// Generates a complete Swift file containing theme data.
    ///
    /// - Parameters:
    ///   - themes: An array of tuples containing theme names and their settings.
    ///   - date: The date to use in the file header (defaults to current date).
    /// - Returns: The generated Swift source code.
    public func generateFile(
        themes: [(name: String, settings: ThemeSettingsInput)],
        date: Date = Date()
    ) -> String {
        var output = generateHeader(date: date)
        output += "\n// MARK: - Generated Theme Data\n\n"
        output += "extension ThemeSettings.BuiltInTheme {\n\n"

        for (name, settings) in themes {
            let propertyName = swiftPropertyName(for: name)
            output += generateThemeProperty(settings: settings, propertyName: propertyName)
            output += "\n"
        }

        output += "}\n"
        return output
    }

    /// Generates the file header with copyright and generation notice.
    ///
    /// - Parameter date: The date to use in the header.
    /// - Returns: The header string.
    public func generateHeader(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let dateString = formatter.string(from: date)

        return """
            //
            // GeneratedThemes.swift
            // DocCStatic
            //
            // AUTO-GENERATED FILE - DO NOT EDIT
            // Generated from JSON theme files in Themes/
            //
            //  Created by theme-codegen on \(dateString).
            //  Copyright © 2026 Rene Hexel. All rights reserved.
            //

            """
    }

    // MARK: - Property Generation

    /// Generates a Swift property for a single theme.
    ///
    /// - Parameters:
    ///   - settings: The theme settings to convert.
    ///   - propertyName: The name for the generated property.
    /// - Returns: The Swift code for the property.
    public func generateThemeProperty(
        settings: ThemeSettingsInput,
        propertyName: String
    ) -> String {
        let humanName = humanReadableName(from: propertyName)
        var code = "\(indentation)/// Generated theme data for the \(humanName) theme.\n"
        code += "\(indentation)static let \(propertyName) = ThemeSettings.Root(\n"
        code += "\(indentation)\(indentation)theme: ThemeSettings.Theme("

        let hasBadge = settings.theme.badge != nil && !settings.theme.badge!.isEmpty
        let hasColours = settings.theme.color != nil && !settings.theme.color!.isEmpty
        let hasTypography = settings.theme.typography != nil && !settings.theme.typography!.isEmpty
        let hasSpacing = settings.theme.spacing != nil && !settings.theme.spacing!.isEmpty

        if hasBadge || hasColours || hasTypography || hasSpacing {
            code += "\n"

            var sections: [String] = []

            if hasBadge {
                sections.append(generateBadgeDictionary(settings.theme.badge!, baseIndent: 3))
            }

            if hasColours {
                sections.append(generateColourDictionary(settings.theme.color!, baseIndent: 3))
            }

            if hasTypography {
                sections.append(generateTypographyDictionary(settings.theme.typography!, baseIndent: 3))
            }

            if hasSpacing {
                sections.append(generateSpacingDictionary(settings.theme.spacing!, baseIndent: 3))
            }

            code += sections.joined(separator: ",\n")
            code += "\n\(indentation)\(indentation))"
        } else {
            code += ")"
        }

        code += "\n\(indentation))\n"
        return code
    }

    // MARK: - Dictionary Generation

    /// Generates Swift code for a colour dictionary.
    ///
    /// - Parameters:
    ///   - colours: The colour dictionary to convert.
    ///   - baseIndent: The base indentation level.
    /// - Returns: The Swift code for the colour dictionary.
    public func generateColourDictionary(
        _ colours: [String: ColorValueInput],
        baseIndent: Int
    ) -> String {
        let indent = String(repeating: indentation, count: baseIndent)
        let entryIndent = String(repeating: indentation, count: baseIndent + 1)

        var code = "\(indent)color: [\n"

        let sortedColours = colours.sorted { $0.key < $1.key }
        for (index, (key, value)) in sortedColours.enumerated() {
            let colourCode = generateColourValue(value)
            let separator = index < sortedColours.count - 1 ? "," : ""
            code += "\(entryIndent)\"\(key)\": \(colourCode)\(separator)\n"
        }

        code += "\(indent)]"
        return code
    }

    /// Generates Swift code for a single colour value.
    ///
    /// - Parameter value: The colour value to convert.
    /// - Returns: The Swift code for the colour value.
    public func generateColourValue(_ value: ColorValueInput) -> String {
        switch value {
        case .single(let colour):
            return "ThemeSettings.ColorValue.single(\"\(colour)\")"
        case .lightDark(let light, let dark):
            return "ThemeSettings.ColorValue.lightDark(light: \"\(light)\", dark: \"\(dark)\")"
        }
    }

    /// Generates Swift code for a badge dictionary.
    ///
    /// - Parameters:
    ///   - badge: The badge dictionary to convert.
    ///   - baseIndent: The base indentation level.
    /// - Returns: The Swift code for the badge dictionary.
    public func generateBadgeDictionary(
        _ badge: [String: String],
        baseIndent: Int
    ) -> String {
        let indent = String(repeating: indentation, count: baseIndent)
        let entryIndent = String(repeating: indentation, count: baseIndent + 1)

        var code = "\(indent)badge: [\n"

        let sortedBadge = badge.sorted { $0.key < $1.key }
        for (index, (key, value)) in sortedBadge.enumerated() {
            // Escape quotes in the value
            let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
            let separator = index < sortedBadge.count - 1 ? "," : ""
            code += "\(entryIndent)\"\(key)\": \"\(escapedValue)\"\(separator)\n"
        }

        code += "\(indent)]"
        return code
    }

    /// Generates Swift code for a typography dictionary.
    ///
    /// - Parameters:
    ///   - typography: The typography dictionary to convert.
    ///   - baseIndent: The base indentation level.
    /// - Returns: The Swift code for the typography dictionary.
    public func generateTypographyDictionary(
        _ typography: [String: String],
        baseIndent: Int
    ) -> String {
        let indent = String(repeating: indentation, count: baseIndent)
        let entryIndent = String(repeating: indentation, count: baseIndent + 1)

        var code = "\(indent)typography: [\n"

        let sortedTypography = typography.sorted { $0.key < $1.key }
        for (index, (key, value)) in sortedTypography.enumerated() {
            // Escape quotes in the value
            let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
            let separator = index < sortedTypography.count - 1 ? "," : ""
            code += "\(entryIndent)\"\(key)\": \"\(escapedValue)\"\(separator)\n"
        }

        code += "\(indent)]"
        return code
    }

    /// Generates Swift code for a spacing dictionary.
    ///
    /// - Parameters:
    ///   - spacing: The spacing dictionary to convert.
    ///   - baseIndent: The base indentation level.
    /// - Returns: The Swift code for the spacing dictionary.
    public func generateSpacingDictionary(
        _ spacing: [String: String],
        baseIndent: Int
    ) -> String {
        let indent = String(repeating: indentation, count: baseIndent)
        let entryIndent = String(repeating: indentation, count: baseIndent + 1)

        var code = "\(indent)spacing: [\n"

        let sortedSpacing = spacing.sorted { $0.key < $1.key }
        for (index, (key, value)) in sortedSpacing.enumerated() {
            // Escape quotes in the value
            let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
            let separator = index < sortedSpacing.count - 1 ? "," : ""
            code += "\(entryIndent)\"\(key)\": \"\(escapedValue)\"\(separator)\n"
        }

        code += "\(indent)]"
        return code
    }

    // MARK: - Naming Helpers

    /// Converts a theme file name to a Swift property name.
    ///
    /// - Parameter themeName: The theme name (e.g., "default", "docc-static-classic").
    /// - Returns: The Swift property name (e.g., "defaultThemeData", "classicThemeData").
    public func swiftPropertyName(for themeName: String) -> String {
        switch themeName {
        case "default":
            return "defaultThemeData"
        case "docc-static-classic":
            return "classicThemeData"
        default:
            // Convert kebab-case to camelCase and append "ThemeData"
            let parts = themeName.split(separator: "-")
            let camelCase = parts.enumerated().map { index, part in
                index == 0 ? String(part) : part.capitalized
            }.joined()
            return camelCase + "ThemeData"
        }
    }

    /// Extracts a human-readable theme name from a property name.
    ///
    /// - Parameter propertyName: The Swift property name.
    /// - Returns: The human-readable name.
    public func humanReadableName(from propertyName: String) -> String {
        switch propertyName {
        case "defaultThemeData":
            return "default"
        case "classicThemeData":
            return "classic"
        default:
            return propertyName.replacingOccurrences(of: "ThemeData", with: "")
        }
    }
}
