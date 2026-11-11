//
// ThemeHookTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import SwiftDocC
import Testing

@testable import DocCStatic

/// Checks the small, always present elements that themes can style but the default
/// theme hides.
///
/// Every page has the same markup whatever the theme, so information that only some
/// themes show is part of every page and hidden by the base stylesheet.
@Suite("Theme Hooks")
struct ThemeHookTests {
    @Test("The navigation bar title starts with an empty icon element")
    func navigationTitleIcon() {
        let markup = HTMLPageBuilder.navigationBarMarkup(depth: 2)
        let icon = "<span class=\"\(HTMLPageBuilder.navigationTitleIconClass)\" aria-hidden=\"true\"></span>"
        #expect(markup.contains("<h2 class=\"nav-title\"><a href=\"../../index.html\">\(icon)Documentation</a></h2>"))
    }

    @Test("Line breaks added to a declaration are marked, those beside parentheses separately")
    func declarationBreaks() {
        let builder = HTMLPageBuilder(configuration: Configuration(
            packageDirectory: FileManager.default.temporaryDirectory,
            outputDirectory: FileManager.default.temporaryDirectory
        ))
        let tokens = HTMLPageBuilder.formattedSwiftTokens([
            (.attribute, "@MainActor", nil), (.text, " ", nil), (.keyword, "init", nil), (.text, "(", nil),
            (.externalParam, "x", nil), (.text, ": ", nil), (.typeIdentifier, "Double", nil), (.text, ", ", nil),
            (.externalParam, "y", nil), (.text, ": ", nil), (.typeIdentifier, "Double", nil), (.text, ")", nil),
        ])
        let markup = tokens.map {
            builder.declarationTokenMarkup(kind: $0.kind, text: $0.text, identifier: $0.identifier, references: [:], depth: 0)
        }.joined()
        let lineBreak = "<span class=\"\(HTMLPageBuilder.declarationBreakClass)\">"
        let parenthesisBreak = "<span class=\"\(HTMLPageBuilder.declarationBreakClass) \(HTMLPageBuilder.declarationParenthesisBreakClass)\">"
        #expect(markup.contains("<span class=\"token-attribute\">@MainActor</span>\(lineBreak)\n</span><span class=\"token-keyword\">init</span>"))
        #expect(markup.contains("(\(parenthesisBreak)\n    </span><span class=\"token-externalParam\">x</span>"))
        #expect(markup.contains(",\(lineBreak)\n    </span><span class=\"token-externalParam\">y</span>"))
        #expect(markup.hasSuffix("\(parenthesisBreak)\n</span>)"))
    }

    /// A page builder whose navigation index lists a structure with a method.
    func builderWithIndex() -> HTMLPageBuilder {
        func node(_ title: String, _ path: String?, _ type: String, _ children: [NavigationNode] = []) -> NavigationNode {
            NavigationNode(title: title, path: path, type: type, children: children,
                           isDeprecated: nil, isExternal: nil, isBeta: nil)
        }
        let module = node("M", "/documentation/m", "module", [
            node("Point", "/documentation/m/point", "struct", [
                node("scaled(by:)", "/documentation/m/point/scaled(by:)", "method"),
            ]),
        ])
        let index = NavigationIndex(schemaVersion: nil, includedArchiveIdentifiers: nil, interfaceLanguages: ["swift": [module]])
        return HTMLPageBuilder(configuration: Configuration(
            packageDirectory: FileManager.default.temporaryDirectory,
            outputDirectory: FileManager.default.temporaryDirectory
        ), navigationIndex: index)
    }

    /// A topic reference to a symbol with declaration fragments.
    func symbolReference(_ title: String, url: String, fragments: [DeclarationRenderSection.Token]) -> TopicRenderReference {
        TopicRenderReference(
            identifier: RenderReferenceIdentifier("doc://m/documentation/m/\(title)"),
            title: title,
            abstract: [],
            url: url,
            kind: .symbol,
            role: "symbol",
            fragments: fragments
        )
    }

    @Test("A topic's kind badge names the navigator type of the page and its letters, without text")
    func topicKindFromNavigator() {
        let reference = symbolReference("scaled(by:)", url: "/documentation/m/point/scaled(by:)", fragments: [
            .init(text: "func", kind: .keyword), .init(text: " ", kind: .text), .init(text: "scaled", kind: .identifier),
        ])
        let html = builderWithIndex().buildSymbolCard(for: reference, depth: 0)
        #expect(html.contains("class=\"link-block topic has-inline-element\" \(TopicTypeIcon.typeAttribute)=\"method\""))
        #expect(html.contains("<span class=\"\(HTMLPageBuilder.topicKindBadgeClass)\" \(TopicTypeIcon.typeAttribute)=\"method\" \(TopicTypeIcon.lettersAttribute)=\"M\" aria-hidden=\"true\"></span>"))
    }

    @Test("Without a navigator row, a topic's kind is the declaration keyword before its name",
          arguments: [("static func +", "func"), ("class var shared", "var"), ("init", "method"), ("case north", "enum")])
    func topicKindFromFragments(declaration: String, type: String) {
        var fragments: [DeclarationRenderSection.Token] = []
        let words = declaration.split(separator: " ").map(String.init)
        for (index, word) in words.enumerated() {
            let isName = index == words.count - 1 && words.count > 1 && !["init"].contains(word)
            fragments.append(.init(text: word, kind: isName ? .identifier : .keyword))
            fragments.append(.init(text: " ", kind: .text))
        }
        let reference = symbolReference("T", url: "/documentation/other/t", fragments: fragments)
        let html = builderWithIndex().buildSymbolCard(for: reference, depth: 0)
        #expect(html.contains("\(TopicTypeIcon.typeAttribute)=\"\(type)\" data-topic-role=\"symbol\""), "\(declaration)")
    }

    @Test("A topic shown by its declaration also carries its plain title, hidden by default")
    func topicTitle() {
        let reference = symbolReference("Point.Components", url: "/documentation/m/point/components", fragments: [
            .init(text: "struct", kind: .keyword), .init(text: " ", kind: .text), .init(text: "Components", kind: .identifier),
        ])
        let html = builderWithIndex().buildSymbolCard(for: reference, depth: 0)
        #expect(html.contains("</code><span class=\"\(HTMLPageBuilder.topicTitleClass)\">Point<wbr>.Components</span></a>"))
        let css = DocCStylesheet.generate(theme: ThemeConfiguration(builtInTheme: .default))
        #expect(css.contains(".link-block .\(HTMLPageBuilder.topicTitleClass) {\n    display: none;\n}"))
    }

    @Test("A module card on the landing page carries the module's symbol count, hidden by default",
          arguments: [(1, "1 symbol"), (61, "61 symbols")])
    func moduleStatistics(count: Int, text: String) {
        let builder = IndexPageBuilder(configuration: Configuration(
            packageDirectory: FileManager.default.temporaryDirectory,
            outputDirectory: FileManager.default.temporaryDirectory
        ))
        let html = builder.buildIndexPage(modules: [
            IndexPageBuilder.ModuleEntry(name: "M", abstract: "About M.", path: "documentation/m/index.html", symbolCount: count),
        ])
        #expect(html.contains("<div class=\"content\">About M.</div></div><div class=\"\(IndexPageBuilder.moduleStatisticsClass)\">\(text)</div><div class=\"link\">"))
        let css = DocCStylesheet.generate(theme: ThemeConfiguration(builtInTheme: .default))
        #expect(css.contains(".card .\(IndexPageBuilder.moduleStatisticsClass) {\n    display: none;\n}"))
    }

    @Test("A tutorial in a tutorials overview carries its abstract, hidden by default")
    func overviewTopicAbstract() {
        let builder = HTMLPageBuilder(configuration: Configuration(
            packageDirectory: FileManager.default.temporaryDirectory,
            outputDirectory: FileManager.default.temporaryDirectory
        ))
        let chapter = TutorialsOverview.Chapter(name: "Basics", topics: [
            TutorialsOverview.Topic(title: "Drawing", url: "drawing/index.html", abstract: "Draw a point."),
            TutorialsOverview.Topic(title: "Erasing", url: "erasing/index.html"),
        ])
        let html = builder.chapterTile(chapter, number: 1, timeline: "--t", volumeHasName: false)
        #expect(html.contains("<div class=\"link\">Drawing</div><div class=\"\(TutorialDocument.topicAbstractClass)\">Draw a point.</div></a>"))
        #expect(html.contains("<div class=\"link\">Erasing</div></a>"))
        let css = DocCStylesheet.generate(theme: ThemeConfiguration(builtInTheme: .default))
        #expect(css.contains(".topic-list .\(TutorialDocument.topicAbstractClass) {\n    display: none;\n}"))
    }

    @Test("The base stylesheet hides the navigation bar title icon")
    func navigationTitleIconIsHiddenByDefault() {
        let css = DocCStylesheet.generate(theme: ThemeConfiguration(builtInTheme: .default))
        #expect(css.contains(".nav-title .\(HTMLPageBuilder.navigationTitleIconClass) {\n    display: none;\n}"))
    }
}
