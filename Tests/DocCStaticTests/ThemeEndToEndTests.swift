//
// ThemeEndToEndTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import DocCStaticThemes
import Foundation
import Testing

@testable import DocCStatic

/// Returns a copy of a theme configuration without feature switches.
///
/// - Parameter theme: The configuration to copy.
/// - Returns: The same configuration with an empty `features` section.
func withoutFeatures(_ theme: ThemeConfiguration) -> ThemeConfiguration {
    var copy = theme
    copy.themeSettings?.features = nil
    return copy
}

/// Returns the generated HTML documents of a fixture output keyed by relative path.
///
/// - Parameter fixture: The generated fixture.
/// - Returns: The contents of every `.html` file.
/// - Throws: An error if a file cannot be read.
func htmlDocuments(of fixture: GeneratedFixture) throws -> [String: String] {
    var documents: [String: String] = [:]
    for file in fixture.files(withExtension: "html") {
        documents[fixture.relativePath(of: file)] = try String(contentsOf: file, encoding: .utf8)
    }
    return documents
}

/// End-to-end tests that run the real generator on the fixture package and
/// check how themes affect the generated site.
@Suite("Theme End-to-End Tests", .serialized)
struct ThemeEndToEndTests {
    @Test("Page HTML depends on the theme only through feature switches",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func htmlIndependentOfTheme(theme: ThemeSettings.BuiltInTheme) async throws {
        let reference = try await FixtureDocumentation.shared.output(
            configuration: withoutFeatures(ThemeConfiguration(builtInTheme: .default)),
            variant: "default-without-features"
        )
        let themed = try await FixtureDocumentation.shared.output(
            configuration: withoutFeatures(ThemeConfiguration(builtInTheme: theme)),
            variant: "\(theme.rawValue)-without-features"
        )
        let referenceHTML = try htmlDocuments(of: reference)
        let themedHTML = try htmlDocuments(of: themed)
        #expect(referenceHTML.keys.sorted() == themedHTML.keys.sorted())
        for (path, html) in referenceHTML {
            #expect(themedHTML[path] == html, "\(path) differs between default and \(theme.rawValue)")
        }

        // Adding the theme's feature switches to the default theme reproduces the theme's HTML
        var defaultWithFeatures = ThemeConfiguration(builtInTheme: .default)
        defaultWithFeatures.themeSettings?.features = theme.settings.features
        let switched = try await FixtureDocumentation.shared.output(
            configuration: defaultWithFeatures,
            variant: "default-with-\(theme.rawValue)-features"
        )
        let full = try await FixtureDocumentation.shared.output(theme: theme)
        let switchedHTML = try htmlDocuments(of: switched)
        for (path, html) in try htmlDocuments(of: full) {
            #expect(switchedHTML[path] == html, "\(path) differs beyond the feature switches of \(theme.rawValue)")
        }
    }

    @Test("Disabling the on-this-page navigator removes it from documentation pages")
    func onThisPageNavigatorSwitch() async throws {
        var disabled = ThemeConfiguration(builtInTheme: .default)
        disabled.themeSettings?.features = [
            "docs": .object(["onThisPageNavigator": .object(["disable": .value("true")])])
        ]
        let without = try await FixtureDocumentation.shared.output(
            configuration: disabled,
            variant: "default-without-on-this-page"
        )
        let with = try await FixtureDocumentation.shared.output(theme: .default)
        let marker = "class=\"\(HTMLPageBuilder.onThisPageContainerClass)\""
        let withPages = try htmlDocuments(of: with).filter { $0.value.contains(marker) }
        #expect(!withPages.isEmpty)
        for (path, html) in try htmlDocuments(of: without) {
            #expect(!html.contains(marker), "\(path) still has the on-this-page navigator")
        }
    }

    @Test("The landing page shows each module's abstract")
    func landingPageAbstracts() async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: .default)
        let index = try fixture.text(at: "index.html")
        #expect(index.contains("Core geometry types used to exercise the static documentation renderer."))
        #expect(index.contains("Labels and canvas extensions built on top of FixtureCore."))
        #expect(!index.contains("Documentation for FixtureCore"))
        #expect(!index.contains("Documentation for FixtureExtras"))
    }

    @Test("A custom theme directory and custom CSS file take effect")
    func customThemeDirectory() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("docc-static-custom-theme-e2e")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try ##"{"theme": {"color": {"link": "#a1b2c3"}}, "features": {"docs": {"onThisPageNavigator": {"disable": true}}}}"##
            .write(to: directory.appendingPathComponent(ThemeBundleLayout.settingsFileName), atomically: true, encoding: .utf8)
        try ".custom-theme-rule { color: #a1b2c3; }".write(
            to: directory.appendingPathComponent("theme.css"), atomically: true, encoding: .utf8)
        let extra = directory.appendingPathComponent("extra.css")
        try ".custom-css-rule { color: red; }".write(to: extra, atomically: true, encoding: .utf8)

        let theme = try ThemeConfiguration.resolveTheme(
            directory.path,
            customCSS: try ThemeConfiguration.loadCustomCSS(from: extra.path),
            warningHandler: nil
        )
        let fixture = try await FixtureDocumentation.shared.output(configuration: theme, variant: "custom-directory")
        let css = try fixture.text(at: "css/main.css")
        #expect(css.contains("--color-link: #a1b2c3;"))
        #expect(css.contains(StylesheetLayer.theme.marker(part: "theme") + "\n.custom-theme-rule { color: #a1b2c3; }"))
        #expect(css.contains(StylesheetLayer.custom.marker() + "\n.custom-css-rule { color: red; }"))
        let marker = "class=\"\(HTMLPageBuilder.onThisPageContainerClass)\""
        for (path, html) in try htmlDocuments(of: fixture) {
            #expect(!html.contains(marker), "\(path) still has the on-this-page navigator")
        }
    }
}
