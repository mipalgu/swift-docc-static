//
// TutorialRenderingTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 4/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Testing
import Foundation
import SwiftDocC
@testable import DocCStatic

@Suite("Tutorial Step Rendering Tests")
struct TutorialStepRenderingTests {
    let renderer = RenderContentHTMLRenderer()

    @Test("Renders step with content")
    func stepWithContent() {
        let step = RenderBlockContent.step(.init(
            content: [
                .paragraph(.init(inlineContent: [.text("Create a new file.")]))
            ],
            caption: []
        ))

        let html = renderer.renderBlockContent(step, references: [:], depth: 0)

        #expect(html.contains("Create a new file."))
        #expect(html.contains("<p>"))
    }

    @Test("Renders step with caption")
    func stepWithCaption() {
        let step = RenderBlockContent.step(.init(
            content: [
                .paragraph(.init(inlineContent: [.text("Step description")]))
            ],
            caption: [
                .paragraph(.init(inlineContent: [.text("This is the caption explaining the step.")]))
            ]
        ))

        let html = renderer.renderBlockContent(step, references: [:], depth: 0)

        #expect(html.contains("Step description"))
        #expect(html.contains("This is the caption"))
        #expect(html.contains("step-caption"))
    }

    @Test("Renders step with code reference")
    func stepWithCodeReference() {
        let codeRef = FileReference(
            identifier: RenderReferenceIdentifier("test-code"),
            fileName: "Example.swift",
            fileType: "swift",
            syntax: "swift",
            content: [
                "import Foundation",
                "",
                "struct Example {",
                "    let value: Int",
                "}"
            ]
        )

        let step = RenderBlockContent.step(.init(
            content: [
                .paragraph(.init(inlineContent: [.text("Add the following code:")]))
            ],
            caption: [],
            code: RenderReferenceIdentifier("test-code")
        ))

        let references: [String: any RenderReference] = [
            "test-code": codeRef
        ]

        let html = renderer.renderBlockContent(step, references: references, depth: 0)

        #expect(html.contains("Add the following code:"))
        #expect(html.contains("step-code"))
        #expect(html.contains("Example.swift"))
        // Code gets syntax highlighted, so check for the highlighted version
        #expect(html.contains("syntax-keyword"))
        #expect(html.contains("Foundation"))
        #expect(html.contains("Example"))
        #expect(html.contains("language-swift"))
    }

    @Test("Renders step without optional fields")
    func stepMinimal() {
        let step = RenderBlockContent.step(.init(
            content: [
                .paragraph(.init(inlineContent: [.text("Simple step")]))
            ],
            caption: []
        ))

        let html = renderer.renderBlockContent(step, references: [:], depth: 0)

        #expect(html.contains("Simple step"))
        #expect(!html.contains("step-code"))
        #expect(!html.contains("step-caption"))
        #expect(!html.contains("step-media"))
    }

    @Test("Step content escapes HTML entities")
    func stepEscapesHTML() {
        let step = RenderBlockContent.step(.init(
            content: [
                .paragraph(.init(inlineContent: [.text("Use <T> for generics & protocols")]))
            ],
            caption: []
        ))

        let html = renderer.renderBlockContent(step, references: [:], depth: 0)

        #expect(html.contains("&lt;T&gt;"))
        #expect(html.contains("&amp;"))
        #expect(!html.contains("<T>"))
    }

    @Test("Multiple steps render correctly")
    func multipleSteps() {
        let steps: [RenderBlockContent] = [
            .step(.init(
                content: [.paragraph(.init(inlineContent: [.text("First step")]))],
                caption: []
            )),
            .step(.init(
                content: [.paragraph(.init(inlineContent: [.text("Second step")]))],
                caption: []
            )),
            .step(.init(
                content: [.paragraph(.init(inlineContent: [.text("Third step")]))],
                caption: []
            ))
        ]

        var allHtml = ""
        for step in steps {
            allHtml += renderer.renderBlockContent(step, references: [:], depth: 0)
        }

        #expect(allHtml.contains("First step"))
        #expect(allHtml.contains("Second step"))
        #expect(allHtml.contains("Third step"))
    }

    @Test("Step with inline code renders correctly")
    func stepWithInlineCode() {
        let step = RenderBlockContent.step(.init(
            content: [
                .paragraph(.init(inlineContent: [
                    .text("Call the "),
                    .codeVoice(code: "validate()"),
                    .text(" method.")
                ]))
            ],
            caption: []
        ))

        let html = renderer.renderBlockContent(step, references: [:], depth: 0)

        #expect(html.contains("<code>validate()</code>"))
        #expect(html.contains("Call the"))
        #expect(html.contains("method."))
    }
}

@Suite("Tutorial Content Rendering Tests")
struct TutorialContentRenderingTests {
    let renderer = RenderContentHTMLRenderer()

    @Test("Paragraph renders correctly")
    func paragraphRendering() {
        let content = RenderBlockContent.paragraph(.init(
            inlineContent: [.text("This is a paragraph.")]
        ))

        let html = renderer.renderBlockContent(content, references: [:], depth: 0)

        #expect(html.contains("<p>"))
        #expect(html.contains("This is a paragraph."))
        #expect(html.contains("</p>"))
    }

    @Test("Code block renders with syntax class")
    func codeBlockRendering() {
        let content = RenderBlockContent.codeListing(.init(
            syntax: "swift",
            code: ["let x = 42", "print(x)"],
            metadata: nil,
            options: nil
        ))

        let html = renderer.renderBlockContent(content, references: [:], depth: 0)

        #expect(html.contains("language-swift"))
        // Code gets syntax highlighted, so check for the highlighted parts
        #expect(html.contains("syntax-keyword"))  // "let" is highlighted
        #expect(html.contains("syntax-number"))   // "42" is highlighted
        #expect(html.contains("print"))
    }

    @Test("Ordered list renders correctly")
    func orderedListRendering() {
        let content = RenderBlockContent.orderedList(.init(
            items: [
                .init(content: [.paragraph(.init(inlineContent: [.text("First item")]))]),
                .init(content: [.paragraph(.init(inlineContent: [.text("Second item")]))])
            ]
        ))

        let html = renderer.renderBlockContent(content, references: [:], depth: 0)

        #expect(html.contains("<ol>"))
        #expect(html.contains("<li>"))
        #expect(html.contains("First item"))
        #expect(html.contains("Second item"))
        #expect(html.contains("</ol>"))
    }

    @Test("Unordered list renders correctly")
    func unorderedListRendering() {
        let content = RenderBlockContent.unorderedList(.init(
            items: [
                .init(content: [.paragraph(.init(inlineContent: [.text("Bullet one")]))]),
                .init(content: [.paragraph(.init(inlineContent: [.text("Bullet two")]))])
            ]
        ))

        let html = renderer.renderBlockContent(content, references: [:], depth: 0)

        #expect(html.contains("<ul>"))
        #expect(html.contains("<li>"))
        #expect(html.contains("Bullet one"))
        #expect(html.contains("Bullet two"))
        #expect(html.contains("</ul>"))
    }
}
