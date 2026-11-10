//
// SidebarDocument.swift
// DocCStatic
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// The shared navigation sidebar document and the names that connect it to the pages embedding it.
///
/// The navigation tree of a documentation site is written once, as a standalone HTML
/// document at the root of the output directory (see ``fileName``).  Every
/// documentation page embeds that document in an `<iframe>` and selects its own row
/// through the URL fragment, so the current page is highlighted and its ancestors are
/// expanded purely with CSS (`:target`), without JavaScript.
///
/// This type is the single authoritative home of the names that the Swift code, the
/// generated stylesheet and the generated scripts must agree on, such as the file
/// name, the row identifier prefix and the `postMessage` message types.  An instance
/// describes which pages have a row of their own in a given navigation index and
/// builds the markup a page uses to embed the shared document.
public struct SidebarDocument: Sendable, Equatable {
    /// The normalised page paths that have a row identifier in the shared document.
    ///
    /// Paths are normalised with ``pagePathKey(_:)``.
    public let rowPaths: Set<String>

    /// Creates a description of the shared sidebar document for a navigation index.
    ///
    /// - Parameter navigationIndex: The navigation index the shared document is built from.
    public init(navigationIndex: NavigationIndex) {
        self.rowPaths = NavigationSidebarBuilder.rowPaths(in: navigationIndex)
    }
}

// MARK: - Names

public extension SidebarDocument {
    /// The file name of the shared sidebar document, relative to the output root.
    ///
    /// Generated pages live below `documentation/` and `tutorials/`, and assets below
    /// `css/`, `js/`, `images/`, `downloads/` and `videos/`, so a file at the root
    /// with this name cannot collide with generated content.
    static let fileName = "sidebar.html"

    /// The prefix of the `id` attribute of every row in the shared document.
    static let rowIdentifierPrefix = "nav:"

    /// The class of the `<body>` element of the shared document.
    static let documentClass = "sidebar-document"

    /// The class of the `<iframe>` that embeds the shared document in a page.
    static let frameClass = "sidebar-frame"

    /// The accessible title of the embedded sidebar and of the shared document.
    static let frameTitle = "Documentation navigation"

    /// The message type a page posts to the sidebar to focus its filter field.
    static let focusFilterMessage = "docc-static:focus-filter"

    /// The message type a page posts to the sidebar to apply a colour scheme.
    ///
    /// The message carries the scheme name (`light`, `dark` or `auto`) in its
    /// `scheme` property.
    static let colourSchemeMessage = "docc-static:color-scheme"

    /// The message type the sidebar posts to its embedding page once it is ready.
    static let readyMessage = "docc-static:sidebar-ready"

    /// The `localStorage` key that stores the colour scheme chosen by the reader.
    static let colourSchemeStorageKey = "docc-color-scheme"

    /// The stylesheet rules that size the embedded frame and lay out the shared document.
    ///
    /// These rules are part of every theme's stylesheet.  They are kept here, next
    /// to the class names they use, so that the names are defined in one place.
    static var stylesheet: String {
        """
        /* Embedded navigation document fills the sidebar container */
        .\(frameClass) {
            flex: 1;
            display: block;
            width: 100%;
            height: 100%;
            border: 0;
            background: var(--color-fill);
        }

        /* Standalone navigation document shown inside the embedded frame */
        body.\(documentClass) {
            margin: 0;
            overflow: hidden;
            background: var(--color-fill);
        }

        body.\(documentClass) .sidebar {
            position: fixed;
            top: 0;
            right: 0;
            bottom: 0;
            left: 0;
            width: auto;
            border-right: none;
            transform: none;
            transition: none;
        }

        """
    }

    /// Returns whether a shared sidebar document is generated for a navigation index.
    ///
    /// A shared document is only generated when the index contains at least one module.
    ///
    /// - Parameter navigationIndex: The navigation index, if any.
    /// - Returns: `true` if the shared document exists for this index.
    static func isAvailable(for navigationIndex: NavigationIndex?) -> Bool {
        guard let navigationIndex else { return false }
        return !navigationIndex.allModules().isEmpty
    }

    /// Normalises a documentation path in the same way generated page paths are derived.
    ///
    /// Leading, trailing and repeated slashes are removed and every component is
    /// lowercased, so `/documentation/Module/Type/` becomes `documentation/module/type`.
    ///
    /// - Parameter path: A documentation path, such as a render node identifier path.
    /// - Returns: The normalised path.
    static func pagePathKey(_ path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: true)
            .map { $0.lowercased() }
            .joined(separator: "/")
    }

    /// Returns the `id` of the row representing a documentation path.
    ///
    /// The identifier is ``rowIdentifierPrefix`` followed by the normalised path (see
    /// ``pagePathKey(_:)``).  Characters that are not safe to use verbatim in a URL
    /// fragment are percent-encoded, so the identifier can be appended to a URL as a
    /// fragment exactly as it appears in the `id` attribute.
    ///
    /// - Parameter path: The documentation path of the row.
    /// - Returns: The row identifier.
    static func rowIdentifier(forPath path: String) -> String {
        var identifier = rowIdentifierPrefix
        for byte in pagePathKey(path).utf8 {
            if fragmentSafeBytes.contains(byte) {
                identifier.unicodeScalars.append(Unicode.Scalar(byte))
            } else {
                identifier += "%" + hexDigits(of: byte)
            }
        }
        return identifier
    }
}

// MARK: - Embedding

public extension SidebarDocument {
    /// Returns the row identifier a page should select in the shared document.
    ///
    /// Pages select their own row.  A page that is not listed in the navigation tree
    /// selects its nearest listed ancestor instead, so that the relevant part of the
    /// tree is still expanded.
    ///
    /// - Parameter path: The documentation path of the page.
    /// - Returns: The row identifier, or `nil` if neither the page nor any of its
    ///   ancestors is listed.
    func targetIdentifier(forPagePath path: String) -> String? {
        var components = Self.pagePathKey(path).split(separator: "/")
        while !components.isEmpty {
            let candidate = components.joined(separator: "/")
            if rowPaths.contains(candidate) {
                return Self.rowIdentifier(forPath: candidate)
            }
            components.removeLast()
        }
        return nil
    }

    /// Builds the sidebar container that embeds the shared document in a page.
    ///
    /// - Parameters:
    ///   - path: The documentation path of the page.
    ///   - depth: The number of directories between the output root and the page.
    /// - Returns: The HTML for the sidebar container.
    func embeddingMarkup(forPagePath path: String, depth: Int) -> String {
        var source = String(repeating: "../", count: depth) + Self.fileName
        if let identifier = targetIdentifier(forPagePath: path) {
            source += "#" + identifier
        }
        return """

                <nav class="sidebar" aria-label="\(escapeHTML(Self.frameTitle))">
                    <iframe class="\(Self.frameClass)" title="\(escapeHTML(Self.frameTitle))" src="\(escapeHTML(source))"></iframe>
                </nav>
        """
    }
}

// MARK: - Private

private extension SidebarDocument {
    /// The bytes that may appear unencoded in a row identifier.
    static let fragmentSafeBytes: Set<UInt8> = Set(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~/()!*+,;=:@$".utf8
    )

    /// Returns the two upper-case hexadecimal digits of a byte.
    static func hexDigits(of byte: UInt8) -> String {
        let digits = Array("0123456789ABCDEF")
        return String([digits[Int(byte >> 4)], digits[Int(byte & 0x0F)]])
    }
}
