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
/// This type is used for parsing theme files and validating their structure.
/// Unknown keys at any level will trigger warnings through the current
/// warning handler.
public struct ThemeSettingsInput: Codable, Equatable, Sendable {
    /// The theme configuration.
    public let theme: ThemeInput

    /// Optional metadata (preserved but not used).
    public let meta: [String: AnyCodable]?

    /// Known top-level keys.
    private static let knownKeys: Set<String> = ["theme", "meta"]

    enum CodingKeys: String, CodingKey {
        case theme
        case meta
    }

    public init(theme: ThemeInput, meta: [String: AnyCodable]? = nil) {
        self.theme = theme
        self.meta = meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decode(ThemeInput.self, forKey: .theme)
        meta = try container.decodeIfPresent([String: AnyCodable].self, forKey: .meta)

        // Warn about unknown top-level keys
        let allKeys = try decoder.container(keyedBy: DynamicCodingKey.self)
        for key in allKeys.allKeys {
            if !Self.knownKeys.contains(key.stringValue) {
                emitWarning("Unknown top-level key '\(key.stringValue)' in theme file")
            }
        }
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

/// Theme configuration containing colour and typography settings.
public struct ThemeInput: Codable, Equatable, Sendable {
    /// Badge settings for the theme.
    public let badge: [String: String]?

    /// Colour settings for the theme.
    public let color: [String: ColorValueInput]?

    /// Typography settings for the theme.
    public let typography: [String: String]?

    /// Spacing settings for the theme (docc-static extension).
    public let spacing: [String: String]?

    /// Known theme keys.
    private static let knownKeys: Set<String> = ["badge", "color", "typography", "spacing"]

    enum CodingKeys: String, CodingKey {
        case badge
        case color
        case typography
        case spacing
    }

    public init(
        badge: [String: String]? = nil,
        color: [String: ColorValueInput]? = nil,
        typography: [String: String]? = nil,
        spacing: [String: String]? = nil
    ) {
        self.badge = badge
        self.color = color
        self.typography = typography
        self.spacing = spacing
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        badge = try container.decodeIfPresent([String: String].self, forKey: .badge)
        color = try container.decodeIfPresent([String: ColorValueInput].self, forKey: .color)
        typography = try container.decodeIfPresent([String: String].self, forKey: .typography)
        spacing = try container.decodeIfPresent([String: String].self, forKey: .spacing)

        // Warn about unknown keys
        let allKeys = try decoder.container(keyedBy: DynamicCodingKey.self)
        for key in allKeys.allKeys {
            if !Self.knownKeys.contains(key.stringValue) {
                emitWarning("Unknown theme key '\(key.stringValue)' - will be ignored")
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
