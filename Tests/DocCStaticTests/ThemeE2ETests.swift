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
        #expect(css.contains(".navigator-card-item:not(.is-group):hover .head-wrapper"))
        #expect(css.contains("background: var(--color-navigator-item-hover)"))

        // Verify the current page's row (the target row) uses variable
        #expect(css.contains(".navigator-card-item:target .head-wrapper"))
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

        // Verify the palette follows the colour scheme
        #expect(css.contains("color-scheme: light dark"))

        // Verify dark mode colour overrides
        #expect(css.contains("--color-fill-gray-quaternary: light-dark(#f0f0f0, #424242)"))
        #expect(css.contains("--color-navigator-item-hover: light-dark(rgba(0, 0, 255, .05), rgba(0, 102, 255, .5))"))
    }

    @Test("Sidebar width respects theme settings")
    func sidebarWidthRespectsTheme() {
        let defaultTheme = ThemeConfiguration(builtInTheme: .default, includeDarkMode: true, customCSS: nil)
        let defaultCSS = DocCStylesheet.generate(theme: defaultTheme)

        let classicTheme = ThemeConfiguration(builtInTheme: .classic, includeDarkMode: true, customCSS: nil)
        let classicCSS = DocCStylesheet.generate(theme: classicTheme)

        // Default theme uses docc-render's default width, kept between 30% and 40% of the viewport
        #expect(defaultCSS.contains("--sidebar-width: var(--spacing-sidebar-width, clamp(calc(min(100vw, 1521px) * 0.3), 400px, calc(min(100vw, 1521px) * 0.4)))"))

        // Classic theme also uses the same variable pattern (theme can override via --spacing-sidebar-width)
        #expect(classicCSS.contains("--sidebar-width: var(--spacing-sidebar-width,"))
    }

    @Test("All themes generate valid CSS")
    func allThemesGenerateValidCSS() {
        // Test both built-in themes
        for theme in [ThemeSettings.BuiltInTheme.default, ThemeSettings.BuiltInTheme.classic] {
            let config = ThemeConfiguration(builtInTheme: theme, includeDarkMode: true, customCSS: nil)
            let css = DocCStylesheet.generate(theme: config)

            // Basic validation
            #expect(!css.isEmpty, "Theme \(theme) generated empty CSS")
            #expect(css.contains("body {"), "Theme \(theme) missing body selector")
            #expect(css.contains("--color-fill:"), "Theme \(theme) missing colour variables")
        }
    }
}
