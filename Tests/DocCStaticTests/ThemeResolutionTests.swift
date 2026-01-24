//
// ThemeResolutionTests.swift
// DocCStaticTests
//
//  Created by Claude on 25/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import XCTest

@testable import DocCStatic

/// Tests for theme resolution logic.
final class ThemeResolutionTests: XCTestCase {
    /// Tests that nil theme string resolves to default theme.
    func testNilThemeResolvesToDefault() throws {
        let theme = try ThemeConfiguration.resolveTheme(nil)

        // Default theme should have settings
        XCTAssertNotNil(theme.themeSettings)

        // Verify it's the default theme by checking accent colour
        XCTAssertEqual(theme.accentColour, "#36f")
    }

    /// Tests exact match with default theme name.
    func testExactMatchDefaultTheme() throws {
        let theme = try ThemeConfiguration.resolveTheme("default")

        XCTAssertNotNil(theme.themeSettings)
        XCTAssertEqual(theme.accentColour, "#36f")
    }

    /// Tests exact match with classic theme name.
    func testExactMatchClassicTheme() throws {
        let theme = try ThemeConfiguration.resolveTheme("docc-static-classic")

        XCTAssertNotNil(theme.themeSettings)
        XCTAssertEqual(theme.accentColour, "#0066cc")
    }

    /// Tests fuzzy match with partial theme name.
    func testFuzzyMatchClassicTheme() throws {
        let theme = try ThemeConfiguration.resolveTheme("classic")

        // Should match "docc-static-classic"
        XCTAssertNotNil(theme.themeSettings)
        XCTAssertEqual(theme.accentColour, "#0066cc")
    }

    /// Tests custom theme file loading.
    func testCustomThemeFile() throws {
        // Create a temporary theme file
        let tempDir = FileManager.default.temporaryDirectory
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
            try? FileManager.default.removeItem(at: themeFile)
        }

        let theme = try ThemeConfiguration.resolveTheme(themeFile.path)

        XCTAssertNotNil(theme.themeSettings)
        XCTAssertEqual(theme.accentColour, "#ff0000")
    }

    /// Tests error for non-existent theme file path.
    func testNonExistentThemeFile() {
        XCTAssertThrowsError(
            try ThemeConfiguration.resolveTheme("/nonexistent/theme.json")
        ) { error in
            guard let resolutionError = error as? ThemeResolutionError else {
                XCTFail("Expected ThemeResolutionError")
                return
            }

            // A path that doesn't exist will fall through to themeNotFound
            // because the file doesn't exist, so it tries to match as a theme name
            switch resolutionError {
            case .themeNotFound(let name, _):
                XCTAssertEqual(name, "/nonexistent/theme.json")
            case .invalidThemeFile:
                // This could also happen if the path check fails differently
                break
            }
        }
    }

    /// Tests error for unknown theme name.
    func testUnknownThemeName() {
        XCTAssertThrowsError(
            try ThemeConfiguration.resolveTheme("nonexistent-theme")
        ) { error in
            guard let resolutionError = error as? ThemeResolutionError else {
                XCTFail("Expected ThemeResolutionError")
                return
            }

            switch resolutionError {
            case .themeNotFound(let name, let available):
                XCTAssertEqual(name, "nonexistent-theme")
                XCTAssertTrue(available.contains("default"))
                XCTAssertTrue(available.contains("docc-static-classic"))
            case .invalidThemeFile:
                XCTFail("Expected themeNotFound, got invalidThemeFile")
            }
        }
    }

    /// Tests dark mode flag is respected.
    func testDarkModeFlag() throws {
        let themeWithDark = try ThemeConfiguration.resolveTheme(nil, includeDarkMode: true)
        XCTAssertTrue(themeWithDark.includeDarkMode)

        let themeWithoutDark = try ThemeConfiguration.resolveTheme(nil, includeDarkMode: false)
        XCTAssertFalse(themeWithoutDark.includeDarkMode)
    }

    /// Tests custom CSS is included.
    func testCustomCSS() throws {
        let customCSS = "body { font-size: 18px; }"
        let theme = try ThemeConfiguration.resolveTheme(nil, customCSS: customCSS)

        XCTAssertEqual(theme.customCSS, customCSS)
    }

    /// Tests invalid JSON in custom theme file.
    func testInvalidThemeJSON() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let themeFile = tempDir.appendingPathComponent("invalid-theme.json")

        let invalidJSON = "{ invalid json }"
        try invalidJSON.write(to: themeFile, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: themeFile)
        }

        XCTAssertThrowsError(
            try ThemeConfiguration.resolveTheme(themeFile.path)
        ) { error in
            guard let resolutionError = error as? ThemeResolutionError else {
                XCTFail("Expected ThemeResolutionError")
                return
            }

            switch resolutionError {
            case .invalidThemeFile(let path, _):
                XCTAssertTrue(path.contains("invalid-theme.json"))
            case .themeNotFound:
                XCTFail("Expected invalidThemeFile, got themeNotFound")
            }
        }
    }
}
