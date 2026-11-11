//
// VueParityRenderingTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import SwiftDocC
import Testing

@testable import DocCStatic

/// Tests of the page chrome and markup that reproduce swift-docc-render.
@Suite("Colour Scheme Toggle")
struct ColourSchemeToggleTests {
    @Test("The toggle is a radio group with Auto checked")
    func toggleMarkup() {
        let html = ColourSchemeToggle.toggleMarkup()
        #expect(html.hasPrefix("<fieldset class=\"\(ColourSchemeToggle.className)\" role=\"radiogroup\">"))
        for scheme in ColourSchemeToggle.Scheme.allCases {
            #expect(html.contains("name=\"\(ColourSchemeToggle.inputName)\" value=\"\(scheme.rawValue)\""))
            #expect(html.contains(">\(scheme.label)</span>"))
        }
        #expect(html.contains("value=\"auto\" checked"))
        #expect(!html.contains("value=\"light\" checked"))
    }

    @Test("Checked radio buttons set the colour scheme without scripts")
    func stylesheetWithoutScripts() {
        let css = ColourSchemeToggle.stylesheet(includeDarkMode: true)
        #expect(css.contains("body:has(.color-scheme-toggle input[value=\"dark\"]:checked)"))
        #expect(css.contains("body[data-color-scheme=\"light\"]"))
        #expect(css.contains("color-scheme: dark;"))
        #expect(css.contains("color-scheme: light;"))
        #expect(css.hasPrefix("@media screen {"))
    }

    @Test("Without dark mode the toggle is hidden")
    func stylesheetWithoutDarkMode() {
        let css = ColourSchemeToggle.stylesheet(includeDarkMode: false)
        #expect(css.contains(".color-scheme-toggle {"))
        #expect(css.contains("display: none;"))
        #expect(!css.contains("color-scheme: dark"))
    }

    @Test("The footer holds the toggle and the custom content in one row")
    func footerMarkup() {
        let html = ColourSchemeToggle.footerMarkup(content: "<a href=\"x\">Credit</a>")
        #expect(html.contains("<footer class=\"footer\">"))
        #expect(html.contains("<div class=\"row\"><fieldset"))
        #expect(html.contains("<div class=\"footer-content\"><a href=\"x\">Credit</a></div>"))
    }

    @Test("The script restores and stores the choice and informs the sidebar")
    func script() {
        let script = ColourSchemeToggle.script
        #expect(script.contains(SidebarDocument.colourSchemeStorageKey))
        #expect(script.contains(SidebarDocument.colourSchemeMessage))
        #expect(script.contains("localStorage.setItem"))
    }

    @Test("The palette follows the colour scheme of the body")
    func paletteUsesLightDark() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains("body {\n    --color-fill: #fff;"))
        #expect(css.contains("--color-fill: light-dark(#fff, #000);"))
        #expect(css.contains("@supports (color: light-dark(#000, #fff))"))
        #expect(css.contains(StylesheetLayer.colourScheme.marker()))
    }
}

@Suite("Swift Declaration Formatting")
struct SwiftDeclarationFormattingTests {
    typealias Token = HTMLPageBuilder.DeclarationToken

    @Test("Functions with several parameters get one parameter per line")
    func multipleParameters() {
        let tokens: [Token] = [
            (.keyword, "static", nil), (.text, " ", nil), (.keyword, "func", nil), (.text, " ", nil),
            (.identifier, "+", nil), (.text, " (", nil), (.internalParam, "lhs", nil), (.text, ": ", nil),
            (.typeIdentifier, "Point", nil), (.text, ", ", nil), (.externalParam, "rhs", nil), (.text, ": ", nil),
            (.typeIdentifier, "Point", nil), (.text, ") -> ", nil), (.typeIdentifier, "Point", nil),
        ]
        let text = HTMLPageBuilder.formattedSwiftTokens(tokens).map(\.text).joined()
        #expect(text == "static func + (\n    lhs: Point,\n    rhs: Point\n) -> Point")
    }

    @Test("Functions with one parameter stay on one line")
    func singleParameter() {
        let tokens: [Token] = [
            (.keyword, "func", nil), (.text, " ", nil), (.identifier, "scaled", nil), (.text, "(", nil),
            (.externalParam, "by", nil), (.text, " ", nil), (.internalParam, "factor", nil), (.text, ": ", nil),
            (.typeIdentifier, "Double", nil), (.text, ") -> ", nil), (.typeIdentifier, "Point", nil),
        ]
        let text = HTMLPageBuilder.formattedSwiftTokens(tokens).map(\.text).joined()
        #expect(text == "func scaled(by factor: Double) -> Point")
    }

    @Test("Attributes before the declaration get a line of their own")
    func attributes() {
        let tokens: [Token] = [
            (.attribute, "@MainActor", nil), (.text, " ", nil), (.keyword, "var", nil), (.text, " ", nil),
            (.identifier, "x", nil),
        ]
        let text = HTMLPageBuilder.formattedSwiftTokens(tokens).map(\.text).joined()
        #expect(text == "@MainActor\nvar x")
    }
}

@Suite("Topic Type Icons")
struct TopicTypeIconTests {
    @Test("Symbol kinds map to the letters of swift-docc-render", arguments: [
        ("struct", "S"), ("structure", "S"), ("class", "C"), ("enum", "E"), ("case", "E"),
        ("protocol", "Pr"), ("extension", "Ex"), ("instanceMethod", "M"), ("init", "M"),
        ("property", "P"), ("typealias", "T"), ("macro", "#"), ("var", "V"),
    ])
    func letters(type: String, letters: String) {
        #expect(TopicTypeIcon.letters(for: TopicTypeIcon.normalisedType(type)) == letters)
    }

    @Test("Functions, operators and articles use drawn icons")
    func drawnIcons() {
        for type in ["func", "op", "article", "module", "subscript", "tutorial"] {
            #expect(TopicTypeIcon.letters(for: TopicTypeIcon.normalisedType(type)) == nil)
        }
        #expect(TopicTypeIcon.markup(for: "article").contains("article-icon"))
        #expect(TopicTypeIcon.markup(for: "module").contains("technology-icon"))
    }

    @Test("Icons carry their type for themes")
    func attributes() {
        let html = TopicTypeIcon.markup(for: "protocol", additionalClass: "navigator-icon")
        #expect(html.hasPrefix("<span class=\"TopicTypeIcon navigator-icon\" data-topic-type=\"protocol\" data-topic-letters=\"Pr\">"))
        #expect(html.contains("two-letter-icon"))
    }

    @Test("Topic lists show icons only for non-symbol roles")
    func topicListIcons() {
        #expect(TopicTypeIcon.topicListIcon(forRole: "article")?.contains("class=\"topic-icon svg-icon\"") == true)
        #expect(TopicTypeIcon.topicListIcon(forRole: "collectionGroup") != nil)
        #expect(TopicTypeIcon.topicListIcon(forRole: "symbol") == nil)
    }
}

@Suite("Navigator Rows")
struct NavigatorRowTests {
    /// A module with a group heading, a structure with a child, and an article.
    func index() -> NavigationIndex {
        func node(_ title: String, _ path: String?, _ type: String, _ children: [NavigationNode] = []) -> NavigationNode {
            NavigationNode(title: title, path: path, type: type, children: children,
                           isDeprecated: nil, isExternal: nil, isBeta: nil)
        }
        let child = node("x", "/documentation/m/point/x", "property")
        let module = node("M", "/documentation/m", "module", [
            node("Essentials", nil, "groupMarker"),
            node("Point", "/documentation/m/point", "struct", [child]),
            node("Guide", "/documentation/m/guide", "article"),
        ])
        return NavigationIndex(schemaVersion: nil, includedArchiveIdentifiers: nil, interfaceLanguages: ["swift": [module]])
    }

    @Test("Group headings share the nesting index of the rows they group")
    func groupNesting() {
        var builder = NavigationSidebarBuilder(navigationIndex: index())
        let html = builder.buildNavigationTree()
        #expect(html.contains("<li class=\"navigator-card-item is-group\" data-nesting-index=\"0\""))
        #expect(html.contains("<h3 class=\"leaf-link\">Essentials</h3>"))
        #expect(html.contains("class=\"navigator-card-item expandable\" data-nesting-index=\"0\""))
        #expect(html.contains("class=\"navigator-card-item\" data-nesting-index=\"1\""))
    }

    @Test("Chevrons are labels filling the depth spacer")
    func chevronLabel() {
        var builder = NavigationSidebarBuilder(navigationIndex: index())
        let html = builder.buildNavigationTree()
        #expect(html.contains("<div class=\"depth-spacer\"><label for=\"nav-0\" class=\"tree-toggle\""))
        #expect(html.contains("<input type=\"checkbox\" id=\"nav-0\" class=\"disclosure-checkbox\"><div class=\"head-wrapper\">"))
    }

    @Test("The filter starts hidden and the single module title stays above the rows")
    func filterAndTitle() {
        var builder = NavigationSidebarBuilder(navigationIndex: index())
        let html = builder.buildNavigationTree()
        #expect(html.contains("<div class=\"filter-wrapper\" id=\"sidebar-filter\" hidden>"))
        let title = try? #require(html.range(of: "class=\"technology-title\""))
        let scroller = try? #require(html.range(of: "class=\"sidebar-content scroller\""))
        if let title, let scroller {
            #expect(title.lowerBound < scroller.lowerBound)
        }
    }
}
