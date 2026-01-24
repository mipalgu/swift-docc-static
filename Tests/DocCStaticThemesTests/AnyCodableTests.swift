//
// AnyCodableTests.swift
// DocCStaticThemesTests
//
//  Created by Rene Hexel on 22/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing

@testable import DocCStaticThemes

@Suite("AnyCodable Tests")
struct AnyCodableTests {
    // MARK: - Decoding Tests

    @Test("Decode string value")
    func testDecodeString() throws {
        let json = "\"hello\""
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded == .string("hello"))
        #expect(decoded.stringValue == "hello")
    }

    @Test("Decode integer value")
    func testDecodeInt() throws {
        let json = "42"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded == .int(42))
        #expect(decoded.intValue == 42)
    }

    @Test("Decode double value")
    func testDecodeDouble() throws {
        let json = "3.14159"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded == .double(3.14159))
        #expect(decoded.doubleValue == 3.14159)
    }

    @Test("Decode boolean true value")
    func testDecodeBoolTrue() throws {
        let json = "true"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded == .bool(true))
        #expect(decoded.boolValue == true)
    }

    @Test("Decode boolean false value")
    func testDecodeBoolFalse() throws {
        let json = "false"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded == .bool(false))
        #expect(decoded.boolValue == false)
    }

    @Test("Decode null value")
    func testDecodeNull() throws {
        let json = "null"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        #expect(decoded == .null)
        #expect(decoded.isNull == true)
    }

    @Test("Decode object value")
    func testDecodeObject() throws {
        let json = """
            {"name": "test", "count": 5}
            """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        if case .object(let dict) = decoded {
            #expect(dict["name"] == .string("test"))
            #expect(dict["count"] == .int(5))
        } else {
            Issue.record("Expected object, got \(decoded)")
        }

        #expect(decoded.objectValue != nil)
        #expect(decoded.objectValue?["name"]?.stringValue == "test")
    }

    @Test("Decode array value")
    func testDecodeArray() throws {
        let json = "[1, \"two\", true]"
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        if case .array(let arr) = decoded {
            #expect(arr.count == 3)
            #expect(arr[0] == .int(1))
            #expect(arr[1] == .string("two"))
            #expect(arr[2] == .bool(true))
        } else {
            Issue.record("Expected array, got \(decoded)")
        }

        #expect(decoded.arrayValue != nil)
        #expect(decoded.arrayValue?.count == 3)
    }

    @Test("Decode nested structure")
    func testDecodeNestedStructure() throws {
        let json = """
            {
                "users": [
                    {"name": "Alice", "age": 30},
                    {"name": "Bob", "age": 25}
                ],
                "count": 2
            }
            """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)

        if case .object(let dict) = decoded {
            #expect(dict["count"] == .int(2))
            if case .array(let users) = dict["users"] {
                #expect(users.count == 2)
            } else {
                Issue.record("Expected users array")
            }
        } else {
            Issue.record("Expected object")
        }
    }

    // MARK: - Encoding Tests

    @Test("Encode string value")
    func testEncodeString() throws {
        let value = AnyCodable.string("hello")
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)

        #expect(json == "\"hello\"")
    }

    @Test("Encode integer value")
    func testEncodeInt() throws {
        let value = AnyCodable.int(42)
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)

        #expect(json == "42")
    }

    @Test("Encode double value")
    func testEncodeDouble() throws {
        let value = AnyCodable.double(3.5)
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)

        #expect(json == "3.5")
    }

    @Test("Encode boolean value")
    func testEncodeBool() throws {
        let value = AnyCodable.bool(true)
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)

        #expect(json == "true")
    }

    @Test("Encode null value")
    func testEncodeNull() throws {
        let value = AnyCodable.null
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)

        #expect(json == "null")
    }

    @Test("Encode object value")
    func testEncodeObject() throws {
        let value = AnyCodable.object(["key": .string("value")])
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)

        #expect(json == "{\"key\":\"value\"}")
    }

    @Test("Encode array value")
    func testEncodeArray() throws {
        let value = AnyCodable.array([.int(1), .int(2), .int(3)])
        let data = try JSONEncoder().encode(value)
        let json = String(data: data, encoding: .utf8)

        #expect(json == "[1,2,3]")
    }

    // MARK: - Accessor Tests

    @Test("Accessors return nil for wrong type")
    func testAccessorsReturnNil() {
        let stringValue = AnyCodable.string("test")

        #expect(stringValue.intValue == nil)
        #expect(stringValue.doubleValue == nil)
        #expect(stringValue.boolValue == nil)
        #expect(stringValue.objectValue == nil)
        #expect(stringValue.arrayValue == nil)
        #expect(stringValue.isNull == false)
    }

    // MARK: - Description Tests

    @Test("Description for string")
    func testDescriptionString() {
        let value = AnyCodable.string("test")
        #expect(value.description == "\"test\"")
    }

    @Test("Description for int")
    func testDescriptionInt() {
        let value = AnyCodable.int(42)
        #expect(value.description == "42")
    }

    @Test("Description for double")
    func testDescriptionDouble() {
        let value = AnyCodable.double(3.14)
        #expect(value.description == "3.14")
    }

    @Test("Description for bool")
    func testDescriptionBool() {
        let value = AnyCodable.bool(true)
        #expect(value.description == "true")
    }

    @Test("Description for null")
    func testDescriptionNull() {
        let value = AnyCodable.null
        #expect(value.description == "null")
    }

    @Test("Description for object")
    func testDescriptionObject() {
        let value = AnyCodable.object(["a": .int(1)])
        #expect(value.description.contains("a"))
    }

    @Test("Description for array")
    func testDescriptionArray() {
        let value = AnyCodable.array([.int(1)])
        #expect(value.description.contains("1"))
    }

    // MARK: - Equatable Tests

    @Test("Equality for same values")
    func testEquality() {
        #expect(AnyCodable.string("a") == AnyCodable.string("a"))
        #expect(AnyCodable.int(1) == AnyCodable.int(1))
        #expect(AnyCodable.double(1.5) == AnyCodable.double(1.5))
        #expect(AnyCodable.bool(true) == AnyCodable.bool(true))
        #expect(AnyCodable.null == AnyCodable.null)
        #expect(AnyCodable.array([.int(1)]) == AnyCodable.array([.int(1)]))
        #expect(AnyCodable.object(["a": .int(1)]) == AnyCodable.object(["a": .int(1)]))
    }

    @Test("Inequality for different values")
    func testInequality() {
        #expect(AnyCodable.string("a") != AnyCodable.string("b"))
        #expect(AnyCodable.int(1) != AnyCodable.int(2))
        #expect(AnyCodable.string("1") != AnyCodable.int(1))
    }
}
