//
// DocCStatic.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

/// DocCStatic is a library for generating static HTML documentation from Swift packages.
///
/// ## Overview
///
/// DocCStatic generates pure HTML/CSS documentation that can be viewed locally
/// in a browser or hosted on any static web server. Unlike standard DocC output,
/// DocCStatic does not require JavaScript for basic functionality.
///
/// ## Getting Started
///
/// To generate documentation programmatically, create a ``Configuration`` and
/// pass it to ``StaticDocumentationGenerator``:
///
/// ```swift
/// import DocCStatic
///
/// let configuration = Configuration(
///     packageDirectory: URL(fileURLWithPath: "."),
///     outputDirectory: URL(fileURLWithPath: ".build/docs")
/// )
///
/// let generator = StaticDocumentationGenerator(configuration: configuration)
/// let result = try await generator.generate()
///
/// print("Generated \(result.generatedPages) pages at \(result.outputDirectory)")
/// ```
///
/// ## Features
///
/// - **Pure HTML/CSS output**: Works without JavaScript (search is optional)
/// - **Multi-package support**: Document all targets and dependencies
/// - **Cross-linking**: Relative links work with `file://` URLs
/// - **DocC compatibility**: Supports articles, tutorials, and code snippets
/// - **Customisable themes**: Match DocC style or create your own
///
/// ## Topics
///
/// ### Configuration
///
/// - ``Configuration``
/// - ``DependencyInclusionPolicy``
/// - ``ThemeConfiguration``
/// - ``ThemeSettings``
/// - ``StylesheetLayer``
///
/// ### Generation
///
/// - ``StaticDocumentationGenerator``
/// - ``GenerationResult``
///
/// ### Diagnostics
///
/// - ``Warning``
/// - ``SourceLocation``

// MARK: - Configuration

import DocCStaticThemes
import Foundation

/// Configuration for static documentation generation.
///
/// Use this type to configure how documentation is generated, including which
/// dependencies to include, where to write output, and styling options.
///
/// ## Overview
///
/// Create a configuration with the required parameters, then pass it to
/// ``StaticDocumentationGenerator`` to generate documentation:
///
/// ```swift
/// let configuration = Configuration(
///     packageDirectory: URL(fileURLWithPath: "."),
///     outputDirectory: URL(fileURLWithPath: ".build/docs")
/// )
/// let generator = StaticDocumentationGenerator(configuration: configuration)
/// let result = try await generator.generate()
/// ```
public struct Configuration: Sendable {
    /// The directory containing the Swift package to document.
    public var packageDirectory: URL

    /// The directory where generated documentation will be written.
    public var outputDirectory: URL

    /// Specific targets to document. If empty, all documentable targets are included.
    public var targets: [String]

    /// Policy for including dependency documentation.
    public var dependencyPolicy: DependencyInclusionPolicy

    /// External documentation URLs for dependencies not included in the build.
    ///
    /// Maps package names to their documentation base URLs.
    public var externalDocumentationURLs: [String: URL]

    /// Whether to generate a client-side search index.
    public var includeSearch: Bool

    /// Theme configuration for the generated documentation.
    public var theme: ThemeConfiguration

    /// Whether to output verbose logging during generation.
    public var isVerbose: Bool

    /// Custom scratch path for Swift build operations.
    ///
    /// If `nil`, uses the default `.build` directory in the package.
    public var scratchPath: URL?

    /// Pre-generated symbol graph directory.
    ///
    /// If set, skips the `swift build` step and uses these symbol graphs directly.
    public var symbolGraphDir: URL?

    /// Custom HTML for the footer.
    ///
    /// This HTML is displayed at the bottom of each page when the user scrolls
    /// all the way down. Set to `nil` to use the default footer.
    public var footerHTML: String?

    /// Paths to documentation archives to use as dependencies for resolving external links.
    ///
    /// These archives must have been built with external link support enabled.
    /// Use `doc://ModuleName/path` syntax in documentation to reference symbols
    /// in these dependency archives.
    public var dependencyArchives: [URL]

    /// The default footer HTML.
    public static let defaultFooter = """
        <a href="https://github.com/mipalgu/swift-docc-static">swift-docc-static</a> \
        by <a href="https://hexel.au">René Hexel</a>
        """

    /// Creates a new configuration for documentation generation.
    ///
    /// - Parameters:
    ///   - packageDirectory: The directory containing the Swift package.
    ///   - outputDirectory: Where to write the generated documentation.
    ///   - targets: Specific targets to document. Empty means all targets.
    ///   - dependencyPolicy: How to handle dependency documentation.
    ///   - externalDocumentationURLs: URLs for external dependency documentation.
    ///   - includeSearch: Whether to generate a search index.
    ///   - theme: Theme configuration.
    ///   - isVerbose: Whether to enable verbose logging.
    ///   - scratchPath: Custom scratch path for builds, or nil for default.
    ///   - symbolGraphDir: Pre-generated symbol graphs, or nil to generate.
    ///   - footerHTML: Custom footer HTML, or nil for the default.
    ///   - dependencyArchives: Documentation archives to resolve external links against.
    public init(
        packageDirectory: URL,
        outputDirectory: URL,
        targets: [String] = [],
        dependencyPolicy: DependencyInclusionPolicy = .all,
        externalDocumentationURLs: [String: URL] = [:],
        includeSearch: Bool = false,
        theme: ThemeConfiguration = .default,
        isVerbose: Bool = false,
        scratchPath: URL? = nil,
        symbolGraphDir: URL? = nil,
        footerHTML: String? = nil,
        dependencyArchives: [URL] = []
    ) {
        self.packageDirectory = packageDirectory
        self.outputDirectory = outputDirectory
        self.targets = targets
        self.dependencyPolicy = dependencyPolicy
        self.externalDocumentationURLs = externalDocumentationURLs
        self.includeSearch = includeSearch
        self.theme = theme
        self.isVerbose = isVerbose
        self.scratchPath = scratchPath
        self.symbolGraphDir = symbolGraphDir
        self.footerHTML = footerHTML
        self.dependencyArchives = dependencyArchives
    }
}

/// Policy for including dependency documentation in the generated output.
public enum DependencyInclusionPolicy: Sendable, Equatable, Hashable {
    /// Include documentation for all dependencies.
    case all

    /// Exclude specific packages by name.
    case exclude([String])

    /// Include only the specified packages.
    case includeOnly([String])

    /// Exclude all dependencies; only document the root package.
    case none
}

/// Configuration for the documentation theme.
///
/// A theme consists of three parts, all optional:
///
/// 1. **Settings** in the swift-docc-render `theme-settings.json` format, which
///    define custom properties (colours, fonts, spacing) and feature switches;
/// 2. **Stylesheets** that are layered after the base stylesheet and can change
///    any rule;
/// 3. **Custom CSS** supplied by the user, layered last.
///
/// Built-in themes are compiled into the binary; custom themes are read from a
/// `theme-settings.json` file or from a theme directory containing that file
/// and optional stylesheets.
///
/// ## Using Theme Settings
///
/// ```swift
/// // Use a built-in theme
/// let classic = ThemeConfiguration(builtInTheme: .classic)
///
/// // Resolve a theme name, settings file or theme directory
/// let custom = try ThemeConfiguration.resolveTheme("MyTheme")
/// ```
public struct ThemeConfiguration: Sendable, Equatable {
    /// The accent colour used for links and highlights.
    ///
    /// This is only used when the theme settings do not define the `link` colour.
    public var accentColour: String

    /// Whether to include dark mode styles.
    public var includeDarkMode: Bool

    /// Custom CSS to append to the generated stylesheet, after the theme's own stylesheets.
    public var customCSS: String?

    /// Theme settings loaded from a theme-settings.json file.
    ///
    /// When set, these settings override the default CSS variable values.
    /// The settings are compatible with swift-docc-render themes.
    public var themeSettings: ThemeSettings.Root?

    /// The theme's own stylesheets, layered after the base stylesheet in this order.
    public var stylesheets: [ThemeStylesheet]

    /// The accent colour used when neither the configuration nor the settings provide one.
    public static let defaultAccentColour = "#0066cc"

    /// The default theme configuration matching swift-docc-render's appearance.
    public static let `default` = ThemeConfiguration(
        builtInTheme: .default,
        includeDarkMode: true,
        customCSS: nil
    )

    /// Creates a new theme configuration.
    ///
    /// - Parameters:
    ///   - accentColour: The accent colour for links and highlights (CSS colour value).
    ///   - includeDarkMode: Whether to generate dark mode styles.
    ///   - customCSS: Optional custom CSS to append.
    ///   - themeSettings: Optional theme settings from a theme-settings.json file.
    ///   - stylesheets: The theme's own stylesheets in application order.
    public init(
        accentColour: String,
        includeDarkMode: Bool,
        customCSS: String? = nil,
        themeSettings: ThemeSettings.Root? = nil,
        stylesheets: [ThemeStylesheet] = []
    ) {
        self.accentColour = accentColour
        self.includeDarkMode = includeDarkMode
        self.customCSS = customCSS
        self.themeSettings = themeSettings
        self.stylesheets = stylesheets
    }

    /// Creates a theme configuration from a built-in theme.
    ///
    /// - Parameters:
    ///   - builtInTheme: The built-in theme to use.
    ///   - includeDarkMode: Whether to include dark mode styles.
    ///   - customCSS: Optional custom CSS to append.
    public init(
        builtInTheme: ThemeSettings.BuiltInTheme,
        includeDarkMode: Bool = true,
        customCSS: String? = nil
    ) {
        self.init(
            themeSettings: builtInTheme.settings,
            stylesheets: builtInTheme.stylesheets,
            includeDarkMode: includeDarkMode,
            customCSS: customCSS
        )
    }

    /// Creates a theme configuration from theme settings.
    ///
    /// - Parameters:
    ///   - themeSettings: The theme settings to use.
    ///   - stylesheets: The theme's own stylesheets in application order.
    ///   - includeDarkMode: Whether to include dark mode styles.
    ///   - customCSS: Optional custom CSS to append.
    public init(
        themeSettings: ThemeSettings.Root,
        stylesheets: [ThemeStylesheet] = [],
        includeDarkMode: Bool = true,
        customCSS: String? = nil
    ) {
        self.accentColour = themeSettings.theme.color?["link"]?.light ?? Self.defaultAccentColour
        self.includeDarkMode = includeDarkMode
        self.customCSS = customCSS
        self.themeSettings = themeSettings
        self.stylesheets = stylesheets
    }

    /// Returns whether a feature switch is on for this theme.
    ///
    /// - Parameter flag: The feature switch to query.
    /// - Returns: The value set by the theme settings, or the switch's default value.
    public func isEnabled(_ flag: ThemeSettings.FeatureFlag) -> Bool {
        themeSettings?.isEnabled(flag) ?? flag.defaultValue
    }

    /// Resolves a theme string to a theme configuration.
    ///
    /// The string is resolved as follows:
    /// 1. If `themeString` is `nil`, the default theme is used.
    /// 2. If the string is the path of an existing directory, it is read as a
    ///    theme directory: a `theme-settings.json` file plus optional
    ///    stylesheets (`*.css`, applied in file name order; files ending in
    ///    `.dark.css` only when dark mode styles are enabled).
    /// 3. If the string is the path of an existing file, it is read as a
    ///    `theme-settings.json` file.
    /// 4. If the string is the exact name of a built-in theme, or one of its
    ///    aliases (the name without the `docc-static-` prefix, such as
    ///    `classic`), that theme is used.
    /// 5. Otherwise, an error is thrown.
    ///
    /// Custom theme files are validated like the built-in themes: unknown keys
    /// and feature switches are reported to `warningHandler`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let defaultTheme = try ThemeConfiguration.resolveTheme(nil)
    /// let classic = try ThemeConfiguration.resolveTheme("classic")
    /// let custom = try ThemeConfiguration.resolveTheme("MyTheme/theme-settings.json")
    /// let bundle = try ThemeConfiguration.resolveTheme("MyTheme")
    /// ```
    ///
    /// - Parameters:
    ///   - themeString: The theme to resolve (theme name, settings file or theme directory).
    ///   - includeDarkMode: Whether to include dark mode styles.
    ///   - customCSS: Optional custom CSS to append after the theme's stylesheets.
    ///   - warningHandler: Receives warnings about custom theme files.
    /// - Returns: A theme configuration for the resolved theme.
    /// - Throws: `ThemeResolutionError` if the theme cannot be resolved.
    public static func resolveTheme(
        _ themeString: String?,
        includeDarkMode: Bool = true,
        customCSS: String? = nil,
        warningHandler: (any ThemeParsingWarningHandler)? = StderrWarningHandler()
    ) throws -> ThemeConfiguration {
        guard let themeString = themeString else {
            return ThemeConfiguration(builtInTheme: .default, includeDarkMode: includeDarkMode, customCSS: customCSS)
        }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: themeString, isDirectory: &isDirectory) {
            let url = URL(fileURLWithPath: themeString).standardizedFileURL
            do {
                if isDirectory.boolValue {
                    guard ThemeBundleSource.isBundle(url) else {
                        throw CocoaError(.fileReadNoSuchFile, userInfo: [
                            NSLocalizedDescriptionKey:
                                "The directory does not contain \(ThemeBundleLayout.settingsFileName)"
                        ])
                    }
                    let bundle = try ThemeBundleSource.load(from: url, warningHandler: warningHandler)
                    return ThemeConfiguration(
                        themeSettings: bundle.settings,
                        stylesheets: bundle.stylesheets,
                        includeDarkMode: includeDarkMode,
                        customCSS: customCSS
                    )
                }
                let settings = try ThemeSettingsParser.parse(contentsOf: url, warningHandler: warningHandler)
                return ThemeConfiguration(
                    themeSettings: settings,
                    includeDarkMode: includeDarkMode,
                    customCSS: customCSS
                )
            } catch {
                throw ThemeResolutionError.invalidThemeFile(themeString, error.localizedDescription)
            }
        }

        if let builtIn = ThemeSettings.BuiltInTheme.named(themeString) {
            return ThemeConfiguration(builtInTheme: builtIn, includeDarkMode: includeDarkMode, customCSS: customCSS)
        }

        throw ThemeResolutionError.themeNotFound(themeString, availableThemeNames)
    }

    /// Reads a custom CSS file to be appended after the theme's stylesheets.
    ///
    /// - Parameter path: The path of the CSS file.
    /// - Returns: The contents of the file.
    /// - Throws: `ThemeResolutionError.invalidThemeFile` if the file cannot be read.
    public static func loadCustomCSS(from path: String) throws -> String {
        do {
            return try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        } catch {
            throw ThemeResolutionError.invalidThemeFile(path, error.localizedDescription)
        }
    }

    /// The names of the built-in themes, with their aliases, for error messages.
    static var availableThemeNames: String {
        ThemeSettings.BuiltInTheme.allCases.map { theme in
            theme.aliases.isEmpty
                ? theme.rawValue
                : "\(theme.rawValue) (\(theme.aliases.joined(separator: ", ")))"
        }.joined(separator: ", ")
    }
}

// MARK: - Theme Resolution Errors

/// Errors that can occur during theme resolution.
public enum ThemeResolutionError: Error, CustomStringConvertible {
    /// The specified theme was not found.
    ///
    /// The associated values are the requested name and the list of available themes.
    case themeNotFound(String, String)

    /// The theme file or directory exists but could not be read.
    ///
    /// The associated values are the path and the reason.
    case invalidThemeFile(String, String)

    /// A description suitable for showing to the user.
    public var description: String {
        switch self {
        case .themeNotFound(let name, let available):
            return "Theme '\(name)' not found. Available themes: \(available)"
        case .invalidThemeFile(let path, let reason):
            return "Failed to read theme '\(path)': \(reason)"
        }
    }
}
