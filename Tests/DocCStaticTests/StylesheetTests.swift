//
// StylesheetTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Testing
import Foundation
@testable import DocCStatic

@Suite("Stylesheet Generation Tests")
struct StylesheetTests {
    @Test("Stylesheet includes CSS custom properties")
    func cssCustomProperties() {
        let css = DocCStylesheet.generate(theme: .default)

        #expect(css.contains("--docc-bg:"))
        #expect(css.contains("--docc-fg:"))
        #expect(css.contains("--docc-accent:"))
    }

    @Test("Stylesheet uses theme accent colour")
    func themeAccentColour() {
        let theme = ThemeConfiguration(accentColour: "#ff5500", includeDarkMode: true)
        let css = DocCStylesheet.generate(theme: theme)

        #expect(css.contains("#ff5500"))
    }

    @Test("Stylesheet includes dark mode when enabled")
    func darkModeEnabled() {
        let theme = ThemeConfiguration(accentColour: "#0066cc", includeDarkMode: true)
        let css = DocCStylesheet.generate(theme: theme)

        #expect(css.contains("@media (prefers-color-scheme: dark)"))
    }

    @Test("Stylesheet excludes dark mode when disabled")
    func darkModeDisabled() {
        let theme = ThemeConfiguration(accentColour: "#0066cc", includeDarkMode: false)
        let css = DocCStylesheet.generate(theme: theme)

        #expect(!css.contains("@media (prefers-color-scheme: dark)"))
    }

    @Test("Stylesheet includes custom CSS when provided")
    func customCSS() {
        let theme = ThemeConfiguration(
            accentColour: "#0066cc",
            includeDarkMode: true,
            customCSS: ".my-class { font-weight: bold; }"
        )
        let css = DocCStylesheet.generate(theme: theme)

        #expect(css.contains(".my-class { font-weight: bold; }"))
    }

    @Test("Stylesheet includes Swift syntax colours")
    func syntaxColours() {
        let css = DocCStylesheet.generate(theme: .default)

        #expect(css.contains("--swift-keyword:"))
        #expect(css.contains("--swift-type:"))
        #expect(css.contains("--swift-string:"))
        #expect(css.contains("--swift-comment:"))
    }

    @Test("Stylesheet includes typography variables")
    func typography() {
        let css = DocCStylesheet.generate(theme: .default)

        #expect(css.contains("--typeface-body:"))
        #expect(css.contains("--typeface-mono:"))
        #expect(css.contains("--typeface-headline:"))
    }

    @Test("Stylesheet includes search result styles")
    func searchResultStyles() {
        let css = DocCStylesheet.generate(theme: .default)

        #expect(css.contains(".search-results"))
        #expect(css.contains(".search-results-list"))
        #expect(css.contains(".search-result-item"))
        #expect(css.contains(".result-title"))
        #expect(css.contains(".result-type"))
    }

    @Test("Stylesheet includes module card styles")
    func moduleCardStyles() {
        let css = DocCStylesheet.generate(theme: .default)

        #expect(css.contains(".module-card"))
        #expect(css.contains(".module-name"))
        #expect(css.contains(".module-abstract"))
    }
}

@Suite("Generation Error Tests")
struct GenerationErrorTests {
    @Test("Symbol graph error has description")
    func symbolGraphError() {
        let error = GenerationError.symbolGraphGenerationFailed("compilation failed")

        #expect(error.errorDescription?.contains("symbol graphs") == true)
        #expect(error.errorDescription?.contains("compilation failed") == true)
    }

    @Test("DocC not found error has description")
    func doccNotFoundError() {
        let error = GenerationError.doccNotFound

        #expect(error.errorDescription?.contains("docc") == true)
    }

    @Test("Archive parsing error has description")
    func archiveParsingError() {
        let error = GenerationError.archiveParsingFailed("invalid JSON")

        #expect(error.errorDescription?.contains("archive") == true)
        #expect(error.errorDescription?.contains("invalid JSON") == true)
    }
}
