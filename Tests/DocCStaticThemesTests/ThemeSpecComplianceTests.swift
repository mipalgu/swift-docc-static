//
// ThemeSpecComplianceTests.swift
// DocCStaticThemesTests
//
// Created by Claude Code on 27/01/2026.
// Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import Testing
@testable import DocCStaticThemes

/// Tests to verify default.theme-settings.json compliance with swift-docc ThemeSettings.spec.json
@Suite("Theme Specification Compliance Tests")
struct ThemeSpecComplianceTests {

    @Test("default.theme-settings.json is valid and parseable")
    func defaultThemeIsValid() throws {
        // Load the default theme JSON file
        let themesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Themes")

        let defaultThemePath = themesDir.appendingPathComponent("default").appendingPathComponent(ThemeBundleLayout.settingsFileName)

        #expect(FileManager.default.fileExists(atPath: defaultThemePath.path),
                "default.theme-settings.json must exist at \(defaultThemePath.path)")

        let jsonData = try Data(contentsOf: defaultThemePath)

        // Parse using ThemeSettingsInput
        let settings = try ThemeSettingsInput.parse(jsonData)

        let theme = settings.theme

        // Verify color section exists and has required colors
        #expect(theme.color != nil, "default theme must have 'color' section")

        if let colors = theme.color {
            // Check that critical colors used by swift-docc-render are present
            let requiredColors = [
                "fill",
                "fill-secondary",
                "fill-tertiary",
                "fill-gray-quaternary",
                "navigator-item-hover",
                "link"
            ]

            for colorName in requiredColors {
                #expect(colors.keys.contains(colorName),
                        "default theme must include '\(colorName)' color")
            }

            // Verify fill-gray-quaternary has correct format (light + dark)
            if let fillGrayQuaternary = colors["fill-gray-quaternary"] {
                switch fillGrayQuaternary {
                case .lightDark(let light, let dark):
                    #expect(light == "#f0f0f0",
                            "fill-gray-quaternary light mode should be #f0f0f0")
                    #expect(dark == "#424242",
                            "fill-gray-quaternary dark mode should be #424242")
                case .single:
                    Issue.record("fill-gray-quaternary must have separate light/dark values")
                }
            }

            // Verify navigator-item-hover has correct format
            if let navigatorItemHover = colors["navigator-item-hover"] {
                switch navigatorItemHover {
                case .lightDark(let light, let dark):
                    #expect(light == "rgba(51, 102, 255, 0.05)",
                            "navigator-item-hover light mode should be rgba(51, 102, 255, 0.05)")
                    #expect(dark == "rgba(0, 102, 255, 0.5)",
                            "navigator-item-hover dark mode should be rgba(0, 102, 255, 0.5)")
                case .single:
                    Issue.record("navigator-item-hover must have separate light/dark values")
                }
            }
        }

        // Verify typography section exists
        #expect(theme.typography != nil, "default theme must have 'typography' section")

        if let typography = theme.typography {
            #expect(typography["html-font"] != nil,
                    "default theme must specify html-font")
            #expect(typography["html-font-mono"] != nil,
                    "default theme must specify html-font-mono")
        }
    }

    @Test("Color values follow spec format")
    func colorValuesFollowSpec() throws {
        let themesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Themes")

        let defaultThemePath = themesDir.appendingPathComponent("default").appendingPathComponent(ThemeBundleLayout.settingsFileName)
        let jsonData = try Data(contentsOf: defaultThemePath)

        let settings = try ThemeSettingsInput.parse(jsonData)

        guard let colors = settings.theme.color else {
            Issue.record("No colors found in default theme")
            return
        }

        // Verify all color values are valid CSS colors or light/dark pairs
        for (name, colorValue) in colors {
            switch colorValue {
            case .single(let cssValue):
                // Simple validation: should not be empty
                #expect(!cssValue.isEmpty,
                        "Color '\(name)' has empty CSS value")
            case .lightDark(let light, let dark):
                // Both light and dark should be non-empty
                #expect(!light.isEmpty,
                        "Color '\(name)' has empty light mode value")
                #expect(!dark.isEmpty,
                        "Color '\(name)' has empty dark mode value")
            }
        }
    }

    @Test("Typography values are valid CSS font-family strings")
    func typographyValuesAreValid() throws {
        let themesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Themes")

        let defaultThemePath = themesDir.appendingPathComponent("default").appendingPathComponent(ThemeBundleLayout.settingsFileName)
        let jsonData = try Data(contentsOf: defaultThemePath)

        let settings = try ThemeSettingsInput.parse(jsonData)

        guard let typography = settings.theme.typography else {
            Issue.record("No typography found in default theme")
            return
        }

        if let htmlFont = typography["html-font"] {
            #expect(!htmlFont.isEmpty,
                    "html-font should not be empty")
            // Should contain at least one font name
            #expect(htmlFont.contains("Helvetica") || htmlFont.contains("sans-serif"),
                    "html-font should specify a font family")
        }

        if let htmlFontMono = typography["html-font-mono"] {
            #expect(!htmlFontMono.isEmpty,
                    "html-font-mono should not be empty")
        }
    }
}
