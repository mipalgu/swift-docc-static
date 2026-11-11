//
// OnThisPageNavigationTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing
@testable import DocCStatic

/// Tests of the "On This Page" column's markup for tracking the section in view.
@Suite("On This Page Navigation Tests")
struct OnThisPageNavigationTests {
    /// The path of the fixture article, whose column lists several sections.
    static let articlePath = "documentation/fixturecore/gettingstarted/index.html"

    /// The anchors the article's column links to, in order.
    static let anchors = ["app-top", "Overview", "Creating-Points", "Comparing-Directions", "Drawing", "Asides", "see-also"]

    @Test("Timeline names are unique dashed identifiers")
    func timelineNames() {
        #expect(OnThisPageNavigation.timeline(0) == "--on-this-page-1")
        #expect(OnThisPageNavigation.timeline(6) == "--on-this-page-7")
    }

    @Test("Anchors become string literals that cannot end the style element")
    func anchorSelectors() {
        #expect(OnThisPageNavigation.selector(forAnchor: "Overview") == #"[id="Overview"]"#)
        #expect(OnThisPageNavigation.selector(forAnchor: #"a"b\c</style>"#) == #"[id="a\"b\\c\3c /style>"]"#)
    }

    @Test("Each section heading is the subject of a view timeline tracking the line swift-docc-render uses")
    func headingTimelines() async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: .default)
        let html = try fixture.text(at: Self.articlePath)
        let head = html.components(separatedBy: "</head>").first ?? ""
        for (index, anchor) in Self.anchors.enumerated().dropFirst() {
            let rule = "\(OnThisPageNavigation.selector(forAnchor: anchor)) { view-timeline-name: \(OnThisPageNavigation.timeline(index));"
                + " view-timeline-inset: \(OnThisPageNavigation.trackingLinePercentage)% 0%; }"
            #expect(head.contains(rule), "no view timeline for \(anchor)")
        }
        #expect(!head.contains(OnThisPageNavigation.selector(forAnchor: "app-top")))
        let scope = Self.anchors.indices.dropFirst().map { OnThisPageNavigation.timeline($0) }.joined(separator: ", ")
        #expect(html.contains("<div class=\"doc-content-wrapper\" style=\"timeline-scope: \(scope)\">"))
    }

    @Test("Each item follows the timelines of its own and the next section heading")
    func itemTimelines() async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: .default)
        let html = try fixture.text(at: Self.articlePath)
        let first = "<li class=\"parent-item active\" style=\"\(OnThisPageNavigation.nextTimelineProperty): \(OnThisPageNavigation.timeline(1))\">"
        #expect(html.contains(first))
        let middle = "<li class=\"child-item\" style=\"\(OnThisPageNavigation.timelineProperty): \(OnThisPageNavigation.timeline(2));"
            + " \(OnThisPageNavigation.nextTimelineProperty): \(OnThisPageNavigation.timeline(3))\">"
        #expect(html.contains(middle))
        let last = "<li class=\"parent-item\" style=\"\(OnThisPageNavigation.timelineProperty): \(OnThisPageNavigation.timeline(6))\">"
        #expect(html.contains(last))
        #expect(html.contains("<nav class=\"\(OnThisPageNavigation.navigationClass)\" aria-label=\"On This Page\">"))
    }

    @Test("Pages without a section list have no timelines")
    func noTimelinesWithoutSections() async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: .default)
        let html = try fixture.text(at: "documentation/fixturecore/point/x/index.html")
        #expect(!html.contains(OnThisPageNavigation.timeline(1)))
    }

    @Test("Items of third-level headings line up with the other items, like swift-docc-render")
    func childItemsAreNotIndented() {
        let css = DocCStylesheet.generate(theme: ThemeConfiguration(builtInTheme: .default))
        var remainder = Substring(css)
        while let open = remainder.firstIndex(of: "{"), let close = remainder[open...].firstIndex(of: "}") {
            let selector = remainder[..<open]
            let declarations = remainder[remainder.index(after: open)..<close]
            if selector.contains("\(OnThisPageNavigation.navigationClass) .child-item") {
                #expect(!declarations.contains("padding"), "\(selector.trimmingCharacters(in: .whitespacesAndNewlines)) indents the item")
                #expect(!declarations.contains("margin"), "\(selector.trimmingCharacters(in: .whitespacesAndNewlines)) indents the item")
            }
            remainder = remainder[remainder.index(after: close)...]
        }
    }
}
