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

        /// Creates a new search document.
        public init(
            id: String,
            title: String,
            type: String,
            path: String,
            summary: String,
            keywords: [String],
            module: String?
        ) {
            self.id = id
            self.title = title
            self.type = type
            self.path = path
            self.summary = summary
            self.keywords = keywords
            self.module = module
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
            self.fields = ["title", "summary", "keywords", "module"]
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

        return SearchDocument(
            id: id,
            title: title,
            type: type,
            path: path,
            summary: summary,
            keywords: keywords,
            module: module
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
