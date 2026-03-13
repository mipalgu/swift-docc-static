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
/// Themes can be configured in two ways:
/// 1. Using the built-in accent colour and dark mode settings
/// 2. Using a theme-settings.json file compatible with swift-docc-render
///
/// ## Using Theme Settings
///
/// ```swift
/// // Load a theme from a file
/// let settings = try ThemeSettingsParser.parse(contentsOf: themeURL)
/// let theme = ThemeConfiguration(themeSettings: settings)
///
/// // Use a built-in theme
/// let theme = ThemeConfiguration(builtInTheme: .classic)
/// ```
public struct ThemeConfiguration: Sendable, Equatable {
    /// The accent colour used for links and highlights.
    ///
    /// This is only used when `themeSettings` is `nil`.
    public var accentColour: String

    /// Whether to include dark mode styles.
    public var includeDarkMode: Bool

    /// Custom CSS to append to the generated stylesheet.
    public var customCSS: String?

    /// Theme settings loaded from a theme-settings.json file.
    ///
    /// When set, these settings override the default CSS variable values.
    /// The settings are compatible with swift-docc-render themes.
    public var themeSettings: ThemeSettings.Root?

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
    public init(
        accentColour: String,
        includeDarkMode: Bool,
        customCSS: String? = nil,
        themeSettings: ThemeSettings.Root? = nil
    ) {
        self.accentColour = accentColour
        self.includeDarkMode = includeDarkMode
        self.customCSS = customCSS
        self.themeSettings = themeSettings
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
        let settings = builtInTheme.settings
        self.accentColour = settings.theme.color?["link"]?.light ?? "#0066cc"
        self.includeDarkMode = includeDarkMode
        self.customCSS = customCSS
        self.themeSettings = settings
    }

    /// Creates a theme configuration from theme settings.
    ///
    /// - Parameters:
    ///   - themeSettings: The theme settings to use.
    ///   - includeDarkMode: Whether to include dark mode styles.
    ///   - customCSS: Optional custom CSS to append.
    public init(
        themeSettings: ThemeSettings.Root,
        includeDarkMode: Bool = true,
        customCSS: String? = nil
    ) {
        self.accentColour = themeSettings.theme.color?["link"]?.light ?? "#0066cc"
        self.includeDarkMode = includeDarkMode
        self.customCSS = customCSS
        self.themeSettings = themeSettings
    }

    /// Resolves a theme string to a theme configuration.
    ///
    /// This method provides smart theme resolution with the following logic:
    /// 1. If `themeString` is `nil`, returns the default theme
    /// 2. If the string is a path to an existing file, loads it as a custom theme
    /// 3. If the string matches a built-in theme name exactly, uses that theme
    /// 4. If the string fuzzy-matches a built-in theme name, uses that theme
    /// 5. Otherwise, throws an error
    ///
    /// Fuzzy matching allows shortcuts like "classic" to match "docc-static-classic".
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Default theme
    /// let theme1 = try ThemeConfiguration.resolveTheme(nil)
    ///
    /// // Custom theme file
    /// let theme2 = try ThemeConfiguration.resolveTheme("/path/to/custom.json")
    ///
    /// // Exact match
    /// let theme3 = try ThemeConfiguration.resolveTheme("default")
    ///
    /// // Fuzzy match
    /// let theme4 = try ThemeConfiguration.resolveTheme("classic") // matches "docc-static-classic"
    /// ```
    ///
    /// - Parameters:
    ///   - themeString: The theme string to resolve (file path or theme name).
    ///   - includeDarkMode: Whether to include dark mode styles.
    ///   - customCSS: Optional custom CSS to append.
    /// - Returns: A theme configuration for the resolved theme.
    /// - Throws: `ThemeResolutionError` if the theme cannot be resolved.
    public static func resolveTheme(
        _ themeString: String?,
        includeDarkMode: Bool = true,
        customCSS: String? = nil
    ) throws -> ThemeConfiguration {
        // 1. No theme specified - use default
        guard let themeString = themeString else {
            return ThemeConfiguration(
                builtInTheme: .default,
                includeDarkMode: includeDarkMode,
                customCSS: customCSS
            )
        }

        // 2. Check if it's a file path that exists
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: themeString) {
            let url = URL(fileURLWithPath: themeString).standardizedFileURL
            do {
                let settings = try ThemeSettingsParser.parse(contentsOf: url)
                return ThemeConfiguration(
                    themeSettings: settings,
                    includeDarkMode: includeDarkMode,
                    customCSS: customCSS
                )
            } catch {
                throw ThemeResolutionError.invalidThemeFile(themeString, error.localizedDescription)
            }
        }

        // 3. Try exact match with built-in themes
        if let builtIn = ThemeSettings.BuiltInTheme(rawValue: themeString) {
            return ThemeConfiguration(
                builtInTheme: builtIn,
                includeDarkMode: includeDarkMode,
                customCSS: customCSS
            )
        }

        // 4. Try fuzzy/containment match
        let allThemes = ThemeSettings.BuiltInTheme.allCases
        if let fuzzyMatch = allThemes.first(where: {
            $0.rawValue.contains(themeString) || themeString.contains($0.rawValue)
        }) {
            return ThemeConfiguration(
                builtInTheme: fuzzyMatch,
                includeDarkMode: includeDarkMode,
                customCSS: customCSS
            )
        }

        // 5. Not found - throw error
        let available = allThemes.map(\.rawValue).joined(separator: ", ")
        throw ThemeResolutionError.themeNotFound(themeString, available)
    }
}

// MARK: - Theme Resolution Errors

/// Errors that can occur during theme resolution.
public enum ThemeResolutionError: Error, CustomStringConvertible {
    /// The specified theme was not found.
    case themeNotFound(String, String)

    /// The theme file exists but could not be parsed.
    case invalidThemeFile(String, String)

    public var description: String {
        switch self {
        case .themeNotFound(let name, let available):
            return "Theme '\(name)' not found. Available themes: \(available)"
        case .invalidThemeFile(let path, let reason):
            return "Failed to parse theme file '\(path)': \(reason)"
        }
    }
}
