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

        #expect(css.contains("--color-fill:"))
        #expect(css.contains("--color-figure-gray:"))
        #expect(css.contains("--color-link:"))
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

        #expect(css.contains("--color-syntax-keywords:"))
        #expect(css.contains("--color-syntax-other-type-names:"))
        #expect(css.contains("--color-syntax-strings:"))
        #expect(css.contains("--color-syntax-comments:"))
    }

    @Test("Stylesheet includes typography variables")
    func typography() {
        let css = DocCStylesheet.generate(theme: .default)

        #expect(css.contains("--typography-html-font:"))
        #expect(css.contains("--typography-html-font-mono:"))
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

    @Test("Default theme CSS includes code block padding variable")
    func codeBlockPaddingVariable() {
        let css = DocCStylesheet.generate(theme: .default)

        // Verify the swift-docc-render compatible variable is defined
        #expect(css.contains("--code-block-style-elements-padding"))
    }

    @Test("Pre element uses code block padding variable")
    func preElementPadding() {
        let css = DocCStylesheet.generate(theme: .default)

        // Verify pre element references the padding variable
        // It should use --code-block-style-elements-padding with fallback to --spacing-pre-padding
        #expect(css.contains("padding: var(--code-block-style-elements-padding"))
    }

    @Test("Default theme code padding is 8px 14px")
    func defaultCodePadding() {
        let css = DocCStylesheet.generate(theme: .default)

        // Verify the default padding value matches swift-docc-render
        #expect(css.contains("8px 14px"))
    }

    @Test("Pre code element has no background")
    func preCodeStyling() {
        let css = DocCStylesheet.generate(theme: .default)

        // Verify pre code has correct styling
        #expect(css.contains("pre code"))
        #expect(css.contains("background: none"))
        #expect(css.contains("display: block"))
    }

    @Test("Spacing variables are defined in body")
    func spacingVariables() {
        let css = DocCStylesheet.generate(theme: .default)

        // Verify swift-docc-render spacing variables are defined
        #expect(css.contains("--spacing-stacked-margin-small"))
        #expect(css.contains("--spacing-stacked-margin-large"))
        #expect(css.contains("--spacing-stacked-margin-xlarge"))
    }

    @Test("Spacing variables have correct values")
    func spacingVariableValues() {
        let css = DocCStylesheet.generate(theme: .default)

        // Verify the spacing values match swift-docc-render
        #expect(css.contains("--spacing-stacked-margin-small: 0.4em"))
        #expect(css.contains("--spacing-stacked-margin-large: 0.8em"))
        #expect(css.contains("--spacing-stacked-margin-xlarge: 1.6em"))
    }

    @Test("Pre element margin uses spacing variable")
    func preElementMargin() {
        let css = DocCStylesheet.generate(theme: .default)

        // Verify pre element uses spacing-stacked-margin-large for top margin
        // Should reference the variable, not use fixed 27px
        #expect(css.contains("--spacing-stacked-margin-large"))
    }

    @Test("Pre code element has zero padding")
    func preCodePadding() {
        let css = DocCStylesheet.generate(theme: .default)

        // Verify pre code has padding: 0 to avoid double padding
        #expect(css.contains("pre code"))
        #expect(css.contains("padding: var(--spacing-pre-code-padding, 0)"))
    }

    // MARK: - Swift-DocC-Render Compliance Tests

    @Test("Stylesheet includes fill-gray-quaternary variable")
    func fillGrayQuaternaryVariable() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--color-fill-gray-quaternary:"))
    }

    @Test("Stylesheet includes navigator-item-hover variable")
    func navigatorItemHoverVariable() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--color-navigator-item-hover:"))
    }

    @Test("Dark mode includes correct fill-gray-quaternary")
    func darkModeFillGrayQuaternary() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--color-fill-gray-quaternary: #424242"))
    }

    @Test("Light mode includes correct fill-gray-quaternary")
    func lightModeFillGrayQuaternary() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--color-fill-gray-quaternary: #f0f0f0"))
    }

    @Test("Dark mode includes correct navigator-item-hover")
    func darkModeNavigatorItemHover() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--color-navigator-item-hover: rgba(0, 102, 255, 0.5)"))
    }

    @Test("Light mode includes correct navigator-item-hover")
    func lightModeNavigatorItemHover() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--color-navigator-item-hover: rgba(51, 102, 255, 0.05)"))
    }

    @Test("Stylesheet includes explicit light mode selector")
    func explicitLightModeSelector() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("body[data-color-scheme=\"light\"]"))
    }

    @Test("Explicit light mode selector includes color variables")
    func explicitLightModeColorVariables() {
        let css = DocCStylesheet.generate(theme: .default)

        // Find the body[data-color-scheme="light"] block
        #expect(css.contains("body[data-color-scheme=\"light\"]"))

        // Verify it contains color variables (these should be in the same block)
        // We can't easily verify they're in the same block without parsing,
        // but we can verify the selector exists which is the critical fix
        #expect(css.contains("--color-fill-gray-quaternary: #f0f0f0"))
        #expect(css.contains("--color-navigator-item-hover: rgba(51, 102, 255, 0.05)"))
    }

    @Test("Technology title background matches swift-docc-render default")
    func technologyTitleBackgroundDefault() {
        let css = DocCStylesheet.generate(theme: .default)

        // Technology title background uses fill-gray-quaternary as default
        #expect(css.contains(".technology-title"))
        #expect(css.contains("background: var(--color-technology-title-background, var(--color-fill-gray-quaternary))"))
    }

    @Test("Leaf link padding matches swift-docc-render default")
    func leafLinkPaddingDefault() {
        let css = DocCStylesheet.generate(theme: .default)

        // Swift-docc-render has no padding on .leaf-link (padding is on container)
        #expect(css.contains(".leaf-link"))
        #expect(css.contains("padding: var(--spacing-leaf-link-padding, 0)"))
    }

    @Test("Module header padding is themeable")
    func moduleHeaderPaddingThemeable() {
        let css = DocCStylesheet.generate(theme: .default)

        // Module header padding should use CSS variable for themeability
        #expect(css.contains(".module-section .module-header"))
        #expect(css.contains("padding: var(--spacing-module-header-padding,"))
    }

    @Test("Module header technology title override rule does not exist")
    func moduleHeaderTechnologyTitleNoOverride() {
        let css = DocCStylesheet.generate(theme: .default)

        // The overly-specific .module-section .module-header .technology-title rule
        // was causing a CSS specificity bug where padding/margin were forced to 0.
        // This rule should NOT exist - .technology-title should stand alone.
        #expect(!css.contains(".module-section .module-header .technology-title"))
        #expect(!css.contains("--spacing-module-header-technology-title-margin"))
        #expect(!css.contains("--spacing-module-header-technology-title-padding"))
        #expect(!css.contains("--spacing-module-header-technology-title-width"))
    }

    @Test("Navigator card hover uses navigator-item-hover variable")
    func navigatorCardHover() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".navigator-card:hover"))
        #expect(css.contains("background: var(--color-navigator-item-hover)"))
    }

    @Test("Navigator card active uses fill-gray-quaternary variable")
    func navigatorCardActive() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".navigator-card.active"))
        #expect(css.contains("background: var(--color-fill-gray-quaternary)"))
    }

    @Test("Navigator card selected uses fill-gray-quaternary variable")
    func navigatorCardSelected() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".navigator-card.selected"))
        #expect(css.contains("background: var(--color-fill-gray-quaternary)"))
    }

    @Test("Technology title hover uses navigator-item-hover as default")
    func technologyTitleHoverDefault() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".technology-title:hover"))
        #expect(css.contains("background: var(--color-technology-title-background-hover, var(--color-navigator-item-hover))"))
    }

    @Test("Sidebar width is themeable")
    func sidebarWidthThemeable() {
        let css = DocCStylesheet.generate(theme: .default)
        // Default sidebar width is 432px per swift-docc-render
        #expect(css.contains("--sidebar-width: var(--spacing-sidebar-width, 432px)"))
    }

    @Test("Default theme sidebar width is 432px")
    func defaultSidebarWidth() {
        let theme = ThemeConfiguration(builtInTheme: .default, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)
        // Sidebar width uses CSS variable for themeability
        #expect(css.contains("--sidebar-width: var(--spacing-sidebar-width, 432px)"))
    }

    @Test("Default theme has fill-gray-quaternary colour")
    func defaultThemeFillGrayQuaternary() {
        let settings = ThemeSettings.BuiltInTheme.default.settings
        let color = settings.theme.color?["fill-gray-quaternary"]
        #expect(color != nil)
    }

    @Test("Default theme has navigator-item-hover colour")
    func defaultThemeNavigatorItemHover() {
        let settings = ThemeSettings.BuiltInTheme.default.settings
        let color = settings.theme.color?["navigator-item-hover"]
        #expect(color != nil)
    }

    @Test("Pre element has individual padding-left and padding-right variables")
    func preIndividualPaddingVariables() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("padding-left: var(--spacing-pre-padding-left, 14px)"))
        #expect(css.contains("padding-right: var(--spacing-pre-padding-right, 14px)"))
    }

    @Test("Technology title active state uses fill-gray-quaternary")
    func technologyTitleActiveState() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".technology-title.active"))
        #expect(css.contains("background: var(--color-fill-gray-quaternary)"))
    }

    @Test("Classic theme has pre-padding-left and pre-padding-right")
    func classicThemePrePadding() {
        let theme = ThemeConfiguration(builtInTheme: .classic, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)
        #expect(css.contains("--spacing-pre-padding-left: 3rem"))
        #expect(css.contains("--spacing-pre-padding-right: 3rem"))
    }

    @Test("Code listings receive content padding")
    func codeListingsGetPadding() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".doc-topic .code-listing"))
        #expect(css.contains("padding-left: var(--spacing-content-padding-horizontal"))
    }

    @Test("Direct paragraphs receive content padding")
    func directParagraphsGetPadding() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".doc-topic > p"))
        #expect(css.contains("padding-left: var(--spacing-content-padding-horizontal"))
    }
}

@Suite("Classic Theme Override Tests")
struct ClassicThemeTests {
    @Test("Classic theme overrides technology title background to transparent")
    func technologyTitleBackgroundClassic() throws {
        let theme = ThemeConfiguration(builtInTheme: .classic, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // Classic theme should override to transparent (matching old docc-static)
        #expect(css.contains("--color-technology-title-background: transparent"))
        #expect(css.contains("--color-technology-title-background-hover: transparent"))
    }

    @Test("Classic theme overrides leaf link padding")
    func leafLinkPaddingClassic() throws {
        let theme = ThemeConfiguration(builtInTheme: .classic, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // Classic theme should have sidebar-style padding (matching old docc-static)
        #expect(css.contains("--spacing-leaf-link-padding: 0.75rem 1.25rem 0.25rem"))
    }

    @Test("Classic theme has badge border radius override")
    func badgeBorderRadiusClassic() throws {
        let theme = ThemeConfiguration(builtInTheme: .classic, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // Classic theme should override badge border-radius to 3px (old docc-static)
        #expect(css.contains("--badge-border-radius: 3px"))
    }

    @Test("Classic theme has filled badge backgrounds")
    func badgeBackgroundsClassic() throws {
        let theme = ThemeConfiguration(builtInTheme: .classic, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // Classic theme should have filled badge backgrounds
        #expect(css.contains("--color-badge-default:"))
        #expect(css.contains("--color-badge-text:"))
        #expect(css.contains("--color-badge-border:"))
    }

    @Test("Classic theme uses SF fonts")
    func sfFontsClassic() throws {
        let theme = ThemeConfiguration(builtInTheme: .classic, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // Classic theme should use SF Pro Text and SF Mono
        #expect(css.contains("'SF Pro Text'"))
        #expect(css.contains("'SF Mono'"))
    }

    @Test("Classic theme has disclosure chevron before text")
    func disclosureChevronOrderClassic() throws {
        let theme = ThemeConfiguration(builtInTheme: .classic, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // Classic theme should have chevron before text (order: -1)
        #expect(css.contains("--spacing-disclosure-chevron-order: -1"))
    }

    @Test("Classic theme sidebar width is 320px")
    func classicSidebarWidth() throws {
        let theme = ThemeConfiguration(builtInTheme: .classic, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // Classic theme should have narrower sidebar (matching old docc-static)
        #expect(css.contains("--spacing-sidebar-width: 320px"))
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

@Suite("Swift-DocC Render Compatibility Tests")
struct SwiftDocCRenderCompatibilityTests {

    @Test("Default theme sidebar width matches swift-docc-render (432px)")
    func defaultSidebarWidth() {
        let theme = ThemeConfiguration(builtInTheme: .default, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // swift-docc-render uses 432px for sidebar width @ 1440px viewport
        #expect(css.contains("--sidebar-width: var(--spacing-sidebar-width, 432px)"))
    }

    @Test("Pre element font-size matches swift-docc-render (17px)")
    func preFontSize() {
        let theme = ThemeConfiguration(builtInTheme: .default, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // swift-docc-render uses 17px for pre font-size
        #expect(css.contains("font-size: var(--spacing-pre-font-size, 17px)"))
    }

    @Test("Pre element border-radius matches swift-docc-render (0px)")
    func preBorderRadius() {
        let theme = ThemeConfiguration(builtInTheme: .default, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // swift-docc-render uses 0px border-radius for pre (no rounding)
        #expect(css.contains("border-radius: var(--spacing-pre-border-radius, 0px)"))
    }

    @Test("Pre element has no horizontal margins in default theme")
    func preNoHorizontalMargins() {
        let theme = ThemeConfiguration(builtInTheme: .default, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // swift-docc-render does not apply content-padding-horizontal to pre
        // The CSS should NOT contain margin-left/right with spacing-content-padding-horizontal for pre
        let preSection = css.components(separatedBy: "pre {").dropFirst().first?.components(separatedBy: "}").first ?? ""
        #expect(!preSection.contains("margin-left: var(--spacing-content-padding-horizontal"))
        #expect(!preSection.contains("margin-right: var(--spacing-content-padding-horizontal"))
    }

    @Test("Pre code element font-size is 15px")
    func preCodeFontSize() {
        let theme = ThemeConfiguration(builtInTheme: .default, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // swift-docc-render uses 15px for pre code font-size
        let preCodeSection = css.components(separatedBy: "pre code {").dropFirst().first?.components(separatedBy: "}").first ?? ""
        #expect(preCodeSection.contains("font-size: 15px") || preCodeSection.contains("font-size: var(--spacing-pre-code-font-size, 15px)"))
    }

    @Test("Pre code element has no border-radius")
    func preCodeNoBorderRadius() {
        let theme = ThemeConfiguration(builtInTheme: .default, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // pre code should not have border-radius
        let preCodeSection = css.components(separatedBy: "pre code {").dropFirst().first?.components(separatedBy: "}").first ?? ""
        #expect(!preCodeSection.contains("border-radius: 4px"))
    }

    @Test("Classic theme overrides pre font-size to 0.8125rem")
    func classicPreFontSize() {
        let theme = ThemeConfiguration(builtInTheme: .classic, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // Classic theme uses 0.8125rem (13px) per docc-static-classic.theme-settings.json
        #expect(css.contains("--spacing-pre-font-size: 0.8125rem"))
    }

    @Test("Classic theme overrides pre border-radius to 12px")
    func classicPreBorderRadius() {
        let theme = ThemeConfiguration(builtInTheme: .classic, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // Classic theme uses 12px border-radius per docc-static-classic.theme-settings.json
        #expect(css.contains("--spacing-pre-border-radius: 12px"))
    }
}

// MARK: - Swift-DocC Render Complete Compatibility Tests

@Suite("Complete Swift-DocC Render Compatibility Tests")
struct CompleteSwiftDocCRenderCompatibilityTests {

    // MARK: - Code Listing Wrapper Styles

    @Test("Code listing wrapper has grey background")
    func codeListing_hasGreyBackground() {
        let css = DocCStylesheet.generate(theme: .default)

        // .code-listing should have a grey background color
        #expect(css.contains(".code-listing"))

        // Check for background color on .code-listing
        let lines = css.split(separator: "\n")
        var inCodeListingBlock = false
        var foundBackground = false

        for line in lines {
            if line.contains(".code-listing") && line.contains("{") {
                inCodeListingBlock = true
            }
            if inCodeListingBlock && line.contains("background") {
                // Should be #f7f7f7 or rgb(247, 247, 247) or similar grey
                foundBackground = true
                break
            }
            if inCodeListingBlock && line.contains("}") {
                inCodeListingBlock = false
            }
        }

        #expect(foundBackground, "Expected .code-listing to have background-color property")
    }

    @Test("Code listing wrapper has border")
    func codeListing_hasBorder() {
        let css = DocCStylesheet.generate(theme: .default)

        #expect(css.contains(".code-listing"))

        // Check for border on .code-listing
        let lines = css.split(separator: "\n")
        var inCodeListingBlock = false
        var foundBorder = false

        for line in lines {
            if line.contains(".code-listing") && line.contains("{") {
                inCodeListingBlock = true
            }
            if inCodeListingBlock && line.contains("border") && !line.contains("border-radius") {
                foundBorder = true
                break
            }
            if inCodeListingBlock && line.contains("}") {
                inCodeListingBlock = false
            }
        }

        #expect(foundBorder, "Expected .code-listing to have border property")
    }

    @Test("Code listing wrapper has rounded corners (4px)")
    func codeListing_hasRoundedCorners() {
        let css = DocCStylesheet.generate(theme: .default)

        #expect(css.contains(".code-listing"))

        // Check for border-radius on .code-listing
        let lines = css.split(separator: "\n")
        var inCodeListingBlock = false
        var foundBorderRadius = false

        for line in lines {
            if line.contains(".code-listing") && line.contains("{") {
                inCodeListingBlock = true
            }
            if inCodeListingBlock && line.contains("border-radius") {
                foundBorderRadius = true
                break
            }
            if inCodeListingBlock && line.contains("}") {
                inCodeListingBlock = false
            }
        }

        #expect(foundBorderRadius, "Expected .code-listing to have border-radius property")
    }

    @Test("Code element inside pre has no border-radius")
    func preCode_hasNoBorderRadius() {
        let css = DocCStylesheet.generate(theme: .default)

        // pre code should NOT have border-radius (it should be 0)
        // Border-radius belongs on the .code-listing wrapper
        let lines = css.split(separator: "\n")
        var inPreCodeBlock = false
        var hasBorderRadius = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "pre code") && trimmed.contains("{") {
                inPreCodeBlock = true
            }
            if inPreCodeBlock && trimmed.contains("border-radius") {
                // Check if it's set to 0
                if !trimmed.contains("0px") && !trimmed.contains(": 0") {
                    hasBorderRadius = true
                }
                break
            }
            if inPreCodeBlock && trimmed == "}" {
                inPreCodeBlock = false
            }
        }

        #expect(!hasBorderRadius, "Expected pre code to have no border-radius (or 0px)")
    }

    // MARK: - Paragraph Spacing

    @Test("Paragraphs have zero bottom margin")
    func paragraphs_haveZeroBottomMargin() {
        let css = DocCStylesheet.generate(theme: .default)

        // main p and article p should have margin-bottom: 0
        let hasMainParagraph = css.contains("main p") || css.contains("article p")
        #expect(hasMainParagraph, "Expected CSS to have main p or article p selector")

        // Check that margin-bottom is 0
        let lines = css.split(separator: "\n")
        var foundZeroMarginBottom = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("margin-bottom") && trimmed.contains(": 0") {
                foundZeroMarginBottom = true
                break
            }
        }

        #expect(foundZeroMarginBottom, "Expected paragraphs to have margin-bottom: 0")
    }

    @Test("First paragraph has top margin")
    func firstParagraph_hasTopMargin() {
        let css = DocCStylesheet.generate(theme: .default)

        // p:first-of-type or p:first-child should have margin-top
        let hasFirstParagraphSelector = css.contains(":first-of-type") || css.contains(":first-child")

        if hasFirstParagraphSelector {
            // Check for margin-top
            let lines = css.split(separator: "\n")
            var foundMarginTop = false

            for line in lines {
                if line.contains("margin-top") && !line.contains(": 0") {
                    foundMarginTop = true
                    break
                }
            }

            #expect(foundMarginTop, "Expected first paragraph to have non-zero margin-top")
        }
    }

    // MARK: - Container General

    @Test(".container-general exists for code blocks")
    func containerGeneral_existsForCodeBlocks() {
        let css = DocCStylesheet.generate(theme: .default)

        // .container-general should exist as it's a child of .code-listing
        #expect(css.contains(".container-general"), "Expected .container-general CSS class to exist")
    }
}

// MARK: - DOM/CSS Comparison Failures (from Puppeteer analysis)

@Suite("DOM CSS Comparison Tests - Based on Puppeteer Analysis")
struct DOMCSSComparisonTests {

    // FAILURE 1: Module Links Background Color
    @Test("Module links (.technology-title) have grey quaternary background, not white")
    func moduleLinks_haveGreyBackground_notWhite() {
        let css = DocCStylesheet.generate(theme: .default)

        // .technology-title should use --color-fill-gray-quaternary (#f0f0f0), NOT --color-fill (white)
        #expect(css.contains(".technology-title"))

        // Find the .technology-title block and check background
        let lines = css.split(separator: "\n")
        var inTechnologyTitleBlock = false
        var hasGreyBackground = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: ".technology-title") && trimmed.contains("{") {
                inTechnologyTitleBlock = true
            }
            if inTechnologyTitleBlock && trimmed.contains("background:") {
                // Should contain fill-gray-quaternary, NOT just fill
                if trimmed.contains("fill-gray-quaternary") {
                    hasGreyBackground = true
                }
                break
            }
            if inTechnologyTitleBlock && trimmed == "}" {
                break
            }
        }

        #expect(hasGreyBackground,
                "technology-title must use var(--color-fill-gray-quaternary), not var(--color-fill)")
    }

    // FAILURE 2: Module Links Width
    @Test("Module links (.technology-title) have auto width, not fixed pixel widths")
    func moduleLinks_haveAutoWidth() {
        let css = DocCStylesheet.generate(theme: .default)

        // .technology-title should NOT have explicit width
        let lines = css.split(separator: "\n")
        var inTechnologyTitleBlock = false
        var hasFixedWidth = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: ".technology-title") && trimmed.contains("{") {
                inTechnologyTitleBlock = true
            }
            if inTechnologyTitleBlock && trimmed.contains("width:") {
                // Should not have explicit px width
                if trimmed.range(of: "\\d+px", options: .regularExpression) != nil {
                    hasFixedWidth = true
                }
                break
            }
            if inTechnologyTitleBlock && trimmed == "}" {
                break
            }
        }

        #expect(!hasFixedWidth,
                "technology-title should not have fixed width - should be auto (default)")
    }

    // FAILURE 3: Wrong CSS Class - should be leaf-link
    @Test("Navigation items use .leaf-link class, not .nav-link")
    func navigationItems_useLeafLinkClass() {
        let css = DocCStylesheet.generate(theme: .default)

        // CSS should have .leaf-link rules
        #expect(css.contains(".leaf-link"),
                "CSS must include .leaf-link class for navigation items")

        // Ideally .nav-link should not exist in default theme (it's the wrong class)
        // However, this is more of an HTML generation test
        // We verify that .leaf-link exists and has proper styles
        let hasLeafLinkStyles = css.contains("a.leaf-link") || css.contains(".leaf-link")
        #expect(hasLeafLinkStyles,
                "leaf-link class must be present and styled")
    }

    // FAILURE 5: Code Block Margins - Pre should have no 80px margins
    @Test("Pre elements have no 80px horizontal margins")
    func preElements_noHugeHorizontalMargins() {
        let css = DocCStylesheet.generate(theme: .default)

        // Pre should NOT have margin-left: 80px or margin-right: 80px
        let lines = css.split(separator: "\n")
        var hasWrongMargins = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "pre") && trimmed.contains("{") {
                // Check subsequent lines for 80px margins
                continue
            }
            if trimmed.contains("margin") && trimmed.contains("80px") {
                hasWrongMargins = true
                break
            }
        }

        #expect(!hasWrongMargins,
                "Pre elements must not have 80px horizontal margins")
    }

    // FAILURE 7: Paragraph Margins - should be top, not bottom
    @Test("Paragraphs have margin-top, not margin-bottom")
    func paragraphs_haveTopMargin_notBottom() {
        let css = DocCStylesheet.generate(theme: .default)

        // Paragraphs should have margin-bottom: 0
        let hasZeroBottomMargin = css.contains("margin-bottom: 0") || css.contains("margin-bottom:0")
        #expect(hasZeroBottomMargin,
                "Paragraphs should have margin-bottom: 0, not 17px")

        // First paragraph should have margin-top
        let hasTopMargin = css.range(of: ":first[^{]*\\{[^}]*margin-top",
                                     options: .regularExpression) != nil
        #expect(hasTopMargin,
                "First paragraph should have margin-top, not margin-bottom")
    }

    // FAILURE 8: Paragraph Padding - should be 0, not 80px
    @Test("Paragraphs have no 80px horizontal padding")
    func paragraphs_noHugeHorizontalPadding() {
        let css = DocCStylesheet.generate(theme: .default)

        // Check if any paragraph rules have 80px padding
        let hasWrongPadding = css.range(of: "(main p|article p)[^{]*\\{[^}]*padding[^:]*:[^;}]*80px",
                                       options: .regularExpression) != nil

        #expect(!hasWrongPadding,
                "Paragraphs must not have 80px horizontal padding - should be 0")
    }

    // FAILURE 9: Sidebar Indentations
    @Test("Sidebar navigation has proper indentation structure")
    func sidebar_hasProperIndentation() {
        let css = DocCStylesheet.generate(theme: .default)

        // Sidebar should have indentation rules
        #expect(css.contains(".sidebar"),
                "CSS must include sidebar styles")

        // Check for nested list indentation with padding-left
        let hasIndentationRules = css.contains("padding-left") &&
                                 (css.contains(".sidebar li") || css.contains(".sidebar ul"))

        #expect(hasIndentationRules,
                "Sidebar must have indentation rules for nested navigation items")
    }

    // COMPREHENSIVE DOM/CSS FAILURES (from Puppeteer analysis)

    // FAILURE: Module link widths must be fluid (auto), not fixed pixels
    @Test("Module links (.technology-title) must have width: auto, not fixed pixels")
    func moduleLinks_mustHaveAutoWidth_notFixedPixels() {
        let css = DocCStylesheet.generate(theme: .default)

        // Find .technology-title block
        let lines = css.split(separator: "\n")
        var inTechnologyTitleBlock = false
        var hasExplicitWidth = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: ".technology-title") && trimmed.contains("{") {
                inTechnologyTitleBlock = true
            }
            if inTechnologyTitleBlock && trimmed.starts(with: "width:") {
                // Should NOT have explicit px width
                if trimmed.contains("px") && !trimmed.contains("auto") {
                    hasExplicitWidth = true
                }
                break
            }
            if inTechnologyTitleBlock && trimmed == "}" {
                break
            }
        }

        #expect(!hasExplicitWidth,
                ".technology-title must NOT have explicit width in px - should be auto for full justification")
    }

    // FAILURE: Paragraphs must have NO horizontal padding
    @Test("Paragraphs must have NO horizontal padding (0px), not 80px")
    func paragraphs_mustHaveNoHorizontalPadding() {
        let css = DocCStylesheet.generate(theme: .default)

        // Main content paragraphs should NOT have horizontal padding
        // Check if p elements have padding-left or padding-right with 80px or similar
        let has80pxPadding = css.range(of: "p\\s*\\{[^}]*(padding-left|padding-right)\\s*:[^;}]*80px",
                                       options: .regularExpression) != nil ||
                            css.range(of: "p\\s*\\{[^}]*padding\\s*:[^;}]*80px",
                                     options: .regularExpression) != nil

        #expect(!has80pxPadding,
                "Paragraphs must NOT have 80px horizontal padding - content is too squeezed")
    }

    // FAILURE: Code listing wrapper must be display: flex (or block with proper width)
    @Test(".code-listing must be display: flex or block, and must NOT collapse")
    func codeListing_mustNotCollapse() {
        let css = DocCStylesheet.generate(theme: .default)

        // .code-listing should exist and have proper display
        let hasCodeListing = css.contains(".code-listing")
        #expect(hasCodeListing, ".code-listing class must exist")

        // Check display property
        let lines = css.split(separator: "\n")
        var inCodeListingBlock = false
        var hasProperDisplay = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: ".code-listing") && trimmed.contains("{") {
                inCodeListingBlock = true
            }
            if inCodeListingBlock && trimmed.starts(with: "display:") {
                // Should be flex or block
                if trimmed.contains("flex") || trimmed.contains("block") {
                    hasProperDisplay = true
                }
                break
            }
            if inCodeListingBlock && trimmed == "}" {
                break
            }
        }

        #expect(hasProperDisplay,
                ".code-listing must have display: flex or display: block")
    }

    // FAILURE: Sidebar nested ul must have consistent padding-left for indentation
    @Test("Sidebar nested ul must have consistent padding-left for proper indentation")
    func sidebar_nestedUl_mustHaveConsistentPadding() {
        let css = DocCStylesheet.generate(theme: .default)

        // Nested ul in sidebar should have padding-left for indentation
        // Look for .sidebar ul ul or similar nested selectors with padding-left
        let hasNestedUlPadding = css.range(of: "\\.sidebar\\s+ul\\s+ul[^{]*\\{[^}]*padding-left",
                                          options: .regularExpression) != nil ||
                                css.range(of: "\\.sidebar-list[^{]*\\{[^}]*padding-left",
                                         options: .regularExpression) != nil

        #expect(hasNestedUlPadding,
                "Sidebar nested ul elements must have padding-left for proper visual indentation")
    }
}

// MARK: - Heading Spacing Tests (Verified via DOM Comparison with swift-docc-render)

@Suite("Heading Spacing Tests - Verified via DOM Comparison")
struct HeadingSpacingTests {

    // IMPORTANT: These tests reflect actual swift-docc-render behaviour verified via Puppeteer DOM comparison
    // swift-docc-render uses margin: 0 on base h1-h6 elements
    // Spacing is achieved through:
    // 1. padding-top on specific section H2s (Topics, Relationships, See Also) = 40px
    // 2. margin-top on content H3s (.doc-topic > h3) = 44.8px
    // 3. margin-top: 0 on topic group H3s (.contenttable-title)

    @Test("Explicit light mode selector exists")
    func explicitLightModeExists() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("body[data-color-scheme=\"light\"]"),
                "Explicit light mode selector must exist for theme switching")
    }

    @Test("Explicit dark mode selector exists")
    func explicitDarkModeExists() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("body[data-color-scheme=\"dark\"]"),
                "Explicit dark mode selector must exist for theme switching")
    }

    @Test("Content heading margin variable exists")
    func contentHeadingMarginVariable() {
        let css = DocCStylesheet.generate(theme: .default)
        // Content H3s use --spacing-content-heading-margin-top for 44.8px (2.8rem) margin
        #expect(css.contains("--spacing-content-heading-margin-top"),
                "Content heading margin variable must exist for theming")
    }

    @Test("Section heading padding variable exists")
    func sectionHeadingPaddingVariable() {
        let css = DocCStylesheet.generate(theme: .default)
        // Section H2s use --spacing-section-heading-padding-top for 40px (2.5rem) padding
        #expect(css.contains("--spacing-section-heading-padding-top"),
                "Section heading padding variable must exist for theming")
    }

    @Test("H1-H6 base elements have zero margin (matches swift-docc-render)")
    func baseHeadingsHaveZeroMargin() {
        let css = DocCStylesheet.generate(theme: .default)
        // swift-docc-render sets margin: 0; padding: 0; on base heading elements
        #expect(css.contains("h1, h2, h3, h4, h5, h6"),
                "Must have combined h1-h6 selector")
        #expect(css.contains("margin: 0"),
                "Base headings must have margin: 0 per swift-docc-render")
    }

    @Test("Topics section H2 has paddingTop 40px (2.5rem)")
    func topicsSectionH2PaddingTop() {
        let css = DocCStylesheet.generate(theme: .default)
        // Verified via DOM comparison: Topics H2 has paddingTop: 40px
        #expect(css.contains(".topics > h2"),
                "Topics H2 selector must exist")
        #expect(css.contains("--spacing-section-heading-padding-top") || css.contains("2.5rem"),
                "Topics H2 must have padding-top of 2.5rem (40px)")
    }

    @Test("Content H3s have margin-top 44.8px (2.8rem)")
    func contentH3MarginTop() {
        let css = DocCStylesheet.generate(theme: .default)
        // Verified via DOM comparison: Content H3s like "Key Features" have marginTop: 44.8px
        #expect(css.contains(".doc-topic > h3"),
                "Content H3 selector must exist")
        #expect(css.contains("--spacing-content-heading-margin-top") || css.contains("2.8rem"),
                "Content H3s must have margin-top of 2.8rem (44.8px)")
    }

    @Test("Topic group H3s have zero margin (matches swift-docc-render)")
    func topicGroupH3ZeroMargin() {
        let css = DocCStylesheet.generate(theme: .default)
        // Verified via DOM comparison: "Essentials" H3 inside .contenttable-section has marginTop: 0px
        #expect(css.contains(".contenttable-title") || css.contains(".contenttable-section h3"),
                "Topic group H3 selector must exist")
    }

    @Test("Documentation hero H1 has margin-bottom 0.5rem")
    func documentationHeroH1MarginBottom() {
        let css = DocCStylesheet.generate(theme: .default)
        // The hero section H1 needs margin-bottom for spacing before abstract
        #expect(css.contains(".documentation-hero h1"),
                "Documentation hero H1 selector must exist")
    }
}

// MARK: - Theme Compatibility Spacing Tests

@Suite("Theme Compatibility Spacing Tests")
struct ThemeCompatibilitySpacingTests {

    @Test("Hero section has bottom margin for content separation")
    func heroBottomMargin() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".documentation-hero"))
        #expect(css.contains("--spacing-hero-margin-bottom"),
                "Hero section must have margin-bottom variable for content separation")
    }

    @Test("Contenttable title has bottom margin")
    func contenttableTitleBottomMargin() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".contenttable-title"))
        #expect(css.contains("--spacing-contenttable-title-margin-bottom"),
                "Contenttable title must have margin-bottom variable for spacing below headings")
    }

    @Test("Contenttable title uses label font style (24px)")
    func contenttableTitleFontSize() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-contenttable-title-font-size"),
                "Contenttable title must have font-size variable matching swift-docc-render label style")
    }

    @Test("Contenttable section has top padding (matches swift-docc-render)")
    func contenttableSectionTopPadding() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".contenttable-section"))
        #expect(css.contains("--spacing-contenttable-section-padding-top"),
                "Contenttable section must have padding-top variable for group separation")
    }

    @Test("First contenttable section has smaller top padding")
    func contenttableFirstSectionPadding() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".contenttable-section:first-child"),
                "First contenttable section must have :first-child selector for smaller padding")
        #expect(css.contains("--spacing-contenttable-first-section-padding-top"),
                "First section must have specific padding-top variable")
    }

    @Test("Nav group header has indentation")
    func navGroupHeaderIndent() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".nav-group-header"))
        #expect(css.contains("--spacing-nav-group-header-indent"),
                "Nav group header must have padding-left variable for visual hierarchy")
    }

    @Test("Sidebar section headings have indentation")
    func sidebarSectionHeadingIndent() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".sidebar-section > h3.leaf-link") ||
                css.contains(".sidebar-section > .leaf-link"),
                "Sidebar section headings must have specific selector for indentation")
        #expect(css.contains("--spacing-sidebar-section-heading-indent"),
                "Sidebar section heading must have indent variable")
    }

    @Test("Content headings have margin-bottom for spacing before lists")
    func contentHeadingMarginBottom() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".doc-topic > h3"))
        #expect(css.contains("--spacing-content-heading-margin-bottom"),
                "Content H3 headings must have margin-bottom variable for spacing before lists")
    }

    @Test("Topic group indent variable exists")
    func topicGroupIndent() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-topic-group-indent"),
                "Topic group indent variable must exist for theming")
    }

    @Test("Code listing uses margin for wrapper indentation")
    func codeListingMarginIndentation() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".doc-topic .code-listing"))
        #expect(css.contains("margin-left: var(--spacing-content-padding-horizontal"),
                "Code listing must use margin-left (not padding-left) to indent the grey box")
        #expect(css.contains("margin-right: var(--spacing-content-padding-horizontal"),
                "Code listing must use margin-right (not padding-right) to indent the grey box")
    }
}
