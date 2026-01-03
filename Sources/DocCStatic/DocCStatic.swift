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
/// - **Customisable themes**: Match Apple's DocC style or create your own
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

    /// Custom HTML for the footer.
    ///
    /// This HTML is displayed at the bottom of each page when the user scrolls
    /// all the way down. Set to `nil` to use the default footer.
    public var footerHTML: String?

    /// The default footer HTML.
    public static let defaultFooter = """
        Generated with <a href="https://github.com/mipalgu/swift-docc-static">swift-docc-static</a> \
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
    ///   - footerHTML: Custom footer HTML, or nil for the default.
    public init(
        packageDirectory: URL,
        outputDirectory: URL,
        targets: [String] = [],
        dependencyPolicy: DependencyInclusionPolicy = .all,
        externalDocumentationURLs: [String: URL] = [:],
        includeSearch: Bool = false,
        theme: ThemeConfiguration = .default,
        isVerbose: Bool = false,
        footerHTML: String? = nil
    ) {
        self.packageDirectory = packageDirectory
        self.outputDirectory = outputDirectory
        self.targets = targets
        self.dependencyPolicy = dependencyPolicy
        self.externalDocumentationURLs = externalDocumentationURLs
        self.includeSearch = includeSearch
        self.theme = theme
        self.isVerbose = isVerbose
        self.footerHTML = footerHTML
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
public struct ThemeConfiguration: Sendable, Equatable, Hashable {
    /// The accent colour used for links and highlights.
    public var accentColour: String

    /// Whether to include dark mode styles.
    public var includeDarkMode: Bool

    /// Custom CSS to append to the generated stylesheet.
    public var customCSS: String?

    /// The default theme configuration matching Apple's DocC appearance.
    public static let `default` = ThemeConfiguration(
        accentColour: "#0066cc",
        includeDarkMode: true,
        customCSS: nil
    )

    /// Creates a new theme configuration.
    ///
    /// - Parameters:
    ///   - accentColour: The accent colour for links and highlights (CSS colour value).
    ///   - includeDarkMode: Whether to generate dark mode styles.
    ///   - customCSS: Optional custom CSS to append.
    public init(
        accentColour: String,
        includeDarkMode: Bool,
        customCSS: String? = nil
    ) {
        self.accentColour = accentColour
        self.includeDarkMode = includeDarkMode
        self.customCSS = customCSS
    }
}
