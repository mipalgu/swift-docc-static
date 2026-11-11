//
// NavigationSidebarTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 24/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Testing
import Foundation
@testable import DocCStatic

@Suite("NavigationNode Badge Tests")
struct NavigationNodeBadgeTests {
    @Test("Struct node has 'S' badge")
    func structBadge() {
        let nodeType = NodeType.struct
        #expect(nodeType.badgeCharacter == "S")
        #expect(nodeType.showsBadge == true)
        #expect(nodeType.badgeClass == "badge-struct")
    }

    @Test("Class node has 'C' badge")
    func classBadge() {
        let nodeType = NodeType.class
        #expect(nodeType.badgeCharacter == "C")
        #expect(nodeType.showsBadge == true)
        #expect(nodeType.badgeClass == "badge-class")
    }

    @Test("Enum node has 'E' badge")
    func enumBadge() {
        let nodeType = NodeType.enum
        #expect(nodeType.badgeCharacter == "E")
        #expect(nodeType.showsBadge == true)
        #expect(nodeType.badgeClass == "badge-enum")
    }

    @Test("Protocol node has 'Pr' badge")
    func protocolBadge() {
        let nodeType = NodeType.protocol
        #expect(nodeType.badgeCharacter == "Pr")
        #expect(nodeType.showsBadge == true)
        #expect(nodeType.badgeClass == "badge-protocol")
    }

    @Test("Function node has 'M' badge")
    func funcBadge() {
        let nodeType = NodeType.func
        #expect(nodeType.badgeCharacter == "M")
        #expect(nodeType.showsBadge == true)
        #expect(nodeType.badgeClass == "badge-func")
    }

    @Test("Property node has 'P' badge")
    func propertyBadge() {
        let nodeType = NodeType.property
        #expect(nodeType.badgeCharacter == "P")
        #expect(nodeType.showsBadge == true)
        #expect(nodeType.badgeClass == "badge-var")
    }

    @Test("Initialiser node has 'M' badge")
    func initBadge() {
        let nodeType = NodeType(rawValue: "init")
        #expect(nodeType.badgeCharacter == "M")
        #expect(nodeType.showsBadge == true)
        #expect(nodeType.badgeClass == "badge-func")
    }

    @Test("Var node has 'P' badge")
    func varBadge() {
        let nodeType = NodeType.var
        #expect(nodeType.badgeCharacter == "P")
        #expect(nodeType.showsBadge == true)
        #expect(nodeType.badgeClass == "badge-var")
    }

    @Test("Article node has no badge")
    func articleNoBadge() {
        let nodeType = NodeType.article
        #expect(nodeType.showsBadge == false)
        #expect(nodeType.iconSVG != nil) // Should have icon instead
    }
}

@Suite("NavigationSidebarBuilder Tests")
struct NavigationSidebarBuilderTests {
    @Test("NavigationSidebarBuilder can be initialised")
    func builderInitialises() {
        let navigationIndex = NavigationIndex(
            schemaVersion: nil,
            includedArchiveIdentifiers: nil,
            interfaceLanguages: [:]
        )

        let builder = NavigationSidebarBuilder(navigationIndex: navigationIndex)
        // Simply verify it can be created without error
        _ = builder
    }

    @Test("Fallback sidebar renders without errors")
    func fallbackSidebarRenders() {
        let navigationIndex = NavigationIndex(
            schemaVersion: nil,
            includedArchiveIdentifiers: nil,
            interfaceLanguages: ["swift": []]
        )

        _ = navigationIndex
        let html = NavigationSidebarBuilder.buildFallbackSidebar()

        // Should contain basic sidebar structure
        #expect(html.contains("<nav class=\"sidebar\""))
        #expect(html.contains("sidebar-content"))
    }

    @Test("Module type has correct badge properties")
    func moduleBadge() {
        let nodeType = NodeType.module
        #expect(nodeType.badgeCharacter == "Mo")
        #expect(nodeType.showsBadge == true)
        #expect(nodeType.badgeClass == "badge-module")
    }

    @Test("Typealias type has correct badge properties")
    func typealiasBadge() {
        let nodeType = NodeType.typealias
        #expect(nodeType.badgeCharacter == "T")
        #expect(nodeType.showsBadge == true)
        #expect(nodeType.badgeClass == "badge-typealias")
    }

    @Test("Navigator card has depth-spacer element")
    func depthSpacerGeneration() {
        let childNode = NavigationNode(
            title: "TestStruct",
            path: "/documentation/test/teststruct",
            type: "struct",
            children: [],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let moduleNode = NavigationNode(
            title: "Test",
            path: "/documentation/test",
            type: "module",
            children: [childNode],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let navigationIndex = NavigationIndex(
            schemaVersion: nil,
            includedArchiveIdentifiers: nil,
            interfaceLanguages: ["swift": [moduleNode]]
        )

        var builder = NavigationSidebarBuilder(navigationIndex: navigationIndex)
        let html = builder.buildNavigationTree()

        // Should contain depth-spacer div
        #expect(html.contains("<div class=\"depth-spacer\">"))
    }

    @Test("Navigator card has nesting-index CSS variable")
    func nestingIndexVariable() {
        let child = NavigationNode(
            title: "InnerStruct",
            path: "/documentation/test/innerstruct",
            type: "struct",
            children: [],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let parent = NavigationNode(
            title: "ParentStruct",
            path: "/documentation/test/parentstruct",
            type: "struct",
            children: [child],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let moduleNode = NavigationNode(
            title: "Test",
            path: "/documentation/test",
            type: "module",
            children: [parent],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let navigationIndex = NavigationIndex(
            schemaVersion: nil,
            includedArchiveIdentifiers: nil,
            interfaceLanguages: ["swift": [moduleNode]]
        )

        var builder = NavigationSidebarBuilder(navigationIndex: navigationIndex)
        let html = builder.buildNavigationTree()

        // Should contain nesting-index CSS variable
        #expect(html.contains("--nesting-index:"))
    }

    @Test("Navigator card has disclosure chevron")
    func disclosureChevron() {
        let child = NavigationNode(
            title: "ChildStruct",
            path: "/documentation/test/childstruct",
            type: "struct",
            children: [],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let parent = NavigationNode(
            title: "ParentStruct",
            path: "/documentation/test/parentstruct",
            type: "struct",
            children: [child],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let moduleNode = NavigationNode(
            title: "Test",
            path: "/documentation/test",
            type: "module",
            children: [parent],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let navigationIndex = NavigationIndex(
            schemaVersion: nil,
            includedArchiveIdentifiers: nil,
            interfaceLanguages: ["swift": [moduleNode]]
        )

        var builder = NavigationSidebarBuilder(navigationIndex: navigationIndex)
        let html = builder.buildNavigationTree()

        // Should contain disclosure chevron elements
        #expect(html.contains("disclosure-checkbox"))
        #expect(html.contains("tree-toggle"))
        #expect(html.contains("expandable"))
    }

    @Test("Navigator badge uses correct CSS classes")
    func badgeCSSClasses() {
        let childNode = NavigationNode(
            title: "TestStruct",
            path: "/documentation/test/teststruct",
            type: "struct",
            children: [],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let moduleNode = NavigationNode(
            title: "Test",
            path: "/documentation/test",
            type: "module",
            children: [childNode],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let navigationIndex = NavigationIndex(
            schemaVersion: nil,
            includedArchiveIdentifiers: nil,
            interfaceLanguages: ["swift": [moduleNode]]
        )

        var builder = NavigationSidebarBuilder(navigationIndex: navigationIndex)
        let html = builder.buildNavigationTree()

        // Should contain the topic type icon of a structure, a framed S
        #expect(html.contains("class=\"TopicTypeIcon navigator-icon\""))
        #expect(html.contains("data-topic-type=\"struct\""))
        #expect(html.contains("<tspan>S</tspan>"))
    }

    @Test("Nesting index increments with depth")
    func nestingIndexIncrement() {
        let grandchild = NavigationNode(
            title: "GrandchildStruct",
            path: "/documentation/test/grandchildstruct",
            type: "struct",
            children: [],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let child = NavigationNode(
            title: "ChildStruct",
            path: "/documentation/test/childstruct",
            type: "struct",
            children: [grandchild],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let parent = NavigationNode(
            title: "ParentStruct",
            path: "/documentation/test/parentstruct",
            type: "struct",
            children: [child],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let moduleNode = NavigationNode(
            title: "Test",
            path: "/documentation/test",
            type: "module",
            children: [parent],
            isDeprecated: nil,
            isExternal: nil,
            isBeta: nil
        )

        let navigationIndex = NavigationIndex(
            schemaVersion: nil,
            includedArchiveIdentifiers: nil,
            interfaceLanguages: ["swift": [moduleNode]]
        )

        var builder = NavigationSidebarBuilder(navigationIndex: navigationIndex)
        let html = builder.buildNavigationTree()

        // Should contain different nesting levels
        #expect(html.contains("--nesting-index: 0"))
        #expect(html.contains("--nesting-index: 1") || html.contains("--nesting-index: 2"))
    }
}
