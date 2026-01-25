//
// ThemeE2ETests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 25/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Testing
import Foundation
@testable import DocCStatic

@Suite("Theme E2E Tests")
struct ThemeE2ETests {
    @Test("Generated CSS contains all swift-docc-render compatible variables")
    func cssContainsAllRequiredVariables() {
        let css = DocCStylesheet.generate(theme: .default)
        let requiredVariables = [
            "--color-fill:",
            "--color-fill-gray-quaternary:",
            "--color-navigator-item-hover:",
            "--sidebar-width:"
        ]
        for variable in requiredVariables {
            #expect(css.contains(variable), "Missing: \(variable)")
        }
    }

    @Test("Classic theme has distinct styling from default")
    func classicThemeDistinct() {
        let classicTheme = ThemeConfiguration(builtInTheme: .classic, includeDarkMode: true, customCSS: nil)
        let classicCSS = DocCStylesheet.generate(theme: classicTheme)

        // Classic theme has narrower sidebar
        #expect(classicCSS.contains("--spacing-sidebar-width: 320px"))

        // Classic theme has transparent technology title background
        #expect(classicCSS.contains("--color-technology-title-background: transparent"))
    }

    @Test("Default theme matches swift-docc-render variable names")
    func defaultThemeVariableNames() {
        let css = DocCStylesheet.generate(theme: .default)

        // Verify swift-docc-render compatible variable naming
        let renderCompatibleVars = [
            "--color-fill",
            "--color-fill-secondary",
            "--color-fill-tertiary",
            "--color-fill-gray",
            "--color-fill-gray-secondary",
            "--color-fill-gray-quaternary",
            "--color-navigator-item-hover",
            "--color-figure-gray",
            "--color-link",
            "--typography-html-font",
            "--typography-html-font-mono"
        ]

        for variable in renderCompatibleVars {
            #expect(css.contains(variable), "Missing swift-docc-render variable: \(variable)")
        }
    }

    @Test("Navigator card states use correct CSS variables")
    func navigatorCardStatesUseVariables() {
        let css = DocCStylesheet.generate(theme: .default)

        // Verify navigator card hover uses variable
        #expect(css.contains(".navigator-card:hover"))
        #expect(css.contains("background: var(--color-navigator-item-hover)"))

        // Verify navigator card active/selected uses variable
        #expect(css.contains(".navigator-card.active"))
        #expect(css.contains("background: var(--color-fill-gray-quaternary)"))
    }

    @Test("Technology title hover uses correct variable")
    func technologyTitleHoverUsesVariable() {
        let css = DocCStylesheet.generate(theme: .default)

        // Verify technology title hover fallback
        #expect(css.contains(".technology-title:hover"))
        #expect(css.contains("var(--color-navigator-item-hover)"))
    }

    @Test("Dark mode includes all required colour overrides")
    func darkModeColourOverrides() {
        let theme = ThemeConfiguration(accentColour: "#0066cc", includeDarkMode: true)
        let css = DocCStylesheet.generate(theme: theme)

        // Verify dark mode section exists
        #expect(css.contains("@media (prefers-color-scheme: dark)"))

        // Verify dark mode colour overrides
        #expect(css.contains("--color-fill-gray-quaternary: #424242"))
        #expect(css.contains("--color-navigator-item-hover: rgba(0, 102, 255, 0.5)"))
    }

    @Test("Sidebar width respects theme settings")
    func sidebarWidthRespectsTheme() {
        let defaultTheme = ThemeConfiguration(builtInTheme: .default, includeDarkMode: true, customCSS: nil)
        let defaultCSS = DocCStylesheet.generate(theme: defaultTheme)

        let classicTheme = ThemeConfiguration(builtInTheme: .classic, includeDarkMode: true, customCSS: nil)
        let classicCSS = DocCStylesheet.generate(theme: classicTheme)

        // Default should be 400px
        #expect(defaultCSS.contains("--spacing-sidebar-width: 400px"))

        // Classic should be 320px
        #expect(classicCSS.contains("--spacing-sidebar-width: 320px"))
    }

    @Test("All themes generate valid CSS")
    func allThemesGenerateValidCSS() {
        // Test both built-in themes
        for theme in [ThemeSettings.BuiltInTheme.default, ThemeSettings.BuiltInTheme.classic] {
            let config = ThemeConfiguration(builtInTheme: theme, includeDarkMode: true, customCSS: nil)
            let css = DocCStylesheet.generate(theme: config)

            // Basic validation
            #expect(!css.isEmpty, "Theme \(theme) generated empty CSS")
            #expect(css.contains(":root"), "Theme \(theme) missing :root selector")
            #expect(css.contains("--color-fill:"), "Theme \(theme) missing colour variables")
        }
    }
}
