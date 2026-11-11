//
// SwiftSyntaxHighlighterTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing
@testable import DocCStatic

/// Tests of the static Swift syntax highlighter.
@Suite("Swift Syntax Highlighter Tests")
struct SwiftSyntaxHighlighterTests {
    let highlighter = SwiftSyntaxHighlighter()

    @Test("An imported module is not coloured as a type, like swift-docc-render",
          arguments: ["Foundation", "FixtureCore", "SwiftUI"])
    func importedModule(module: String) {
        let html = highlighter.highlight("import \(module)\n\nlet point = Point()")
        #expect(html.hasPrefix("<span class=\"syntax-keyword\">import</span> \(module)\n"))
        #expect(html.contains("<span class=\"syntax-type\">Point</span>"))
    }

    @Test("An import declaration keeps highlighting its comment")
    func importWithComment() {
        let html = highlighter.highlight("import Foundation // for URL")
        #expect(html == "<span class=\"syntax-keyword\">import</span> Foundation <span class=\"syntax-comment\">// for URL</span>")
    }

    @Test("A type name still starts a type outside import declarations")
    func typeName() {
        let html = highlighter.highlight("var canvas: Canvas")
        #expect(html == "<span class=\"syntax-keyword\">var</span> canvas: <span class=\"syntax-type\">Canvas</span>")
    }
}
