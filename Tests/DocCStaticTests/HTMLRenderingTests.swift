//
// HTMLRenderingTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Testing
import Foundation
@testable import DocCStatic

@Suite("HTML Escaping Tests")
struct HTMLEscapingTests {
    @Test("Escapes ampersand")
    func escapeAmpersand() {
        let result = escapeHTML("foo & bar")
        #expect(result == "foo &amp; bar")
    }

    @Test("Escapes less than")
    func escapeLessThan() {
        let result = escapeHTML("a < b")
        #expect(result == "a &lt; b")
    }

    @Test("Escapes greater than")
    func escapeGreaterThan() {
        let result = escapeHTML("a > b")
        #expect(result == "a &gt; b")
    }

    @Test("Escapes double quotes")
    func escapeDoubleQuotes() {
        let result = escapeHTML("\"quoted\"")
        #expect(result == "&quot;quoted&quot;")
    }

    @Test("Escapes single quotes")
    func escapeSingleQuotes() {
        let result = escapeHTML("it's")
        #expect(result == "it&#39;s")
    }

    @Test("Escapes multiple special characters")
    func escapeMultiple() {
        let result = escapeHTML("<script>alert('xss');</script>")
        #expect(result == "&lt;script&gt;alert(&#39;xss&#39;);&lt;/script&gt;")
    }

    @Test("Leaves safe text unchanged")
    func safeText() {
        let result = escapeHTML("Hello World")
        #expect(result == "Hello World")
    }
}

@Suite("Content Renderer Tests")
struct ContentRendererTests {
    @Test("Renderer initialises correctly")
    func rendererInit() {
        let renderer = RenderContentHTMLRenderer()
        // Simply verify it can be created without error
        _ = renderer
    }
}

@Suite("Page Builder Tests")
struct PageBuilderTests {
    @Test("Page builder initialises with configuration")
    func pageBuilderInit() {
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp/package"),
            outputDirectory: URL(fileURLWithPath: "/tmp/output")
        )
        let builder = HTMLPageBuilder(configuration: config)

        #expect(builder.configuration.packageDirectory.path == "/tmp/package")
        #expect(builder.configuration.outputDirectory.path == "/tmp/output")
    }

    @Test("Page builder respects search configuration")
    func searchConfiguration() {
        let configWithSearch = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp"),
            outputDirectory: URL(fileURLWithPath: "/tmp/docs"),
            includeSearch: true
        )
        let builderWithSearch = HTMLPageBuilder(configuration: configWithSearch)
        #expect(builderWithSearch.configuration.includeSearch == true)

        let configWithoutSearch = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp"),
            outputDirectory: URL(fileURLWithPath: "/tmp/docs"),
            includeSearch: false
        )
        let builderWithoutSearch = HTMLPageBuilder(configuration: configWithoutSearch)
        #expect(builderWithoutSearch.configuration.includeSearch == false)
    }
}

@Suite("Index Page Builder Tests")
struct IndexPageBuilderTests {
    @Test("Index page builder initialises correctly")
    func indexBuilderInit() {
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp/package"),
            outputDirectory: URL(fileURLWithPath: "/tmp/output")
        )
        let builder = IndexPageBuilder(configuration: config)

        #expect(builder.configuration.packageDirectory.path == "/tmp/package")
    }

    @Test("Module entry stores all fields")
    func moduleEntry() {
        let entry = IndexPageBuilder.ModuleEntry(
            name: "TestModule",
            abstract: "A test module",
            path: "documentation/testmodule/index.html",
            symbolCount: 42
        )

        #expect(entry.name == "TestModule")
        #expect(entry.abstract == "A test module")
        #expect(entry.path == "documentation/testmodule/index.html")
        #expect(entry.symbolCount == 42)
    }

    @Test("Index page contains HTML structure")
    func indexPageStructure() {
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp/mypackage"),
            outputDirectory: URL(fileURLWithPath: "/tmp/docs")
        )
        let builder = IndexPageBuilder(configuration: config)

        let modules = [
            IndexPageBuilder.ModuleEntry(
                name: "TestModule",
                abstract: "Test description",
                path: "documentation/testmodule/index.html",
                symbolCount: 10
            )
        ]

        let html = builder.buildIndexPage(modules: modules)

        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("<html"))
        #expect(html.contains("</html>"))
        #expect(html.contains("TestModule"))
        #expect(html.contains("Test description"))
    }

    @Test("Index page includes search scripts when enabled")
    func indexPageWithSearch() {
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp/package"),
            outputDirectory: URL(fileURLWithPath: "/tmp/docs"),
            includeSearch: true
        )
        let builder = IndexPageBuilder(configuration: config)
        let html = builder.buildIndexPage(modules: [])

        // Search is now via spotlight overlay (activated by '/' key), not a visible form
        #expect(html.contains("js/lunr.min.js"))
        #expect(html.contains("js/search.js"))
    }

    @Test("Index page excludes search form when disabled")
    func indexPageWithoutSearch() {
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp/package"),
            outputDirectory: URL(fileURLWithPath: "/tmp/docs"),
            includeSearch: false
        )
        let builder = IndexPageBuilder(configuration: config)
        let html = builder.buildIndexPage(modules: [])

        #expect(!html.contains("search-form"))
        #expect(!html.contains("js/search.js"))
    }

    @Test("Modules are sorted alphabetically")
    func modulesSorted() {
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp"),
            outputDirectory: URL(fileURLWithPath: "/tmp/docs")
        )
        let builder = IndexPageBuilder(configuration: config)

        let modules = [
            IndexPageBuilder.ModuleEntry(name: "Zebra", abstract: "", path: "", symbolCount: 0),
            IndexPageBuilder.ModuleEntry(name: "Apple", abstract: "", path: "", symbolCount: 0),
            IndexPageBuilder.ModuleEntry(name: "Mango", abstract: "", path: "", symbolCount: 0)
        ]

        let html = builder.buildIndexPage(modules: modules)

        // Check that Apple appears before Mango which appears before Zebra
        let appleIndex = html.range(of: "Apple")!.lowerBound
        let mangoIndex = html.range(of: "Mango")!.lowerBound
        let zebraIndex = html.range(of: "Zebra")!.lowerBound

        #expect(appleIndex < mangoIndex)
        #expect(mangoIndex < zebraIndex)
    }
}
