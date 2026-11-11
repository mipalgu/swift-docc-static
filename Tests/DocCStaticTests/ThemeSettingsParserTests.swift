//
// ThemeSettingsParserTests.swift
// DocCStaticTests
//
//  Created by Claude on 21/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing

@testable import DocCStatic

@Suite("ThemeSettingsParser Tests")
struct ThemeSettingsParserTests {
    // MARK: - JSON Parsing Tests

    @Test("Parse theme settings with single color values")
    func testParseSingleColorValues() throws {
        let json = """
            {
              "theme": {
                "color": {
                  "link": "#0066cc",
                  "aside-note-border": "#2196f3"
                }
              }
            }
            """
        let data = Data(json.utf8)
        let settings = try ThemeSettingsParser.parse(data)

        #expect(settings.theme.color?["link"] == .single("#0066cc"))
        #expect(settings.theme.color?["aside-note-border"] == .single("#2196f3"))
    }

    @Test("Parse theme settings with light/dark color values")
    func testParseLightDarkColorValues() throws {
        let json = """
            {
              "theme": {
                "color": {
                  "fill": { "light": "#ffffff", "dark": "#1d1d1f" },
                  "fill-secondary": { "light": "#f5f5f7", "dark": "#2c2c2e" }
                }
              }
            }
            """
        let data = Data(json.utf8)
        let settings = try ThemeSettingsParser.parse(data)

        if case .lightDark(let light, let dark) = settings.theme.color?["fill"] {
            #expect(light == "#ffffff")
            #expect(dark == "#1d1d1f")
        } else {
            Issue.record("Expected lightDark color value for 'fill'")
        }

        if case .lightDark(let light, let dark) = settings.theme.color?["fill-secondary"] {
            #expect(light == "#f5f5f7")
            #expect(dark == "#2c2c2e")
        } else {
            Issue.record("Expected lightDark color value for 'fill-secondary'")
        }
    }

    @Test("Parse theme settings with typography")
    func testParseTypography() throws {
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
        let settings = try ThemeSettingsParser.parse(data)

        #expect(settings.theme.typography?["html-font"] == "system-ui, sans-serif")
        #expect(settings.theme.typography?["html-font-mono"] == "Menlo, monospace")
    }

    @Test("Parse complete theme settings")
    func testParseCompleteThemeSettings() throws {
        let json = """
            {
              "theme": {
                "color": {
                  "fill": { "light": "#ffffff", "dark": "#1d1d1f" },
                  "link": "#0066cc"
                },
                "typography": {
                  "html-font": "-apple-system, sans-serif"
                }
              }
            }
            """
        let data = Data(json.utf8)
        let settings = try ThemeSettingsParser.parse(data)

        #expect(settings.theme.color != nil)
        #expect(settings.theme.typography != nil)
        #expect(settings.theme.color?.count == 2)
        #expect(settings.theme.typography?.count == 1)
    }

    // MARK: - CSS Generation Tests

    @Test("Generate light mode CSS")
    func testGenerateLightModeCSS() throws {
        let settings = ThemeSettings.Root(
            theme: ThemeSettings.Theme(
                color: [
                    "fill": .lightDark(light: "#ffffff", dark: "#1d1d1f"),
                    "link": .single("#0066cc"),
                ],
                typography: [
                    "html-font": "system-ui, sans-serif"
                ]
            )
        )

        let css = ThemeSettingsParser.generateLightModeCSS(from: settings)

        #expect(css.contains("--color-fill: #ffffff"))
        #expect(css.contains("--color-link: #0066cc"))
        #expect(css.contains("--typography-html-font: system-ui, sans-serif"))
        #expect(css.contains("body {"))
    }

    @Test("Generate dark mode CSS")
    func testGenerateDarkModeCSS() throws {
        let settings = ThemeSettings.Root(
            theme: ThemeSettings.Theme(
                color: [
                    "fill": .lightDark(light: "#ffffff", dark: "#1d1d1f"),
                    "link": .single("#0066cc"),  // Same for both modes
                ]
            )
        )

        let css = ThemeSettingsParser.generateDarkModeCSS(from: settings)

        // Should include fill (different values)
        #expect(css.contains("--color-fill: light-dark(#ffffff, #1d1d1f)"))
        // Should NOT include link (same value for both modes)
        #expect(!css.contains("--color-link"))
        #expect(css.contains("@supports (color: light-dark(#000, #fff))"))
    }

    @Test("Generate CSS includes both modes when enabled")
    func testGenerateCSSWithBothModes() throws {
        let settings = ThemeSettings.Root(
            theme: ThemeSettings.Theme(
                color: [
                    "fill": .lightDark(light: "#ffffff", dark: "#1d1d1f")
                ]
            )
        )

        let css = ThemeSettingsParser.generateCSS(from: settings, includeDarkMode: true)

        #expect(css.contains("body {"))
        #expect(css.contains("light-dark(#ffffff, #1d1d1f)"))
    }

    @Test("Generate CSS without dark mode when disabled")
    func testGenerateCSSWithoutDarkMode() throws {
        let settings = ThemeSettings.Root(
            theme: ThemeSettings.Theme(
                color: [
                    "fill": .lightDark(light: "#ffffff", dark: "#1d1d1f")
                ]
            )
        )

        let css = ThemeSettingsParser.generateCSS(from: settings, includeDarkMode: false)

        #expect(css.contains("body {"))
        #expect(!css.contains("light-dark("))
    }

    // MARK: - Color Value Tests

    @Test("ColorValue light property returns correct value")
    func testColorValueLight() {
        let single = ThemeSettings.ColorValue.single("#0066cc")
        let lightDark = ThemeSettings.ColorValue.lightDark(light: "#ffffff", dark: "#1d1d1f")

        #expect(single.light == "#0066cc")
        #expect(lightDark.light == "#ffffff")
    }

    @Test("ColorValue dark property returns correct value")
    func testColorValueDark() {
        let single = ThemeSettings.ColorValue.single("#0066cc")
        let lightDark = ThemeSettings.ColorValue.lightDark(light: "#ffffff", dark: "#1d1d1f")

        #expect(single.dark == "#0066cc")
        #expect(lightDark.dark == "#1d1d1f")
    }

    // MARK: - Variable Extraction Tests

    @Test("Extract variables for light mode")
    func testExtractVariablesLight() {
        let settings = ThemeSettings.Root(
            theme: ThemeSettings.Theme(
                color: [
                    "fill": .lightDark(light: "#ffffff", dark: "#1d1d1f"),
                    "link": .single("#0066cc"),
                ],
                typography: [
                    "html-font": "system-ui"
                ]
            )
        )

        let variables = ThemeSettingsParser.extractVariables(from: settings, colorScheme: .light)

        #expect(variables["--color-fill"] == "#ffffff")
        #expect(variables["--color-link"] == "#0066cc")
        #expect(variables["--typography-html-font"] == "system-ui")
    }

    @Test("Extract variables for dark mode")
    func testExtractVariablesDark() {
        let settings = ThemeSettings.Root(
            theme: ThemeSettings.Theme(
                color: [
                    "fill": .lightDark(light: "#ffffff", dark: "#1d1d1f"),
                    "link": .single("#0066cc"),
                ]
            )
        )

        let variables = ThemeSettingsParser.extractVariables(from: settings, colorScheme: .dark)

        #expect(variables["--color-fill"] == "#1d1d1f")
        #expect(variables["--color-link"] == "#0066cc")
    }

    // MARK: - Built-in Theme Tests

    @Test("Classic theme has expected color values")
    func testClassicTheme() {
        let classic = ThemeSettings.BuiltInTheme.classic.settings

        #expect(classic.theme.color != nil)
        #expect(classic.theme.typography != nil)

        // Check some expected values
        if case .lightDark(let light, _) = classic.theme.color?["fill"] {
            #expect(light == "#ffffff")
        } else {
            Issue.record("Expected lightDark color value for 'fill'")
        }

        #expect(classic.theme.color?["link"]?.light == "#0066cc")
    }

    @Test("Built-in theme raw values")
    func testBuiltInThemeRawValues() {
        #expect(ThemeSettings.BuiltInTheme.classic.rawValue == "docc-static-classic")
        #expect(ThemeSettings.BuiltInTheme(rawValue: "docc-static-classic") == .classic)
        #expect(ThemeSettings.BuiltInTheme(rawValue: "unknown") == nil)
    }

    // MARK: - ThemeConfiguration Tests

    @Test("ThemeConfiguration with built-in theme")
    func testThemeConfigurationWithBuiltInTheme() {
        let config = ThemeConfiguration(builtInTheme: .classic)

        #expect(config.themeSettings != nil)
        #expect(config.accentColour == "#0066cc")
        #expect(config.includeDarkMode == true)
    }

    @Test("ThemeConfiguration with theme settings")
    func testThemeConfigurationWithThemeSettings() {
        let settings = ThemeSettings.Root(
            theme: ThemeSettings.Theme(
                color: ["link": .single("#ff0000")]
            )
        )

        let config = ThemeConfiguration(themeSettings: settings, includeDarkMode: false)

        #expect(config.themeSettings != nil)
        #expect(config.accentColour == "#ff0000")
        #expect(config.includeDarkMode == false)
    }

    @Test("Default ThemeConfiguration uses generated theme settings")
    func testDefaultThemeConfiguration() {
        let config = ThemeConfiguration.default

        // Default theme now uses generated theme data from Themes/default.theme-settings.json
        #expect(config.themeSettings != nil)
        #expect(config.accentColour == "#36f")
        #expect(config.includeDarkMode == true)
    }

    // MARK: - Real swift-docc Theme Integration Tests

    @Test("Parse real swift-docc Solarized theme (mportiz08)")
    func testParseRealSolarizedTheme() throws {
        // This is a real theme-settings.json used with swift-docc
        // Source: https://mportiz08.github.io/swift-docc/theme-settings.json
        let json = """
            {
              "meta": {},
              "theme": {
                "aside": {
                  "border-radius": "6px",
                  "border-style": "double",
                  "border-width": "3px"
                },
                "border-radius": "0",
                "button": {
                  "border-radius": "8px",
                  "border-style": "solid",
                  "border-width": "2px"
                },
                "code": {
                  "border-radius": "2px",
                  "border-style": "dashed",
                  "border-width": "2px",
                  "indentationWidth": 2
                },
                "color": {
                  "aside-deprecated-background": "var(--color-fill-secondary)",
                  "aside-deprecated-border": "var(--color-figure-orange)",
                  "figure-gray": {
                    "light": "var(--color-solarized-base00)",
                    "dark": "var(--color-solarized-base0)"
                  },
                  "fill": {
                    "light": "var(--color-solarized-base3)",
                    "dark": "var(--color-solarized-base03)"
                  },
                  "solarized-base03": "rgb(0, 43, 54)",
                  "solarized-base3": "rgb(253, 246, 227)",
                  "syntax-keywords": "var(--color-solarized-green)",
                  "solarized-green": "rgb(133, 153, 0)"
                },
                "typography": {
                  "html-font": "-apple-system, BlinkMacSystemFont, \\"Segoe UI\\", Helvetica, Arial, sans-serif",
                  "html-font-mono": "ui-monospace, SFMono-Regular, \\"SF Mono\\", Menlo, Consolas, monospace"
                }
              },
              "features": {
                "docs": {}
              }
            }
            """
        let data = Data(json.utf8)
        let settings = try ThemeSettingsParser.parse(data)

        // Verify parsing succeeds
        #expect(settings.theme.color != nil)
        #expect(settings.theme.typography != nil)

        // Verify single color values (CSS variable references)
        #expect(settings.theme.color?["solarized-base03"] == .single("rgb(0, 43, 54)"))
        #expect(settings.theme.color?["syntax-keywords"] == .single("var(--color-solarized-green)"))

        // Verify light/dark color values with CSS variable references
        if case .lightDark(let light, let dark) = settings.theme.color?["fill"] {
            #expect(light == "var(--color-solarized-base3)")
            #expect(dark == "var(--color-solarized-base03)")
        } else {
            Issue.record("Expected lightDark color value for 'fill'")
        }

        // Verify typography
        #expect(settings.theme.typography?["html-font"]?.contains("-apple-system") == true)
        #expect(settings.theme.typography?["html-font-mono"]?.contains("ui-monospace") == true)

        // Verify CSS generation works
        let css = ThemeSettingsParser.generateCSS(from: settings, includeDarkMode: true)
        #expect(css.contains("--color-solarized-base03: rgb(0, 43, 54)"))
        #expect(css.contains("--color-syntax-keywords: var(--color-solarized-green)"))
        #expect(css.contains("--typography-html-font:"))
    }
}
