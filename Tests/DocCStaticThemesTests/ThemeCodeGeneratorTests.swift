//
// ThemeCodeGeneratorTests.swift
// DocCStaticThemesTests
//
//  Created by Rene Hexel on 22/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing

@testable import DocCStaticThemes

@Suite("ThemeCodeGenerator Tests")
struct ThemeCodeGeneratorTests {
    let generator = ThemeCodeGenerator()

    // MARK: - Naming Tests

    @Test("Swift property name for default theme")
    func testPropertyNameDefault() {
        let name = generator.swiftPropertyName(for: "default")
        #expect(name == "defaultThemeData")
    }

    @Test("Swift property name for classic theme")
    func testPropertyNameClassic() {
        let name = generator.swiftPropertyName(for: "docc-static-classic")
        #expect(name == "classicThemeData")
    }

    @Test("Swift property name for custom theme")
    func testPropertyNameCustom() {
        let name = generator.swiftPropertyName(for: "my-custom-theme")
        #expect(name == "myCustomThemeThemeData")
    }

    @Test("Human readable name for default theme")
    func testHumanReadableNameDefault() {
        let name = generator.humanReadableName(from: "defaultThemeData")
        #expect(name == "default")
    }

    @Test("Human readable name for classic theme")
    func testHumanReadableNameClassic() {
        let name = generator.humanReadableName(from: "classicThemeData")
        #expect(name == "classic")
    }

    @Test("Human readable name for custom theme")
    func testHumanReadableNameCustom() {
        let name = generator.humanReadableName(from: "myCustomThemeThemeData")
        #expect(name == "myCustomTheme")
    }

    // MARK: - Colour Value Generation Tests

    @Test("Generate single colour value")
    func testGenerateSingleColourValue() {
        let value = ColorValueInput.single("#0066cc")
        let code = generator.generateColourValue(value)
        #expect(code == "ThemeSettings.ColorValue.single(\"#0066cc\")")
    }

    @Test("Generate light/dark colour value")
    func testGenerateLightDarkColourValue() {
        let value = ColorValueInput.lightDark(light: "#ffffff", dark: "#000000")
        let code = generator.generateColourValue(value)
        #expect(code == "ThemeSettings.ColorValue.lightDark(light: \"#ffffff\", dark: \"#000000\")")
    }

    // MARK: - Colour Dictionary Generation Tests

    @Test("Generate colour dictionary")
    func testGenerateColourDictionary() {
        let colours: [String: ColorValueInput] = [
            "link": .single("#0066cc"),
            "fill": .lightDark(light: "#ffffff", dark: "#000000"),
        ]
        let code = generator.generateColourDictionary(colours, baseIndent: 0)

        #expect(code.contains("color: ["))
        #expect(code.contains("\"fill\": ThemeSettings.ColorValue.lightDark(light: \"#ffffff\", dark: \"#000000\")"))
        #expect(code.contains("\"link\": ThemeSettings.ColorValue.single(\"#0066cc\")"))
        #expect(code.contains("]"))
    }

    @Test("Colour dictionary is sorted alphabetically")
    func testColourDictionarySorting() {
        let colours: [String: ColorValueInput] = [
            "zebra": .single("#000"),
            "alpha": .single("#fff"),
        ]
        let code = generator.generateColourDictionary(colours, baseIndent: 0)

        let alphaIndex = code.range(of: "alpha")!.lowerBound
        let zebraIndex = code.range(of: "zebra")!.lowerBound
        #expect(alphaIndex < zebraIndex)
    }

    // MARK: - Typography Dictionary Generation Tests

    @Test("Generate typography dictionary")
    func testGenerateTypographyDictionary() {
        let typography: [String: String] = [
            "html-font": "system-ui, sans-serif",
            "html-font-mono": "Menlo, monospace",
        ]
        let code = generator.generateTypographyDictionary(typography, baseIndent: 0)

        #expect(code.contains("typography: ["))
        #expect(code.contains("\"html-font\": \"system-ui, sans-serif\""))
        #expect(code.contains("\"html-font-mono\": \"Menlo, monospace\""))
        #expect(code.contains("]"))
    }

    @Test("Typography escapes double quotes")
    func testTypographyEscapesDoubleQuotes() {
        let typography: [String: String] = [
            "html-font": "\"SF Pro\", sans-serif",
        ]
        let code = generator.generateTypographyDictionary(typography, baseIndent: 0)

        // Double quotes should be escaped in the generated Swift string
        #expect(code.contains("\\\"SF Pro\\\""))
    }

    @Test("Typography preserves single quotes")
    func testTypographyPreservesSingleQuotes() {
        let typography: [String: String] = [
            "html-font": "'SF Pro', sans-serif",
        ]
        let code = generator.generateTypographyDictionary(typography, baseIndent: 0)

        // Single quotes don't need escaping in Swift strings
        #expect(code.contains("'SF Pro'"))
    }

    // MARK: - Theme Property Generation Tests

    @Test("Generate theme property with colours only")
    func testGenerateThemePropertyColoursOnly() {
        let theme = ThemeInput(color: ["link": .single("#0066cc")])
        let settings = ThemeSettingsInput(theme: theme)
        let code = generator.generateThemeProperty(settings: settings, propertyName: "testThemeData")

        #expect(code.contains("/// Generated theme data for the test theme."))
        #expect(code.contains("static let testThemeData = ThemeSettings.Root("))
        #expect(code.contains("theme: ThemeSettings.Theme("))
        #expect(code.contains("color: ["))
        #expect(code.contains("\"link\": ThemeSettings.ColorValue.single(\"#0066cc\")"))
    }

    @Test("Generate theme property with typography only")
    func testGenerateThemePropertyTypographyOnly() {
        let theme = ThemeInput(typography: ["html-font": "system-ui"])
        let settings = ThemeSettingsInput(theme: theme)
        let code = generator.generateThemeProperty(settings: settings, propertyName: "testThemeData")

        #expect(code.contains("typography: ["))
        #expect(code.contains("\"html-font\": \"system-ui\""))
        #expect(!code.contains("color: ["))
    }

    @Test("Generate theme property with both colours and typography")
    func testGenerateThemePropertyBoth() {
        let theme = ThemeInput(
            color: ["link": .single("#0066cc")],
            typography: ["html-font": "system-ui"]
        )
        let settings = ThemeSettingsInput(theme: theme)
        let code = generator.generateThemeProperty(settings: settings, propertyName: "testThemeData")

        #expect(code.contains("color: ["))
        #expect(code.contains("typography: ["))
    }

    @Test("Generate theme property with empty theme")
    func testGenerateThemePropertyEmpty() {
        let theme = ThemeInput()
        let settings = ThemeSettingsInput(theme: theme)
        let code = generator.generateThemeProperty(settings: settings, propertyName: "emptyThemeData")

        #expect(code.contains("static let emptyThemeData = ThemeSettings.Root("))
        #expect(code.contains("theme: ThemeSettings.Theme()"))
    }

    // MARK: - Header Generation Tests

    @Test("Generate header contains expected elements")
    func testGenerateHeader() {
        let date = Date()
        let header = generator.generateHeader(date: date)

        #expect(header.contains("GeneratedThemes.swift"))
        #expect(header.contains("DocCStatic"))
        #expect(header.contains("AUTO-GENERATED FILE - DO NOT EDIT"))
        #expect(header.contains("theme-codegen"))
        #expect(header.contains("Copyright © 2026 Rene Hexel"))
    }

    // MARK: - Full File Generation Tests

    @Test("Generate file with single theme")
    func testGenerateFileSingleTheme() {
        let theme = ThemeInput(color: ["link": .single("#0066cc")])
        let settings = ThemeSettingsInput(theme: theme)
        let themes = [(name: "default", settings: settings)]

        let code = generator.generateFile(themes: themes)

        #expect(code.contains("extension ThemeSettings.BuiltInTheme {"))
        #expect(code.contains("static let defaultThemeData"))
        #expect(code.hasSuffix("}\n"))
    }

    @Test("Generate file with multiple themes")
    func testGenerateFileMultipleThemes() {
        let defaultTheme = ThemeInput(color: ["link": .single("#0066cc")])
        let classicTheme = ThemeInput(color: ["link": .single("#ff0000")])

        let themes = [
            (name: "default", settings: ThemeSettingsInput(theme: defaultTheme)),
            (name: "docc-static-classic", settings: ThemeSettingsInput(theme: classicTheme)),
        ]

        let code = generator.generateFile(themes: themes)

        #expect(code.contains("static let defaultThemeData"))
        #expect(code.contains("static let classicThemeData"))
    }

    // MARK: - Custom Indentation Tests

    @Test("Custom indentation is respected")
    func testCustomIndentation() {
        let customGenerator = ThemeCodeGenerator(indentation: "\t")
        let theme = ThemeInput(color: ["link": .single("#0066cc")])
        let settings = ThemeSettingsInput(theme: theme)
        let code = customGenerator.generateThemeProperty(settings: settings, propertyName: "testThemeData")

        #expect(code.contains("\t///"))
        #expect(code.contains("\tstatic let"))
    }
}
