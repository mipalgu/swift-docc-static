//
// SidebarDocumentTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing
@testable import DocCStatic

/// Builds a navigation node for tests.
private func node(
    _ title: String,
    _ path: String?,
    _ type: String,
    _ children: [NavigationNode]? = nil
) -> NavigationNode {
    NavigationNode(
        title: title,
        path: path,
        type: type,
        children: children,
        isDeprecated: nil,
        isExternal: nil,
        isBeta: nil
    )
}

/// A two-module navigation index with nesting, group markers, an operator
/// path and a page that is curated twice.
private func twoModuleIndex() -> NavigationIndex {
    let point = node("Point", "/documentation/Alpha/Point", "struct", [
        node("Operators", nil, "groupMarker"),
        node("+(_:_:)", "/documentation/Alpha/Point/+(_:_:)", "op"),
        node("Instance Properties", nil, "groupMarker"),
        node("x", "/documentation/Alpha/Point/x", "property"),
    ])
    let alpha = node("Alpha", "/documentation/Alpha", "module", [
        node("Essentials", nil, "groupMarker"),
        node("Getting Started", "/documentation/Alpha/GettingStarted", "article"),
        point,
        node("Also Point", nil, "groupMarker"),
        node("Point", "/documentation/Alpha/Point", "struct"),
    ])
    let beta = node("Beta", "/documentation/Beta", "module", [
        node("Label", "/documentation/Beta/Label", "struct"),
    ])
    return NavigationIndex(
        schemaVersion: nil,
        includedArchiveIdentifiers: nil,
        interfaceLanguages: ["swift": [alpha, beta]]
    )
}

/// A single-module navigation index.
private func singleModuleIndex() -> NavigationIndex {
    let gamma = node("Gamma", "/documentation/gamma", "module", [
        node("Thing", "/documentation/gamma/thing", "class", [
            node("run()", "/documentation/gamma/thing/run()", "method"),
        ]),
    ])
    return NavigationIndex(
        schemaVersion: nil,
        includedArchiveIdentifiers: nil,
        interfaceLanguages: ["swift": [gamma]]
    )
}

/// Returns all values of the given attribute in the HTML, with the character
/// references the generator writes (`&amp;`, `&lt;`, `&gt;`, `&quot;` and `&#39;`)
/// replaced by their characters, as a browser reads them.
func attributeValues(_ attribute: String, in html: String) -> [String] {
    let pattern = "\\s\(attribute)=\"([^\"]*)\""
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(html.startIndex..., in: html)
    return regex.matches(in: html, range: range).compactMap {
        Range($0.range(at: 1), in: html).map { unescapedHTML(String(html[$0])) }
    }
}

/// Replaces the character references the generator writes by their characters.
func unescapedHTML(_ text: String) -> String {
    text.replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&amp;", with: "&")
}

@Suite("Sidebar Document Names")
struct SidebarDocumentNameTests {
    @Test("Sidebar document lives at the output root and cannot collide with pages")
    func fileNameIsAtRoot() {
        #expect(!SidebarDocument.fileName.contains("/"))
        #expect(SidebarDocument.fileName.hasSuffix(".html"))
        #expect(SidebarDocument.fileName != "index.html")
    }

    @Test("Page path keys use the same normalisation as page output paths")
    func pagePathKeyNormalisation() {
        #expect(SidebarDocument.pagePathKey("/documentation/Alpha/Point/") == "documentation/alpha/point")
        #expect(SidebarDocument.pagePathKey("documentation//Alpha") == "documentation/alpha")
    }

    @Test("Page path keys give components starting with a period swift-docc's apostrophe")
    func leadingPeriods() {
        #expect(SidebarDocument.pagePathKey("/documentation/A/Span/...(_:_:)") == "documentation/a/span/'...(_:_:)")
        #expect(SidebarDocument.pagePathKey("/documentation/A/Span/'...(_:_:)") == "documentation/a/span/'...(_:_:)")
        #expect(SidebarDocument.pagePathKey("/documentation/A/Span/.._(_:)-1x2y") == "documentation/a/span/'.._(_:)-1x2y")
        #expect(SidebarDocument.pagePathKey("/documentation/A/Span/+(_:_:)") == "documentation/a/span/+(_:_:)")
    }

    @Test("Row identifiers are prefixed, lowercased and fragment-safe")
    func rowIdentifierEncoding() {
        let plain = SidebarDocument.rowIdentifier(forPath: "/documentation/Alpha/Point")
        #expect(plain == SidebarDocument.rowIdentifierPrefix + "documentation/alpha/point")

        let operatorID = SidebarDocument.rowIdentifier(forPath: "/documentation/Alpha/Point/+(_:_:)")
        #expect(operatorID == SidebarDocument.rowIdentifierPrefix + "documentation/alpha/point/+(_:_:)")

        let unsafe = SidebarDocument.rowIdentifier(forPath: "/documentation/a/<(_:_:) \"x\"%é")
        let suffix = unsafe.dropFirst(SidebarDocument.rowIdentifierPrefix.count)
        #expect(!suffix.contains("<"))
        #expect(!suffix.contains(" "))
        #expect(!suffix.contains("\""))
        #expect(!suffix.contains("é"))
        #expect(suffix.contains("%3C"))
        #expect(suffix.contains("%25"))
        #expect(suffix.contains("%C3%A9"))
    }

    @Test("Distinct paths give distinct identifiers")
    func identifiersAreInjective() {
        let a = SidebarDocument.rowIdentifier(forPath: "/documentation/a/%3C")
        let b = SidebarDocument.rowIdentifier(forPath: "/documentation/a/<")
        #expect(a != b)
    }
}

@Suite("Shared Sidebar Document")
struct SharedSidebarDocumentTests {
    func document(_ index: NavigationIndex = twoModuleIndex(), includeSearch: Bool = false) -> String {
        var builder = NavigationSidebarBuilder(navigationIndex: index)
        return builder.buildSidebarDocument(includeSearch: includeSearch)
    }

    @Test("Document is a standalone HTML page that targets the top window")
    func standaloneDocument() {
        let html = document()
        #expect(html.hasPrefix("<!DOCTYPE html>"))
        #expect(html.contains("<html lang=\"en\">"))
        #expect(html.contains("<title>\(SidebarDocument.frameTitle)</title>"))
        #expect(html.contains("<base target=\"_top\">"))
        #expect(html.contains("<link rel=\"stylesheet\" href=\"css/main.css\">"))
        #expect(html.contains("<body class=\"\(SidebarDocument.documentClass)\""))
        #expect(html.contains("<meta name=\"robots\" content=\"noindex\">"))
    }

    @Test("Document contains every module with links relative to the output root")
    func linksAreRootRelative() {
        let html = document()
        let hrefs = attributeValues("href", in: html).filter { $0.hasSuffix("index.html") }
        #expect(hrefs.contains("documentation/alpha/index.html"))
        #expect(hrefs.contains("documentation/beta/index.html"))
        #expect(hrefs.contains("documentation/alpha/point/+(_:_:)/index.html"))
        #expect(hrefs.allSatisfy { !$0.hasPrefix("../") && !$0.hasPrefix("/") })
    }

    @Test("Every row identifier is unique and only the first occurrence of a page has one")
    func identifiersAreUnique() {
        let html = document()
        let ids = attributeValues("id", in: html)
        #expect(Set(ids).count == ids.count)
        let pointID = SidebarDocument.rowIdentifier(forPath: "/documentation/alpha/point")
        #expect(ids.filter { $0 == pointID }.count == 1)
        // The duplicate Point row is still rendered as a link
        let pointLinks = html.components(separatedBy: "href=\"documentation/alpha/point/index.html\"").count - 1
        #expect(pointLinks == 2)
    }

    @Test("Modules and rows carry identifiers derived from their paths")
    func rowsCarryIdentifiers() {
        let html = document()
        let ids = Set(attributeValues("id", in: html))
        for path in [
            "/documentation/alpha", "/documentation/beta",
            "/documentation/alpha/gettingstarted", "/documentation/alpha/point",
            "/documentation/alpha/point/+(_:_:)", "/documentation/alpha/point/x",
            "/documentation/beta/label",
        ] {
            #expect(ids.contains(SidebarDocument.rowIdentifier(forPath: path)), "Missing id for \(path)")
        }
    }

    @Test("Row identifiers announced by the model all exist in the document")
    func modelMatchesDocument() {
        for index in [twoModuleIndex(), singleModuleIndex()] {
            let html = document(index)
            let ids = Set(attributeValues("id", in: html))
            let model = SidebarDocument(navigationIndex: index)
            #expect(!model.rowPaths.isEmpty)
            for path in model.rowPaths {
                #expect(ids.contains(SidebarDocument.rowIdentifier(forPath: path)), "Missing id for \(path)")
            }
        }
    }

    @Test("Document contains no per-page state")
    func noPerPageState() {
        let html = document()
        #expect(!html.contains(" checked"))
        #expect(!html.contains("selected"))
        #expect(!html.contains(" active"))
        #expect(!html.contains("aria-current="))
    }

    @Test("Document output is deterministic")
    func deterministic() {
        #expect(document() == document())
    }

    @Test("Single-module documents also carry identifiers")
    func singleModule() {
        let html = document(singleModuleIndex())
        let ids = Set(attributeValues("id", in: html))
        #expect(ids.contains(SidebarDocument.rowIdentifier(forPath: "/documentation/gamma")))
        #expect(ids.contains(SidebarDocument.rowIdentifier(forPath: "/documentation/gamma/thing/run()")))
    }

    @Test("Filter box and its script live in the sidebar document")
    func filterLivesInDocument() {
        let html = document()
        #expect(html.contains("filter-input\""))
        #expect(html.contains("id=\"sidebar-filter\""))
        #expect(html.contains(SidebarDocument.focusFilterMessage))
        #expect(html.contains(SidebarDocument.colourSchemeMessage))
        #expect(html.contains(SidebarDocument.colourSchemeStorageKey))
        #expect(!html.contains(".nav-link"))
        #expect(!html.contains("nav-child-item"))
    }

    @Test("Search scripts are referenced from the document only when search is enabled")
    func searchScripts() {
        #expect(!document(includeSearch: false).contains("js/search.js"))
        let withSearch = document(includeSearch: true)
        #expect(withSearch.contains("<script src=\"js/lunr.min.js\" defer></script>"))
        #expect(withSearch.contains("<script src=\"js/search.js\" defer></script>"))
    }

    @Test("Empty navigation index has no shared document")
    func emptyIndexHasNoDocument() {
        let empty = NavigationIndex(schemaVersion: nil, includedArchiveIdentifiers: nil, interfaceLanguages: ["swift": []])
        #expect(!SidebarDocument.isAvailable(for: empty))
        #expect(!SidebarDocument.isAvailable(for: nil))
        #expect(SidebarDocument.isAvailable(for: twoModuleIndex()))
    }

    @Test("Fallback sidebar keeps the inline structure")
    func fallbackSidebar() {
        let html = NavigationSidebarBuilder.buildFallbackSidebar()
        #expect(html.contains("<nav class=\"sidebar\""))
        #expect(html.contains("sidebar-content"))
    }
}

@Suite("Sidebar Embedding")
struct SidebarEmbeddingTests {
    @Test("Pages embed the shared document with their own row as the fragment")
    func embeddingUsesFragment() {
        let model = SidebarDocument(navigationIndex: twoModuleIndex())
        let html = model.embeddingMarkup(forPagePath: "/documentation/Alpha/Point/x", depth: 4)
        let expectedID = SidebarDocument.rowIdentifier(forPath: "/documentation/alpha/point/x")
        #expect(html.contains("<nav class=\"sidebar\""))
        #expect(html.contains("<iframe class=\"\(SidebarDocument.frameClass)\""))
        #expect(html.contains("title=\"\(SidebarDocument.frameTitle)\""))
        #expect(html.contains("src=\"../../../../\(SidebarDocument.fileName)#\(expectedID)\""))
    }

    @Test("Pages missing from the tree point at their nearest listed ancestor")
    func embeddingFallsBackToAncestor() {
        let model = SidebarDocument(navigationIndex: twoModuleIndex())
        #expect(model.targetIdentifier(forPagePath: "/documentation/alpha/point/y")
                == SidebarDocument.rowIdentifier(forPath: "/documentation/alpha/point"))
        #expect(model.targetIdentifier(forPagePath: "/documentation/alpha/unlisted")
                == SidebarDocument.rowIdentifier(forPath: "/documentation/alpha"))
        #expect(model.targetIdentifier(forPagePath: "/documentation/gamma") == nil)
        let html = model.embeddingMarkup(forPagePath: "/documentation/gamma", depth: 2)
        #expect(html.contains("src=\"../../\(SidebarDocument.fileName)\""))
    }
}

@Suite("Sidebar Stylesheet")
struct SidebarStylesheetTests {
    let css = DocCStylesheet.generate(theme: .default)

    @Test("Embedded frame fills the sidebar container without a border")
    func frameFillsContainer() {
        #expect(css.contains(".\(SidebarDocument.frameClass) {"))
        #expect(css.contains("body.\(SidebarDocument.documentClass) {"))
    }

    @Test("Target row is styled as selected and scrolled with context")
    func targetIsSelected() {
        #expect(css.contains(".navigator-card-item:target .head-wrapper"))
        #expect(css.contains("scroll-margin-top"))
        #expect(css.contains(".module-header:target .technology-title"))
    }

    @Test("Rows on the target path invert their disclosure checkbox")
    func targetPathInvertsCheckbox() {
        #expect(css.contains(":has(+ .nav-children-wrapper :target)"))
        #expect(css.contains("> .disclosure-checkbox:not(:checked)"))
        #expect(css.contains(".module-section:has(:target) > .disclosure-checkbox:not(:checked) ~ .module-contents"))
    }

    @Test("Item chevrons rotate with the checkbox that precedes the row's head")
    func itemChevronRotates() {
        #expect(css.contains("> .disclosure-checkbox:checked ~ .head-wrapper .chevron"))
        #expect(css.contains("> .disclosure-checkbox:not(:checked) ~ .head-wrapper .chevron"))
    }

    @Test("Expanded children are not clipped by a fixed maximum height")
    func expandedChildrenAreNotClipped() {
        #expect(!css.contains("max-height: 5000px"))
    }
}

@Suite("Doc Link Post-Processing of the Sidebar")
struct SidebarPostProcessingTests {
    @Test("Content without doc links is returned unchanged")
    func unchangedWithoutDocLinks() {
        let processor = DocLinkPostProcessor(documentedModules: ["Alpha": "Alpha"], externalURLs: [:])
        let html = "<p>No links here</p>"
        #expect(processor.process(html, currentDepth: 0) == html)
    }

    @Test("Doc links to pages with periods, colons and leading periods resolve to their files")
    func awkwardDocLinks() {
        let processor = DocLinkPostProcessor(documentedModules: ["Alpha": "Alpha"], externalURLs: [:])
        let html = "<p>See doc://Alpha/documentation/Alpha/Point/distance(to:), "
            + "doc://Alpha/documentation/Alpha/marker-swift.var and doc://Alpha/documentation/Alpha/Span/...(_:_:).</p>"
        let processed = processor.process(html, currentDepth: 2)
        #expect(processed.contains("href=\"../../documentation/alpha/point/distance(to:)/index.html\""))
        #expect(processed.contains("href=\"../../documentation/alpha/marker-swift.var/index.html\""))
        #expect(processed.contains("href=\"../../documentation/alpha/span/&#39;...(_:_:)/index.html\""))
        #expect(processed.hasSuffix("</a>.</p>"))
        #expect(processed.contains("</a>, "))
    }

    @Test("Generated files that are not documentation pages are skipped")
    func sidebarDocumentIsSkipped() {
        #expect(!DocLinkPostProcessor.shouldProcess(relativePath: SidebarDocument.fileName))
        #expect(DocLinkPostProcessor.shouldProcess(relativePath: "documentation/alpha/index.html"))
        #expect(DocLinkPostProcessor.shouldProcess(relativePath: "index.html"))
    }
}

@Suite("Sidebar Document Size")
struct SidebarDocumentSizeTests {
    /// A module with many symbols of every kind the navigator shows.
    func largeIndex(rows: Int) -> NavigationIndex {
        let kinds = ["struct", "class", "enum", "protocol", "method", "property", "op", "func", "article", "typealias"]
        let children = (0..<rows).map { number in
            let kind = kinds[number % kinds.count]
            return node("Symbol\(number)", "/documentation/large/symbol\(number)", kind,
                        number % 5 == 0 ? [node("member()", "/documentation/large/symbol\(number)/member()", "method")] : nil)
        }
        return NavigationIndex(schemaVersion: nil, includedArchiveIdentifiers: nil,
                               interfaceLanguages: ["swift": [node("Large", "/documentation/large", "module", children)]])
    }

    func document(_ index: NavigationIndex) -> String {
        var builder = NavigationSidebarBuilder(navigationIndex: index)
        return builder.buildSidebarDocument(includeSearch: false)
    }

    @Test("Rows refer to icons defined once in the document")
    func iconsAreDefinedOnce() throws {
        let html = document(largeIndex(rows: 40))
        let references = attributeValues("href", in: html).filter { $0.hasPrefix("#") }.map { String($0.dropFirst()) }
        #expect(!references.isEmpty)
        let identifiers = attributeValues("id", in: html)
        for reference in Set(references) {
            #expect(identifiers.filter { $0 == reference }.count == 1, "\(reference) is not defined exactly once")
        }
        // No row repeats the drawing of an icon or chevron
        let rows = html.components(separatedBy: "<li class=\"navigator-card-item").dropFirst()
        #expect(rows.count >= 40)
        for row in rows {
            let markup = row.components(separatedBy: "</li>").first ?? row
            #expect(!markup.contains("<path") && !markup.contains("<text") && !markup.contains("<rect"))
        }
    }

    @Test("Icons keep the classes and geometry of swift-docc-render's icons")
    func iconReferencesKeepTheOuterElement() throws {
        for type in ["struct", "protocol", "article", "op", "func", "tutorial", "module", "collection"] {
            let inline = TopicTypeIcon.svg(for: TopicTypeIcon.normalisedType(type))
            let identifier = TopicTypeIcon.symbolIdentifier(for: type)
            let reference = TopicTypeIcon.referenceMarkup(for: type, additionalClass: "navigator-icon")
            let wrapper = try #require(TopicTypeIcon.markup(for: type, additionalClass: "navigator-icon").components(separatedBy: "<svg").first)
            #expect(reference.hasPrefix(wrapper))
            #expect(reference.contains("<svg class=\"\(TopicTypeIcon.attribute("class", of: inline) ?? "")\""))
            #expect(reference.contains("<use href=\"#\(identifier)\"/>"))
            let definitions = TopicTypeIcon.symbolDefinitions(for: [type])
            let viewBox = try #require(TopicTypeIcon.attribute("viewBox", of: inline))
            #expect(definitions.contains("<symbol id=\"\(identifier)\" viewBox=\"\(viewBox)\">\(TopicTypeIcon.content(of: inline))</symbol>"))
        }
    }

    @Test("Large navigators stay compact")
    func bytesPerRow() {
        let rows = 1000
        let html = document(largeIndex(rows: rows))
        // Each row (and every fifth row's child) costs less than 600 bytes on average,
        // where icons drawn in every row cost more than 800
        #expect(html.utf8.count < rows * 6 / 5 * 600, "\(html.utf8.count) bytes for \(rows * 6 / 5) rows")
    }
}

@Suite("Shared Topic Icons on Pages")
struct SharedTopicIconTests {
    @Test("Topic icons that a page repeats are drawn once and referred to")
    func repeatedIconsAreShared() throws {
        let article = try #require(TopicTypeIcon.topicListIcon(forRole: "article"))
        let tutorial = try #require(TopicTypeIcon.topicListIcon(forRole: "tutorial"))
        let page = "<html><body data-x=\"1\">\n<main>\(article)\(article)\(tutorial)\(article)</main></body></html>"
        let shared = TopicTypeIcon.sharingRepeatedTopicIcons(in: page)
        #expect(!shared.contains(article))
        #expect(shared.components(separatedBy: "<use href=\"#").count - 1 == 3)
        #expect(shared.components(separatedBy: "<symbol ").count - 1 == 1)
        // An icon shown once stays inline
        #expect(shared.contains(tutorial))
        // The definitions follow the opening body tag and keep the icon's view box
        #expect(shared.contains("<body data-x=\"1\"><svg class=\"\(TopicTypeIcon.symbolsClassName)\""))
        let reference = try #require(shared.range(of: "<svg class=\"topic-icon svg-icon\" viewBox=\"0 0 14 14\" aria-hidden=\"true\"><use href=\"#"))
        #expect(!reference.isEmpty)
    }

    @Test("Pages without repeated icons are unchanged")
    func singleIconsStayInline() throws {
        let article = try #require(TopicTypeIcon.topicListIcon(forRole: "article"))
        let page = "<html><body>\(article)</body></html>"
        #expect(TopicTypeIcon.sharingRepeatedTopicIcons(in: page) == page)
    }
}
