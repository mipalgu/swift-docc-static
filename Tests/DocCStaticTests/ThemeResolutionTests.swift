//
// ThemeResolutionTests.swift
// DocCStaticTests
//
//  Created by Claude on 25/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing

@testable import DocCStatic

/// Tests for theme resolution logic.
@Suite("Theme Resolution Tests")
struct ThemeResolutionTests {
    /// Tests that nil theme string resolves to default theme.
    @Test("Nil theme string resolves to the default theme")
    func nilThemeResolvesToDefault() throws {
        let theme = try ThemeConfiguration.resolveTheme(nil)

        // Default theme should have settings
        #expect(theme.themeSettings != nil)

        // Verify it's the default theme by checking accent colour
        #expect(theme.accentColour == "#36f")
    }

    /// Tests exact match with default theme name.
    @Test("Exact match with the default theme name")
    func exactMatchDefaultTheme() throws {
        let theme = try ThemeConfiguration.resolveTheme("default")

        #expect(theme.themeSettings != nil)
        #expect(theme.accentColour == "#36f")
    }

    /// Tests exact match with classic theme name.
    @Test("Exact match with the classic theme name")
    func exactMatchClassicTheme() throws {
        let theme = try ThemeConfiguration.resolveTheme("docc-static-classic")

        #expect(theme.themeSettings != nil)
        #expect(theme.accentColour == "#0066cc")
    }

    /// Tests matching with the short name of the classic theme.
    @Test("Short name of the classic theme")
    func fuzzyMatchClassicTheme() throws {
        let theme = try ThemeConfiguration.resolveTheme("classic")

        // Should match "docc-static-classic"
        #expect(theme.themeSettings != nil)
        #expect(theme.accentColour == "#0066cc")
    }

    /// Tests custom theme file loading.
    @Test("Custom theme file")
    func customThemeFile() throws {
        // Create a temporary theme file
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let themeFile = tempDir.appendingPathComponent("test-theme.json")

        let themeJSON = """
            {
              "theme": {
                "color": {
                  "link": "#ff0000"
                }
              }
            }
            """

        try themeJSON.write(to: themeFile, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let theme = try ThemeConfiguration.resolveTheme(themeFile.path)

        #expect(theme.themeSettings != nil)
        #expect(theme.accentColour == "#ff0000")
    }

    /// Tests error for non-existent theme file path.
    @Test("Non-existent theme file")
    func nonExistentThemeFile() {
        #expect {
            try ThemeConfiguration.resolveTheme("/nonexistent/theme.json")
        } throws: { error in
            guard let resolutionError = error as? ThemeResolutionError else {
                Issue.record("Expected ThemeResolutionError")
                return true
            }

            // A path that doesn't exist will fall through to themeNotFound
            // because the file doesn't exist, so it tries to match as a theme name
            switch resolutionError {
            case .themeNotFound(let name, _):
                #expect(name == "/nonexistent/theme.json")
            case .invalidThemeFile:
                // This could also happen if the path check fails differently
                break
            }
            return true
        }
    }

    /// Tests error for unknown theme name.
    @Test("Unknown theme name")
    func unknownThemeName() {
        #expect {
            try ThemeConfiguration.resolveTheme("nonexistent-theme")
        } throws: { error in
            guard let resolutionError = error as? ThemeResolutionError else {
                Issue.record("Expected ThemeResolutionError")
                return true
            }

            switch resolutionError {
            case .themeNotFound(let name, let available):
                #expect(name == "nonexistent-theme")
                #expect(available.contains("default"))
                #expect(available.contains("docc-static-classic"))
            case .invalidThemeFile:
                Issue.record("Expected themeNotFound, got invalidThemeFile")
            }
            return true
        }
    }

    /// Tests dark mode flag is respected.
    @Test("Dark mode flag")
    func darkModeFlag() throws {
        let themeWithDark = try ThemeConfiguration.resolveTheme(nil, includeDarkMode: true)
        #expect(themeWithDark.includeDarkMode)

        let themeWithoutDark = try ThemeConfiguration.resolveTheme(nil, includeDarkMode: false)
        #expect(!themeWithoutDark.includeDarkMode)
    }

    /// Tests custom CSS is included.
    @Test("Custom CSS")
    func customCSS() throws {
        let customCSS = "body { font-size: 18px; }"
        let theme = try ThemeConfiguration.resolveTheme(nil, customCSS: customCSS)

        #expect(theme.customCSS == customCSS)
    }

    /// Tests invalid JSON in custom theme file.
    @Test("Invalid JSON in a custom theme file")
    func invalidThemeJSON() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let themeFile = tempDir.appendingPathComponent("invalid-theme.json")

        let invalidJSON = "{ invalid json }"
        try invalidJSON.write(to: themeFile, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        #expect {
            try ThemeConfiguration.resolveTheme(themeFile.path)
        } throws: { error in
            guard let resolutionError = error as? ThemeResolutionError else {
                Issue.record("Expected ThemeResolutionError")
                return true
            }

            switch resolutionError {
            case .invalidThemeFile(let path, _):
                #expect(path.contains("invalid-theme.json"))
            case .themeNotFound:
                Issue.record("Expected invalidThemeFile, got themeNotFound")
            }
            return true
        }
    }
}
