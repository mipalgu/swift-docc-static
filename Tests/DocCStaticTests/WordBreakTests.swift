//
// WordBreakTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import SwiftDocC
import Testing

@testable import DocCStatic

/// Tests of the word break opportunities in long names (swift-docc-render's `WordBreak`).
@Suite("Word Breaks")
struct WordBreakTests {
    @Test("Breaks follow swift-docc-render's default boundaries", arguments: [
        ("fooBarBaz", "foo<wbr>Bar<wbr>Baz"),
        ("foo:bar:baz:", "foo:<wbr>bar:<wbr>baz:"),
        ("Foo.Bar.Baz", "Foo<wbr>.Bar<wbr>.Baz"),
        ("foo_bar_baz", "foo<wbr>_bar<wbr>_baz"),
        ("foobarbaz", "foobarbaz"),
        ("init(x:y:)", "init(x:<wbr>y:)"),
        ("a:bC", "a:<wbr>bC"),
        ("URLSession", "URLSession"),
        ("", ""),
    ])
    func boundaries(text: String, expected: String) {
        #expect(WordBreak.markup(text) == expected)
    }

    @Test("Text between the breaks is escaped")
    func escaping() {
        #expect(WordBreak.markup("a<b.c") == "a&lt;b<wbr>.c")
        #expect(WordBreak.markup("Array<Element>.first") == "Array&lt;Element&gt;.first")
        #expect(WordBreak.markup("a & b") == "a &amp; b")
    }

    @Test("Non-ASCII letters are never break boundaries")
    func nonASCII() {
        #expect(WordBreak.markup("éÉ.ü") == "éÉ.ü")
    }

    @Test("Inline code gets word breaks")
    func inlineCode() {
        let html = RenderContentHTMLRenderer().renderInlineContent(
            [.codeVoice(code: "GenerationError.modelNotFound")], references: [:]
        ).html
        #expect(html == "<code class=\"inline-code\">Generation<wbr>Error<wbr>.model<wbr>Not<wbr>Found</code>")
    }

    @Test("Decorated titles break inside and after every token")
    func decoratedTitle() {
        let tokens: [DeclarationRenderSection.Token] = [
            .init(text: "func", kind: .keyword),
            .init(text: " ", kind: .text),
            .init(text: "addPrefix", kind: .identifier),
            .init(text: "(", kind: .text),
        ]
        let html = renderDecoratedTitle(tokens)
        #expect(html.contains("<span class=\"decorator\">func</span><wbr>"))
        #expect(html.contains("<span class=\"decorator empty-token\"> </span><wbr>"))
        #expect(html.contains("<span class=\"identifier\">add<wbr>Prefix</span><wbr>"))
        #expect(html.hasSuffix("<span class=\"decorator\">(</span><wbr></code>"))
    }
}
