//
// OnThisPageNavigation.swift
// DocCStatic
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// The names and rules of the "On This Page" column that the page markup, the
/// stylesheet and the page script share.
///
/// Like swift-docc-render's `OnThisPageNav`, the column highlights one item: the first
/// item while the page is scrolled to the top, the last item once it is scrolled to the
/// bottom, and otherwise the last item whose section heading has passed a line
/// ``trackingLinePercentage`` percent down the window.
///
/// Without JavaScript, scroll-driven animations track this.  Each section heading is
/// the subject of a view timeline named by ``timeline(_:)``, whose scroll port starts
/// at the tracking line (see ``headingRules(anchors:)``).  Each item of the list follows
/// the timeline of its own heading (``timelineProperty``) and that of the next item's
/// heading (``nextTimelineProperty``), and is highlighted while its own heading has
/// passed the line and the next one has not.  Browsers without scroll-driven
/// animations use the page script instead, or show the first item highlighted.
public enum OnThisPageNavigation {
    /// The class of the `<nav>` element that lists the sections.
    public static let navigationClass = "OnThisPageNav"

    /// The anchor of the first item, which links to the top of the page.
    public static let topAnchor = "app-top"

    /// How far down the window, in percent of its height, a section heading must be
    /// scrolled for its item to become current.
    public static let trackingLinePercentage = 30

    /// The custom property of an item that names the view timeline of its own heading.
    public static let timelineProperty = "--on-this-page-timeline"

    /// The custom property of an item that names the view timeline of the next item's heading.
    public static let nextTimelineProperty = "--on-this-page-next-timeline"

    /// Returns the name of the view timeline of an item's section heading.
    ///
    /// - Parameter index: The zero-based position of the item in the list.
    /// - Returns: A dashed identifier unique within the page.
    public static func timeline(_ index: Int) -> String {
        "--on-this-page-\(index + 1)"
    }

    /// Returns a selector that matches the element with the given identifier.
    ///
    /// The identifier becomes a CSS string serialised like CSSOM's "serialize a
    /// string": a null character becomes U+FFFD, control characters (including line
    /// feeds, carriage returns and form feeds) become hexadecimal escapes, and quotation
    /// marks and backslashes are escaped.  A `<` also becomes a hexadecimal escape, so
    /// the selector cannot end the `<style>` element that contains it.  Any identifier
    /// is therefore matched exactly.
    ///
    /// - Parameter anchor: The identifier of the section heading.
    /// - Returns: An attribute selector.
    public static func selector(forAnchor anchor: String) -> String {
        var escaped = ""
        for scalar in anchor.unicodeScalars {
            switch scalar.value {
            case 0:
                escaped.unicodeScalars.append("\u{FFFD}")
            case 0x01...0x1F, 0x7F, 0x3C:
                escaped += "\\" + String(scalar.value, radix: 16) + " "
            case 0x22, 0x5C:
                escaped += "\\"
                escaped.unicodeScalars.append(scalar)
            default:
                escaped.unicodeScalars.append(scalar)
            }
        }
        return "[id=\"\(escaped)\"]"
    }

    /// Returns the style element that makes the section headings of a page the subjects
    /// of the items' view timelines.
    ///
    /// The first item links to the top of the page and needs no timeline.
    ///
    /// - Parameter anchors: The anchors of the items, in order.
    /// - Returns: A `<style>` element for the document head, or an empty string if the
    ///   page lists no sections besides its title.
    public static func headingRules(anchors: [String]) -> String {
        guard anchors.count > 1 else { return "" }
        let rules = anchors.enumerated().dropFirst().map { index, anchor in
            "\(selector(forAnchor: anchor)) { view-timeline-name: \(timeline(index));"
                + " view-timeline-inset: \(trackingLinePercentage)% 0%; }"
        }
        return "\n    <style>\n    " + rules.joined(separator: "\n    ") + "\n    </style>"
    }

    /// Returns the `timeline-scope` declaration that lets the items see the headings' timelines.
    ///
    /// - Parameter count: The number of items.
    /// - Returns: The declaration for an element that contains both the headings and the list.
    public static func timelineScope(count: Int) -> String {
        "timeline-scope: " + (1..<count).map { timeline($0) }.joined(separator: ", ")
    }

    /// Returns the custom properties of an item that name the timelines it follows.
    ///
    /// - Parameters:
    ///   - index: The zero-based position of the item.
    ///   - count: The number of items.
    /// - Returns: The declarations for the item's `style` attribute.
    public static func itemTimelines(index: Int, count: Int) -> String {
        var declarations: [String] = []
        if index > 0 {
            declarations.append("\(timelineProperty): \(timeline(index))")
        }
        if index + 1 < count {
            declarations.append("\(nextTimelineProperty): \(timeline(index + 1))")
        }
        return declarations.joined(separator: "; ")
    }
}
