//
// ThemeLayerTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import DocCStaticThemes
import Foundation
import Testing

@testable import DocCStatic

/// The package's `Themes` directory in the source tree.
let packageThemesDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // DocCStaticTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // package root
    .appendingPathComponent("Themes")

/// Returns the layer markers of a generated stylesheet, in order.
///
/// - Parameter css: The generated stylesheet.
/// - Returns: The marker comments, such as `/* docc-static layer: base/00-variables */`.
func layerMarkers(in css: String) -> [String] {
    css.split(separator: "\n").map(String.init).filter { $0.hasPrefix(StylesheetLayer.markerPrefix) }
}

@Suite("Built-in Theme Bundles")
struct BuiltInThemeBundleTests {
    @Test("Every bundle in Themes is a built-in theme and vice versa")
    func bundlesMatchCases() throws {
        let bundles = try ThemeBundleSource.loadAll(in: packageThemesDirectory)
        #expect(bundles.map(\.name) == ThemeSettings.BuiltInTheme.allCases.map(\.rawValue))
        for bundle in bundles {
            let theme = try #require(ThemeSettings.BuiltInTheme(rawValue: bundle.name))
            #expect(theme.settings == bundle.settings, "Compiled settings of \(bundle.name)")
            #expect(theme.stylesheets == bundle.stylesheets, "Compiled stylesheets of \(bundle.name)")
        }
    }

    @Test("Built-in theme bundles parse without warnings")
    func noWarnings() throws {
        let warnings = CollectingWarningHandler()
        _ = try ThemeBundleSource.loadAll(in: packageThemesDirectory, warningHandler: warnings)
        #expect(warnings.warnings.isEmpty, "\(warnings.warnings)")
    }

    @Test("Names are exact; aliases drop the docc-static prefix")
    func namedLookup() {
        #expect(ThemeSettings.BuiltInTheme.named("default") == .default)
        #expect(ThemeSettings.BuiltInTheme.named("docc-static-classic") == .classic)
        #expect(ThemeSettings.BuiltInTheme.named("classic") == .classic)
        #expect(ThemeSettings.BuiltInTheme.classic.aliases == ["classic"])
        #expect(ThemeSettings.BuiltInTheme.named("class") == nil)
        #expect(ThemeSettings.BuiltInTheme.named("Classic") == nil)
        #expect(ThemeSettings.BuiltInTheme.named("docc-static-classic-dark") == nil)
        #expect(ThemeSettings.BuiltInTheme.named("defaults") == nil)
    }

    @Test("Theme resolution is exact rather than fuzzy")
    func noFuzzyResolution() {
        for name in ["class", "static", "docc", "def", "default-theme"] {
            #expect(throws: ThemeResolutionError.self, "\(name)") {
                try ThemeConfiguration.resolveTheme(name, warningHandler: nil)
            }
        }
    }
}

@Suite("Stylesheet Layers")
struct StylesheetLayerTests {
    @Test("Layers appear in cascade order for every built-in theme", arguments: ThemeSettings.BuiltInTheme.allCases)
    func layerOrder(theme: ThemeSettings.BuiltInTheme) {
        let configuration = ThemeConfiguration(builtInTheme: theme, customCSS: ".custom {}")
        let markers = layerMarkers(in: DocCStylesheet.generate(theme: configuration))
        let expected =
            BaseStylesheet.parts.map { StylesheetLayer.base.marker(part: $0.name) }
            + [StylesheetLayer.sidebarDocument.marker(), StylesheetLayer.themeSettings.marker()]
            + theme.stylesheets.map { StylesheetLayer.theme.marker(part: $0.name) }
            + [StylesheetLayer.custom.marker()]
        #expect(markers == expected)
    }

    @Test("Base stylesheet parts are compiled in file name order")
    func baseOrder() {
        let names = BaseStylesheet.parts.map(\.name)
        #expect(!names.isEmpty)
        #expect(names == names.sorted())
        #expect(BaseStylesheet.parts.contains { $0.isDarkModeOnly })
    }

    @Test("Dark mode only parts are left out without dark mode")
    func darkModeParts() {
        let css = DocCStylesheet.generate(theme: ThemeConfiguration(builtInTheme: .default, includeDarkMode: false))
        for part in BaseStylesheet.parts where part.isDarkModeOnly {
            #expect(!layerMarkers(in: css).contains(StylesheetLayer.base.marker(part: part.name)))
        }
    }

    @Test("The accent layer is only used when the settings do not define a link colour")
    func accentLayer() {
        let accentOnly = DocCStylesheet.generate(theme: ThemeConfiguration(accentColour: "#ff5500", includeDarkMode: true))
        #expect(layerMarkers(in: accentOnly).contains(StylesheetLayer.accent.marker()))
        #expect(accentOnly.contains("--color-link: #ff5500;"))
        let builtIn = DocCStylesheet.generate(theme: .default)
        #expect(!layerMarkers(in: builtIn).contains(StylesheetLayer.accent.marker()))
    }

    @Test("Custom CSS comes last, after the theme's stylesheets")
    func customLast() throws {
        let theme = ThemeConfiguration(
            themeSettings: ThemeSettings.Root(theme: ThemeSettings.Theme()),
            stylesheets: [ThemeStylesheet(name: "theme", css: ".theme-rule {}")],
            customCSS: ".custom-rule {}"
        )
        let css = DocCStylesheet.generate(theme: theme)
        let themeRule = try #require(css.range(of: ".theme-rule {}"))
        let customRule = try #require(css.range(of: ".custom-rule {}"))
        #expect(themeRule.lowerBound < customRule.lowerBound)
        #expect(layerMarkers(in: css).last == StylesheetLayer.custom.marker())
    }

    @Test("The sidebar rules use the shared class names")
    func sidebarRules() {
        let css = DocCStylesheet.generate(theme: .default)
        #expect(css.contains(".\(SidebarDocument.frameClass) {"))
        #expect(css.contains("body.\(SidebarDocument.documentClass) .sidebar {"))
    }
}

@Suite("Runtime Theme Loading")
struct RuntimeThemeLoadingTests {
    /// Creates a temporary directory for one test.
    func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("docc-static-theme-loading-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test("Runtime parsing reports unknown keys like the theme compiler")
    func runtimeWarnings() throws {
        let json = #"{"theme": {"colour": {"link": "red"}}, "featurez": {}}"#
        let warnings = CollectingWarningHandler()
        _ = try ThemeSettingsParser.parse(Data(json.utf8), warningHandler: warnings)
        #expect(warnings.warnings.count == 2)
        #expect(warnings.warnings.contains { $0.contains("colour") })
        #expect(warnings.warnings.contains { $0.contains("featurez") })
    }

    @Test("Custom theme files report warnings during resolution")
    func resolutionWarnings() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("custom.json")
        try #"{"theme": {"colors": {}}}"#.write(to: file, atomically: true, encoding: .utf8)
        let warnings = CollectingWarningHandler()
        _ = try ThemeConfiguration.resolveTheme(file.path, warningHandler: warnings)
        #expect(warnings.warnings.count == 1)
    }

    @Test("Generic specification sections become custom properties")
    func genericSections() throws {
        let json = """
            {"theme": {"code": {"border-width": "2px", "indentationWidth": 2},
                       "aside": {"border-radius": "6px"},
                       "border-radius": "0",
                       "button": {"background": {"light": "white", "dark": "black"}}}}
            """
        let settings = try ThemeSettingsParser.parse(Data(json.utf8))
        let css = ThemeSettingsParser.generateCSS(from: settings, includeDarkMode: true)
        #expect(css.contains("--code-border-width: 2px;"))
        #expect(css.contains("--code-indentationWidth: 2;"))
        #expect(css.contains("--aside-border-radius: 6px;"))
        #expect(css.contains("--border-radius: 0;"))
        #expect(css.contains("--button-background: white;"))
        #expect(css.contains("--button-background: black;"))
        let dark = ThemeSettingsParser.extractVariables(from: settings, colorScheme: .dark)
        #expect(dark["--button-background"] == "black")
    }

    @Test("A theme directory supplies settings and stylesheets")
    func themeDirectory() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try ##"{"theme": {"color": {"link": "#123456"}}, "features": {"docs": {"onThisPageNavigator": {"disable": true}}}}"##
            .write(to: directory.appendingPathComponent(ThemeBundleLayout.settingsFileName), atomically: true, encoding: .utf8)
        try ".from-theme-directory {}".write(
            to: directory.appendingPathComponent("theme.css"), atomically: true, encoding: .utf8)
        try ".dark-only {}".write(
            to: directory.appendingPathComponent("theme.dark.css"), atomically: true, encoding: .utf8)

        let theme = try ThemeConfiguration.resolveTheme(directory.path, warningHandler: nil)
        #expect(theme.accentColour == "#123456")
        #expect(theme.isEnabled(.onThisPageNavigatorDisabled))
        #expect(theme.stylesheets.map(\.name) == ["theme", "theme.dark"])
        let css = DocCStylesheet.generate(theme: theme)
        #expect(css.contains(".from-theme-directory {}"))
        #expect(css.contains(".dark-only {}"))

        let light = try ThemeConfiguration.resolveTheme(directory.path, includeDarkMode: false, warningHandler: nil)
        let lightCSS = DocCStylesheet.generate(theme: light)
        #expect(lightCSS.contains(".from-theme-directory {}"))
        #expect(!lightCSS.contains(".dark-only {}"))
    }

    @Test("A directory without settings is not a theme")
    func directoryWithoutSettings() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect {
            try ThemeConfiguration.resolveTheme(directory.path, warningHandler: nil)
        } throws: { error in
            guard case ThemeResolutionError.invalidThemeFile(let path, let reason)? = error as? ThemeResolutionError
            else { return false }
            return path == directory.path && reason.contains(ThemeBundleLayout.settingsFileName)
        }
    }

    @Test("A custom CSS file is read for the custom layer")
    func customCSSFile() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("extra.css")
        try ".extra-rule { color: red; }".write(to: file, atomically: true, encoding: .utf8)
        let css = try ThemeConfiguration.loadCustomCSS(from: file.path)
        let theme = try ThemeConfiguration.resolveTheme("classic", customCSS: css, warningHandler: nil)
        let stylesheet = DocCStylesheet.generate(theme: theme)
        #expect(stylesheet.hasSuffix(StylesheetLayer.custom.marker() + "\n.extra-rule { color: red; }\n\n"))
        #expect(throws: ThemeResolutionError.self) {
            try ThemeConfiguration.loadCustomCSS(from: directory.appendingPathComponent("missing.css").path)
        }
    }

    @Test("Feature switches default to off for built-in themes without them")
    func builtInFeatureDefaults() {
        #expect(!ThemeConfiguration.default.isEnabled(.onThisPageNavigatorDisabled))
        let none = ThemeConfiguration(accentColour: "#000", includeDarkMode: true)
        #expect(none.isEnabled(.quickNavigationEnabled))
    }
}
