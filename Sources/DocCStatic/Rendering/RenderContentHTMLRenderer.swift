//
// RenderContentHTMLRenderer.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import SwiftDocC

/// Renders DocC render content to HTML.
///
/// This type converts `RenderInlineContent` and `RenderBlockContent` from
/// SwiftDocC's render model into HTML strings.
public struct RenderContentHTMLRenderer: Sendable {
    /// The syntax highlighter for Swift code.
    private let swiftHighlighter = SwiftSyntaxHighlighter()
    /// The result of rendering inline content.
    public struct InlineResult: Sendable {
        /// The rendered HTML string.
        public let html: String

        /// The plain text content (for descriptions, etc.).
        public let plainText: String
    }
    /// Creates a new content renderer.
    public init() {}
}

// MARK: - Inline Content Public
public extension RenderContentHTMLRenderer {
    /// Renders an array of inline content elements to HTML.
    ///
    /// - Parameters:
    ///   - content: The inline content to render.
    ///   - references: The references dictionary for resolving links.
    ///   - depth: The depth of the current page for calculating relative URLs.
    /// - Returns: The rendered HTML and plain text.
    func renderInlineContent(
        _ content: [RenderInlineContent],
        references: [String: any RenderReference],
        depth: Int = 0
    ) -> InlineResult {
        var html = ""
        var plainText = ""

        for element in content {
            let result = renderInlineElement(element, references: references, depth: depth)
            html += result.html
            plainText += result.plainText
        }

        return InlineResult(html: html, plainText: plainText)
    }
}

// MARK: - Inline Content Private
private extension RenderContentHTMLRenderer {
    func renderInlineElement(
        _ element: RenderInlineContent,
        references: [String: any RenderReference],
        depth: Int
    ) -> InlineResult {
        switch element {
        case .text(let text):
            return InlineResult(
                html: escapeHTML(text),
                plainText: text
            )

        case .codeVoice(let code):
            return InlineResult(
                html: "<code class=\"inline-code\">\(escapeHTML(code))</code>",
                plainText: code
            )

        case .emphasis(let inlineContent):
            let inner = renderInlineContent(inlineContent, references: references, depth: depth)
            return InlineResult(
                html: "<em>\(inner.html)</em>",
                plainText: inner.plainText
            )

        case .strong(let inlineContent):
            let inner = renderInlineContent(inlineContent, references: references, depth: depth)
            return InlineResult(
                html: "<strong>\(inner.html)</strong>",
                plainText: inner.plainText
            )

        case .strikethrough(let inlineContent):
            let inner = renderInlineContent(inlineContent, references: references, depth: depth)
            return InlineResult(
                html: "<s>\(inner.html)</s>",
                plainText: inner.plainText
            )

        case .subscript(let inlineContent):
            let inner = renderInlineContent(inlineContent, references: references, depth: depth)
            return InlineResult(
                html: "<sub>\(inner.html)</sub>",
                plainText: inner.plainText
            )

        case .superscript(let inlineContent):
            let inner = renderInlineContent(inlineContent, references: references, depth: depth)
            return InlineResult(
                html: "<sup>\(inner.html)</sup>",
                plainText: inner.plainText
            )

        case .newTerm(let inlineContent):
            let inner = renderInlineContent(inlineContent, references: references, depth: depth)
            return InlineResult(
                html: "<dfn>\(inner.html)</dfn>",
                plainText: inner.plainText
            )

        case .inlineHead(let inlineContent):
            let inner = renderInlineContent(inlineContent, references: references, depth: depth)
            return InlineResult(
                html: "<strong class=\"inline-head\">\(inner.html)</strong>",
                plainText: inner.plainText
            )

        case .reference(let identifier, let isActive, let overridingTitle, let overridingTitleInlineContent):
            return renderReference(
                identifier: identifier,
                isActive: isActive,
                overridingTitle: overridingTitle,
                overridingTitleInlineContent: overridingTitleInlineContent,
                references: references,
                depth: depth
            )

        case .image(let identifier, _):
            return renderImage(identifier: identifier, references: references, depth: depth)
        }
    }

    /// The roles of the pages whose titles links show as code, like swift-docc-render's
    /// `ReferenceInternalSymbol`; links to other pages, such as modules, show plain text.
    static let codeTitleRoles: Set<String> = ["symbol", "dictionarySymbol"]

    /// Renders a link to another page or an external URL (swift-docc-render's `Reference`).
    ///
    /// Links are `a.inline-link` elements.  A link to a symbol that keeps the symbol's
    /// own title shows the title as code, like swift-docc-render.  Inactive links
    /// render their title only.
    func renderReference(
        identifier: RenderReferenceIdentifier,
        isActive: Bool,
        overridingTitle: String?,
        overridingTitleInlineContent: [RenderInlineContent]?,
        references: [String: any RenderReference],
        depth: Int
    ) -> InlineResult {
        let topicReference = references[identifier.identifier] as? TopicRenderReference
        let linkReference = references[identifier.identifier] as? LinkReference

        let title: String
        var titleHTML: String
        if let overridingTitleContent = overridingTitleInlineContent {
            let rendered = renderInlineContent(overridingTitleContent, references: references, depth: depth)
            title = rendered.plainText
            titleHTML = rendered.html
        } else if let overriding = overridingTitle {
            title = overriding
            titleHTML = escapeHTML(overriding)
        } else if let topicReference {
            title = topicReference.title
            titleHTML = escapeHTML(topicReference.title)
            if topicReference.kind == .symbol, let role = topicReference.role, Self.codeTitleRoles.contains(role) {
                titleHTML = "<code>\(titleHTML)</code>"
            }
        } else if let linkReference {
            let rendered = renderInlineContent(linkReference.titleInlineContent, references: references, depth: depth)
            title = rendered.plainText.isEmpty ? linkReference.title : rendered.plainText
            titleHTML = rendered.html.isEmpty ? escapeHTML(linkReference.title) : rendered.html
        } else {
            title = identifier.identifier
            titleHTML = escapeHTML(identifier.identifier)
        }

        let url: String? = if let topicReference {
            makeRelativeURL(topicReference.url, depth: depth)
        } else if let linkReference {
            makeRelativeURL(linkReference.url, depth: depth)
        } else {
            nil
        }
        if isActive, let url {
            return InlineResult(
                html: "<a href=\"\(escapeHTML(url))\" class=\"inline-link\">\(titleHTML)</a>",
                plainText: title
            )
        }
        return InlineResult(
            html: "<span class=\"inactive-reference\">\(titleHTML)</span>",
            plainText: title
        )
    }

    func renderImage(
        identifier: RenderReferenceIdentifier,
        references: [String: any RenderReference],
        depth: Int
    ) -> InlineResult {
        if let imageRef = references[identifier.identifier] as? ImageReference {
            let altText = imageRef.altText ?? ""
            // Use the first available asset variant
            if let firstVariant = imageRef.asset.variants.first {
                let src = firstVariant.value.absoluteString
                // Make image paths relative if they start with /
                let relativeSrc = src.hasPrefix("/") ? makeRelativeAssetURL(src, depth: depth) : src
                return InlineResult(
                    html: "<img src=\"\(escapeHTML(relativeSrc))\" alt=\"\(escapeHTML(altText))\">",
                    plainText: altText
                )
            }
        }
        return InlineResult(html: "", plainText: "")
    }

    /// Converts an absolute DocC URL to a relative URL.
    func makeRelativeURL(_ url: String, depth: Int) -> String {
        let cleanPath = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let prefix = String(repeating: "../", count: depth)
        // Don't add index.html for anchors or external URLs
        if url.hasPrefix("#") || url.contains("://") || url.hasPrefix("mailto:") {
            return url
        }
        return "\(prefix)\(cleanPath)/index.html"
    }

    /// Converts an absolute asset URL to a relative URL (no index.html suffix).
    func makeRelativeAssetURL(_ url: String, depth: Int) -> String {
        let cleanPath = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let prefix = String(repeating: "../", count: depth)
        return "\(prefix)\(cleanPath)"
    }
}

// MARK: - Block Content Public

public extension RenderContentHTMLRenderer {
    /// Renders a block content element to HTML.
    ///
    /// - Parameters:
    ///   - block: The block content to render.
    ///   - references: The references dictionary for resolving links.
    ///   - depth: The depth of the current page for calculating relative URLs.
    /// - Returns: The rendered HTML string.
    func renderBlockContent(_ block: RenderBlockContent, references: [String: any RenderReference], depth: Int = 0) -> String {
        switch block {
        case .paragraph(let paragraph):
            let content = renderInlineContent(paragraph.inlineContent, references: references, depth: depth)
            if paragraph.inlineContent.count == 1, case .image = paragraph.inlineContent[0] {
                return "\n        <p class=\"inline-image-container\">\(content.html)</p>"
            }
            return "\n        <p>\(content.html)</p>"

        case .heading(let heading):
            let text = heading.text
            let anchor = heading.anchor ?? slugify(text)
            return "\n        <h\(heading.level) id=\"\(escapeHTML(anchor))\">"
                + Self.headerAnchor(anchor: anchor, title: escapeHTML(text))
                + "</h\(heading.level)>"

        case .aside(let aside):
            return renderAside(aside, references: references, depth: depth)

        case .codeListing(let codeListing):
            return renderCodeListing(codeListing)

        case .unorderedList(let list):
            return renderUnorderedList(list, references: references, depth: depth)

        case .orderedList(let list):
            return renderOrderedList(list, references: references, depth: depth)

        case .table(let table):
            return renderTable(table, references: references, depth: depth)

        case .termList(let termList):
            return renderTermList(termList, references: references, depth: depth)

        case .thematicBreak:
            return "\n        <hr>"

        case .dictionaryExample(let example):
            var html = ""
            for block in example.summary ?? [] {
                html += renderBlockContent(block, references: references, depth: depth)
            }
            return html

        case .step(let tutorialStep):
            return renderTutorialStep(tutorialStep, references: references, depth: depth)

        case .endpointExample, .tabNavigator, .video, .links, .row, .small:
            // These are more complex and will be handled in Phase 6
            return ""

        case ._nonfrozenEnum_useDefaultCase:
            return ""

        @unknown default:
            return ""
        }
    }
}

// MARK: - Heading Anchors

public extension RenderContentHTMLRenderer {
    /// The text that assistive technologies read after a heading's anchor link.
    static let headerAnchorDescription = "in page link"

    /// Builds the link that makes a heading an anchor (swift-docc-render's `LinkableHeading`).
    ///
    /// The link icon after the title appears while the heading is hovered or focused.
    ///
    /// - Parameters:
    ///   - anchor: The identifier of the heading.
    ///   - title: The heading text, already escaped for HTML.
    /// - Returns: The `a.header-anchor` element.
    static func headerAnchor(anchor: String, title: String) -> String {
        "<a href=\"#\(escapeHTML(anchor))\" class=\"header-anchor\" data-after-text=\"\(headerAnchorDescription)\">\(title)"
            + "<svg class=\"icon svg-icon link-icon\" viewBox=\"0 0 20 20\" aria-hidden=\"true\">"
            + "<path d=\"M19.34,4.88L15.12,.66c-.87-.87-2.3-.87-3.17,0l-3.55,3.56-1.38,1.38-1.4,1.4c-.47,.47-.68,1.09-.64,1.7,.02,.29,.09,.58,.21,.84,.11,.23,.24,.44,.43,.63l4.22,4.22h0l.53-.53,.53-.53h0l-4.22-4.22c-.29-.29-.29-.77,0-1.06l1.4-1.4,.91-.91,.58-.58,.55-.55,2.9-2.9c.29-.29,.77-.29,1.06,0l4.22,4.22c.29,.29,.29,.77,0,1.06l-2.9,2.9c.14,.24,.24,.49,.31,.75,.08,.32,.11,.64,.09,.96l3.55-3.55c.87-.87,.87-2.3,0-3.17Z\"/>"
            + "<path d=\"M14.41,9.82s0,0,0,0l-4.22-4.22h0l-.53,.53-.53,.53h0l4.22,4.22c.29,.29,.29,.77,0,1.06l-1.4,1.4-.91,.91-.58,.58-.55,.55h0l-2.9,2.9c-.29,.29-.77,.29-1.06,0L1.73,14.04c-.29-.29-.29-.77,0-1.06l2.9-2.9c-.14-.24-.24-.49-.31-.75-.08-.32-.11-.64-.09-.97L.68,11.93c-.87,.87-.87,2.3,0,3.17l4.22,4.22c.87,.87,2.3,.87,3.17,0l3.55-3.55,1.38-1.38,1.4-1.4c.47-.47,.68-1.09,.64-1.7-.02-.29-.09-.58-.21-.84-.11-.22-.24-.44-.43-.62Z\"/>"
            + "</svg></a>"
    }
}

// MARK: - Block Content Private

private extension RenderContentHTMLRenderer {
    func renderAside(_ aside: RenderBlockContent.Aside, references: [String: any RenderReference], depth: Int) -> String {
        let styleClass = aside.style.rawValue.lowercased()
        let displayName = aside.name

        var html = """

                <aside class="\(styleClass)" aria-label="\(escapeHTML(styleClass))">
                    <p class="label">\(escapeHTML(displayName))</p>
        """

        for block in aside.content {
            html += renderBlockContent(block, references: references, depth: depth)
        }

        html += """

                </aside>
        """

        return html
    }

    func renderCodeListing(_ codeListing: RenderBlockContent.CodeListing) -> String {
        let language = codeListing.syntax ?? "swift"
        let code = codeListing.code.joined(separator: "\n")

        // Apply syntax highlighting for Swift code
        let highlightedCode: String
        if language.lowercased() == "swift" {
            highlightedCode = swiftHighlighter.highlight(code)
        } else {
            highlightedCode = escapeHTML(code)
        }

        // One line container per line, like swift-docc-render's `CodeListing`
        let lines = highlightedCode.components(separatedBy: "\n").map {
            "<span class=\"code-line-container\"><span class=\"code-line\">\($0)</span></span>"
        }
        return """

                <div class="code-listing" data-syntax="\(escapeHTML(language))">\
        <div class="container-general"><pre class="language-\(escapeHTML(language))"><code>\(lines.joined(separator: "\n"))
        </code></pre></div></div>
        """
    }

    func renderUnorderedList(
        _ list: RenderBlockContent.UnorderedList,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = "\n        <ul>"

        for item in list.items {
            html += "\n            <li>"
            for block in item.content {
                html += renderBlockContent(block, references: references, depth: depth)
            }
            html += "</li>"
        }

        html += "\n        </ul>"
        return html
    }

    func renderOrderedList(
        _ list: RenderBlockContent.OrderedList,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        let startAttr = list.startIndex != 1 ? " start=\"\(list.startIndex)\"" : ""
        var html = "\n        <ol\(startAttr)>"

        for item in list.items {
            html += "\n            <li>"
            for block in item.content {
                html += renderBlockContent(block, references: references, depth: depth)
            }
            html += "</li>"
        }

        html += "\n        </ol>"
        return html
    }

    func renderTable(
        _ table: RenderBlockContent.Table,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = "\n        <div class=\"table-wrapper\"><table>"

        // Header row
        if let headerRow = table.rows.first {
            html += "\n            <thead>\n                <tr>"
            for cell in headerRow.cells {
                html += "\n                    <th scope=\"col\">"
                for block in cell {
                    html += renderBlockContent(block, references: references, depth: depth)
                }
                html += "</th>"
            }
            html += "\n                </tr>\n            </thead>"
        }

        // Body rows
        if table.rows.count > 1 {
            html += "\n            <tbody>"
            for row in table.rows.dropFirst() {
                html += "\n                <tr>"
                for cell in row.cells {
                    html += "\n                    <td>"
                    for block in cell {
                        html += renderBlockContent(block, references: references, depth: depth)
                    }
                    html += "</td>"
                }
                html += "\n                </tr>"
            }
            html += "\n            </tbody>"
        }

        html += "\n        </table></div>"
        return html
    }

    func renderTermList(
        _ termList: RenderBlockContent.TermList,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = "\n        <dl>"

        for item in termList.items {
            let termContent = renderInlineContent(item.term.inlineContent, references: references, depth: depth)
            html += "\n            <dt>\(termContent.html)</dt>"
            html += "\n            <dd>"
            for block in item.definition.content {
                html += renderBlockContent(block, references: references, depth: depth)
            }
            html += "</dd>"
        }

        html += "\n        </dl>"
        return html
    }

    func renderTutorialStep(
        _ step: RenderBlockContent.TutorialStep,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = ""

        // Render the step content (description)
        for block in step.content {
            html += renderBlockContent(block, references: references, depth: depth)
        }

        // Render media (image/video) if present
        if let mediaIdentifier = step.media,
           let mediaRef = references[mediaIdentifier.identifier] as? ImageReference {
            // Use the first available asset variant
            if let firstVariant = mediaRef.asset.variants.first {
                let src = firstVariant.value.absoluteString
                let relativeSrc = src.hasPrefix("/") ? makeRelativeAssetURL(src, depth: depth) : src
                let altText = mediaRef.altText ?? ""
                html += """

                    <div class="step-media">
                        <img src="\(escapeHTML(relativeSrc))" alt="\(escapeHTML(altText))">
                    </div>
            """
            }
        }

        // Render code reference if present
        if let codeIdentifier = step.code,
           let codeRef = references[codeIdentifier.identifier] as? FileReference {
            let language = codeRef.syntax
            let code = codeRef.content.joined(separator: "\n")
            // Apply syntax highlighting for Swift code
            let highlightedCode: String
            if language.lowercased() == "swift" {
                highlightedCode = swiftHighlighter.highlight(code)
            } else {
                highlightedCode = escapeHTML(code)
            }
            html += """

                    <div class="step-code">
                        <p class="code-file-name">\(escapeHTML(codeRef.fileName))</p>
                        <pre class="language-\(language)"><code>\(highlightedCode)</code></pre>
                    </div>
            """
        }

        // Render caption if present
        if !step.caption.isEmpty {
            html += "\n            <div class=\"step-caption\">"
            for block in step.caption {
                html += renderBlockContent(block, references: references, depth: depth)
            }
            html += "\n            </div>"
        }

        return html
    }
}

// MARK: - Utilities

/// Converts a string to a URL-friendly slug.
func slugify(_ string: String) -> String {
    string
        .lowercased()
        .replacingOccurrences(of: " ", with: "-")
        .filter { $0.isLetter || $0.isNumber || $0 == "-" }
}
