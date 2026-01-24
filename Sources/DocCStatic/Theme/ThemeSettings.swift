//
// ThemeSettings.swift
// DocCStatic
//
//  Created by Claude on 21/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation

/// Represents a theme-settings.json file from swift-docc-render.
///
/// This type models the theme settings format used by swift-docc-render,
/// allowing themes to be shared between swift-docc and swift-docc-static.
///
/// ## Format
///
/// A theme-settings.json file has the following structure:
///
/// ```json
/// {
///   "theme": {
///     "color": {
///       "fill": { "light": "#ffffff", "dark": "#1d1d1f" },
///       "link": "#0066cc"
///     },
///     "typography": {
///       "html-font": "system-ui, sans-serif"
///     }
///   }
/// }
/// ```
///
/// Color values can be either:
/// - A single string value (used for both light and dark modes)
/// - An object with `light` and `dark` keys for mode-specific values
///
/// ## Topics
///
/// ### Model Types
/// - ``ThemeSettingsRoot``
/// - ``ThemeSettingsTheme``
/// - ``ThemeColorValue``
public enum ThemeSettings {}

// MARK: - Root Model

extension ThemeSettings {
    /// The root structure of a theme-settings.json file.
    public struct Root: Codable, Sendable, Equatable {
        /// The theme configuration.
        public var theme: Theme

        /// Creates a new theme settings root.
        ///
        /// - Parameter theme: The theme configuration.
        public init(theme: Theme) {
            self.theme = theme
        }
    }
}

// MARK: - Theme Model

extension ThemeSettings {
    /// The theme configuration containing color, typography, and spacing settings.
    ///
    /// This structure is backward compatible with swift-docc's theme-settings.json format.
    /// The `color` and `typography` sections follow the swift-docc specification exactly.
    /// The `spacing` section is a docc-static extension that swift-docc will ignore.
    public struct Theme: Codable, Sendable, Equatable {
        /// Color settings for the theme.
        ///
        /// Each key becomes a `--color-<key>` CSS variable.
        /// Values can be single strings or light/dark variants.
        public var color: [String: ColorValue]?

        /// Typography settings for the theme.
        ///
        /// Each key becomes a `--typography-<key>` CSS variable.
        /// In swift-docc, only `html-font` and `html-font-mono` are supported.
        public var typography: [String: String]?

        /// Spacing settings for the theme (docc-static extension).
        ///
        /// Each key becomes a `--spacing-<key>` CSS variable.
        /// This section is ignored by swift-docc but allows docc-static
        /// themes to customize margins, padding, and other spacing values.
        public var spacing: [String: String]?

        /// Creates a new theme configuration.
        ///
        /// - Parameters:
        ///   - color: Color settings dictionary.
        ///   - typography: Typography settings dictionary.
        ///   - spacing: Spacing settings dictionary (docc-static extension).
        public init(
            color: [String: ColorValue]? = nil,
            typography: [String: String]? = nil,
            spacing: [String: String]? = nil
        ) {
            self.color = color
            self.typography = typography
            self.spacing = spacing
        }
    }
}

// MARK: - Color Value

extension ThemeSettings {
    /// A color value that can be either a single string or light/dark variants.
    ///
    /// This type supports the swift-docc-render theme format where colors can be:
    /// - A single CSS color value (e.g., `"#0066cc"`)
    /// - An object with separate `light` and `dark` values
    public enum ColorValue: Codable, Sendable, Equatable {
        /// A single color value used for both light and dark modes.
        case single(String)

        /// Separate color values for light and dark modes.
        case lightDark(light: String, dark: String)

        /// Returns the color value for light mode.
        public var light: String {
            switch self {
            case .single(let value):
                return value
            case .lightDark(let light, _):
                return light
            }
        }

        /// Returns the color value for dark mode.
        public var dark: String {
            switch self {
            case .single(let value):
                return value
            case .lightDark(_, let dark):
                return dark
            }
        }

        // MARK: - Codable

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            // Try to decode as a string first
            if let stringValue = try? container.decode(String.self) {
                self = .single(stringValue)
                return
            }

            // Try to decode as an object with light/dark keys
            let keyedContainer = try decoder.container(keyedBy: CodingKeys.self)
            let light = try keyedContainer.decode(String.self, forKey: .light)
            let dark = try keyedContainer.decode(String.self, forKey: .dark)
            self = .lightDark(light: light, dark: dark)
        }

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .single(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .lightDark(let light, let dark):
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(light, forKey: .light)
                try container.encode(dark, forKey: .dark)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case light
            case dark
        }
    }
}

// MARK: - Built-in Themes

extension ThemeSettings {
    /// Available built-in themes.
    ///
    /// Theme data is generated at build time from the JSON files in the `Themes/` directory
    /// by the `GenerateThemeCode` build tool plugin. This ensures the JSON files remain
    /// the single source of truth for theme definitions.
    public enum BuiltInTheme: String, CaseIterable, Sendable {
        /// The default theme matching swift-docc-render's appearance.
        case `default` = "default"

        /// The classic swift-docc-static theme with Apple SF fonts.
        case classic = "docc-static-classic"

        /// Returns the theme settings for this built-in theme.
        ///
        /// The theme data is generated from `Themes/*.theme-settings.json` files
        /// by the `theme-codegen` tool at build time.
        public var settings: Root {
            switch self {
            case .default:
                return Self.defaultThemeData
            case .classic:
                return Self.classicThemeData
            }
        }
    }
}

// Note: The `defaultThemeData` and `classicThemeData` properties are generated
// by the GenerateThemeCode build tool plugin from the JSON files in Themes/.
// See: Plugins/GenerateThemeCode/GenerateThemeCode.swift
