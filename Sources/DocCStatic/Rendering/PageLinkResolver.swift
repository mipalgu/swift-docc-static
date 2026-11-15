//
// PageLinkResolver.swift
// DocCStatic
//
//  Created by Rene Hexel on 15/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// Decides where links to documentation pages point.
///
/// A link to a page of the generated site is a relative link to the page's
/// `index.html` file.  A link to a page that the site does not contain, such as a
/// symbol of a dependency that is not documented, points to the page in the
/// module's hosted documentation if ``ExternalDocumentation`` knows it; otherwise
/// there is no destination and the reference is shown as unlinked text, like
/// swift-docc-render shows references it cannot resolve.
public struct PageLinkResolver: Sendable {
    /// The normalised paths (see ``SidebarDocument/pagePathKey(_:)``) of the pages
    /// of the generated site, or `nil` if every documentation page is assumed to be
    /// generated.
    public let generatedPagePaths: Set<String>?

    /// The hosted documentation of modules outside the generated site.
    public let externalDocumentation: ExternalDocumentation

    /// The name of the file that holds each generated page in its directory.
    public static let pageFileName = "index.html"

    /// The separator between the path and the fragment of a URL.
    static let fragmentSeparator: Character = "#"

    /// A resolver that assumes every documentation page is generated.
    public static let unrestricted = PageLinkResolver()

    /// Creates a link resolver.
    ///
    /// - Parameters:
    ///   - generatedPagePaths: The normalised paths of the generated pages, or `nil`
    ///     to assume that every documentation page is generated.
    ///   - externalDocumentation: The hosted documentation of other modules.
    public init(
        generatedPagePaths: Set<String>? = nil,
        externalDocumentation: ExternalDocumentation = ExternalDocumentation()
    ) {
        self.generatedPagePaths = generatedPagePaths
        self.externalDocumentation = externalDocumentation
    }

    /// Returns whether a page is part of the generated site.
    ///
    /// - Parameter url: The DocC URL of the page, such as
    ///   `/documentation/module/symbol`, optionally followed by a fragment.
    /// - Returns: `true` if the page is generated.
    public func isGenerated(_ url: String) -> Bool {
        guard let generatedPagePaths else { return true }
        return generatedPagePaths.contains(SidebarDocument.pagePathKey(Self.splitFragment(url).path))
    }

    /// Returns the destination of a link to a page.
    ///
    /// - Parameters:
    ///   - url: The DocC URL of the page, such as `/documentation/module/symbol` or
    ///     `/documentation/module/article#heading`; URLs with a scheme and fragments
    ///     of the current page are returned unchanged.
    ///   - depth: The number of directories between the output root and the page
    ///     that contains the link.
    /// - Returns: A relative link to a generated page, an absolute link to a page of
    ///   external documentation, or `nil` if the page is neither.
    public func destination(forPage url: String, depth: Int) -> String? {
        if Self.isAbsoluteOrLocal(url) { return url }
        let (path, fragment) = Self.splitFragment(url)
        let suffix = fragment.map { String(Self.fragmentSeparator) + $0 } ?? ""
        if isGenerated(path) {
            return Self.relativePageURL(path, depth: depth) + suffix
        }
        return externalDocumentation.url(forPagePath: path).map { $0 + suffix }
    }

    /// Returns a relative link to a generated page.
    ///
    /// - Parameters:
    ///   - path: The DocC path of the page, optionally followed by a fragment.
    ///   - depth: The number of directories between the output root and the page
    ///     that contains the link.
    /// - Returns: The link to the page's file, followed by the fragment if any.
    public static func relativePageURL(_ path: String, depth: Int) -> String {
        let (pagePath, fragment) = splitFragment(path)
        let prefix = String(repeating: "../", count: depth)
        let key = SidebarDocument.pagePathKey(pagePath)
        let file = key.isEmpty ? pageFileName : key + "/" + pageFileName
        return prefix + file + (fragment.map { String(fragmentSeparator) + $0 } ?? "")
    }

    /// Returns whether a URL has a scheme or only refers to a fragment of the
    /// current page, so that it needs no resolution.
    ///
    /// - Parameter url: The URL to check.
    /// - Returns: `true` for URLs such as `https://example.com`, `mailto:` addresses
    ///   and `#fragment`.
    public static func isAbsoluteOrLocal(_ url: String) -> Bool {
        url.hasPrefix(String(fragmentSeparator)) || url.contains("://") || url.hasPrefix("mailto:")
    }

    /// Splits a URL into its path and its fragment.
    ///
    /// - Parameter url: The URL to split.
    /// - Returns: The part before the first `#`, and the part after it, if any.
    static func splitFragment(_ url: String) -> (path: String, fragment: String?) {
        guard let index = url.firstIndex(of: fragmentSeparator) else { return (url, nil) }
        return (String(url[..<index]), String(url[url.index(after: index)...]))
    }
}

// MARK: - Symbol Names

public extension PageLinkResolver {
    /// Returns the path of a symbol below the documentation root, from its reference.
    ///
    /// DocC writes a symbol link it cannot resolve as code showing the link's text,
    /// such as `Module/Symbol`; this is the equivalent text for a resolved symbol
    /// whose page is not available.
    ///
    /// - Parameter identifier: The reference identifier, such as
    ///   `doc://Bundle/documentation/Module/Type/member`.
    /// - Returns: The components after the documentation root, such as
    ///   `["Module", "Type", "member"]`, or `nil` if the identifier has no such path.
    static func symbolPathComponents(ofIdentifier identifier: String) -> [String]? {
        guard let url = URL(string: identifier) else { return nil }
        let components = url.path.split(separator: "/").map(String.init)
        guard components.count >= 2,
              components[0].lowercased() == ExternalDocumentation.documentationRoot
        else { return nil }
        return Array(components.dropFirst())
    }

    /// Returns the qualified name of a symbol, such as `Module.Type`, from its reference.
    ///
    /// This is how DocC names a related type it cannot resolve; disambiguation
    /// suffixes of the path, such as `-swift.struct`, are left out.
    ///
    /// - Parameter identifier: The reference identifier of the symbol.
    /// - Returns: The module and symbol names joined by periods, or `nil` if the
    ///   identifier has no documentation path.
    static func qualifiedSymbolName(ofIdentifier identifier: String) -> String? {
        symbolPathComponents(ofIdentifier: identifier)?.map { component in
            guard !component.hasPrefix("-"), let dash = component.firstIndex(of: "-") else { return component }
            return String(component[..<dash])
        }.joined(separator: ".")
    }
}
