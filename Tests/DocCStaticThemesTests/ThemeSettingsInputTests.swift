//
// ThemeSettingsInputTests.swift
// DocCStaticThemesTests
//
//  Created by Rene Hexel on 22/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing

@testable import DocCStaticThemes

@Suite("ThemeSettingsInput Tests")
struct ThemeSettingsInputTests {
    // MARK: - Basic Parsing Tests

    @Test("Parse minimal theme settings")
    func testParseMinimalTheme() throws {
        let json = """
            {
                "theme": {}
            }
            """
        let data = Data(json.utf8)
        let settings = try ThemeSettingsInput.parse(data)

        #expect(settings.theme.color == nil)
        #expect(settings.theme.typography == nil)
        #expect(settings.meta == nil)
    }

    @Test("Parse theme with colours")
    func testParseThemeWithColours() throws {
        let json = """
            {
                "theme": {
                    "color": {
                        "link": "#0066cc",
                        "fill": { "light": "#ffffff", "dark": "#000000" }
                    }
                }
            }
            """
        let data = Data(json.utf8)
        let settings = try ThemeSettingsInput.parse(data)

        #expect(settings.theme.color != nil)
        #expect(settings.theme.color?.count == 2)
        #expect(settings.theme.color?["link"] == .single("#0066cc"))
        #expect(settings.theme.color?["fill"] == .lightDark(light: "#ffffff", dark: "#000000"))
    }

    @Test("Parse theme with typography")
    func testParseThemeWithTypography() throws {
        let json = """
            {
                "theme": {
                    "typography": {
                        "html-font": "system-ui, sans-serif",
                        "html-font-mono": "Menlo, monospace"
                    }
                }
            }
            """
        let data = Data(json.utf8)
        let settings = try ThemeSettingsInput.parse(data)

        #expect(settings.theme.typography != nil)
        #expect(settings.theme.typography?["html-font"] == "system-ui, sans-serif")
        #expect(settings.theme.typography?["html-font-mono"] == "Menlo, monospace")
    }

    @Test("Parse complete theme settings")
    func testParseCompleteTheme() throws {
        let json = """
            {
                "theme": {
                    "color": {
                        "link": "#0066cc"
                    },
                    "typography": {
                        "html-font": "system-ui"
                    }
                },
                "meta": {
                    "version": "1.0"
                }
            }
            """
        let data = Data(json.utf8)
        let settings = try ThemeSettingsInput.parse(data)

        #expect(settings.theme.color != nil)
        #expect(settings.theme.typography != nil)
        #expect(settings.meta != nil)
        #expect(settings.meta?["version"]?.stringValue == "1.0")
    }

    // MARK: - Warning Tests

    @Test("Warning for unknown top-level key")
    func testWarningForUnknownTopLevelKey() throws {
        let json = """
            {
                "theme": {},
                "unknownKey": "value"
            }
            """
        let data = Data(json.utf8)
        let warningHandler = CollectingWarningHandler()
        _ = try ThemeSettingsInput.parse(data, warningHandler: warningHandler)

        #expect(warningHandler.warnings.count == 1)
        #expect(warningHandler.warnings[0].contains("unknownKey"))
    }

    @Test("Warning for unknown theme key")
    func testWarningForUnknownThemeKey() throws {
        let json = """
            {
                "theme": {
                    "color": {},
                    "unknownThemeKey": "value"
                }
            }
            """
        let data = Data(json.utf8)
        let warningHandler = CollectingWarningHandler()
        _ = try ThemeSettingsInput.parse(data, warningHandler: warningHandler)

        #expect(warningHandler.warnings.count == 1)
        #expect(warningHandler.warnings[0].contains("unknownThemeKey"))
    }

    @Test("Warning for unknown colour variant")
    func testWarningForUnknownColourVariant() throws {
        let json = """
            {
                "theme": {
                    "color": {
                        "fill": { "light": "#fff", "dark": "#000", "medium": "#888" }
                    }
                }
            }
            """
        let data = Data(json.utf8)
        let warningHandler = CollectingWarningHandler()
        _ = try ThemeSettingsInput.parse(data, warningHandler: warningHandler)

        #expect(warningHandler.warnings.count == 1)
        #expect(warningHandler.warnings[0].contains("medium"))
    }

    @Test("Multiple warnings are collected")
    func testMultipleWarnings() throws {
        let json = """
            {
                "theme": {
                    "unknownKey1": "value",
                    "unknownKey2": "value"
                },
                "unknownTopLevel": "value"
            }
            """
        let data = Data(json.utf8)
        let warningHandler = CollectingWarningHandler()
        _ = try ThemeSettingsInput.parse(data, warningHandler: warningHandler)

        #expect(warningHandler.warnings.count == 3)
    }

    @Test("No warning handler means no crash")
    func testNoWarningHandler() throws {
        let json = """
            {
                "theme": {},
                "unknownKey": "value"
            }
            """
        let data = Data(json.utf8)
        // Should not crash without a warning handler
        let settings = try ThemeSettingsInput.parse(data, warningHandler: nil)
        #expect(settings.theme.color == nil)
    }

    // MARK: - Initialisation Tests

    @Test("Create ThemeSettingsInput programmatically")
    func testProgrammaticInit() {
        let theme = ThemeInput(
            color: ["link": .single("#0066cc")],
            typography: ["html-font": "system-ui"]
        )
        let settings = ThemeSettingsInput(
            theme: theme,
            meta: ["version": .string("1.0")]
        )

        #expect(settings.theme.color?["link"]?.light == "#0066cc")
        #expect(settings.theme.typography?["html-font"] == "system-ui")
        #expect(settings.meta?["version"]?.stringValue == "1.0")
    }

    // MARK: - Equatable Tests

    @Test("ThemeSettingsInput equality")
    func testEquality() {
        let theme1 = ThemeInput(color: ["link": .single("#0066cc")])
        let theme2 = ThemeInput(color: ["link": .single("#0066cc")])
        let settings1 = ThemeSettingsInput(theme: theme1)
        let settings2 = ThemeSettingsInput(theme: theme2)

        #expect(settings1 == settings2)
    }

    @Test("ThemeSettingsInput inequality")
    func testInequality() {
        let theme1 = ThemeInput(color: ["link": .single("#0066cc")])
        let theme2 = ThemeInput(color: ["link": .single("#ff0000")])
        let settings1 = ThemeSettingsInput(theme: theme1)
        let settings2 = ThemeSettingsInput(theme: theme2)

        #expect(settings1 != settings2)
    }

    // MARK: - File Parsing Tests

    @Test("Parse from file URL")
    func testParseFromFileURL() throws {
        let json = """
            {
                "theme": {
                    "color": {
                        "link": "#0066cc"
                    }
                }
            }
            """
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test-theme.json")
        try json.write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let settings = try ThemeSettingsInput.parse(contentsOf: fileURL)
        #expect(settings.theme.color?["link"]?.light == "#0066cc")
    }
}

@Suite("ColorValueInput Tests")
struct ColorValueInputTests {
    // MARK: - Single Value Tests

    @Test("Parse single colour value")
    func testParseSingleColour() throws {
        let json = "\"#0066cc\""
        let data = Data(json.utf8)
        let colour = try JSONDecoder().decode(ColorValueInput.self, from: data)

        #expect(colour == .single("#0066cc"))
        #expect(colour.light == "#0066cc")
        #expect(colour.dark == "#0066cc")
    }

    // MARK: - Light/Dark Value Tests

    @Test("Parse light/dark colour value")
    func testParseLightDarkColour() throws {
        let json = """
            { "light": "#ffffff", "dark": "#000000" }
            """
        let data = Data(json.utf8)
        let colour = try JSONDecoder().decode(ColorValueInput.self, from: data)

        #expect(colour == .lightDark(light: "#ffffff", dark: "#000000"))
        #expect(colour.light == "#ffffff")
        #expect(colour.dark == "#000000")
    }

    // MARK: - Encoding Tests

    @Test("Encode single colour value")
    func testEncodeSingleColour() throws {
        let colour = ColorValueInput.single("#0066cc")
        let data = try JSONEncoder().encode(colour)
        let json = String(data: data, encoding: .utf8)

        #expect(json == "\"#0066cc\"")
    }

    @Test("Encode light/dark colour value")
    func testEncodeLightDarkColour() throws {
        let colour = ColorValueInput.lightDark(light: "#ffffff", dark: "#000000")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(colour)
        let json = String(data: data, encoding: .utf8)

        #expect(json == "{\"dark\":\"#000000\",\"light\":\"#ffffff\"}")
    }

    // MARK: - Equatable Tests

    @Test("ColorValueInput equality")
    func testEquality() {
        #expect(ColorValueInput.single("#fff") == ColorValueInput.single("#fff"))
        #expect(ColorValueInput.lightDark(light: "#fff", dark: "#000")
            == ColorValueInput.lightDark(light: "#fff", dark: "#000"))
    }

    @Test("ColorValueInput inequality")
    func testInequality() {
        #expect(ColorValueInput.single("#fff") != ColorValueInput.single("#000"))
        #expect(ColorValueInput.single("#fff") != ColorValueInput.lightDark(light: "#fff", dark: "#fff"))
    }
}

@Suite("ThemeInput Tests")
struct ThemeInputTests {
    @Test("Create empty ThemeInput")
    func testEmptyThemeInput() {
        let theme = ThemeInput()
        #expect(theme.color == nil)
        #expect(theme.typography == nil)
    }

    @Test("Create ThemeInput with colour")
    func testThemeInputWithColour() {
        let theme = ThemeInput(color: ["link": .single("#0066cc")])
        #expect(theme.color?["link"]?.light == "#0066cc")
    }

    @Test("Create ThemeInput with typography")
    func testThemeInputWithTypography() {
        let theme = ThemeInput(typography: ["html-font": "system-ui"])
        #expect(theme.typography?["html-font"] == "system-ui")
    }

    @Test("ThemeInput equality")
    func testEquality() {
        let theme1 = ThemeInput(color: ["link": .single("#0066cc")])
        let theme2 = ThemeInput(color: ["link": .single("#0066cc")])
        #expect(theme1 == theme2)
    }
}

@Suite("Warning Handler Tests")
struct WarningHandlerTests {
    @Test("CollectingWarningHandler collects warnings")
    func testCollectingWarningHandler() {
        let handler = CollectingWarningHandler()

        handler.handleWarning("Warning 1")
        handler.handleWarning("Warning 2")

        #expect(handler.warnings.count == 2)
        #expect(handler.warnings[0] == "Warning 1")
        #expect(handler.warnings[1] == "Warning 2")
    }

    @Test("CollectingWarningHandler is thread-safe")
    func testCollectingWarningHandlerThreadSafety() async {
        let handler = CollectingWarningHandler()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    handler.handleWarning("Warning \(i)")
                }
            }
        }

        #expect(handler.warnings.count == 100)
    }

    @Test("StderrWarningHandler can be created")
    func testStderrWarningHandler() {
        let handler = StderrWarningHandler()
        // Just verify it can be created and called without crashing
        handler.handleWarning("Test warning")
    }
}

@Suite("DynamicCodingKey Tests")
struct DynamicCodingKeyTests {
    @Test("Create DynamicCodingKey from string")
    func testStringInit() {
        let key = DynamicCodingKey(stringValue: "test")
        #expect(key?.stringValue == "test")
        #expect(key?.intValue == nil)
    }

    @Test("Create DynamicCodingKey from int")
    func testIntInit() {
        let key = DynamicCodingKey(intValue: 42)
        #expect(key?.stringValue == "42")
        #expect(key?.intValue == 42)
    }
}
