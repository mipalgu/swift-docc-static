//
// ThemeSettingValue.swift
// DocCStaticThemes
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation

/// A generic value in a `theme-settings.json` file.
///
/// The swift-docc-render theme format allows nested objects whose leaves become
/// CSS custom properties.  A leaf is either a plain value or a pair of values for
/// the light and dark colour schemes.  This type models such a tree so that every
/// section of the format can be read, validated and turned into custom properties
/// in the same way swift-docc-render does it.
///
/// Numbers and Booleans are stored in their textual JSON form, because they end
/// up as CSS values.
public indirect enum ThemeSettingValue: Codable, Equatable, Hashable, Sendable {
    /// A single value used for both colour schemes.
    case value(String)

    /// Separate values for the light and dark colour schemes.
    case lightDark(light: String, dark: String)

    /// A nested object whose keys are appended to the custom property name.
    case object([String: ThemeSettingValue])

    /// The keys that mark an object as a light and dark pair.
    private enum SchemeKeys: String, CodingKey {
        case light
        case dark
    }

    /// Decodes a value, a light and dark pair, or a nested object.
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: A decoding error if the value is an array or `null`.
    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if let string = try? single.decode(String.self) {
            self = .value(string)
            return
        }
        if let bool = try? single.decode(Bool.self) {
            self = .value(bool ? "true" : "false")
            return
        }
        if let integer = try? single.decode(Int.self) {
            self = .value(String(integer))
            return
        }
        if let number = try? single.decode(Double.self) {
            self = .value(String(number))
            return
        }
        let object = try decoder.container(keyedBy: DynamicCodingKey.self)
        var entries: [String: ThemeSettingValue] = [:]
        for key in object.allKeys {
            entries[key.stringValue] = try object.decode(ThemeSettingValue.self, forKey: key)
        }
        if entries.count == 2,
            case .value(let light)? = entries[SchemeKeys.light.stringValue],
            case .value(let dark)? = entries[SchemeKeys.dark.stringValue]
        {
            self = .lightDark(light: light, dark: dark)
        } else {
            self = .object(entries)
        }
    }

    /// Encodes the value in the same shape it was decoded from.
    ///
    /// - Parameter encoder: The encoder to write to.
    /// - Throws: An encoding error.
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .value(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .lightDark(let light, let dark):
            var container = encoder.container(keyedBy: SchemeKeys.self)
            try container.encode(light, forKey: .light)
            try container.encode(dark, forKey: .dark)
        case .object(let entries):
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in entries {
                guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
                try container.encode(value, forKey: codingKey)
            }
        }
    }

    /// Flattens the value into custom property suffixes and values.
    ///
    /// Nested keys are joined with `-`, exactly like swift-docc-render's
    /// `objectToCustomProperties()`.  For example, `{"code": {"border-width": "2px"}}`
    /// flattened with the prefix `code` yields `("code-border-width", "2px")`.
    ///
    /// - Parameters:
    ///   - prefix: The name accumulated so far (without the leading `--`).
    ///   - dark: Whether to pick the dark value of light and dark pairs.
    /// - Returns: The flattened entries, sorted by name.
    public func flattened(prefix: String, dark: Bool) -> [(name: String, value: String)] {
        switch self {
        case .value(let value):
            return [(prefix, value)]
        case .lightDark(let light, let darkValue):
            return [(prefix, dark ? darkValue : light)]
        case .object(let entries):
            return entries.sorted { $0.key < $1.key }.flatMap { key, value in
                value.flattened(prefix: prefix.isEmpty ? key : "\(prefix)-\(key)", dark: dark)
            }
        }
    }

    /// Whether this value, or any value nested inside it, differs between the colour schemes.
    public var hasDarkVariant: Bool {
        switch self {
        case .value:
            return false
        case .lightDark(let light, let dark):
            return light != dark
        case .object(let entries):
            return entries.values.contains { $0.hasDarkVariant }
        }
    }

    /// The key paths of all leaves below this value, sorted, outermost key first.
    ///
    /// A plain value or a light and dark pair is a leaf with an empty path.
    public var leafPaths: [[String]] {
        guard case .object(let entries) = self else { return [[]] }
        return entries.sorted { $0.key < $1.key }.flatMap { key, value in
            value.leafPaths.map { [key] + $0 }
        }
    }

    /// Looks up a nested value by its key path.
    ///
    /// - Parameter path: The keys to follow, outermost first.
    /// - Returns: The value at the path, or `nil` if the path does not exist.
    public func value(at path: [String]) -> ThemeSettingValue? {
        guard let first = path.first else { return self }
        guard case .object(let entries) = self, let next = entries[first] else { return nil }
        return next.value(at: Array(path.dropFirst()))
    }
}
