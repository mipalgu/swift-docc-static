//
// SearchIndexBuilderTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Testing
import Foundation
@testable import DocCStatic

@Suite("Search Index Builder Tests")
struct SearchIndexBuilderTests {
    @Test("Search document stores all fields")
    func searchDocumentFields() {
        let document = SearchIndexBuilder.SearchDocument(
            id: "doc/test/symbol",
            title: "TestSymbol",
            type: "symbol",
            path: "doc/test/symbol/index.html",
            summary: "A test symbol for testing",
            keywords: ["test", "symbol", "testing"],
            module: "TestModule"
        )

        #expect(document.id == "doc/test/symbol")
        #expect(document.title == "TestSymbol")
        #expect(document.type == "symbol")
        #expect(document.path == "doc/test/symbol/index.html")
        #expect(document.summary == "A test symbol for testing")
        #expect(document.keywords == ["test", "symbol", "testing"])
        #expect(document.module == "TestModule")
    }

    @Test("Search document handles nil module")
    func searchDocumentNilModule() {
        let document = SearchIndexBuilder.SearchDocument(
            id: "doc/test",
            title: "Test",
            type: "article",
            path: "doc/test/index.html",
            summary: "A test article",
            keywords: [],
            module: nil
        )

        #expect(document.module == nil)
    }

    @Test("Search index includes version and fields")
    func searchIndexStructure() {
        let documents: [SearchIndexBuilder.SearchDocument] = []
        let index = SearchIndexBuilder.SearchIndex(documents: documents)

        #expect(index.version == "1.0")
        #expect(index.fields == ["title", "summary", "keywords", "module"])
        #expect(index.documents.isEmpty)
    }

    @Test("Search index can be encoded to JSON")
    func searchIndexEncodable() throws {
        let document = SearchIndexBuilder.SearchDocument(
            id: "test",
            title: "Test",
            type: "symbol",
            path: "test/index.html",
            summary: "Test summary",
            keywords: ["test"],
            module: "TestModule"
        )
        let index = SearchIndexBuilder.SearchIndex(documents: [document])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(index)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"version\":\"1.0\""))
        #expect(json.contains("\"title\":\"Test\""))
        #expect(json.contains("\"module\":\"TestModule\""))
    }

    @Test("Builder creates with configuration")
    func builderInitialisation() {
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp"),
            outputDirectory: URL(fileURLWithPath: "/tmp/docs")
        )
        let builder = SearchIndexBuilder(configuration: config)

        #expect(builder.configuration.packageDirectory.path == "/tmp")
    }

    @Test("Builder builds empty index initially")
    func emptyBuilderIndex() {
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp"),
            outputDirectory: URL(fileURLWithPath: "/tmp/docs")
        )
        let builder = SearchIndexBuilder(configuration: config)
        let index = builder.index

        #expect(index.documents.isEmpty)
    }
}

@Suite("Search Document Type Tests")
struct SearchDocumentTypeTests {
    @Test("Symbol type is 'symbol'")
    func symbolType() {
        let document = SearchIndexBuilder.SearchDocument(
            id: "test", title: "Test", type: "symbol",
            path: "test.html", summary: "", keywords: [], module: nil
        )
        #expect(document.type == "symbol")
    }

    @Test("Article type is 'article'")
    func articleType() {
        let document = SearchIndexBuilder.SearchDocument(
            id: "test", title: "Test", type: "article",
            path: "test.html", summary: "", keywords: [], module: nil
        )
        #expect(document.type == "article")
    }

    @Test("Tutorial type is 'tutorial'")
    func tutorialType() {
        let document = SearchIndexBuilder.SearchDocument(
            id: "test", title: "Test", type: "tutorial",
            path: "test.html", summary: "", keywords: [], module: nil
        )
        #expect(document.type == "tutorial")
    }
}
