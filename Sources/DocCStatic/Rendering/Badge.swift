//
// Badge.swift
// DocCStatic
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import SwiftDocC

/// The badges and tags swift-docc-render shows for deprecated and beta symbols.
///
/// A badge (swift-docc-render's `Badge`) is a small label after a navigator row, a
/// topic in a topic list, or the current page in the breadcrumbs.  The title of a
/// deprecated or beta symbol is followed by a coloured tag instead.  Both carry the
/// variant in their class, so that themes can restyle them.
public enum Badge {
    /// The class of every badge.
    public static let className = "badge"

    /// The kinds of symbol status that swift-docc-render marks.
    public enum Variant: String, CaseIterable, Sendable {
        /// The symbol is deprecated.
        case deprecated
        /// The symbol is introduced in a beta release.
        case beta

        /// The label swift-docc-render shows for the variant.
        public var label: String {
            switch self {
            case .deprecated: "Deprecated"
            case .beta: "Beta"
            }
        }
    }

    /// Returns the markup of a badge.
    ///
    /// - Parameters:
    ///   - variant: The variant, such as `deprecated`, or the type of a tag.
    ///   - text: The label of the badge.
    /// - Returns: A `span.badge` element with the class `badge-<variant>`.
    public static func markup(variant: String, text: String) -> String {
        "<span class=\"\(className) \(className)-\(escapeHTML(variant))\" role=\"presentation\">\(escapeHTML(text))</span>"
    }

    /// Returns the markup of the badge of a symbol status.
    ///
    /// - Parameter variant: The status.
    /// - Returns: A `span.badge` element labelled like swift-docc-render.
    public static func markup(_ variant: Variant) -> String {
        markup(variant: variant.rawValue, text: variant.label)
    }

    /// Returns the tag that follows the title of a deprecated or beta symbol.
    ///
    /// Like swift-docc-render's `Title`, the tag is an empty `small` element whose
    /// class and `data-tag-name` attribute hold the label, which the stylesheet shows.
    ///
    /// - Parameter variant: The status.
    /// - Returns: The `small` element.
    public static func titleTag(_ variant: Variant) -> String {
        "<small class=\"\(variant.label)\" data-tag-name=\"\(variant.label)\"></small>"
    }

    /// Returns the statuses of the page of a render node.
    ///
    /// Like swift-docc-render, a page is deprecated if it has a deprecation summary or
    /// if it is deprecated on every platform it lists, and beta if it is beta on every
    /// platform it lists.
    ///
    /// - Parameter renderNode: The render node of the page.
    /// - Returns: The statuses, empty for a page that is neither deprecated nor beta.
    public static func statuses(of renderNode: RenderNode) -> Set<Variant> {
        let platforms = renderNode.metadata.platforms ?? []
        var statuses = Set<Variant>()
        if !(renderNode.deprecationSummary ?? []).isEmpty
            || (!platforms.isEmpty && platforms.allSatisfy { $0.deprecated != nil }) {
            statuses.insert(.deprecated)
        }
        if !platforms.isEmpty && platforms.allSatisfy(\.beta) {
            statuses.insert(.beta)
        }
        return statuses
    }

    /// Returns the status the title and the breadcrumbs of a page show.
    ///
    /// - Parameter renderNode: The render node of the page.
    /// - Returns: `deprecated` for a deprecated page, otherwise `beta` for a beta page,
    ///   or `nil` for a page that is neither.
    public static func status(of renderNode: RenderNode) -> Variant? {
        let statuses = statuses(of: renderNode)
        return statuses.contains(.deprecated) ? .deprecated : statuses.first
    }

    /// Returns the badge of a topic in a topic list (swift-docc-render's `TopicsLinkBlock`).
    ///
    /// A deprecated topic shows a badge unless the listing page is deprecated itself;
    /// otherwise a beta topic shows one unless the listing page is beta.
    ///
    /// - Parameters:
    ///   - reference: The topic reference.
    ///   - pageStatuses: The statuses of the page that lists the topic.
    /// - Returns: The badge markup, or an empty string.
    public static func topicMarkup(for reference: TopicRenderReference, pageStatuses: Set<Variant>) -> String {
        if reference.isDeprecated && !pageStatuses.contains(.deprecated) {
            return markup(.deprecated)
        }
        if reference.isBeta && !pageStatuses.contains(.beta) {
            return markup(.beta)
        }
        return ""
    }
}
