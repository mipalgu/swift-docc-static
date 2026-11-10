//
// ThemeConsistencyTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import DocCStaticThemes
import Foundation
import Testing

@testable import DocCStatic

/// The custom properties a stylesheet defines and reads.
struct CustomPropertyUsage {
    /// The custom properties declared anywhere (`--name: value`).
    let defined: Set<String>

    /// The custom properties read anywhere (`var(--name ...)`).
    let read: Set<String>

    /// The custom properties read at least once without a fallback value.
    let readWithoutFallback: Set<String>

    /// Analyses a stylesheet.
    ///
    /// - Parameter css: The stylesheet text.
    init(css: String) {
        let withoutComments = css.replacing(#/\/\*[\s\S]*?\*\//#, with: "")
        defined = Set(withoutComments.matches(of: #/(--[A-Za-z0-9_-]+)\s*:/#).map { String($0.output.1) })
        var read = Set<String>()
        var withoutFallback = Set<String>()
        for match in withoutComments.matches(of: #/var\(\s*(--[A-Za-z0-9_-]+)\s*([,)])/#) {
            read.insert(String(match.output.1))
            if match.output.2 == ")" { withoutFallback.insert(String(match.output.1)) }
        }
        self.read = read
        self.readWithoutFallback = withoutFallback
    }
}

/// Checks that every built-in theme's custom properties and the base stylesheet agree.
@Suite("Theme Custom Property Consistency")
struct ThemeCustomPropertyTests {
    @Test("Every custom property a theme sets is read by some rule", arguments: ThemeSettings.BuiltInTheme.allCases)
    func everyThemePropertyIsRead(theme: ThemeSettings.BuiltInTheme) throws {
        let css = DocCStylesheet.generate(theme: ThemeConfiguration(builtInTheme: theme))
        let usage = CustomPropertyUsage(css: css)
        var set = Set(ThemeSettingsParser.customProperties(from: theme.settings, dark: false).map(\.name))
        for stylesheet in theme.stylesheets {
            set.formUnion(CustomPropertyUsage(css: stylesheet.css).defined)
        }
        let unused = set.subtracting(usage.read)
        VisualRegressionHarness.reconcile(
            occurring: Dictionary(uniqueKeysWithValues: unused.map { ($0, "set but never read") }),
            known: try VisualRegressionHarness.knownIssues(for: theme.rawValue).unusedProperties,
            kind: "unused custom properties",
            listName: "unusedProperties",
            theme: theme.rawValue
        )
    }

    @Test("Every custom property read without a fallback is defined", arguments: ThemeSettings.BuiltInTheme.allCases)
    func everyReadPropertyIsDefined(theme: ThemeSettings.BuiltInTheme) throws {
        let css = DocCStylesheet.generate(theme: ThemeConfiguration(builtInTheme: theme))
        let usage = CustomPropertyUsage(css: css)
        let undefined = usage.readWithoutFallback.subtracting(usage.defined)
        VisualRegressionHarness.reconcile(
            occurring: Dictionary(uniqueKeysWithValues: undefined.map { ($0, "read without fallback, never defined") }),
            known: try VisualRegressionHarness.knownIssues(for: theme.rawValue).undefinedProperties,
            kind: "undefined custom properties",
            listName: "undefinedProperties",
            theme: theme.rawValue
        )
    }

    @Test("Custom property analysis finds definitions, reads and missing fallbacks")
    func analysis() {
        let usage = CustomPropertyUsage(css: """
            :root { --a: 1px; /* --ignored: 2px; var(--ignored-read) */ }
            .x { margin: var(--a) var(--b, 2px); padding: var( --c ); }
            """)
        #expect(usage.defined == ["--a"])
        #expect(usage.read == ["--a", "--b", "--c"])
        #expect(usage.readWithoutFallback == ["--a", "--c"])
    }
}

/// One page of the fixture as listed in `Tests/VisualRegression/pages.json`.
struct FixturePage: Decodable, Sendable, CustomTestStringConvertible {
    /// The page identifier.
    let id: String

    /// The kind of page: `landing`, `documentation` or `tutorial`.
    let kind: String

    /// The page's path in swift-docc-static output.
    let `static`: String

    /// The path relative to the output directory.
    var relativePath: String { String(self.static.drop(while: { $0 == "/" })) }

    /// The identifier shown in test results.
    var testDescription: String { id }

    /// The pages of the fixture, read from the harness's page list.
    static let all: [FixturePage] = {
        let file = VisualRegressionHarness.directory.appendingPathComponent("pages.json")
        guard let data = try? Data(contentsOf: file),
            let pages = try? JSONDecoder().decode([FixturePage].self, from: data)
        else { return [] }
        return pages
    }()
}

/// Checks the DOM structure of every page type for every built-in theme.
@Suite("Theme DOM Structure", .serialized)
struct ThemeDOMStructureTests {
    /// The markup every page of a kind must contain, and markup specific to some pages.
    static let required: [String: [String]] = [
        "landing": ["class=\"index-header\"", "class=\"module-card\"", "<footer"],
        "documentation": [
            "class=\"documentation-nav\"", "<iframe class=\"\(SidebarDocument.frameClass)\"",
            "class=\"documentation-hero", "<h1>", "class=\"primary-content-container\"", "<footer",
        ],
        "tutorial": ["<h1", "<footer"],
        "module": ["class=\"contenttable", "id=\"topics\""],
        "structure": ["<section class=\"declaration\"", "id=\"topics\"", "id=\"relationships\"", "id=\"see-also\""],
        "class": ["<section class=\"declaration\"", "id=\"topics\""],
        "enumeration": ["<section class=\"declaration\"", "id=\"topics\""],
        "protocol": ["<section class=\"declaration\"", "id=\"topics\"", "class=\"mentions\""],
        "defaultImplementations": ["id=\"topics\""],
        "method": ["<section class=\"declaration\"", "class=\"parameters\"", "class=\"mentions\""],
        "property": ["<section class=\"declaration\""],
        "operator": ["<section class=\"declaration\"", "class=\"parameters\""],
        "nested": ["<section class=\"declaration\"", "id=\"topics\""],
        "article": [
            "class=\"code-listing\"", "<table", "<img", "<ol", "<ul", "<code>",
            "aside note", "aside tip", "aside important", "aside warning", "aside experiment",
        ],
        "tutorial-page": [
            "class=\"\(TutorialDocument.heroClass)\"", "class=\"\(TutorialDocument.sectionClass)\"",
            "class=\"\(TutorialDocument.stepClass)\"", "class=\"\(TutorialDocument.assessmentsClass)\"",
        ],
        "tutorialsOverview": [
            "class=\"\(TutorialDocument.overviewHeroClass)\"", "class=\"\(TutorialDocument.chapterClass) tile\"",
        ],
    ]

    @Test("The fixture page list covers every page kind")
    func pageList() {
        #expect(Set(FixturePage.all.map(\.kind)) == ["landing", "documentation", "tutorial"])
        #expect(FixturePage.all.count >= 14)
    }

    @Test("Every page type has its structure", arguments: ThemeSettings.BuiltInTheme.allCases, FixturePage.all)
    func structure(theme: ThemeSettings.BuiltInTheme, page: FixturePage) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let html = try fixture.text(at: page.relativePath)
        let pageKey = page.id == "tutorial" ? "tutorial-page" : page.id
        for markup in (Self.required[page.kind] ?? []) + (Self.required[pageKey] ?? []) {
            #expect(html.contains(markup), "\(page.id) for \(theme.rawValue) lacks \(markup)")
        }
        #expect(!html.contains("Documentation for "), "\(page.id) shows a placeholder abstract")
    }
}
