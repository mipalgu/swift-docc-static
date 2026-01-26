//
// HTMLRenderingCompatibilityTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 27/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Testing
import Foundation
import SwiftDocC
@testable import DocCStatic

/// Tests to verify HTML rendering matches swift-docc-render structure
@Suite("HTML Rendering Compatibility Tests")
struct HTMLRenderingCompatibilityTests {

    // MARK: - Code Listing Wrapper Structure

    @Test("Code blocks are wrapped in .code-listing div")
    func codeBlocks_haveCodeListingWrapper() async throws {
        let renderer = RenderContentHTMLRenderer()

        let codeListing = RenderBlockContent.codeListing(
            RenderBlockContent.CodeListing(syntax: "swift", code: ["let x = 42"], metadata: nil, options: nil)
        )

        let html = renderer.renderBlockContent(codeListing, references: [:], depth: 0)

        #expect(html.contains("<div class=\"code-listing\""),
                "Code blocks must be wrapped in .code-listing div")
        #expect(html.contains("<div class=\"container-general\">"),
                "Code blocks must contain .container-general div")
        #expect(html.contains("<pre class=\"language-swift\"><code>"),
                "Code blocks must contain pre and code elements")
    }

    @Test("Code listing wrapper has data-syntax attribute")
    func codeListing_hasDataSyntaxAttribute() async throws {
        let renderer = RenderContentHTMLRenderer()

        let codeListing = RenderBlockContent.codeListing(
            RenderBlockContent.CodeListing(syntax: "swift", code: ["func test() {}"], metadata: nil, options: nil)
        )

        let html = renderer.renderBlockContent(codeListing, references: [:], depth: 0)

        #expect(html.contains("data-syntax=\"swift\""),
                "Code listing wrapper must have data-syntax attribute with language")
    }

    @Test("Code listing contains .container-general div")
    func codeListing_hasContainerGeneralDiv() async throws {
        let renderer = RenderContentHTMLRenderer()

        let codeListing = RenderBlockContent.codeListing(
            RenderBlockContent.CodeListing(syntax: "python", code: ["print('hello')"], metadata: nil, options: nil)
        )

        let html = renderer.renderBlockContent(codeListing, references: [:], depth: 0)

        #expect(html.contains("<div class=\"container-general\">"),
                "Code listing must contain .container-general wrapper div")
    }

    // MARK: - Navigation Sidebar Structure

    @Test("Single-module sidebar has NO Documentation heading (avoids duplicate)")
    func singleModuleSidebar_noDocumentationHeading() async throws {
        var builder = NavigationSidebarBuilder(navigationIndex: createTestNavigationIndex())

        let html = builder.buildSidebar(
            moduleName: "TestModule",
            currentPath: "/documentation/testmodule",
            depth: 0
        )

        // Single module view should NOT have "Documentation" heading
        // (it already has the module title as h2)
        #expect(!html.contains("<h2 class=\"nav-title\">Documentation</h2>"),
                "Single-module sidebar must NOT have Documentation heading (avoids duplicate h2)")
    }

    @Test("Multi-module sidebar shows ALL module links")
    func multiModuleSidebar_showsAllModules() async throws {
        // Create navigation index with multiple modules
        let multiModuleIndex = createMultiModuleNavigationIndex()
        var builder = NavigationSidebarBuilder(navigationIndex: multiModuleIndex)

        let html = builder.buildSidebar(
            moduleName: "ModuleA",
            currentPath: "/documentation/modulea",
            depth: 0
        )

        // Should contain current module
        #expect(html.contains("ModuleA"),
                "Sidebar must show current module")

        // MUST also contain other modules (docc-static multi-module support)
        #expect(html.contains("ModuleB"),
                "Sidebar MUST show links to other modules in multi-module documentation")
    }

    @Test("Multi-module sidebar has NO duplicate Documentation headings")
    func multiModuleSidebar_noDuplicateHeadings() async throws {
        let multiModuleIndex = createMultiModuleNavigationIndex()
        var builder = NavigationSidebarBuilder(navigationIndex: multiModuleIndex)

        let html = builder.buildSidebar(
            moduleName: "ModuleA",
            currentPath: "/documentation/modulea",
            depth: 0
        )

        // Count occurrences of "Documentation" heading
        let documentationHeadingCount = html.components(separatedBy: "<h2 class=\"nav-title\">Documentation</h2>").count - 1

        #expect(documentationHeadingCount <= 1,
                "Must have at most ONE Documentation heading, not multiple")
    }

    @Test("Document links use leaf-link class")
    func documentLinks_useLeafLinkClass() async throws {
        var builder = NavigationSidebarBuilder(navigationIndex: createTestNavigationIndex())

        let html = builder.buildSidebar(
            moduleName: "TestModule",
            currentPath: "/documentation/testmodule",
            depth: 0
        )

        #expect(html.contains("class=\"leaf-link\""),
                "Document links must use .leaf-link class to match swift-docc-render")
        #expect(!html.contains("class=\"nav-link\""),
                "Document links should not use .nav-link class (use .leaf-link instead)")
    }

    // MARK: - Helper Methods

    private func createTestNavigationIndex() -> NavigationIndex {
        let moduleNode = NavigationNode(
            title: "TestModule",
            path: "/documentation/testmodule",
            type: "module",
            children: [
                NavigationNode(
                    title: "Getting Started",
                    path: "/documentation/testmodule/gettingstarted",
                    type: "article",
                    children: nil,
                    isDeprecated: nil,
                    isExternal: nil,
                    isBeta: nil
                )
            ],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        // Create navigation index from JSON
        let json = """
        {
            "interfaceLanguages": {
                "swift": [\(encodeNode(moduleNode))]
            }
        }
        """

        let decoder = JSONDecoder()
        return try! decoder.decode(NavigationIndex.self, from: json.data(using: .utf8)!)
    }

    private func createMultiModuleNavigationIndex() -> NavigationIndex {
        let moduleA = NavigationNode(
            title: "ModuleA",
            path: "/documentation/modulea",
            type: "module",
            children: [],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let moduleB = NavigationNode(
            title: "ModuleB",
            path: "/documentation/moduleb",
            type: "module",
            children: [],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        // Create navigation index from JSON
        let json = """
        {
            "interfaceLanguages": {
                "swift": [\(encodeNode(moduleA)), \(encodeNode(moduleB))]
            }
        }
        """

        let decoder = JSONDecoder()
        return try! decoder.decode(NavigationIndex.self, from: json.data(using: .utf8)!)
    }

    private func encodeNode(_ node: NavigationNode) -> String {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(node)
        return String(data: data, encoding: .utf8)!
    }
}
