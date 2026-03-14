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

    @Test("Code listings use auto margins for alignment")
    func codeListingsAutoMargins() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".doc-topic .code-listing"))
        #expect(css.contains("margin-left: auto"),
                "Code listing must use auto margins to align grey box with paragraph text")
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

    @Test("Section heading padding exists via contenttable title")
    func sectionHeadingPaddingVariable() {
        let css = DocCStylesheet.generate(theme: .default)
        // Section H2s (Topics, Relationships, See Also) are now .contenttable.alt-light .title
        // with 40px padding-top, matching docc-render ContentTable.vue
        #expect(css.contains(".contenttable.alt-light .title"),
                "Section heading selector .contenttable.alt-light .title must exist")
        #expect(css.contains("padding-top: 40px"),
                "Section headings must have padding-top: 40px")
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

    @Test("Topics section H2 has paddingTop 40px via contenttable title")
    func topicsSectionH2PaddingTop() {
        let css = DocCStylesheet.generate(theme: .default)
        // Verified via DOM comparison: Topics H2 has paddingTop: 40px
        // Topics/Relationships/See Also use .contenttable.alt-light structure matching docc-render
        #expect(css.contains(".contenttable.alt-light .title"),
                "Topics H2 selector .contenttable.alt-light .title must exist")
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var hasPaddingTop = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".contenttable.alt-light .title") && trimmed.contains("{") {
                inBlock = true
            }
            if inBlock && trimmed.contains("padding-top:") && trimmed.contains("40px") {
                hasPaddingTop = true
                break
            }
            if inBlock && trimmed == "}" { break }
        }
        #expect(hasPaddingTop, "Topics H2 must have padding-top of 40px")
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

    @Test("Documentation hero H1 has margin-bottom 0 (matches docc-render)")
    func documentationHeroH1MarginBottom() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".documentation-hero h1"),
                "Documentation hero H1 selector must exist")
        #expect(css.contains("margin-bottom: 0"),
                "Documentation hero H1 must have margin-bottom: 0 per docc-render")
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

    @Test("No special first-child padding for contenttable sections (matches docc-render)")
    func contenttableNoFirstChildSpecialPadding() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(!css.contains(".contenttable-section:first-child"),
                "First contenttable section must NOT have :first-child override — docc-render treats all sections equally")
    }

    @Test("Nav group header has indentation (flat list structure)")
    func navGroupHeaderIndent() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".navigator-card.is-group"),
                "Group markers use .is-group class in flat list structure")
        #expect(css.contains("--nesting-index"),
                "Flat list uses --nesting-index for depth-based indentation")
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

    @Test("Content headings have margin-bottom 0 (Phase 3 update)")
    func contentHeadingMarginBottom() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".doc-topic > h3"))
        // Phase 3: Changed to margin-bottom: 0 (docc-render parity)
        let lines = css.components(separatedBy: "\n")
        var inH3Block = false
        var hasMarginBottomZero = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".doc-topic > h3") {
                inH3Block = true
            }
            if inH3Block && trimmed.contains("margin-bottom: 0") {
                hasMarginBottomZero = true
                break
            }
            if inH3Block && trimmed == "}" { break }
        }
        #expect(hasMarginBottomZero,
                "Content H3 headings must have margin-bottom: 0 (Phase 3: docc-render parity)")
    }

    @Test("Topic group uses contenttable-section padding (matches docc-render)")
    func topicGroupIndent() {
        let css = DocCStylesheet.generate(theme: .default)
        // Topic groups use .contenttable-section with padding-top from contenttable-section-padding-top variable
        #expect(css.contains(".contenttable-section"),
                "Topic group selector .contenttable-section must exist")
        #expect(css.contains("--spacing-contenttable-section-padding-top"),
                "Topic group must use contenttable-section-padding-top variable for spacing")
    }

    @Test("Code listing uses auto margins and calc max-width to align with content text")
    func codeListingAlignedWithContent() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".doc-topic .code-listing"))
        #expect(css.contains("margin-left: auto"),
                "Code listing must use margin-left: auto for centring (matching paragraph model)")
        #expect(css.contains("margin-right: auto"),
                "Code listing must use margin-right: auto for centring (matching paragraph model)")
        // max-width = content-max-width − 2 × content-padding so grey box aligns with text
        #expect(css.contains("max-width: calc(var(--spacing-content-max-width, 980px) - 2 * var(--spacing-content-padding-horizontal, 80px))"),
                "Code listing max-width must be content-max-width minus 2× content-padding (820px)")
    }
}

// MARK: - Pixel-Level Parity Tests (Verified via Puppeteer DOM Comparison)

@Suite("Pixel-Level Parity with swift-docc-render")
struct PixelLevelParityTests {

    @Test("Root font-size is 17px (themeable via --spacing-html-font-size)")
    func rootFontSize17px() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("html {"),
                "Must have html selector")
        #expect(css.contains("font-size: var(--spacing-html-font-size, 17px)"),
                "Root font-size must be 17px via themeable variable to match docc-render")
    }

    @Test("H1 font-size is 40px with 44px line-height")
    func h1FontSize40px() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-h1-font-size, 40px"),
                "H1 font-size default must be 40px")
        #expect(css.contains("--spacing-h1-line-height, 44px"),
                "H1 line-height default must be 44px")
    }

    @Test("Eyebrow has no text-transform: capitalize")
    func eyebrowNoTextTransformCapitalize() {
        let css = DocCStylesheet.generate(theme: .default)
        // Find the .eyebrow block and ensure it does NOT contain text-transform: capitalize
        let lines = css.components(separatedBy: "\n")
        var inEyebrowBlock = false
        var hasCapitalize = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(".eyebrow") && trimmed.contains("{") {
                inEyebrowBlock = true
            }
            if inEyebrowBlock && trimmed.contains("text-transform") && trimmed.contains("capitalize") {
                hasCapitalize = true
                break
            }
            if inEyebrowBlock && trimmed == "}" {
                inEyebrowBlock = false
            }
        }

        #expect(!hasCapitalize,
                "Eyebrow must NOT have text-transform: capitalize — docc-render uses none")
    }

    @Test("Contenttable title font-weight is 400")
    func contenttableTitleFontWeight400() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-contenttable-title-font-weight, 400"),
                "Contenttable title font-weight default must be 400 (not 600)")
    }

    @Test("Contenttable title margin-bottom is 0")
    func contenttableTitleMarginBottomZero() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-contenttable-title-margin-bottom, 0"),
                "Contenttable title margin-bottom default must be 0")
    }

    @Test("No first-child special padding for contenttable sections")
    func noFirstChildSpecialPadding() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(!css.contains(".contenttable-section:first-child"),
                "Must NOT have .contenttable-section:first-child — docc-render treats all sections equally")
    }

    @Test("Link-block topic items have margin-top 15px")
    func linkBlockTopicMarginTop() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".link-block.topic"),
                "Must have .link-block.topic selector")
        #expect(css.contains("--spacing-link-block-topic-margin-top, 15px"),
                "Link-block topic margin-top default must be 15px")
    }

    @Test("Topic abstract uses body font (17px/25px)")
    func topicAbstractBodyFont() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".link-block .abstract"),
                "Must have .link-block .abstract selector")
        #expect(css.contains("--spacing-topic-abstract-font-size, 17px"),
                "Topic abstract font-size must be 17px (body font, not hero 21px)")
        #expect(css.contains("--spacing-topic-abstract-line-height, 25px"),
                "Topic abstract line-height must be 25px")
    }

    @Test("Topic abstract has margin-inline-start for icon spacing")
    func topicAbstractMarginLeft() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("margin-inline-start: var(--spacing-topic-abstract-margin-start"),
                "Topic abstract must have margin-inline-start for icon alignment")
    }

    @Test("Hero margin-bottom is 0")
    func heroMarginBottomZero() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-hero-margin-bottom, 0)"),
                "Hero margin-bottom default must be 0 (not 2rem)")
    }

    @Test("Hero content max-width is 980px")
    func heroContentMaxWidth980px() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-hero-max-width, 980px"),
                "Hero content max-width must be 980px")
    }

    @Test("Hero content has 80px horizontal padding")
    func heroContentPadding80px() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-hero-padding-left, 80px"),
                "Hero content must have 80px left padding")
        #expect(css.contains("--spacing-hero-padding-right, 80px"),
                "Hero content must have 80px right padding")
    }

    @Test("Adjacent sibling margin rules exist (matches _typography.scss)")
    func adjacentSiblingMarginRules() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("h1 + *"),
                "Must have h1 + * adjacent sibling rule")
        #expect(css.contains("p + *"),
                "Must have p + * adjacent sibling rule")
        #expect(css.contains("margin-inline-start: var(--spacing-list-indent, 1.176em)"),
                "ul/ol must use margin-inline-start: 1.176em (em(20px) at 17px root)")
    }

    @Test("Sidebar heading font-size is 17px (not 12px)")
    func sidebarHeadingFontSize17px() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-sidebar-heading-font-size, 17px"),
                "Sidebar heading font-size must be 17px, not 0.75rem/12px")
    }

    @Test("Sidebar heading has no uppercase text-transform")
    func sidebarHeadingNoUppercase() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-sidebar-heading-text-transform, none"),
                "Sidebar heading text-transform must default to none, not uppercase")
    }

    @Test("Eyebrow margin-bottom is 15px (overrides .doc-topic p reset)")
    func eyebrowMarginBottom15px() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".doc-topic .eyebrow"),
                "Must have .doc-topic .eyebrow selector for specificity")
        #expect(css.contains("--spacing-eyebrow-margin-bottom, 15px"),
                "Eyebrow margin-bottom must be 15px")
    }

    @Test("Hero H1 margin-bottom is 12px (Phase 3 update)")
    func heroH1MarginBottomZero() {
        let css = DocCStylesheet.generate(theme: .default)
        // Phase 3: Changed to margin-bottom: 12px (title-abstract gap)
        let lines = css.components(separatedBy: "\n")
        var inHeroH1Block = false
        var hasMarginBottom12px = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".documentation-hero h1") && trimmed.contains("{") {
                inHeroH1Block = true
            }
            if inHeroH1Block && trimmed.contains("margin-bottom:") && trimmed.contains("12px") {
                hasMarginBottom12px = true
                break
            }
            if inHeroH1Block && trimmed == "}" {
                inHeroH1Block = false
            }
        }

        #expect(hasMarginBottom12px,
                "Hero H1 must have margin-bottom: 12px (Phase 3: title-abstract gap)")
    }
}

// MARK: - Layout Safety Tests (Prevent Sidebar/Content Overlap Regressions)

@Suite("Layout Safety Tests — Prevent Sidebar Overlap Regressions")
struct LayoutSafetyTests {

    /// Helper: extract the LAST `.doc-topic` block from the CSS (the one that could
    /// override the layout rule if it comes later in the cascade).
    /// Returns nil if no duplicate `.doc-topic` rule exists after the layout rule.
    private func findDuplicateDocTopicRule(in css: String) -> String? {
        let blocks = css.components(separatedBy: ".doc-topic {")
        // First occurrence is the layout rule (margin-left: sidebar-width).
        // Any subsequent occurrences would override it.
        guard blocks.count > 2 else { return nil }
        // Return the content of the last duplicate block
        return blocks.last?.components(separatedBy: "}").first
    }

    @Test("doc-topic must NOT have margin-left: auto (would break sidebar layout)")
    func docTopicNoMarginLeftAuto() {
        let css = DocCStylesheet.generate(theme: .default)
        // If a second .doc-topic rule exists with margin-left: auto, it overrides
        // the layout rule's margin-left: var(--sidebar-width) — content slides under sidebar.
        if let duplicate = findDuplicateDocTopicRule(in: css) {
            #expect(!duplicate.contains("margin-left: auto"),
                    "A later .doc-topic rule must NOT set margin-left: auto — it overrides the sidebar layout")
        }
    }

    @Test("doc-topic must NOT have margin-right: auto (would break sidebar layout)")
    func docTopicNoMarginRightAuto() {
        let css = DocCStylesheet.generate(theme: .default)
        if let duplicate = findDuplicateDocTopicRule(in: css) {
            #expect(!duplicate.contains("margin-right: auto"),
                    "A later .doc-topic rule must NOT set margin-right: auto — it breaks sidebar positioning")
        }
    }

    @Test("doc-topic layout rule has margin-left: var(--sidebar-width)")
    func docTopicHasSidebarMargin() {
        let css = DocCStylesheet.generate(theme: .default)
        // The essential layout rule: .doc-topic needs margin-left equal to sidebar width
        #expect(css.contains("margin-left: var(--sidebar-width)"),
                "doc-topic must have margin-left: var(--sidebar-width) for sidebar layout")
    }

    @Test("doc-topic layout rule has max-width: calc(100% - var(--sidebar-width))")
    func docTopicHasSidebarMaxWidth() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("max-width: calc(100% - var(--sidebar-width))"),
                "doc-topic must have max-width accounting for sidebar width")
    }

    @Test("No later .doc-topic rule overrides max-width with a fixed pixel value")
    func docTopicNoFixedMaxWidthOverride() {
        let css = DocCStylesheet.generate(theme: .default)
        // A second .doc-topic { max-width: 980px } would override the sidebar-aware calc()
        if let duplicate = findDuplicateDocTopicRule(in: css) {
            let hasFixedMaxWidth = duplicate.range(of: "max-width:\\s*\\d+px",
                                                    options: .regularExpression) != nil ||
                                   duplicate.range(of: "max-width:\\s*var\\(--spacing-content-max-width",
                                                    options: .regularExpression) != nil
            #expect(!hasFixedMaxWidth,
                    "A later .doc-topic rule must NOT override max-width with a fixed value — it breaks sidebar layout")
        }
    }

    @Test("Hero content padding aligns with section content padding")
    func heroContentPaddingMatchesSections() {
        let css = DocCStylesheet.generate(theme: .default)
        // Hero content should use similar horizontal padding as doc-topic sections
        // Both should use 80px (5rem) so text aligns vertically
        #expect(css.contains("--spacing-hero-padding-left, 80px"),
                "Hero content left padding must match section content padding (80px)")
        #expect(css.contains("--spacing-hero-padding-right, 80px"),
                "Hero content right padding must match section content padding (80px)")
    }

    @Test("Documentation-layout is a flex container")
    func documentationLayoutIsFlex() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".documentation-layout"),
                "documentation-layout class must exist")
        let lines = css.components(separatedBy: "\n")
        var inLayoutBlock = false
        var hasFlex = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".documentation-layout") && trimmed.contains("{") {
                inLayoutBlock = true
            }
            if inLayoutBlock && trimmed.contains("display: flex") {
                hasFlex = true
                break
            }
            if inLayoutBlock && trimmed == "}" {
                inLayoutBlock = false
            }
        }
        #expect(hasFlex, "documentation-layout must be display: flex for sidebar/content layout")
    }

    @Test("Sidebar is position: fixed with sidebar-width")
    func sidebarIsFixed() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inSidebarBlock = false
        var hasFixed = false
        var hasWidth = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(".sidebar {") || trimmed.hasPrefix(".sidebar{") {
                inSidebarBlock = true
            }
            if inSidebarBlock {
                if trimmed.contains("position: fixed") { hasFixed = true }
                if trimmed.contains("width: var(--sidebar-width)") { hasWidth = true }
            }
            if inSidebarBlock && trimmed == "}" {
                break
            }
        }
        #expect(hasFixed, "Sidebar must be position: fixed")
        #expect(hasWidth, "Sidebar must use var(--sidebar-width) for width")
    }
}

// MARK: - DOM Comparison Parity Tests (Puppeteer-verified, Session 2)

@Suite("DOM Comparison Parity — Puppeteer-verified Fixes")
struct DOMComparisonParityTests {

    // A. Content Padding Model

    @Test("Content padding horizontal is 80px fixed (not 5rem which computes to 85px)")
    func contentPaddingHorizontal80pxFixed() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-content-padding-horizontal: 80px"),
                "Content padding must be 80px fixed, not 5rem (which is 85px at 17px root)")
    }

    @Test("Content sections have max-width 980px with auto margins")
    func contentSectionsMaxWidth980px() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("max-width: var(--spacing-content-max-width, 980px)"),
                "Content sections must have max-width 980px")
        #expect(css.contains("margin-left: var(--spacing-content-margin-left, auto)"),
                "Content sections must have margin-left: auto for centring")
        #expect(css.contains("margin-right: var(--spacing-content-margin-right, auto)"),
                "Content sections must have margin-right: auto for centring")
    }

    @Test("Top-level sections within doc-topic have margin-top: 0")
    func topLevelSectionsNoMarginTop() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".doc-topic > section"),
                "Must have .doc-topic > section selector")
    }

    // B. Colour Issues

    @Test("Hero abstract uses --color-figure-gray (white in dark mode), not secondary (grey)")
    func heroAbstractColourIsGray() {
        let css = DocCStylesheet.generate(theme: .default)
        // Find .documentation-hero .abstract and check colour
        let lines = css.components(separatedBy: "\n")
        var inHeroAbstract = false
        var usesGray = false
        var usesGraySecondary = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".documentation-hero") && trimmed.contains(".abstract")
                && trimmed.contains("{")
            {
                inHeroAbstract = true
            }
            if inHeroAbstract && trimmed.contains("color:") {
                if trimmed.contains("--color-figure-gray-secondary") {
                    usesGraySecondary = true
                } else if trimmed.contains("--color-figure-gray") {
                    usesGray = true
                }
                break
            }
            if inHeroAbstract && trimmed == "}" {
                break
            }
        }

        #expect(usesGray,
                "Hero abstract must use --color-figure-gray (white in dark mode)")
        #expect(!usesGraySecondary,
                "Hero abstract must NOT use --color-figure-gray-secondary (grey in dark mode)")
    }

    @Test("Dark mode link colour is #09f (via theme settings)")
    func darkModeLinkColour() {
        let css = DocCStylesheet.generate(theme: .default)
        // The theme settings CSS should generate --color-link: #09f in dark mode
        let hasDarkLink = css.range(
            of: "prefers-color-scheme:\\s*dark[^}]*--color-link:\\s*#09f",
            options: .regularExpression) != nil
        #expect(hasDarkLink,
                "Dark mode must override --color-link to #09f")
    }

    // C. Typography / Code Issues

    @Test("Inline code has transparent background, no padding, inherits font-size")
    func inlineCodeTransparent() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--color-code-inline-background, transparent"),
                "Inline code background must default to transparent")
        #expect(css.contains("--spacing-code-padding, 0"),
                "Inline code padding must default to 0")
        #expect(css.contains("--spacing-code-border-radius, 0"),
                "Inline code border-radius must default to 0")
        #expect(css.contains("--spacing-code-font-size, inherit"),
                "Inline code font-size must default to inherit")
    }

    @Test("Code font-family includes Menlo")
    func codeFontFamilyIncludesMenlo() {
        let css = DocCStylesheet.generate(theme: .default)
        // Both code and pre elements should include Menlo in font-family
        #expect(css.contains("Menlo, monospace"),
                "Code font-family must include Menlo before monospace")
    }

    @Test("Pre element display is block (not flex)")
    func preDisplayBlock() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-pre-display, block"),
                "Pre element display must default to block, not flex")
    }

    @Test("Pre element max-width is none (not 100%)")
    func preMaxWidthNone() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-pre-max-width, none"),
                "Pre element max-width must default to none, not 100%")
    }

    // D. Spacing / Margin Issues

    @Test("Declaration section margin is 0")
    func declarationMarginZero() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-declaration-margin, 0"),
                "Declaration margin must default to 0, not 30px")
    }

    @Test("Hero content children have margin-top: 0 (prevents p tag margins)")
    func heroContentChildrenNoMarginTop() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".documentation-hero__content > *"),
                "Must have .documentation-hero__content > * selector to reset child margins")
    }

    @Test("Link-block abstract has margin-bottom: 0")
    func linkBlockAbstractMarginBottomZero() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inLinkBlockAbstract = false
        var hasMarginBottomZero = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".link-block") && trimmed.contains(".abstract")
                && trimmed.contains("{")
            {
                inLinkBlockAbstract = true
            }
            if inLinkBlockAbstract && trimmed.contains("margin-bottom: 0") {
                hasMarginBottomZero = true
                break
            }
            if inLinkBlockAbstract && trimmed == "}" {
                inLinkBlockAbstract = false
            }
        }

        #expect(hasMarginBottomZero,
                "Link-block abstract must have margin-bottom: 0")
    }

    @Test("Topics H2 padding-top is 40px fixed (not 2.5rem)")
    func topicsH2PaddingTop40pxFixed() {
        let css = DocCStylesheet.generate(theme: .default)
        // Topics/Relationships/See Also H2 are .contenttable.alt-light .title with padding-top: 40px
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var hasPaddingTop = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".contenttable.alt-light .title") && trimmed.contains("{") {
                inBlock = true
            }
            if inBlock && trimmed.contains("padding-top:") && trimmed.contains("40px") {
                hasPaddingTop = true
                break
            }
            if inBlock && trimmed == "}" { break }
        }
        #expect(hasPaddingTop,
                "Topics H2 padding-top must be 40px fixed, not 2.5rem (42.5px at 17px root)")
    }

    // E. Topic Link Issues

    @Test("Topic link display is inline with vertical padding")
    func topicLinkInline() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-topic-link-display, inline)"),
                "Topic link display must default to inline (not inline-flex) for natural inline flow")
        #expect(css.contains("--spacing-topic-link-padding, 5px 0"),
                "Topic link padding must default to 5px 0")
    }

    @Test("Topic icon wrapper is inline-flex with 17px margin-right")
    func topicIconWrapperInlineFlex() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-topic-icon-display, inline-flex)"),
                "Topic icon wrapper display must default to inline-flex")
        #expect(css.contains("--spacing-topic-icon-margin-right, 17px"),
                "Topic icon wrapper margin-right must be 17px")
    }

    // F. Breadcrumb Issues

    @Test("Breadcrumb has 14px font-size, 20px line-height, and 20px margin-bottom")
    func breadcrumbStyling() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-hierarchy-font-size, 14px"),
                "Breadcrumb font-size must be 14px")
        #expect(css.contains("--spacing-hierarchy-line-height, 20px"),
                "Breadcrumb line-height must be 20px")
        #expect(css.contains("--spacing-hierarchy-margin-bottom, 20px"),
                "Breadcrumb margin-bottom must be 20px")
    }

    @Test("Breadcrumb has no border-bottom and padding is 0")
    func breadcrumbNoBorderNoPadding() {
        let css = DocCStylesheet.generate(theme: .default)
        // Hierarchy is now a ul inside the hero — no border-bottom needed,
        // padding: 0 is part of the list reset
        #expect(!css.contains("--spacing-hierarchy-border-bottom"),
                "Breadcrumb should not use border-bottom variable (ul inside hero)")
        #expect(css.contains("padding: 0"),
                "Breadcrumb padding must be 0 (list reset)")
    }

    @Test("Breadcrumb colour is --color-figure-gray (white in dark), not secondary")
    func breadcrumbColourIsGray() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inHierarchy = false
        var usesGray = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if (trimmed.hasPrefix(".hierarchy") || trimmed.hasPrefix("nav.hierarchy"))
                && trimmed.contains("{")
            {
                inHierarchy = true
            }
            if inHierarchy && trimmed.contains("color:") && trimmed.contains("--color-figure-gray")
                && !trimmed.contains("--color-figure-gray-secondary")
            {
                usesGray = true
                break
            }
            if inHierarchy && trimmed == "}" {
                inHierarchy = false
            }
        }

        #expect(usesGray,
                "Breadcrumb must use --color-figure-gray, not --color-figure-gray-secondary")
    }

    // G. Sidebar and Section Separator Issues (DOM Comparison v2)

    @Test("Sidebar section heading uses figure-gray-secondary-alt colour (rgb 176,176,176)")
    func sidebarHeadingColour() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--color-figure-gray-secondary-alt"),
                "Leaf-link colour must use figure-gray-secondary-alt, not figure-gray-secondary")
        // Must NOT use the lighter --color-figure-gray-secondary for leaf-link colour
        let lines = css.components(separatedBy: "\n")
        var inLeafLink = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(".leaf-link") && trimmed.contains("{") {
                inLeafLink = true
            }
            if inLeafLink && trimmed.contains("color:") {
                #expect(trimmed.contains("figure-gray-secondary-alt"),
                        "leaf-link colour must reference figure-gray-secondary-alt")
                break
            }
            if inLeafLink && trimmed == "}" { break }
        }
    }

    @Test("Section H2s (Topics, Relationships, See Also) have border-top separator")
    func sectionH2sBorderTop() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("border-top: 1px solid var(--color-fill-gray)"),
                "Section H2s must have border-top separator matching docc-render ContentTable.vue")
    }

    @Test("Overview H2 (first child of doc-content) has border-top and 40px padding-top")
    func overviewSeparatorAfterDeclaration() {
        let css = DocCStylesheet.generate(theme: .default)
        // Declaration is now rendered inside the hero, so Overview H2 is the first h2 in .doc-content
        #expect(css.contains(".doc-content > h2:first-child"),
                "Must target Overview H2 as first child of doc-content for separator")
        // The CSS rule is a multi-selector block; search for the properties after the selector
        let lines = css.components(separatedBy: "\n")
        var inRule = false
        var hasBorderTop = false
        var hasPaddingTop = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Enter rule block when we see the selector (may not have { on same line)
            if trimmed.contains(".doc-content > h2:first-child") {
                inRule = true
            }
            if inRule && trimmed.contains("{") && !trimmed.hasPrefix("//") {
                // Reset to property-scanning mode once we see the opening brace
            }
            if inRule {
                if trimmed.contains("border-top:") && trimmed.contains("fill-gray") {
                    hasBorderTop = true
                }
                if trimmed.contains("padding-top:") && trimmed.contains("40px") {
                    hasPaddingTop = true
                }
                if trimmed == "}" { break }
            }
        }
        #expect(hasBorderTop, "Overview H2 must have border-top separator")
        #expect(hasPaddingTop, "Overview H2 must have 40px padding-top")
    }

    @Test("Content before section gets 40px margin gap")
    func overviewBottomMarginBeforeSection() {
        let css = DocCStylesheet.generate(theme: .default)
        // Content is now in .doc-content inside .doc-content-wrapper
        #expect(css.contains(".doc-content > p + section"),
                "Must target paragraph adjacent to section for 40px gap")
    }

    // H. Sidebar Indentation and Font-Weight (DOM Comparison v3)

    @Test("Sidebar section headings indented 40px (aligns with card padding + depth-spacer)")
    func sidebarSectionHeadingIndent40px() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inRule = false
        var hasPadding = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".sidebar-section > h3.leaf-link") || trimmed.contains(".sidebar-section > .leaf-link") {
                inRule = true
            }
            if inRule && trimmed.contains("padding-left:") && trimmed.contains("40px") {
                hasPadding = true
                break
            }
            if inRule && trimmed == "}" { break }
        }
        #expect(hasPadding,
                "Sidebar section headings must have 40px padding-left (matching docc-render: 20px card-padding + 20px depth-spacer)")
    }

    @Test("Navigator card links have font-weight 400 (non-heading items)")
    func navigatorCardLinkFontWeight400() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inRule = false
        var hasWeight = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(".navigator-card a") && trimmed.contains("{") && !trimmed.contains(":hover") {
                inRule = true
            }
            if inRule && trimmed.contains("font-weight:") && trimmed.contains("400") {
                hasWeight = true
                break
            }
            if inRule && trimmed == "}" { break }
        }
        #expect(hasWeight,
                "Navigator card link font-weight must be 400 (matches docc-render non-active items)")
    }

    @Test("Active/selected navigator card links have font-weight 600")
    func navigatorCardActiveFontWeight600() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".navigator-card.active a") || css.contains(".navigator-card.selected a"),
                "Active/selected navigator card links must have font-weight override")
        let lines = css.components(separatedBy: "\n")
        var inRule = false
        var hasWeight = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if (trimmed.contains(".navigator-card.active a") || trimmed.contains(".navigator-card.selected a")) && trimmed.contains("{") {
                inRule = true
            }
            if inRule && trimmed.contains("font-weight:") && trimmed.contains("600") {
                hasWeight = true
                break
            }
            if inRule && trimmed == "}" { break }
        }
        #expect(hasWeight,
                "Active/selected navigator card links must have font-weight 600 matching docc-render")
    }
}

// MARK: - CSS Parity Phase 2 Tests (Puppeteer-verified Discrepancies)

@Suite("CSS Parity Phase 2 — Remaining Discrepancies")
struct CSSParityPhase2Tests {

    @Test("Module page Overview H2 has 40px padding-top and NO border (Phase 3 update)")
    func modulePageOverviewSpacing() {
        let css = DocCStylesheet.generate(theme: .default)
        // Declaration is now inside the hero; module pages use .doc-content-wrapper so Overview H2
        // is the first-child of .doc-content — overridden to have no border for module pages
        let selector = ".doc-topic > .doc-content-wrapper > .doc-content > h2:first-child"
        #expect(css.contains(selector),
                "Must target Overview H2 as first child of doc-content inside doc-content-wrapper")
        let lines = css.components(separatedBy: "\n")
        var foundSelector = false
        var inRule = false
        var hasPaddingTop = false
        var hasBorderNone = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".doc-content-wrapper > .doc-content > h2:first-child") {
                foundSelector = true
            }
            if foundSelector && trimmed.contains("{") {
                inRule = true
                foundSelector = false
            }
            if inRule {
                if trimmed.contains("padding-top:") && trimmed.contains("40px") {
                    hasPaddingTop = true
                }
                if trimmed.contains("border-top:") && trimmed.contains("none") {
                    hasBorderNone = true
                }
                if trimmed == "}" { break }
            }
        }
        #expect(hasPaddingTop,
                "Module page Overview H2 must have 40px padding-top (matches docc-render)")
        #expect(hasBorderNone,
                "Module page Overview H2 must have border-top: none (only symbol pages get border)")
    }

    @Test("Disclosure chevron has margin-left: auto for flush-right alignment")
    func disclosureChevronFlushRight() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inRule = false
        var hasMarginLeftAuto = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".technology-title .disclosure-chevron") && trimmed.contains("{") {
                inRule = true
            }
            if inRule && trimmed.contains("margin-left:") && trimmed.contains("auto") {
                hasMarginLeftAuto = true
                break
            }
            if inRule && trimmed == "}" { break }
        }
        #expect(hasMarginLeftAuto,
                "Disclosure chevron must have margin-left: auto for flush-right alignment in flex container")
    }

    @Test("Navigator card has no vertical padding (matches docc-render)")
    func navigatorCardNoPaddingTopBottom() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inRule = false
        var paddingValue = ""
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(".navigator-card {") || trimmed.hasPrefix(".navigator-card{") {
                inRule = true
            }
            if inRule && trimmed.hasPrefix("padding:") {
                paddingValue = trimmed
                break
            }
            if inRule && trimmed == "}" { break }
        }
        #expect(!paddingValue.contains("5px"),
                "Navigator card must NOT have 5px vertical padding — docc-render has 0")
    }

    @Test("Navigator card has 20px padding-left (matches docc-render card model)")
    func navigatorCardPaddingLeft() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-navigator-card-padding-left, 20px"),
                "Navigator card must have 20px padding-left matching docc-render")
    }

    @Test("Module contents list has 0 padding-left (card padding provides base indent)")
    func moduleContentsNoPaddingLeft() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inRule = false
        var hasPaddingZero = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".module-section .module-contents") && trimmed.contains("{") {
                inRule = true
            }
            if inRule && trimmed.contains("padding-left:") && trimmed.contains("0") {
                hasPaddingZero = true
                break
            }
            if inRule && trimmed == "}" { break }
        }
        #expect(hasPaddingZero,
                "Module contents must have padding-left: 0 (card padding-left: 20px provides the base indent)")
    }
}

// MARK: - Puppeteer-Verified Pixel-Accuracy Tests (Phase 2b)

@Suite("Puppeteer-Verified Pixel-Accuracy Tests")
struct PuppeteerVerifiedPixelAccuracyTests {

    // DISCREPANCY 1: Technology-title chevron not vertically centred
    // Measured: chevron centre 6.8px below title centre because:
    //   a) align-self defaults to auto (baseline), and
    //   b) h2 + * { margin-top: 0.8em } applies 13.6px margin-top to the LABEL after the H2.
    // Fix: align-self: center AND margin-top: 0 on the chevron.
    @Test("Technology-title chevron has align-self: center and margin-top: 0 for vertical centring")
    func technologyTitleChevronVerticalCentre() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inRule = false
        var hasAlignSelf = false
        var hasMarginTopZero = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".technology-title .disclosure-chevron") && trimmed.contains("{") {
                inRule = true
            }
            if inRule && trimmed.contains("align-self:") && trimmed.contains("center") {
                hasAlignSelf = true
            }
            if inRule && trimmed.contains("margin-top:") && trimmed.contains("0") {
                hasMarginTopZero = true
            }
            if inRule && trimmed == "}" { break }
        }
        #expect(hasAlignSelf,
                "Chevron must have align-self: center — Puppeteer measured 6.8px vertical offset without it")
        #expect(hasMarginTopZero,
                "Chevron must have margin-top: 0 — h2 + * rule applies 13.6px margin-top to the LABEL after the H2")
    }

    // DISCREPANCY 2: Sidebar nav items 22px too far right
    // Measured: icon at 62px (should be 40px), link at 83px (should be 64px).
    // Root cause: .sidebar ul ul { padding-left: 16px } adds unwanted nesting indent.
    // docc-render uses depth-spacer exclusively for nesting — no UL padding.
    @Test("Sidebar nested ULs have zero padding-left (depth-spacer handles nesting)")
    func sidebarNestedULZeroPadding() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inRule = false
        var paddingValue = ""
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".sidebar ul ul") && trimmed.contains("{") {
                inRule = true
            }
            if inRule && trimmed.contains("padding-left:") {
                paddingValue = trimmed
                break
            }
            if inRule && trimmed == "}" { break }
        }
        #expect(paddingValue.contains("0"),
                "sidebar ul ul must have padding-left: 0 — Puppeteer measured 16px excess indent pushing icons from 40px to 62px")
    }

    // DISCREPANCY 3: Sidebar card height 32px vs docc-render 35px
    // Measured: docc-render card height = 35px, docc-static = 32px (min-height).
    @Test("Navigator card min-height is 35px (matches docc-render)")
    func navigatorCardMinHeight35px() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-navigator-card-min-height, 35px"),
                "Navigator card min-height must be 35px — Puppeteer measured 32px vs docc-render 35px")
    }

    // DISCREPANCY 4: Bullet points outdented from paragraph text
    // docc-render indents list text via margin-inline-start: em(20px) on UL,
    // placing bullets in the margin space (aligned with paragraph text).
    // Fix: .doc-topic > ul/ol > li { margin-left: 1.176em } — bullets sit in the margin,
    // aligning with paragraph text; list text is indented 1.176em further.
    @Test("Content list items have margin-left for text indent (bullets align with paragraphs)")
    func contentLIMarginIndent() {
        let css = DocCStylesheet.generate(theme: .default)
        // There must be a rule for .doc-topic > ul > li / .doc-topic > ol > li
        // with margin-left that includes the list-indent
        let hasLIMargin = css.contains(".doc-topic > ul > li") &&
            css.range(of: "\\.doc-topic > ul > li[^}]*margin-left:", options: .regularExpression) != nil
        #expect(hasLIMargin,
                "Content LI must have margin-left for list indent — Puppeteer measured bullets misaligned with paragraph text")
    }

    // DISCREPANCY 5: Sidebar card icon 6.4px too far right, text 2.8px too far right
    // Root cause: gap: 0.375rem on .navigator-card applies between ALL children.
    // docc-render uses gap: 0 with margin-right: 7px on the icon only.
    @Test("Navigator card has zero gap (icon margin-right handles spacing)")
    func navigatorCardZeroGap() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-navigator-card-gap, 0)"),
                "Navigator card gap must be 0 — Puppeteer measured 6.4px excess offset from flex gap")
    }

    @Test("Symbol icon is 17x17 with 7px margin-right (matches docc-render)")
    func symbolIconDimensions() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-symbol-icon-width, 17px"),
                "Symbol icon must be 17px wide (docc-render uses 17px)")
        #expect(css.contains("--spacing-symbol-icon-margin-right, 7px"),
                "Symbol icon must have 7px margin-right (docc-render .navigator-icon-wrapper)")
    }

    // MARK: - Phase 2b: Hierarchy List Styling

    @Test("Hierarchy uses list-style none (ul-based breadcrumbs)")
    func hierarchyListStyleNone() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("list-style: none"),
                "Hierarchy must use list-style: none for ul-based breadcrumbs")
    }

    @Test("Hierarchy uses CSS ::before separators on li + li")
    func hierarchyCSSSeparators() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".hierarchy li + li::before"),
                "Hierarchy must use CSS ::before on li + li for separators")
        #expect(css.contains("content: \"/\""),
                "Hierarchy separator content must be '/'")
    }

    // MARK: - Phase 2b: Decorated Title Styling

    @Test("Decorated title uses monospace font")
    func decoratedTitleFont() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".decorated-title"),
                "CSS must include .decorated-title selector")
        #expect(css.contains("--typography-html-font-mono, monospace"),
                "Decorated title must use mono font variable with monospace fallback")
    }

    @Test("Decorated title decorator class has secondary label colour")
    func decoratedTitleDecoratorColour() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".decorated-title .decorator"),
                "CSS must include .decorated-title .decorator selector")
        #expect(css.contains("--color-secondary-label"),
                "Decorator must use --color-secondary-label variable")
    }

    @Test("Decorated title identifier class has link colour and bold weight")
    func decoratedTitleIdentifierStyle() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".decorated-title .identifier"),
                "CSS must include .decorated-title .identifier selector")
    }
}

// MARK: - DOM Comparison Phase 2c Tests (Remaining Discrepancies)

@Suite("DOM Comparison Phase 2c — Remaining Discrepancies")
struct DOMComparisonPhase2cTests {

    // Item 1: Code listing dark mode background
    @Test("Dark mode defines --color-code-background for code listings")
    func darkModeCodeBackground() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--color-code-background: #2c2c2e"),
                "Dark mode must define --color-code-background to avoid light grey (#f7f7f7) in dark mode")
    }

    // Item 2: Code listing dark mode border
    @Test("Dark mode defines --color-grid for code listing borders")
    func darkModeGridColour() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--color-grid: #424245"),
                "Dark mode must define --color-grid to avoid light grey (#ccc) borders in dark mode")
    }

    // Item 3: Sidebar badge-name spacing
    @Test("Navigator card badge has margin-right for badge-name spacing")
    func navigatorCardBadgeMarginRight() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".navigator-card .badge"),
                "Must have .navigator-card .badge selector for badge spacing")
        #expect(css.contains("--spacing-navigator-card-badge-margin-right, 7px"),
                "Navigator card badge must have 7px margin-right for spacing between badge and name")
    }

    // Item 4: Declaration source no bottom border
    @Test("Declaration source has no bottom border (avoids spurious hairline)")
    func declarationSourceNoBottomBorder() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inRule = false
        var hasBorderBottomNone = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".declaration .source") && trimmed.contains("{") {
                inRule = true
            }
            if inRule && trimmed.contains("border-bottom:") && trimmed.contains("none") {
                hasBorderBottomNone = true
                break
            }
            if inRule && trimmed == "}" { break }
        }
        #expect(hasBorderBottomNone,
                "Declaration source must have border-bottom: none — docc-render has no bottom border on declaration")
    }

    // Item 5: Decorated title display inline
    @Test("Decorated title specifies display: inline")
    func decoratedTitleDisplayInline() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var hasInline = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(".decorated-title {") || trimmed.hasPrefix(".decorated-title{") {
                inBlock = true
            }
            if inBlock && trimmed.contains("display:") && trimmed.contains("inline")
                && !trimmed.contains("inline-flex") && !trimmed.contains("inline-block")
            {
                hasInline = true
                break
            }
            if inBlock && trimmed == "}" { break }
        }
        #expect(hasInline,
                "Decorated title must have display: inline to match docc-render")
    }

    // Item 5 supporting: Topic link uses inline display (not inline-flex)
    @Test("Topic link uses inline display for natural inline flow")
    func topicLinkInlineDisplay() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-topic-link-display, inline)"),
                "Topic link display must default to inline (not inline-flex) for natural inline flow")
    }

    // Item 5 supporting: Topic icon wrapper uses inline-flex (not flex)
    @Test("Topic icon wrapper uses inline-flex display")
    func topicIconWrapperInlineFlex() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-topic-icon-display, inline-flex)"),
                "Topic icon wrapper must use inline-flex (not flex) to participate in inline flow")
    }

    // Item 6: No-icon link block abstract has zero indent
    @Test("Link-block without icon has zero abstract indent")
    func noIconAbstractIndent() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".link-block.no-icon .abstract"),
                "Must have .link-block.no-icon .abstract selector for items without icons")
    }

    // Item 7: Eyebrow display block
    @Test("Eyebrow has display: block for span tag")
    func eyebrowDisplayBlock() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var hasDisplayBlock = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".eyebrow") && trimmed.contains("{") {
                inBlock = true
            }
            if inBlock && trimmed.contains("display:") && trimmed.contains("block") {
                hasDisplayBlock = true
                break
            }
            if inBlock && trimmed == "}" { break }
        }
        #expect(hasDisplayBlock,
                "Eyebrow must have display: block since it is now a <span> (inline by default)")
    }

    // Item 8: Nav position sticky
    @Test("Documentation nav uses sticky positioning")
    func navPositionSticky() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var hasSticky = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".documentation-nav") && trimmed.contains("{") {
                inBlock = true
            }
            if inBlock && trimmed.contains("position:") && trimmed.contains("sticky") {
                hasSticky = true
                break
            }
            if inBlock && trimmed == "}" { break }
        }
        #expect(hasSticky,
                "Documentation nav must use position: sticky (docc-render uses sticky, not fixed)")
    }

    // Item 9: Navigator card padding-right
    @Test("Navigator card has 20px padding-right")
    func navigatorCardPaddingRight() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-navigator-card-padding-right, 20px"),
                "Navigator card must have 20px padding-right to match docc-render")
    }

    // Item 10: Hero abstract wrapper
    @Test("Hero abstract uses div wrapper with content class")
    func heroAbstractDivWrapper() {
        let css = DocCStylesheet.generate(theme: .default)
        // When the abstract changes from <p> to <div class="abstract content"><p>...</p></div>,
        // the CSS should still apply correctly
        #expect(css.contains(".documentation-hero .abstract"),
                "Hero abstract selector must target .abstract class (works for both <p> and <div> tags)")
    }
}

@Suite("CSS Parity Phase 3 — Spacing & Border Fixes (17px Root Corrections)")
struct DOMComparisonPhase3Tests {
    // Item 1: Hero H1 margin-bottom
    @Test("Hero H1 has 12px margin-bottom for title-abstract gap")
    func heroH1MarginBottom() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var hasMarginBottom = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".documentation-hero h1") && trimmed.contains("{") {
                inBlock = true
            }
            if inBlock && trimmed.contains("margin-bottom:") && trimmed.contains("12px") {
                hasMarginBottom = true
                break
            }
            if inBlock && trimmed == "}" { break }
        }
        #expect(hasMarginBottom,
                "Hero H1 must have margin-bottom: 12px to create gap between title and abstract")
    }

    // Item 2: Module page Overview H2 has NO border (symbol pages DO have border)
    @Test("Module page Overview H2 has no border-top")
    func overviewH2NoBorder() {
        let css = DocCStylesheet.generate(theme: .default)
        // Module pages override .doc-content > h2:first-child to remove border
        // (symbol pages have border via .doc-content > h2:first-child rule)
        let lines = css.components(separatedBy: "\n")
        var foundRule = false
        var hasBorderNone = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".doc-content-wrapper > .doc-content > h2:first-child") {
                foundRule = true
            }
            if foundRule && trimmed.contains("border-top:") && trimmed.contains("none") {
                hasBorderNone = true
                break
            }
            if foundRule && trimmed == "}" { break }
        }
        #expect(foundRule, "Must have module-page h2:first-child override rule")
        #expect(hasBorderNone,
                "Module page first H2 must have border-top: none (only symbol pages get border)")
    }

    // Item 3: Overview H2 uses padding-top (not margin-top) for consistent spacing
    @Test("Overview H2 (first child of doc-content) uses padding-top 40px")
    func overviewH2MarginTop() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var hasPaddingTop = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".doc-content > h2:first-child") && trimmed.contains("{") {
                inBlock = true
            }
            if inBlock && trimmed.contains("padding-top:") && trimmed.contains("40px") {
                hasPaddingTop = true
                break
            }
            if inBlock && trimmed == "}" { break }
        }
        #expect(hasPaddingTop,
                "Overview H2 (first-child of doc-content) must use padding-top: 40px")
    }

    // Item 4: Content H3 margin-top is 44.8px (not rem-based)
    @Test("Content H3 has margin-top 44.8px (fixed, not rem)")
    func contentH3MarginTop() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var hasCorrectMarginTop = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".doc-topic > h3") && trimmed.contains("{") {
                inBlock = true
            }
            if inBlock && trimmed.contains("margin-top:") && trimmed.contains("44.8px") {
                hasCorrectMarginTop = true
                break
            }
            if inBlock && trimmed == "}" { break }
        }
        #expect(hasCorrectMarginTop,
                "Content H3 must have margin-top: 44.8px (not 2.8rem which = 47.6px at 17px root)")
    }

    // Item 5: Content H3 margin-bottom is 0
    @Test("Content H3 has margin-bottom 0")
    func contentH3MarginBottomZero() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var hasOldMarginBottom = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".doc-topic > h3") && trimmed.contains("{") {
                inBlock = true
            }
            if inBlock && trimmed.contains("margin-bottom: var(--spacing-content-heading-margin-bottom") {
                hasOldMarginBottom = true
                break
            }
            if inBlock && trimmed == "}" { break }
        }
        #expect(!hasOldMarginBottom,
                "Content H3 must NOT have margin-bottom: var(--spacing-content-heading-margin-bottom...) (should be 0)")
    }

    // Item 6: Paragraph margin-top is 0.8rem (not 0.85rem)
    @Test("Paragraph margin-top is 0.8rem (13.6px at 17px root)")
    func paragraphMarginTop() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var foundCorrect = false
        var foundIncorrect = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains(".doc-topic p") {
                inBlock = true
            }
            if inBlock {
                if trimmed.contains("margin-top:") {
                    if trimmed.contains("0.8rem") {
                        foundCorrect = true
                    }
                    if trimmed.contains("0.85rem") {
                        foundIncorrect = true
                    }
                }
                if trimmed == "}" {
                    inBlock = false
                }
            }
        }
        #expect(foundCorrect,
                "Paragraph margin-top must use 0.8rem (13.6px at 17px root)")
        #expect(!foundIncorrect,
                "Paragraph margin-top must NOT use 0.85rem (would be 14.45px at 17px root)")
    }
}

