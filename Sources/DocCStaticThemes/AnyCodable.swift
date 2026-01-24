//
// AnyCodable.swift
// DocCStaticThemes
//
//  Created by Rene Hexel on 22/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation

/// A type-erased Codable value that can represent any JSON value.
///
/// This wrapper allows decoding unknown or dynamic JSON structures
/// while still using Swift's Codable system. It supports all standard
/// JSON types: strings, numbers, booleans, objects, arrays, and null.
///
/// ## Example
///
/// ```swift
/// struct Flexible: Codable {
///     let id: Int
///     let metadata: [String: AnyCodable]
/// }
///
/// let json = """
/// { "id": 1, "metadata": { "name": "test", "count": 42 } }
/// """
/// let data = json.data(using: .utf8)!
/// let decoded = try JSONDecoder().decode(Flexible.self, from: data)
/// ```
public enum AnyCodable: Codable, Equatable, Sendable, CustomStringConvertible {
    /// A string value.
    case string(String)

    /// An integer value.
    case int(Int)

    /// A floating-point value.
    case double(Double)

    /// A boolean value.
    case bool(Bool)

    /// An object (dictionary) value.
    case object([String: AnyCodable])

    /// An array value.
    case array([AnyCodable])

    /// A null value.
    case null

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let object = try? container.decode([String: AnyCodable].self) {
            self = .object(object)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode AnyCodable value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    // MARK: - Accessors

    /// Returns the string value if this is a `.string`, otherwise `nil`.
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// Returns the integer value if this is an `.int`, otherwise `nil`.
    public var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    /// Returns the double value if this is a `.double`, otherwise `nil`.
    public var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }

    /// Returns the boolean value if this is a `.bool`, otherwise `nil`.
    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    /// Returns the object value if this is an `.object`, otherwise `nil`.
    public var objectValue: [String: AnyCodable]? {
        if case .object(let value) = self { return value }
        return nil
    }

    /// Returns the array value if this is an `.array`, otherwise `nil`.
    public var arrayValue: [AnyCodable]? {
        if case .array(let value) = self { return value }
        return nil
    }

    /// Returns `true` if this is a `.null` value.
    public var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    // MARK: - CustomStringConvertible

    public var description: String {
        switch self {
        case .string(let value): return "\"\(value)\""
        case .int(let value): return "\(value)"
        case .double(let value): return "\(value)"
        case .bool(let value): return "\(value)"
        case .object(let value): return "\(value)"
        case .array(let value): return "\(value)"
        case .null: return "null"
        }
    }
}
