//
// ThemeBundle.swift
// DocCStaticThemes
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation

/// The file layout of theme bundles and stylesheet directories.
///
/// A theme bundle is a directory that contains a `theme-settings.json` file and
/// any number of stylesheets (`*.css`).  The stylesheets are applied in the
/// order of their file names after the base stylesheet.  A stylesheet whose
/// name ends in `.dark.css` is only included when dark mode styles are enabled.
///
/// The built-in themes are the bundles in the package's `Themes` directory and
/// are named after their directory.  The base stylesheet shared by all themes
/// follows the same stylesheet rules.
public enum ThemeBundleLayout {
    /// The name of the settings file inside a theme bundle.
    public static let settingsFileName = "theme-settings.json"

    /// The file extension of stylesheets.
    public static let stylesheetExtension = "css"

    /// The file name suffix that marks a stylesheet as dark mode only.
    public static let darkModeStylesheetSuffix = ".dark.css"

    /// The prefix that may be left out when naming a built-in theme.
    ///
    /// For example, the built-in theme `docc-static-classic` can also be
    /// selected as `classic`.
    public static let builtInNamePrefix = "docc-static-"

    /// Returns the alternative names under which a built-in theme can be selected.
    ///
    /// - Parameter name: The name of the built-in theme (its directory name).
    /// - Returns: The aliases, which may be empty.
    public static func aliases(forBuiltInTheme name: String) -> [String] {
        guard name.hasPrefix(builtInNamePrefix), name.count > builtInNamePrefix.count else { return [] }
        return [String(name.dropFirst(builtInNamePrefix.count))]
    }

    /// Reads the stylesheets of a directory in application order.
    ///
    /// - Parameter directory: The directory to read.
    /// - Returns: The stylesheets sorted by file name; an empty array if there are none.
    /// - Throws: An error if the directory exists but cannot be read.
    public static func stylesheets(in directory: URL) throws -> [ThemeStylesheet] {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue
        else { return [] }
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == stylesheetExtension }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.map { file in
            try ThemeStylesheet(
                name: file.deletingPathExtension().lastPathComponent,
                isDarkModeOnly: file.lastPathComponent.hasSuffix(darkModeStylesheetSuffix),
                css: String(contentsOf: file, encoding: .utf8)
            )
        }
    }
}

/// A stylesheet that is part of the base stylesheet or of a theme bundle.
public struct ThemeStylesheet: Equatable, Hashable, Sendable {
    /// The name of the stylesheet: its file name without the `.css` extension.
    public var name: String

    /// Whether the stylesheet is only included when dark mode styles are enabled.
    public var isDarkModeOnly: Bool

    /// The CSS text.
    public var css: String

    /// Creates a stylesheet.
    ///
    /// - Parameters:
    ///   - name: The name used to identify the stylesheet in the generated CSS.
    ///   - isDarkModeOnly: Whether to include the stylesheet only with dark mode styles.
    ///   - css: The CSS text.
    public init(name: String, isDarkModeOnly: Bool = false, css: String) {
        self.name = name
        self.isDarkModeOnly = isDarkModeOnly
        self.css = css
    }
}

/// A theme bundle read from a directory.
///
/// The same loader reads the built-in themes when the package is built and
/// custom theme directories at run time, so both are validated identically.
public struct ThemeBundleSource: Equatable, Sendable {
    /// The name of the theme, which is the name of its directory.
    public var name: String

    /// The parsed theme settings.
    public var settings: ThemeSettingsInput

    /// The theme's stylesheets in application order.
    public var stylesheets: [ThemeStylesheet]

    /// Creates a theme bundle.
    ///
    /// - Parameters:
    ///   - name: The name of the theme.
    ///   - settings: The theme settings.
    ///   - stylesheets: The theme's stylesheets in application order.
    public init(name: String, settings: ThemeSettingsInput, stylesheets: [ThemeStylesheet] = []) {
        self.name = name
        self.settings = settings
        self.stylesheets = stylesheets
    }

    /// Whether a directory looks like a theme bundle.
    ///
    /// - Parameter directory: The directory to check.
    /// - Returns: `true` if the directory contains a settings file.
    public static func isBundle(_ directory: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(ThemeBundleLayout.settingsFileName).path
        )
    }

    /// Reads a theme bundle from a directory.
    ///
    /// - Parameters:
    ///   - directory: The bundle directory, containing `theme-settings.json` and
    ///     optional stylesheets.
    ///   - warningHandler: Receives warnings about unknown keys in the settings.
    /// - Returns: The theme bundle.
    /// - Throws: An error if the settings file is missing or invalid, or a
    ///   stylesheet cannot be read.
    public static func load(
        from directory: URL,
        warningHandler: (any ThemeParsingWarningHandler)? = nil
    ) throws -> ThemeBundleSource {
        let settingsFile = directory.appendingPathComponent(ThemeBundleLayout.settingsFileName)
        let settings = try ThemeSettingsInput.parse(contentsOf: settingsFile, warningHandler: warningHandler)
        return ThemeBundleSource(
            name: directory.standardizedFileURL.lastPathComponent,
            settings: settings,
            stylesheets: try ThemeBundleLayout.stylesheets(in: directory)
        )
    }

    /// Reads all theme bundles in a directory.
    ///
    /// - Parameters:
    ///   - directory: The directory whose subdirectories are theme bundles.
    ///   - warningHandler: Receives warnings about unknown keys in the settings.
    /// - Returns: The bundles sorted by name.
    /// - Throws: An error if a bundle cannot be read.
    public static func loadAll(
        in directory: URL,
        warningHandler: (any ThemeParsingWarningHandler)? = nil
    ) throws -> [ThemeBundleSource] {
        let entries = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        return try entries.filter(isBundle)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try load(from: $0, warningHandler: warningHandler) }
    }
}
