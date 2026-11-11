//
// TopicStatusRenderingTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing
@testable import DocCStatic

/// Tests of how deprecated symbols and topic lists are marked, as in swift-docc-render.
@Suite("Topic Status Rendering")
struct TopicStatusRenderingTests {
    /// The page of the fixture's deprecated method.
    static let deprecatedPath = "documentation/fixturecore/point/horizontaldistance(to:)/index.html"

    /// The page of the structure that lists the deprecated method.
    static let structurePath = "documentation/fixturecore/point/index.html"

    @Test("Badges carry their variant and label")
    func badgeMarkup() {
        #expect(Badge.markup(.deprecated) == "<span class=\"badge badge-deprecated\" role=\"presentation\">Deprecated</span>")
        #expect(Badge.markup(.beta) == "<span class=\"badge badge-beta\" role=\"presentation\">Beta</span>")
        #expect(Badge.titleTag(.beta) == "<small class=\"Beta\" data-tag-name=\"Beta\"></small>")
    }

    @Test("Navigator rows of deprecated and beta symbols end with a badge")
    func navigatorBadges() throws {
        let json = """
        [{"title": "old()", "path": "/documentation/m/old()", "type": "method", "deprecated": true},
         {"title": "new()", "path": "/documentation/m/new()", "type": "method", "beta": true},
         {"title": "plain()", "path": "/documentation/m/plain()", "type": "method"}]
        """
        let nodes = try JSONDecoder().decode([NavigationNode].self, from: Data(json.utf8))
        #expect(NavigationSidebarBuilder.badgeMarkup(for: nodes[0]) == Badge.markup(.deprecated))
        #expect(NavigationSidebarBuilder.badgeMarkup(for: nodes[1]) == Badge.markup(.beta))
        #expect(NavigationSidebarBuilder.badgeMarkup(for: nodes[2]).isEmpty)
    }

    @Test("A deprecated symbol's page shows its tag, badge and deprecation summary")
    func deprecatedPage() async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: .default)
        let html = try fixture.text(at: Self.deprecatedPath)
        #expect(html.contains("<h1 class=\"title\"><span>horizontal<wbr>Distance(to:)</span>"
            + "<small class=\"Deprecated\" data-tag-name=\"Deprecated\"></small></h1>"))
        #expect(html.contains("<ul class=\"nav-menu-items hierarchy has-badge\""))
        #expect(html.contains("<span class=\"current item\">horizontalDistance(to:)</span>" + Badge.markup(.deprecated) + "</li></ul>"))
        #expect(html.contains("<div class=\"description\"><aside class=\"deprecated\" aria-label=\"deprecated\">"
            + "<p class=\"label\">Deprecated</p><div class=\"content\">"))
        #expect(html.contains("Use distance(to:) instead."))
    }

    @Test("Breadcrumbs beside a badge show one parent fewer")
    func breadcrumbsWithBadge() async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: .default)
        let html = try fixture.text(at: Self.deprecatedPath)
        // The single parent counts two steps away, as swift-docc-render reserves a place for the badge
        #expect(html.contains("data-parents=\"2\""))
        #expect(html.contains("<li class=\"nav-menu-item hierarchy-item\" data-from-end=\"2\">"))
    }

    @Test("Topic lists strike deprecated topics through and render abstracts in full")
    func deprecatedTopic() async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: .default)
        let html = try fixture.text(at: Self.structurePath)
        let topic = try #require(html.components(separatedBy: "<div class=\"link-block topic").first {
            $0.contains("horizontaldistance(to:)/index.html")
        })
        #expect(topic.contains("class=\"link has-adjacent-elements deprecated\""))
        #expect(topic.contains("<code class=\"inline-code\">other</code>"))
        #expect(topic.contains("class=\"inline-link\"><code>distance(to:)</code></a>"))
        #expect(topic.contains("</div></div>" + Badge.markup(.deprecated) + "</div>"))
    }

    @Test("Topics without an abstract keep their badges on the same line")
    func topicWithoutAbstract() async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: .default)
        let html = try fixture.text(at: Self.structurePath)
        let topic = try #require(html.components(separatedBy: "<div class=\"link-block topic").first {
            $0.contains("equatable-implementations/index.html")
        })
        #expect(topic.hasPrefix(" has-inline-element\""))
        #expect(topic.contains("class=\"link\">"))
        #expect(!topic.contains("has-adjacent-elements"))
    }

    @Test("Short relationship lists are listed on one line")
    func relationshipLayout() async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: .default)
        let protocolPage = try fixture.text(at: "documentation/fixturecore/shape/index.html")
        #expect(protocolPage.contains("<ul class=\"relationships-list inline\">"))
        let structurePage = try fixture.text(at: Self.structurePath)
        #expect(structurePage.contains("<ul class=\"relationships-list column\">"))
    }

    @Test("The navigator marks the deprecated method")
    func navigatorRow() async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: .default)
        let html = try fixture.text(at: SidebarDocument.fileName)
        let row = try #require(html.components(separatedBy: "<li class=\"navigator-card-item").first {
            $0.contains("horizontaldistance(to:)/index.html\" class=\"leaf-link\">")
        })
        #expect(row.contains("</a>" + Badge.markup(.deprecated) + "</div>"))
    }
}
