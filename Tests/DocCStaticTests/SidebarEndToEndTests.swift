//
// SidebarEndToEndTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing
@testable import DocCStatic

/// End-to-end tests that run the real generator on the fixture package and check
/// that the navigation sidebar is emitted once and embedded by every page.
@Suite("Shared Sidebar End-to-End Tests", .serialized)
struct SidebarEndToEndTests {
    /// Returns the documentation pages (pages below `documentation/`).
    func documentationPages(in fixture: GeneratedFixture) -> [URL] {
        fixture.files(withExtension: "html").filter {
            fixture.relativePath(of: $0).hasPrefix("documentation/")
        }
    }

    /// Extracts the fragment-free, query-free part of a relative link.
    func stripFragment(_ link: String) -> String {
        String(link.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0])
    }

    /// Percent-decodes a link if possible.
    func decoded(_ link: String) -> String {
        link.removingPercentEncoding ?? link
    }

    @Test("Exactly one sidebar document is generated at the output root",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func exactlyOneSidebarDocument(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let sidebars = fixture.allFiles().filter { $0.lastPathComponent == SidebarDocument.fileName }
        #expect(sidebars.count == 1)
        #expect(sidebars.map { fixture.relativePath(of: $0) } == [SidebarDocument.fileName])
    }

    @Test("No generated page contains the inlined navigation tree",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func noInlinedTree(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        for page in fixture.files(withExtension: "html") {
            let relative = fixture.relativePath(of: page)
            guard relative != SidebarDocument.fileName else { continue }
            let html = try String(contentsOf: page, encoding: .utf8)
            #expect(!html.contains("class=\"navigator-card"), "Inlined tree in \(relative)")
            #expect(!html.contains("class=\"sidebar-content\""), "Inlined tree in \(relative)")
        }
    }

    @Test("Every documentation page embeds the sidebar with a unique existing fragment",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func everyPageEmbedsSidebar(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let sidebar = try fixture.text(at: SidebarDocument.fileName)
        let ids = attributeValues("id", in: sidebar)
        let pages = documentationPages(in: fixture)
        #expect(pages.count > 20)
        for page in pages {
            let relative = fixture.relativePath(of: page)
            let html = try String(contentsOf: page, encoding: .utf8)
            let frames = html.components(separatedBy: "<iframe class=\"\(SidebarDocument.frameClass)\"").count - 1
            #expect(frames == 1, "Expected one sidebar frame in \(relative)")
            let depth = relative.split(separator: "/").count - 1
            let prefix = String(repeating: "../", count: depth) + SidebarDocument.fileName + "#"
            guard let source = attributeValues("src", in: html).first(where: { $0.hasPrefix(prefix) }) else {
                Issue.record("No sidebar fragment in \(relative)")
                continue
            }
            let fragment = String(source.dropFirst(prefix.count))
            #expect(ids.filter { $0 == fragment }.count == 1, "Fragment \(fragment) of \(relative)")
            // The page's own row is the target whenever the page is listed in the tree
            let pagePath = String(relative.dropLast("/index.html".count))
            let ownID = SidebarDocument.rowIdentifier(forPath: pagePath)
            if ids.contains(ownID) {
                #expect(fragment == ownID, "Page \(relative) should target its own row")
            }
        }
    }

    @Test("Every link in the sidebar document resolves to an existing file",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func sidebarLinksResolve(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let sidebar = try fixture.text(at: SidebarDocument.fileName)
        let fileManager = FileManager.default
        var checked = 0
        for link in attributeValues("href", in: sidebar) + attributeValues("src", in: sidebar) {
            let target = decoded(stripFragment(link))
            guard !target.isEmpty, !target.contains("://") else { continue }
            #expect(!target.hasPrefix("/") && !target.hasPrefix("../"), "Link \(link) is not root-relative")
            let path = fixture.outputDirectory.appendingPathComponent(target).path
            #expect(fileManager.fileExists(atPath: path), "Broken sidebar link \(link)")
            checked += 1
        }
        #expect(checked > 20)
    }

    @Test("The sidebar document carries no per-page state",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func sidebarHasNoPageState(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let sidebar = try fixture.text(at: SidebarDocument.fileName)
        #expect(!sidebar.contains(" checked"))
        #expect(!sidebar.contains("selected"))
        #expect(!sidebar.contains(" active"))
        #expect(!sidebar.contains("aria-current="))
        #expect(sidebar.contains("<base target=\"_top\">"))
    }

    @Test("Pages without a sidebar stay without one")
    func pagesWithoutSidebar() async throws {
        let fixture = try await FixtureDocumentation.shared.output()
        let pages = fixture.files(withExtension: "html").filter {
            fixture.relativePath(of: $0).hasPrefix("tutorials/")
        }
        #expect(pages.count >= 2)
        // The index page shows the navigator like the root page of swift-docc-render
        let index = try fixture.text(at: "index.html")
        #expect(index.contains("src=\"\(SidebarDocument.fileName)\""))
        for page in pages {
            let html = try String(contentsOf: page, encoding: .utf8)
            #expect(!html.contains(SidebarDocument.fileName), "\(fixture.relativePath(of: page))")
        }
    }

    @Test("Page sizes no longer scale with the size of the navigation tree")
    func pageSizesAreProportional() async throws {
        let fixture = try await FixtureDocumentation.shared.output()
        let sidebarBytes = try fixture.text(at: SidebarDocument.fileName).utf8.count
        let pages = try documentationPages(in: fixture).map { try String(contentsOf: $0, encoding: .utf8) }
        let largest = pages.map(\.utf8.count).max() ?? 0
        let total = pages.map(\.utf8.count).reduce(0, +)
        // The tree is shared rather than repeated, so no page carries it.
        #expect(largest < sidebarBytes + largest / 2)
        #expect(total < pages.count * sidebarBytes)
    }

    @Test("The sidebar document is neither indexed nor counted as a page")
    func sidebarIsNotContent() async throws {
        let fixture = try await FixtureDocumentation.shared.output()
        let searchIndex = try fixture.text(at: "search-index.json")
        #expect(!searchIndex.contains(SidebarDocument.fileName))
        // Every HTML file except the landing page and the sidebar document is a rendered page
        let renderedPages = fixture.files(withExtension: "html").filter {
            let relative = fixture.relativePath(of: $0)
            return relative != "index.html" && relative != SidebarDocument.fileName
        }
        #expect(fixture.result.generatedPages == renderedPages.count)
    }

    @Test("Generation is deterministic across two runs")
    func deterministic() async throws {
        let first = try await FixtureDocumentation.shared.output(run: 0)
        let second = try await FixtureDocumentation.shared.output(run: 1)
        let firstFiles = first.allFiles().map { first.relativePath(of: $0) }
        let secondFiles = second.allFiles().map { second.relativePath(of: $0) }
        #expect(firstFiles == secondFiles)
        for relative in firstFiles where secondFiles.contains(relative) {
            let a = try Data(contentsOf: first.outputDirectory.appendingPathComponent(relative))
            let b = try Data(contentsOf: second.outputDirectory.appendingPathComponent(relative))
            #expect(a == b, "\(relative) differs between runs")
        }
    }

    @Test("Generated output does not leak the generation directories")
    func noLocalPathsLeak() async throws {
        let fixture = try await FixtureDocumentation.shared.output()
        let workspace = fixture.outputDirectory.deletingLastPathComponent().deletingLastPathComponent()
        let markers = [workspace.path, workspace.resolvingSymlinksInPath().path]
        for file in fixture.files(withExtension: "html") + fixture.files(withExtension: "json") {
            let text = try String(contentsOf: file, encoding: .utf8)
            for marker in markers {
                #expect(!text.contains(marker), "\(fixture.relativePath(of: file)) leaks a local path")
            }
        }
    }
}
