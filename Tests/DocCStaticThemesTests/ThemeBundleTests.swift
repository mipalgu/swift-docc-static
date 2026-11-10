//
// ThemeBundleTests.swift
// DocCStaticThemesTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing

@testable import DocCStaticThemes

/// Creates a fresh temporary directory for a test.
///
/// - Returns: The directory URL.
/// - Throws: A file system error.
private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("docc-static-theme-bundle-tests")
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

@Suite("Generic Theme Values")
struct ThemeSettingValueTests {
    @Test("Strings, numbers and Booleans become plain values")
    func plainValues() throws {
        let json = #"{"a": "x", "b": 2, "c": true, "d": 1.5}"#
        let values = try JSONDecoder().decode([String: ThemeSettingValue].self, from: Data(json.utf8))
        #expect(values["a"] == .value("x"))
        #expect(values["b"] == .value("2"))
        #expect(values["c"] == .value("true"))
        #expect(values["d"] == .value("1.5"))
    }

    @Test("Objects with exactly light and dark strings become pairs")
    func lightDarkPairs() throws {
        let json = ##"{"pair": {"light": "#fff", "dark": "#000"}, "nested": {"light": "#fff", "other": "1"}}"##
        let values = try JSONDecoder().decode([String: ThemeSettingValue].self, from: Data(json.utf8))
        #expect(values["pair"] == .lightDark(light: "#fff", dark: "#000"))
        #expect(values["nested"] == .object(["light": .value("#fff"), "other": .value("1")]))
    }

    @Test("Flattening joins nested keys with dashes like swift-docc-render")
    func flattening() {
        let value = ThemeSettingValue.object([
            "border-width": .value("2px"),
            "fill": .lightDark(light: "white", dark: "black"),
        ])
        let light = value.flattened(prefix: "code", dark: false)
        let dark = value.flattened(prefix: "code", dark: true)
        #expect(light.map(\.name) == ["code-border-width", "code-fill"])
        #expect(light.map(\.value) == ["2px", "white"])
        #expect(dark.map(\.value) == ["2px", "black"])
        #expect(value.hasDarkVariant)
        #expect(!ThemeSettingValue.value("x").hasDarkVariant)
    }

    @Test("Leaf paths and lookup follow the key structure")
    func leafPathsAndLookup() {
        let value = ThemeSettingValue.object([
            "docs": .object(["onThisPageNavigator": .object(["disable": .value("true")])])
        ])
        #expect(value.leafPaths == [["docs", "onThisPageNavigator", "disable"]])
        #expect(value.value(at: ["docs", "onThisPageNavigator", "disable"]) == .value("true"))
        #expect(value.value(at: ["docs", "missing"]) == nil)
    }

    @Test("Values survive an encoding round trip")
    func roundTrip() throws {
        let value = ThemeSettingValue.object([
            "a": .value("1"),
            "b": .lightDark(light: "l", dark: "d"),
            "c": .object(["d": .value("e")]),
        ])
        let data = try JSONEncoder().encode(value)
        #expect(try JSONDecoder().decode(ThemeSettingValue.self, from: data) == value)
    }
}

@Suite("Theme Settings Specification Coverage")
struct ThemeSettingsSpecificationTests {
    @Test("Every section of the swift-docc-render specification is accepted without warnings")
    func specificationSections() throws {
        let json = """
            {
              "meta": { "title": "Docs" },
              "theme": {
                "aside": { "border-radius": "6px", "border-style": "double", "border-width": "3px" },
                "badge": { "border-radius": "3px" },
                "border-radius": "0",
                "button": { "border-radius": "8px" },
                "code": { "border-width": "2px", "indentationWidth": 2 },
                "color": { "fill": "#fff" },
                "icons": { "article": "/article.svg" },
                "tutorial-step": { "border-radius": "4px" },
                "typography": { "html-font": "serif" },
                "device-frames": { "phone": { "screenTop": 10 } },
                "spacing": { "sidebar-width": "300px" }
              },
              "features": {
                "docs": {
                  "quickNavigation": { "enable": false },
                  "onThisPageNavigator": { "disable": true },
                  "i18n": { "enable": false }
                }
              }
            }
            """
        let warnings = CollectingWarningHandler()
        let settings = try ThemeSettingsInput.parse(Data(json.utf8), warningHandler: warnings)
        #expect(warnings.warnings.isEmpty, "\(warnings.warnings)")
        #expect(settings.theme.other?["code"]?.value(at: ["indentationWidth"]) == .value("2"))
        #expect(settings.theme.other?["border-radius"] == .value("0"))
        #expect(settings.theme.other?.keys.sorted() == [
            "aside", "border-radius", "button", "code", "device-frames", "icons", "tutorial-step",
        ])
        #expect(settings.isEnabled(.onThisPageNavigatorDisabled))
        #expect(!settings.isEnabled(.quickNavigationEnabled))
        #expect(!settings.isEnabled(.internationalisationEnabled))
    }

    @Test("Feature switches fall back to their defaults")
    func featureDefaults() throws {
        let settings = try ThemeSettingsInput.parse(Data(#"{"theme": {}}"#.utf8))
        for flag in ThemeFeatureFlag.all {
            #expect(settings.isEnabled(flag) == flag.defaultValue, "\(flag)")
        }
    }

    @Test("Unknown feature switches are reported")
    func unknownFeatureSwitch() throws {
        let json = #"{"theme": {}, "features": {"docs": {"onThisPageNavigator": {"hide": true}}}}"#
        let warnings = CollectingWarningHandler()
        _ = try ThemeSettingsInput.parse(Data(json.utf8), warningHandler: warnings)
        #expect(warnings.warnings.count == 1)
        #expect(warnings.warnings.first?.contains("features.docs.onThisPageNavigator.hide") == true)
    }

    @Test("Feature switch names are dotted key paths")
    func featureDescriptions() {
        #expect(ThemeFeatureFlag.onThisPageNavigatorDisabled.description == "docs.onThisPageNavigator.disable")
        #expect(ThemeFeatureFlag.all.filter(\.isHonoured) == [.onThisPageNavigatorDisabled])
    }

    @Test("Generic sections and features survive an encoding round trip")
    func roundTrip() throws {
        let json = ##"{"theme": {"code": {"border-width": "2px"}, "color": {"fill": "#fff"}}, "features": {"docs": {"i18n": {"enable": true}}}}"##
        let settings = try ThemeSettingsInput.parse(Data(json.utf8))
        let data = try JSONEncoder().encode(settings)
        #expect(try ThemeSettingsInput.parse(data) == settings)
    }
}

@Suite("Theme Bundles")
struct ThemeBundleSourceTests {
    @Test("A bundle directory provides settings and stylesheets in file name order")
    func loadBundle() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = root.appendingPathComponent("my-theme")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try #"{"theme": {"color": {"link": "red"}}}"#.write(
            to: bundle.appendingPathComponent(ThemeBundleLayout.settingsFileName), atomically: true, encoding: .utf8)
        try "b {}".write(to: bundle.appendingPathComponent("b.css"), atomically: true, encoding: .utf8)
        try "a {}".write(to: bundle.appendingPathComponent("a.css"), atomically: true, encoding: .utf8)
        try "d {}".write(to: bundle.appendingPathComponent("c.dark.css"), atomically: true, encoding: .utf8)
        try "ignored".write(to: bundle.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        #expect(ThemeBundleSource.isBundle(bundle))
        let source = try ThemeBundleSource.load(from: bundle)
        #expect(source.name == "my-theme")
        #expect(source.settings.theme.color?["link"] == .single("red"))
        #expect(source.stylesheets.map(\.name) == ["a", "b", "c.dark"])
        #expect(source.stylesheets.map(\.isDarkModeOnly) == [false, false, true])
        #expect(source.stylesheets.map(\.css) == ["a {}", "b {}", "d {}"])
    }

    @Test("Only directories with a settings file are bundles")
    func loadAllBundles() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["zeta", "alpha"] {
            let bundle = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
            try #"{"theme": {}}"#.write(
                to: bundle.appendingPathComponent(ThemeBundleLayout.settingsFileName), atomically: true,
                encoding: .utf8)
        }
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("not-a-theme"), withIntermediateDirectories: true)
        #expect(try ThemeBundleSource.loadAll(in: root).map(\.name) == ["alpha", "zeta"])
    }

    @Test("A missing stylesheet directory has no stylesheets")
    func missingStylesheetDirectory() throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #expect(try ThemeBundleLayout.stylesheets(in: missing).isEmpty)
    }

    @Test("Built-in theme aliases drop the docc-static prefix")
    func aliases() {
        #expect(ThemeBundleLayout.aliases(forBuiltInTheme: "docc-static-classic") == ["classic"])
        #expect(ThemeBundleLayout.aliases(forBuiltInTheme: "default").isEmpty)
        #expect(ThemeBundleLayout.aliases(forBuiltInTheme: "docc-static-").isEmpty)
    }
}

@Suite("Theme Code Generation for Bundles")
struct ThemeBundleCodeGenerationTests {
    let generator = ThemeCodeGenerator()

    /// A small bundle used by several tests.
    var bundle: ThemeBundleSource {
        ThemeBundleSource(
            name: "docc-static-classic",
            settings: ThemeSettingsInput(
                theme: ThemeInput(color: ["link": .single("#06c")], other: ["code": .object(["border-width": .value("1px")])]),
                features: ["docs": .object(["onThisPageNavigator": .object(["disable": .value("true")])])]
            ),
            stylesheets: [ThemeStylesheet(name: "theme", css: "html { font-size: 16px; }\n")]
        )
    }

    @Test("Generated files contain no date and are reproducible")
    func reproducible() {
        let first = generator.generateFile(bundles: [bundle], baseStylesheets: [])
        let second = generator.generateFile(bundles: [bundle], baseStylesheets: [])
        #expect(first == second)
        #expect(!generator.generateHeader().contains("Created by"))
        let datePattern = #/\d{1,2}/\d{1,2}/\d{4}/#
        #expect(first.firstMatch(of: datePattern) == nil)
    }

    @Test("The built-in theme enumeration is generated from the bundle names")
    func enumeration() {
        let code = generator.generateBuiltInThemeEnum(names: ["default", "docc-static-classic", "my-theme"])
        #expect(code.contains("public enum BuiltInTheme: String, CaseIterable, Sendable {"))
        #expect(code.contains("case `default` = \"default\""))
        #expect(code.contains("case `classic` = \"docc-static-classic\""))
        #expect(code.contains("case `myTheme` = \"my-theme\""))
    }

    @Test("Generated files contain settings, features, generic sections, stylesheets and accessors")
    func fileContents() {
        let base = [ThemeStylesheet(name: "00-base", css: "body {}\n"), ThemeStylesheet(name: "01-x.dark", isDarkModeOnly: true, css: "a {}\n")]
        let code = generator.generateFile(bundles: [bundle], baseStylesheets: base)
        #expect(code.contains("import DocCStaticThemes"))
        #expect(code.contains("static let classicThemeData = ThemeSettings.Root("))
        #expect(code.contains("other: ["))
        #expect(code.contains("\"code\": .object(["))
        #expect(code.contains("features: ["))
        #expect(code.contains("\"disable\": .value(\"true\")"))
        #expect(code.contains("static let classicThemeStylesheets: [ThemeStylesheet] = ["))
        #expect(code.contains("html { font-size: 16px; }"))
        #expect(code.contains("enum BaseStylesheet {"))
        #expect(code.contains("name: \"01-x.dark\""))
        #expect(code.contains("isDarkModeOnly: true"))
        #expect(code.contains("case .classic: return Self.classicThemeData"))
        #expect(code.contains("case .classic: return Self.classicThemeStylesheets"))
    }

    @Test("Raw string literals use enough delimiters for their content")
    func rawStringDelimiters() {
        #expect(generator.rawStringLiteral("a {}").hasPrefix("#\"\"\"\n"))
        #expect(generator.rawStringLiteral("a {}").hasSuffix("\n\"\"\"#"))
        let tricky = "content: \"\"\"#; x: \\#(y)"
        let literal = generator.rawStringLiteral(tricky)
        #expect(literal.hasPrefix("##\"\"\"\n"))
        #expect(literal.hasSuffix("\"\"\"##"))
    }

    @Test("String literals escape backslashes, quotes and control characters")
    func stringLiterals() {
        #expect(generator.swiftStringLiteral(#"a"b\c"#) == #""a\"b\\c""#)
        #expect(generator.swiftStringLiteral("a\nb") == #""a\nb""#)
    }

    @Test("Case names are camel case without the built-in prefix")
    func caseNames() {
        #expect(generator.swiftCaseName(for: "default") == "default")
        #expect(generator.swiftCaseName(for: "docc-static-classic") == "classic")
        #expect(generator.swiftCaseName(for: "my-custom-theme") == "myCustomTheme")
        #expect(generator.swiftCaseName(for: "2024-theme") == "theme2024Theme")
        #expect(generator.stylesheetPropertyName(for: "docc-static-classic") == "classicThemeStylesheets")
    }
}
