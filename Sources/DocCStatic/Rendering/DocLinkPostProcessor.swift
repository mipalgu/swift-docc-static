//
// DocLinkPostProcessor.swift
// DocCStatic
//
//  Created by Rene Hexel on 15/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import RegexBuilder

/// Regex to match `doc://` URLs in plain text.
/// Matches: doc://bundleID/path/to/symbol
nonisolated(unsafe) private let docLinkRegex = Regex {
    "doc://"
    Capture {
        OneOrMore(.anyOf("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"))
    }
    Capture {
        "/"
        OneOrMore {
            CharacterClass(
                .anyOf("/()-_"),
                ("a"..."z"),
                ("A"..."Z"),
                ("0"..."9")
            )
        }
    }
}

/// Post-processes generated HTML to resolve `doc://` URLs into proper links.
///
/// This processor scans HTML content for unresolved `doc://` URLs and replaces them
/// with proper `<a href="...">` links based on:
/// - Cross-target links within the same package (relative links)
/// - Included dependencies (relative links)
/// - External documentation URL mappings (absolute links)
public struct DocLinkPostProcessor: Sendable {
    /// Known modules being documented (for cross-target resolution).
    /// Maps module name to its bundle identifier.
    public let documentedModules: [String: String]

    /// External documentation URL mappings (bundle ID -> base URL).
    public let externalURLs: [String: URL]

    /// Creates a new post-processor.
    ///
    /// - Parameters:
    ///   - documentedModules: Map of module names to bundle identifiers being documented.
    ///   - externalURLs: Map of bundle identifiers to external documentation base URLs.
    public init(documentedModules: [String: String], externalURLs: [String: URL]) {
        self.documentedModules = documentedModules
        self.externalURLs = externalURLs
    }

    /// Processes HTML content, replacing `doc://` URLs with proper links.
    ///
    /// - Parameters:
    ///   - html: The HTML content to process.
    ///   - currentDepth: The depth of the current page for calculating relative URLs.
    /// - Returns: The processed HTML content with resolved links.
    public func process(_ html: String, currentDepth: Int) -> String {
        var result = html

        // Find all matches and collect them with their ranges
        var replacements: [(Range<String.Index>, String)] = []

        for match in result.matches(of: docLinkRegex) {
            let fullRange = match.range
            let bundleID = String(match.1)
            let path = String(match.2)

            // Skip if inside a code block
            if isInsideCodeBlock(result, at: fullRange) {
                continue
            }

            // Try to resolve the link
            if let resolvedURL = resolveDocLink(bundleID: bundleID, path: path, currentDepth: currentDepth) {
                let displayName = extractDisplayName(from: path)
                let link = "<a href=\"\(escapeHTML(resolvedURL))\">\(escapeHTML(displayName))</a>"
                replacements.append((fullRange, link))
            }
        }

        // Apply replacements in reverse order to preserve indices
        for (range, replacement) in replacements.reversed() {
            result.replaceSubrange(range, with: replacement)
        }

        return result
    }

    /// Resolves a `doc://` link to an actual URL.
    ///
    /// - Parameters:
    ///   - bundleID: The bundle identifier from the doc:// URL.
    ///   - path: The path component from the doc:// URL.
    ///   - currentDepth: The depth of the current page.
    /// - Returns: The resolved URL string, or nil if unresolvable.
    private func resolveDocLink(bundleID: String, path: String, currentDepth: Int) -> String? {
        // Check if it's a module we're documenting (cross-target)
        for (moduleName, moduleBundleID) in documentedModules {
            if bundleID == moduleBundleID || bundleID.lowercased() == moduleName.lowercased() {
                return makeRelativeLink(to: path, depth: currentDepth)
            }
        }

        // Check external URL mappings
        if let baseURL = externalURLs[bundleID] {
            // Construct the full external URL
            var url = baseURL.absoluteString
            if !url.hasSuffix("/") {
                url += "/"
            }
            // Remove leading slash from path and lowercase for URL compatibility
            let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
            let lowercasedPath = cleanPath.lowercased()
            return url + lowercasedPath
        }

        // Unresolved - return nil
        return nil
    }

    /// Creates a relative link to a path from the current depth.
    ///
    /// - Parameters:
    ///   - path: The target path.
    ///   - depth: The current page depth.
    /// - Returns: The relative URL string.
    private func makeRelativeLink(to path: String, depth: Int) -> String {
        let prefix = String(repeating: "../", count: depth)
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        // DocC generates lowercase directory names for modules
        let lowercasedPath = cleanPath.lowercased()
        return "\(prefix)\(lowercasedPath)/index.html"
    }

    /// Extracts a display name from a documentation path.
    ///
    /// - Parameter path: The path like `/documentation/SwiftDocC/RenderNode`.
    /// - Returns: The display name (e.g., "RenderNode").
    private func extractDisplayName(from path: String) -> String {
        // Get the last path component
        let components = path.split(separator: "/").map(String.init)
        return components.last ?? path
    }

    /// Checks if a range is inside a code block.
    ///
    /// - Parameters:
    ///   - html: The HTML content.
    ///   - range: The range to check.
    /// - Returns: True if the range is inside a code block.
    private func isInsideCodeBlock(_ html: String, at range: Range<String.Index>) -> Bool {
        let beforeText = String(html[html.startIndex..<range.lowerBound])

        let codeOpens = beforeText.matches(of: /<code/).count
        let codeCloses = beforeText.matches(of: /<\/code>/).count
        let preOpens = beforeText.matches(of: /<pre/).count
        let preCloses = beforeText.matches(of: /<\/pre>/).count

        // If there are more opens than closes, we're inside a code block
        return (codeOpens > codeCloses) || (preOpens > preCloses)
    }
}
