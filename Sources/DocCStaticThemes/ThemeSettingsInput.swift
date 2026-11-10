//
// ThemeSettingsInput.swift
// DocCStaticThemes
//
//  Created by Rene Hexel on 22/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation

/// A handler for theme parsing warnings.
///
/// Implement this protocol to receive warnings about unknown keys
/// or other non-fatal issues encountered during theme parsing.
public protocol ThemeParsingWarningHandler: Sendable {
    /// Called when a warning is encountered during parsing.
    ///
    /// - Parameter message: The warning message.
    func handleWarning(_ message: String)
}

/// A default warning handler that prints to stderr.
public struct StderrWarningHandler: ThemeParsingWarningHandler {
    public init() {}

    public func handleWarning(_ message: String) {
        FileHandle.standardError.write("[theme] Warning: \(message)\n".data(using: .utf8)!)
    }
}

/// A warning handler that collects warnings into an array.
public final class CollectingWarningHandler: ThemeParsingWarningHandler, @unchecked Sendable {
    private let lock = NSLock()
    private var _warnings: [String] = []

    /// The collected warnings.
    public var warnings: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _warnings
    }

    public init() {}

    public func handleWarning(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        _warnings.append(message)
    }
}

/// Container for task-local warning handler.
public enum ThemeParsingContext {
    /// Thread-local storage for the current warning handler.
    @TaskLocal
    public static var warningHandler: (any ThemeParsingWarningHandler)? = nil
}

/// Emits a warning using the current warning handler.
///
/// - Parameter message: The warning message.
func emitWarning(_ message: String) {
    ThemeParsingContext.warningHandler?.handleWarning(message)
}

// MARK: - Dynamic Coding Key

/// A dynamic coding key for iterating over unknown keys.
public struct DynamicCodingKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// MARK: - Theme Settings Input

/// Root structure of a theme-settings.json file.
///
/// This is the single model of the swift-docc-render theme format used by both
/// the build-time theme compiler and the runtime theme loader.  Unknown keys at
/// any level trigger warnings through the current warning handler, so that a
/// misspelt key is reported instead of being silently ignored.
public struct ThemeSettingsInput: Codable, Equatable, Sendable {
    /// The theme configuration.
    public var theme: ThemeInput

    /// Optional metadata (preserved but not used).
    public var meta: [String: AnyCodable]?

    /// Optional feature switches, keyed like swift-docc-render's `features` section.
    ///
    /// Use ``isEnabled(_:)`` to query a switch rather than reading this tree directly.
    public var features: [String: ThemeSettingValue]?

    /// Known top-level keys.
    private static let knownKeys: Set<String> = Set(CodingKeys.allCases.map(\.rawValue))

    enum CodingKeys: String, CodingKey, CaseIterable {
        case theme
        case meta
        case features
    }

    /// Creates theme settings.
    ///
    /// - Parameters:
    ///   - theme: The theme configuration.
    ///   - meta: Optional metadata.
    ///   - features: Optional feature switches.
    public init(
        theme: ThemeInput,
        meta: [String: AnyCodable]? = nil,
        features: [String: ThemeSettingValue]? = nil
    ) {
        self.theme = theme
        self.meta = meta
        self.features = features
    }

    /// Decodes theme settings, warning about unknown keys and feature switches.
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: A decoding error if a known section has the wrong shape.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decode(ThemeInput.self, forKey: .theme)
        meta = try container.decodeIfPresent([String: AnyCodable].self, forKey: .meta)
        features = try container.decodeIfPresent([String: ThemeSettingValue].self, forKey: .features)

        // Warn about unknown top-level keys
        let allKeys = try decoder.container(keyedBy: DynamicCodingKey.self)
        for key in allKeys.allKeys {
            if !Self.knownKeys.contains(key.stringValue) {
                emitWarning("Unknown top-level key '\(key.stringValue)' in theme file")
            }
        }

        // Warn about feature switches that neither swift-docc-render nor docc-static know
        if let features {
            let known = Set(ThemeFeatureFlag.all.map(\.description))
            for path in ThemeSettingValue.object(features).leafPaths {
                let dotted = path.joined(separator: ".")
                if !known.contains(dotted) {
                    emitWarning("Unknown feature switch 'features.\(dotted)' - will be ignored")
                }
            }
        }
    }

    /// Returns whether a feature switch is on.
    ///
    /// - Parameter flag: The feature switch to query.
    /// - Returns: The value set by the theme, or the switch's default value.
    public func isEnabled(_ flag: ThemeFeatureFlag) -> Bool {
        guard let features,
            case .value(let value)? = ThemeSettingValue.object(features).value(at: flag.path)
        else {
            return flag.defaultValue
        }
        return value == "true"
    }

    /// Parses theme settings from JSON data.
    ///
    /// - Parameters:
    ///   - data: The JSON data to parse.
    ///   - warningHandler: Optional handler for parsing warnings.
    /// - Returns: The parsed theme settings.
    /// - Throws: An error if the JSON is invalid.
    public static func parse(
        _ data: Data,
        warningHandler: (any ThemeParsingWarningHandler)? = nil
    ) throws -> ThemeSettingsInput {
        try ThemeParsingContext.$warningHandler.withValue(warningHandler) {
            let decoder = JSONDecoder()
            return try decoder.decode(ThemeSettingsInput.self, from: data)
        }
    }

    /// Parses theme settings from a file URL.
    ///
    /// - Parameters:
    ///   - url: The URL of the theme-settings.json file.
    ///   - warningHandler: Optional handler for parsing warnings.
    /// - Returns: The parsed theme settings.
    /// - Throws: An error if the file cannot be read or parsed.
    public static func parse(
        contentsOf url: URL,
        warningHandler: (any ThemeParsingWarningHandler)? = nil
    ) throws -> ThemeSettingsInput {
        let data = try Data(contentsOf: url)
        return try parse(data, warningHandler: warningHandler)
    }
}

// MARK: - Theme Input

/// The `theme` section of a theme-settings.json file.
///
/// The sections most themes use (`badge`, `color`, `typography` and the
/// docc-static `spacing` extension) are modelled explicitly.  The remaining
/// sections defined by the swift-docc-render specification (`aside`,
/// `border-radius`, `button`, `code`, `icons`, `tutorial-step` and
/// `device-frames`) are kept as generic values in ``other`` and become custom
/// properties in the same way.
public struct ThemeInput: Codable, Equatable, Sendable {
    /// Badge settings for the theme.
    public var badge: [String: String]?

    /// Colour settings for the theme.
    public var color: [String: ColorValueInput]?

    /// Typography settings for the theme.
    public var typography: [String: String]?

    /// Spacing settings for the theme (docc-static extension).
    public var spacing: [String: String]?

    /// The other sections of the swift-docc-render specification, keyed by section name.
    public var other: [String: ThemeSettingValue]?

    /// The sections of the specification that are kept in ``other``.
    public static let genericSectionKeys: Set<String> = [
        "aside", "border-radius", "button", "code", "icons", "tutorial-step", "device-frames",
    ]

    /// Known theme keys.
    private static let knownKeys: Set<String> = Set(CodingKeys.allCases.map(\.rawValue))
        .union(genericSectionKeys)

    enum CodingKeys: String, CodingKey, CaseIterable {
        case badge
        case color
        case typography
        case spacing
    }

    /// Creates a theme section.
    ///
    /// - Parameters:
    ///   - badge: Badge settings.
    ///   - color: Colour settings.
    ///   - typography: Typography settings.
    ///   - spacing: Spacing settings (docc-static extension).
    ///   - other: The other sections of the specification, keyed by section name.
    public init(
        badge: [String: String]? = nil,
        color: [String: ColorValueInput]? = nil,
        typography: [String: String]? = nil,
        spacing: [String: String]? = nil,
        other: [String: ThemeSettingValue]? = nil
    ) {
        self.badge = badge
        self.color = color
        self.typography = typography
        self.spacing = spacing
        self.other = other
    }

    /// Decodes the theme section, warning about unknown keys.
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: A decoding error if a section has the wrong shape.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        badge = try container.decodeIfPresent([String: String].self, forKey: .badge)
        color = try container.decodeIfPresent([String: ColorValueInput].self, forKey: .color)
        typography = try container.decodeIfPresent([String: String].self, forKey: .typography)
        spacing = try container.decodeIfPresent([String: String].self, forKey: .spacing)

        // Keep the generic sections and warn about unknown keys
        let allKeys = try decoder.container(keyedBy: DynamicCodingKey.self)
        var other: [String: ThemeSettingValue] = [:]
        for key in allKeys.allKeys {
            if Self.genericSectionKeys.contains(key.stringValue) {
                other[key.stringValue] = try allKeys.decode(ThemeSettingValue.self, forKey: key)
            } else if !Self.knownKeys.contains(key.stringValue) {
                emitWarning("Unknown theme key '\(key.stringValue)' - will be ignored")
            }
        }
        self.other = other.isEmpty ? nil : other
    }

    /// Encodes the theme section in the shape it was decoded from.
    ///
    /// - Parameter encoder: The encoder to write to.
    /// - Throws: An encoding error.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(badge, forKey: .badge)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(typography, forKey: .typography)
        try container.encodeIfPresent(spacing, forKey: .spacing)
        if let other {
            var generic = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in other {
                guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
                try generic.encode(value, forKey: codingKey)
            }
        }
    }
}

// MARK: - Colour Value Input

/// A colour value that can be either a single string or light/dark variants.
///
/// This type supports the swift-docc-render theme format where colours can be:
/// - A single CSS colour value (e.g., `"#0066cc"`)
/// - An object with separate `light` and `dark` values
public enum ColorValueInput: Codable, Equatable, Sendable {
    /// A single colour value used for both light and dark modes.
    case single(String)

    /// Separate colour values for light and dark modes.
    case lightDark(light: String, dark: String)

    /// Returns the colour value for light mode.
    public var light: String {
        switch self {
        case .single(let value): return value
        case .lightDark(let light, _): return light
        }
    }

    /// Returns the colour value for dark mode.
    public var dark: String {
        switch self {
        case .single(let value): return value
        case .lightDark(_, let dark): return dark
        }
    }

    /// Known keys for light/dark colour objects.
    private static let knownKeys: Set<String> = ["light", "dark"]

    private enum CodingKeys: String, CodingKey {
        case light
        case dark
    }

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

        // Warn about unknown keys in the light/dark object
        let allKeys = try decoder.container(keyedBy: DynamicCodingKey.self)
        for key in allKeys.allKeys {
            if !Self.knownKeys.contains(key.stringValue) {
                emitWarning("Unknown colour variant '\(key.stringValue)' - only 'light' and 'dark' are supported")
            }
        }

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
}
