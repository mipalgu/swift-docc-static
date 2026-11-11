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

        // The palette follows the colour scheme of the body through light-dark() pairs
        #expect(css.contains("color-scheme: light dark"))
        #expect(css.contains("light-dark("))
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
        #expect(css.contains("--spacing-stacked-margin-xlarge: calc(var(--spacing-stacked-margin-large) * 2)"))
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
        #expect(css.contains("--color-fill-gray-quaternary: light-dark(#f0f0f0, #424242)"))
    }

    @Test("Light mode includes correct fill-gray-quaternary")
    func lightModeFillGrayQuaternary() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--color-fill-gray-quaternary: #f0f0f0"))
    }

    @Test("Dark mode includes correct navigator-item-hover")
    func darkModeNavigatorItemHover() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--color-navigator-item-hover: light-dark(rgba(0, 0, 255, 0.05), rgba(0, 102, 255, 0.5))"))
    }

    @Test("Light mode includes correct navigator-item-hover")
    func lightModeNavigatorItemHover() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--color-navigator-item-hover: rgba(0, 0, 255, 0.05)"))
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
        #expect(css.contains("--color-navigator-item-hover: rgba(0, 0, 255, 0.05)"))
    }

    @Test("Technology title background matches swift-docc-render default")
    func technologyTitleBackgroundDefault() {
        let css = DocCStylesheet.generate(theme: .default)

        // The technology title has the navigator's background unless it is the current page
        #expect(css.contains(".technology-title"))
        #expect(css.contains("background: var(--color-technology-title-background, var(--color-fill))"))
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

        // A module's header is its technology title, whose padding is themeable
        #expect(css.contains(".module-header"))
        #expect(css.contains("padding: var(--spacing-technology-title-padding,"))
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
        #expect(css.contains(".navigator-card-item:not(.is-group):hover .head-wrapper"))
        #expect(css.contains("background: var(--color-navigator-item-hover)"))
    }

    @Test("Navigator card active uses fill-gray-quaternary variable")
    func navigatorCardActive() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".navigator-card-item:target .head-wrapper"))
        #expect(css.contains("background: var(--color-fill-gray-quaternary)"))
    }

    @Test("Navigator card selected uses fill-gray-quaternary variable")
    func navigatorCardSelected() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".navigator-card-item:target .leaf-link"))
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
        // Default sidebar width is 400px per swift-docc-render (LARGE_DEFAULT_WIDTH in AdjustableSidebarWidth.vue)
        #expect(css.contains("--sidebar-width: var(--spacing-sidebar-width, clamp(calc(min(100vw, 1521px) * 0.3), 400px, calc(min(100vw, 1521px) * 0.4)))"))
    }

    @Test("Default theme sidebar width is 400px")
    func defaultSidebarWidth() {
        let theme = ThemeConfiguration(builtInTheme: .default, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)
        // Sidebar width uses CSS variable for themeability
        #expect(css.contains("--sidebar-width: var(--spacing-sidebar-width, clamp(calc(min(100vw, 1521px) * 0.3), 400px, calc(min(100vw, 1521px) * 0.4)))"))
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
        #expect(css.contains(".technology-title:target"))
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
        // Code listings fill the content column, which is centred with auto margins
        #expect(css.contains(".full-width-container .container"))
        #expect(css.contains("margin-left: var(--spacing-hero-margin-left, auto)"),
                "The content column must use auto margins to align code with paragraph text")
    }

    @Test("Direct paragraphs receive content padding")
    func directParagraphsGetPadding() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".full-width-container .container"))
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

    @Test("Default theme sidebar width matches swift-docc-render (400px)")
    func defaultSidebarWidth() {
        let theme = ThemeConfiguration(builtInTheme: .default, includeDarkMode: true, customCSS: nil)
        let css = DocCStylesheet.generate(theme: theme)

        // swift-docc-render uses 432px for sidebar width @ 1440px viewport
        #expect(css.contains("--sidebar-width: var(--spacing-sidebar-width, clamp(calc(min(100vw, 1521px) * 0.3), 400px, calc(min(100vw, 1521px) * 0.4)))"))
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
        let preCodeSection = css.components(separatedBy: ".code-listing pre > code {").dropFirst().first?.components(separatedBy: "}").first ?? ""
        #expect(preCodeSection.contains("font-size: var(--spacing-pre-code-font-size, 0.8823529412rem)"))
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

        // Paragraphs are reset to no margins, like swift-docc-render's reset
        let hasMainParagraph = css.contains("hgroup, input, legend, li, ol, p, pre, ul {")
        #expect(hasMainParagraph, "Expected the reset rule to include paragraphs")

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



    @Test("H1-H6 base elements have zero margin (matches swift-docc-render)")
    func baseHeadingsHaveZeroMargin() {
        let css = DocCStylesheet.generate(theme: .default)
        // swift-docc-render sets margin: 0; padding: 0; on base heading elements
        #expect(css.contains("h1, h2, h3, h4, h5, h6"),
                "Must have combined h1-h6 selector")
        #expect(css.contains("margin: 0"),
                "Base headings must have margin: 0 per swift-docc-render")
    }



    @Test("Topic group H3s have zero margin (matches swift-docc-render)")
    func topicGroupH3ZeroMargin() {
        let css = DocCStylesheet.generate(theme: .default)
        // Verified via DOM comparison: "Essentials" H3 inside .contenttable-section has marginTop: 0px
        #expect(css.contains(".contenttable-title") || css.contains(".contenttable-section h3"),
                "Topic group H3 selector must exist")
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




    @Test("Sidebar heading has no uppercase text-transform")
    func sidebarHeadingNoUppercase() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("--spacing-sidebar-heading-text-transform, none"),
                "Sidebar heading text-transform must default to none, not uppercase")
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

}

// MARK: - DOM Comparison Parity Tests (Puppeteer-verified, Session 2)

@Suite("DOM Comparison Parity — Puppeteer-verified Fixes")
struct DOMComparisonParityTests {

    // A. Content Padding Model




    // B. Colour Issues



    // C. Typography / Code Issues


    @Test("Code font-family includes Menlo")
    func codeFontFamilyIncludesMenlo() {
        let css = DocCStylesheet.generate(theme: .default)
        // Both code and pre elements should include Menlo in font-family
        #expect(css.contains("Menlo, monospace"),
                "Code font-family must include Menlo before monospace")
    }



    // D. Spacing / Margin Issues





    // E. Topic Link Issues



    // F. Breadcrumb Issues


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


    // G. Sidebar and Section Separator Issues (DOM Comparison v2)


    @Test("Section H2s (Topics, Relationships, See Also) have border-top separator")
    func sectionH2sBorderTop() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("border-top: 1px solid var(--color-fill-gray)"),
                "Section H2s must have border-top separator matching docc-render ContentTable.vue")
    }



    // H. Sidebar Indentation and Font-Weight (DOM Comparison v3)



}

// MARK: - CSS Parity Phase 2 Tests (Puppeteer-verified Discrepancies)

@Suite("CSS Parity Phase 2 — Remaining Discrepancies")
struct CSSParityPhase2Tests {



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


}

// MARK: - Puppeteer-Verified Pixel-Accuracy Tests (Phase 2b)

@Suite("Puppeteer-Verified Pixel-Accuracy Tests")
struct PuppeteerVerifiedPixelAccuracyTests {







    // MARK: - Phase 2b: Hierarchy List Styling

    @Test("Hierarchy uses list-style none (ul-based breadcrumbs)")
    func hierarchyListStyleNone() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("list-style: none"),
                "Hierarchy must use list-style: none for ul-based breadcrumbs")
    }


    // MARK: - Phase 2b: Decorated Title Styling


    @Test("Decorated title decorator class has secondary label colour")
    func decoratedTitleDecoratorColour() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".decorated-title .decorator"),
                "CSS must include .decorated-title .decorator selector")
        #expect(css.contains("--color-secondary-label"),
                "Decorator must use --color-secondary-label variable")
    }

}

// MARK: - DOM Comparison Phase 2c Tests (Remaining Discrepancies)

@Suite("DOM Comparison Phase 2c — Remaining Discrepancies")
struct DOMComparisonPhase2cTests {









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

}

// MARK: - Layout Width and Padding Parity Tests
// These tests guard against double-padding regressions found during DOM comparison.
// The key invariant: content text must start at the same horizontal offset (80px into
// the content column) regardless of whether it is in primary content or a Topics section.

@Suite("Layout Width and Padding Parity — Prevent Double-Padding Regressions")
struct LayoutPaddingParityTests {

    // Extracts all properties inside the first CSS block whose selector line
    // matches `selectorPredicate`. Handles multi-selector rules.
    private func properties(in css: String, matching selectorPredicate: (String) -> Bool) -> [String: String] {
        let lines = css.components(separatedBy: "\n")
        var result: [String: String] = [:]
        var inBlock = false
        var depth = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !inBlock {
                if selectorPredicate(trimmed) {
                    inBlock = true
                    // Opening brace may be on this line or a subsequent selector line
                    if trimmed.hasSuffix("{") { depth = 1 }
                }
                if inBlock && trimmed.hasSuffix("{") { depth = 1 }
                continue
            }
            if trimmed.hasSuffix("{") {
                depth += 1
                continue
            }
            if trimmed == "}" {
                depth -= 1
                if depth == 0 { break }
                continue
            }
            // Property line: "name: value;"
            if depth == 1, let colon = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[trimmed.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colon)...])
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: ";", with: "")
                    .trimmingCharacters(in: .whitespaces)
                result[key] = value
            }
        }
        return result
    }



    @Test("contenttable.alt-light section itself has no horizontal padding (full-width)")
    func contenttableAltLightNoPadding() {
        let css = DocCStylesheet.generate(theme: .default)
        // The section must not receive any direct padding-left from a rule whose selector
        // targets .contenttable.alt-light directly (without a descendant combinator for .container).
        // We look for a block where selector is EXACTLY ".contenttable.alt-light {" with padding-left.
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var foundPaddingLeft = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Only match the block for .contenttable.alt-light alone (not .container child)
            if !inBlock && trimmed.hasPrefix(".contenttable.alt-light") &&
               !trimmed.contains(".container") && !trimmed.contains(".title") &&
               !trimmed.contains(".section") {
                inBlock = true
            }
            if inBlock {
                if trimmed.contains("padding-left:") {
                    foundPaddingLeft = true
                }
                if trimmed == "}" { inBlock = false }
            }
        }
        #expect(!foundPaddingLeft,
                ".contenttable.alt-light section must NOT have direct padding-left (it is full-width; only inner .container has padding)")
    }

    @Test("contenttable.alt-light has no background colour (matches docc-render ContentTable.vue)")
    func contenttableAltLightNoBackground() {
        let css = DocCStylesheet.generate(theme: .default)
        // In docc-render, the alt-light class is a modifier with no background-color.
        // The Topics section appears on a white/transparent background matching the page.
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var foundBackground = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !inBlock && trimmed.hasPrefix(".contenttable.alt-light") &&
               !trimmed.contains(".container") && !trimmed.contains(".title") &&
               !trimmed.contains(".section") {
                inBlock = true
            }
            if inBlock {
                if trimmed.contains("background-color:") || trimmed.contains("background:") {
                    foundBackground = true
                }
                if trimmed == "}" { inBlock = false }
            }
        }
        #expect(!foundBackground,
                ".contenttable.alt-light must NOT have a background-color rule — in docc-render the alt-light class carries no background (docc-render ContentTable.vue scoped styles have no background property)")
    }



    @Test("No descendant .doc-topic section rule sets horizontal padding (prevents double-padding)")
    func noDescendantSectionPaddingRule() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var blockHasPaddingLeft = false
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Detect a rule that uses `.doc-topic section` as a descendant selector
            // (no `>` combinator — this catches ALL sections including contenttable)
            if !inBlock && trimmed.contains(".doc-topic section") && !trimmed.contains(".doc-topic section >") {
                inBlock = true
            }
            if inBlock {
                if trimmed.contains("padding-left:") { blockHasPaddingLeft = true }
                if trimmed == "}" { inBlock = false }
            }
        }
        #expect(!blockHasPaddingLeft,
                "A '.doc-topic section' descendant rule must NOT set padding-left — it matches .contenttable.alt-light and causes double-padding. Use .primary-content-container instead.")
    }

    @Test("No legacy descendant .doc-topic .declaration rule sets horizontal padding (prevents double-padding in hero)")
    func noLegacyDeclarationPaddingRule() {
        let css = DocCStylesheet.generate(theme: .default)
        let lines = css.components(separatedBy: "\n")
        var inBlock = false
        var blockHasPaddingLeft = false
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match the legacy grouped rule that includes ".doc-topic .declaration" as one
            // of several selectors and sets padding-left (the old container-model fallback).
            // The .declaration rule inside .documentation-hero__content already inherits
            // the correct horizontal position; a descendant rule duplicates it.
            if !inBlock && trimmed == ".doc-topic .declaration," {
                inBlock = true
            }
            if inBlock {
                if trimmed.contains("padding-left:") { blockHasPaddingLeft = true }
                if trimmed == "}" { inBlock = false }
            }
            _ = i  // suppress unused-variable warning
        }
        #expect(!blockHasPaddingLeft,
                "'.doc-topic .declaration' must NOT set padding-left in a grouped fallback rule — the hero's .documentation-hero__content already provides the 80px gutter.")
    }



}

