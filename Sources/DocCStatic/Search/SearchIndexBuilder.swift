//
// SearchIndexBuilder.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import SwiftDocC

/// Builds a search index for client-side documentation search.
///
/// This type generates a JSON search index that can be loaded by Lunr.js
/// for fast client-side full-text search.
public struct SearchIndexBuilder: Sendable {
    /// A searchable document entry.
    public struct SearchDocument: Codable, Equatable, Hashable, Sendable {
        /// The unique identifier for this document.
        public let id: String

        /// The document title.
        public let title: String

        /// The document type (symbol, article, tutorial).
        public let type: String

        /// The relative URL path to the document.
        public let path: String

        /// The document's abstract/summary text.
        public let summary: String

        /// Keywords extracted from the content.
        public let keywords: [String]

        /// The parent module or package name.
        public let module: String?

        /// Full text content extracted from the page.
        public let content: String

        /// Creates a new search document.
        public init(
            id: String,
            title: String,
            type: String,
            path: String,
            summary: String,
            keywords: [String],
            module: String?,
            content: String
        ) {
            self.id = id
            self.title = title
            self.type = type
            self.path = path
            self.summary = summary
            self.keywords = keywords
            self.module = module
            self.content = content
        }
    }

    /// The complete search index.
    public struct SearchIndex: Codable, Equatable, Hashable, Sendable {
        /// The index version for compatibility checking.
        public let version: String

        /// The searchable documents.
        public let documents: [SearchDocument]

        /// Field configuration for Lunr.js.
        public let fields: [String]

        /// Creates a new search index.
        public init(version: String = "1.0", documents: [SearchDocument]) {
            self.version = version
            self.documents = documents
            self.fields = ["title", "summary", "keywords", "module", "content"]
        }
    }

    /// The configuration for index building.
    public let configuration: Configuration

    /// Collected documents during processing.
    private var documents: [SearchDocument] = []

    /// Creates a new search index builder.
    ///
    /// - Parameter configuration: The generation configuration.
    public init(configuration: Configuration) {
        self.configuration = configuration
    }
}

// MARK: - Public

public extension SearchIndexBuilder {
    /// Returns  the complete search index.
    ///
    /// This builds and returns the complete search index
    /// for the indexed documents.
    ///
    /// - Returns: The search index ready for serialisation.
    var index: SearchIndex {
        SearchIndex(documents: documents)
    }

    /// Adds a render node to the search index.
    ///
    /// - Parameter renderNode: The render node to index.
    mutating func addToIndex(_ renderNode: RenderNode) {
        let document = createSearchDocument(from: renderNode)
        documents.append(document)
    }

    /// Writes the search index to a file.
    ///
    /// - Parameter url: The output URL for the search index JSON file.
    /// - Throws: An error if writing fails.
    func writeIndex(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(index)
        try data.write(to: url)
    }
}

// MARK: - Private Methods

private extension SearchIndexBuilder {
    func createSearchDocument(from renderNode: RenderNode) -> SearchDocument {
        let id = renderNode.identifier.path
        let title = renderNode.metadata.title ?? extractTitleFromPath(renderNode.identifier.path)
        let type = documentType(for: renderNode.kind)
        let path = pathToHTML(renderNode.identifier.path)
        let summary = extractSummary(from: renderNode)
        let keywords = extractKeywords(from: renderNode)
        let module = extractModule(from: renderNode)
        let content = extractContent(from: renderNode)

        return SearchDocument(
            id: id,
            title: title,
            type: type,
            path: path,
            summary: summary,
            keywords: keywords,
            module: module,
            content: content
        )
    }

    func extractTitleFromPath(_ path: String) -> String {
        path.components(separatedBy: "/").last ?? path
    }

    func documentType(for kind: RenderNode.Kind) -> String {
        switch kind {
        case .symbol:
            return "symbol"
        case .article:
            return "article"
        case .tutorial:
            return "tutorial"
        case .section, .overview:
            return "section"
        @unknown default:
            return "unknown"
        }
    }

    func pathToHTML(_ path: String) -> String {
        let cleanPath = path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        return "\(cleanPath)/index.html"
    }

    func extractSummary(from renderNode: RenderNode) -> String {
        guard let abstract = renderNode.abstract else { return "" }

        var text = ""
        for content in abstract {
            text += extractText(from: content)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extracts all text content from a render node for full-text search.
    func extractContent(from renderNode: RenderNode) -> String {
        var parts: [String] = []

        // Extract from abstract
        if let abstract = renderNode.abstract {
            for content in abstract {
                let text = extractText(from: content)
                if !text.isEmpty { parts.append(text) }
            }
        }

        // Extract from primary content sections
        for section in renderNode.primaryContentSections {
            let sectionText = extractSectionText(from: section)
            if !sectionText.isEmpty { parts.append(sectionText) }
        }

        // Extract from sections array (tutorials, articles)
        for section in renderNode.sections {
            let sectionText = extractSectionText(from: section)
            if !sectionText.isEmpty { parts.append(sectionText) }
        }

        // Extract from topic sections
        for section in renderNode.topicSections {
            if let title = section.title {
                parts.append(title)
            }
        }

        // Limit content length to avoid huge search index
        let joined = parts.joined(separator: " ")
        if joined.count > 5000 {
            return String(joined.prefix(5000))
        }
        return joined
    }

    /// Extracts text from a render section based on its kind.
    func extractSectionText(from section: any RenderSection) -> String {
        switch section.kind {
        case .content, .discussion:
            if let contentSection = section as? ContentRenderSection {
                return contentSection.content.map { extractBlockText(from: $0) }.joined(separator: " ")
            }
        case .hero, .intro:
            if let intro = section as? IntroRenderSection {
                var text = intro.title
                text += " " + intro.content.map { extractBlockText(from: $0) }.joined(separator: " ")
                return text
            }
        case .tasks:
            if let tutorialSection = section as? TutorialSectionsRenderSection {
                var text = ""
                for taskGroup in tutorialSection.tasks {
                    text += taskGroup.title + " "
                    for layout in taskGroup.contentSection {
                        text += extractContentLayoutText(from: layout) + " "
                    }
                    for step in taskGroup.stepsSection {
                        text += extractBlockText(from: step) + " "
                    }
                }
                return text
            }
        case .volume:
            if let volume = section as? VolumeRenderSection {
                var text = volume.name ?? ""
                for chapter in volume.chapters {
                    if let name = chapter.name { text += " " + name }
                    text += " " + chapter.content.map { extractBlockText(from: $0) }.joined(separator: " ")
                }
                return text
            }
        case .articleBody:
            if let articleSection = section as? TutorialArticleSection {
                return articleSection.content.map { extractContentLayoutText(from: $0) }.joined(separator: " ")
            }
        case .contentAndMedia:
            if let camSection = section as? ContentAndMediaSection {
                return camSection.content.map { extractBlockText(from: $0) }.joined(separator: " ")
            }
        case .resources:
            if let resourcesSection = section as? ResourcesRenderSection {
                var text = ""
                for tile in resourcesSection.tiles {
                    text += tile.title + " "
                    text += tile.content.map { extractBlockText(from: $0) }.joined(separator: " ") + " "
                }
                return text
            }
        default:
            break
        }
        return ""
    }

    /// Extracts text from a ContentLayout element.
    func extractContentLayoutText(from layout: ContentLayout) -> String {
        switch layout {
        case .fullWidth(let content):
            return content.map { extractBlockText(from: $0) }.joined(separator: " ")
        case .contentAndMedia(let section):
            return section.content.map { extractBlockText(from: $0) }.joined(separator: " ")
        case .columns(let sections):
            return sections.flatMap { $0.content.map { extractBlockText(from: $0) } }.joined(separator: " ")
        }
    }

    /// Extracts text from a block content element.
    func extractBlockText(from block: RenderBlockContent) -> String {
        switch block {
        case .paragraph(let p):
            return p.inlineContent.map { extractText(from: $0) }.joined()
        case .heading(let h):
            return h.text
        case .aside(let a):
            return a.content.map { extractBlockText(from: $0) }.joined(separator: " ")
        case .codeListing(let c):
            return c.code.joined(separator: " ")
        case .unorderedList(let l):
            return l.items.flatMap { $0.content.map { extractBlockText(from: $0) } }.joined(separator: " ")
        case .orderedList(let l):
            return l.items.flatMap { $0.content.map { extractBlockText(from: $0) } }.joined(separator: " ")
        case .step(let s):
            return s.content.map { extractBlockText(from: $0) }.joined(separator: " ")
        case .table(let t):
            var text = ""
            for row in t.rows {
                for cell in row.cells {
                    for content in cell {
                        text += extractBlockText(from: content) + " "
                    }
                }
            }
            return text
        case .termList(let t):
            var text = ""
            for item in t.items {
                text += extractText(from: item.term.inlineContent) + " "
                text += item.definition.content.map { extractBlockText(from: $0) }.joined(separator: " ") + " "
            }
            return text
        default:
            return ""
        }
    }

    /// Extracts text from an array of inline content.
    func extractText(from contents: [RenderInlineContent]) -> String {
        contents.map { extractText(from: $0) }.joined()
    }

    func extractText(from content: RenderInlineContent) -> String {
        switch content {
        case .text(let text):
            return text
        case .codeVoice(let code):
            return code
        case .emphasis(let children), .strong(let children),
             .strikethrough(let children), .subscript(let children),
             .superscript(let children), .newTerm(let children),
             .inlineHead(let children):
            return children.map { extractText(from: $0) }.joined()
        case .reference(_, _, let title, _):
            return title ?? ""
        case .image(_, _):
            return ""
        }
    }

    func extractKeywords(from renderNode: RenderNode) -> [String] {
        var keywords: [String] = []

        // Add the title words
        if let title = renderNode.metadata.title {
            keywords.append(contentsOf: tokenise(title))
        }

        // Add symbol-specific keywords
        if renderNode.kind == .symbol {
            // Add role information
            if let role = renderNode.metadata.role {
                keywords.append(role)
            }

            // Add fragment tokens from declarations
            for section in renderNode.primaryContentSections {
                if let declarations = section as? DeclarationsRenderSection {
                    for declaration in declarations.declarations {
                        for token in declaration.tokens {
                            if case .identifier = token.kind {
                                keywords.append(token.text)
                            } else if case .typeIdentifier = token.kind {
                                keywords.append(token.text)
                            }
                        }
                    }
                }
            }
        }

        // Add topic section titles
        for section in renderNode.topicSections {
            if let title = section.title {
                keywords.append(contentsOf: tokenise(title))
            }
        }

        return Array(Set(keywords)).filter { !$0.isEmpty }
    }

    func extractModule(from renderNode: RenderNode) -> String? {
        // Extract the module name from the path
        let components = renderNode.identifier.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .components(separatedBy: "/")

        // The module is typically the second component after "documentation"
        if components.count >= 2 && components.first == "documentation" {
            return components[1]
        }
        return components.first
    }

    func tokenise(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
            .map { $0.lowercased() }
    }
}
