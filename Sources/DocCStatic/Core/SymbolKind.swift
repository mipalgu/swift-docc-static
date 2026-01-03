//
// SymbolKind.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
@preconcurrency import SwiftDocC

/// A symbol kind for documentation display, wrapping `DocumentationNode.Kind`.
///
/// This type provides convenient access to symbol kinds for rendering badges
/// and categorising symbols in the documentation output.
public struct SymbolKind: Hashable, CaseIterable, Identifiable, RawRepresentable, @unchecked Sendable {
    /// The underlying documentation node kind.
    public let kind: DocumentationNode.Kind

    /// The unique identifier for this symbol kind.
    public var id: String { kind.id }

    /// The raw value (name) of this symbol kind.
    public var rawValue: String { kind.name }

    /// The display name for this symbol kind.
    public var name: String { kind.name }

    /// Whether this kind represents a symbol (as opposed to an article or tutorial).
    public var isSymbol: Bool { kind.isSymbol }

    // MARK: - RawRepresentable

    /// Creates a symbol kind from a raw value (name).
    ///
    /// - Parameter rawValue: The name of the documentation node kind.
    public init?(rawValue: String) {
        guard let match = DocumentationNode.Kind.allKnownValues.first(where: { $0.name == rawValue }) else {
            return nil
        }
        self.kind = match
    }

    // MARK: - Initialisers

    /// Creates a symbol kind from a `DocumentationNode.Kind`.
    ///
    /// - Parameter kind: The documentation node kind.
    public init(_ kind: DocumentationNode.Kind) {
        self.kind = kind
    }

    /// Creates a symbol kind from an identifier string.
    ///
    /// - Parameter id: The identifier of the documentation node kind.
    public init?(id: String) {
        guard let match = DocumentationNode.Kind.allKnownValues.first(where: { $0.id == id }) else {
            return nil
        }
        self.kind = match
    }

    /// Creates a symbol kind from a keyword string (e.g., "struct", "class", "enum").
    ///
    /// - Parameter keyword: The Swift keyword for the symbol type.
    public init?(keyword: String) {
        switch keyword.lowercased() {
        case "struct", "structure":
            self.kind = .structure
        case "class":
            self.kind = .class
        case "enum", "enumeration":
            self.kind = .enumeration
        case "protocol":
            self.kind = .protocol
        case "func", "function":
            self.kind = .function
        case "var", "variable":
            self.kind = .globalVariable
        case "let", "constant":
            self.kind = .globalVariable
        case "typealias":
            self.kind = .typeAlias
        case "associatedtype":
            self.kind = .associatedType
        case "init", "initializer":
            self.kind = .initializer
        case "deinit", "deinitializer":
            self.kind = .deinitializer
        case "subscript":
            self.kind = .instanceSubscript
        case "operator":
            self.kind = .operator
        case "macro":
            self.kind = .macro
        case "case":
            self.kind = .enumerationCase
        case "extension":
            self.kind = .extension
        case "module":
            self.kind = .module
        case "article":
            self.kind = .article
        case "tutorial":
            self.kind = .tutorial
        default:
            return nil
        }
    }

    // MARK: - CaseIterable

    /// All known symbol kinds.
    public static var allCases: [SymbolKind] {
        DocumentationNode.Kind.allKnownValues.map { SymbolKind($0) }
    }

    // MARK: - Predefined Kinds

    // Grouping
    public static let landingPage = SymbolKind(.landingPage)
    public static let collection = SymbolKind(.collection)
    public static let collectionGroup = SymbolKind(.collectionGroup)

    // Conceptual
    public static let root = SymbolKind(.root)
    public static let module = SymbolKind(.module)
    public static let article = SymbolKind(.article)
    public static let sampleCode = SymbolKind(.sampleCode)
    public static let tutorial = SymbolKind(.tutorial)
    public static let tutorialArticle = SymbolKind(.tutorialArticle)

    // Containers
    public static let `class` = SymbolKind(.class)
    public static let structure = SymbolKind(.structure)
    public static let enumeration = SymbolKind(.enumeration)
    public static let `protocol` = SymbolKind(.protocol)
    public static let `extension` = SymbolKind(.extension)
    public static let dictionary = SymbolKind(.dictionary)
    public static let namespace = SymbolKind(.namespace)

    // Leaves
    public static let globalVariable = SymbolKind(.globalVariable)
    public static let typeAlias = SymbolKind(.typeAlias)
    public static let associatedType = SymbolKind(.associatedType)
    public static let function = SymbolKind(.function)
    public static let `operator` = SymbolKind(.operator)
    public static let macro = SymbolKind(.macro)

    // Member-only leaves
    public static let enumerationCase = SymbolKind(.enumerationCase)
    public static let initializer = SymbolKind(.initializer)
    public static let deinitializer = SymbolKind(.deinitializer)
    public static let instanceMethod = SymbolKind(.instanceMethod)
    public static let instanceProperty = SymbolKind(.instanceProperty)
    public static let instanceSubscript = SymbolKind(.instanceSubscript)
    public static let typeMethod = SymbolKind(.typeMethod)
    public static let typeProperty = SymbolKind(.typeProperty)
    public static let typeSubscript = SymbolKind(.typeSubscript)

    // Unknown
    public static let unknown = SymbolKind(.unknown)
}

// MARK: - Badge Display

extension SymbolKind {
    /// The badge character for this symbol kind.
    public var badgeCharacter: String {
        switch kind {
        case .class, .extendedClass:
            return "C"
        case .structure, .extendedStructure:
            return "S"
        case .enumeration, .extendedEnumeration, .enumerationCase:
            return "E"
        case .protocol, .extendedProtocol:
            return "P"
        case .typeAlias, .typeDef, .associatedType:
            return "T"
        case .function, .instanceMethod, .typeMethod, .initializer, .deinitializer, .operator:
            return "F"
        case .globalVariable, .localVariable, .instanceVariable, .instanceProperty, .typeProperty, .typeConstant:
            return "V"
        case .instanceSubscript, .typeSubscript:
            return "Su"
        case .macro:
            return "M"
        case .module, .extendedModule:
            return "Mo"
        case .extension:
            return "Ex"
        case .article, .tutorialArticle:
            return "A"
        case .tutorial:
            return "Tu"
        case .collection, .collectionGroup, .landingPage, .root:
            return "Co"
        case .sampleCode:
            return "Sc"
        default:
            return "?"
        }
    }

    /// The CSS class for this symbol kind's badge.
    public var badgeClass: String {
        switch kind {
        case .class, .extendedClass:
            return "badge-class"
        case .structure, .extendedStructure:
            return "badge-struct"
        case .enumeration, .extendedEnumeration, .enumerationCase:
            return "badge-enum"
        case .protocol, .extendedProtocol:
            return "badge-protocol"
        case .typeAlias, .typeDef, .associatedType:
            return "badge-typealias"
        case .function, .instanceMethod, .typeMethod, .initializer, .deinitializer, .operator, .instanceSubscript, .typeSubscript:
            return "badge-func"
        case .globalVariable, .localVariable, .instanceVariable, .instanceProperty, .typeProperty, .typeConstant:
            return "badge-var"
        case .macro:
            return "badge-macro"
        case .module, .extendedModule, .extension:
            return "badge-module"
        case .article, .tutorialArticle:
            return "badge-article"
        case .tutorial:
            return "badge-tutorial"
        case .collection, .collectionGroup, .landingPage, .root:
            return "badge-collection"
        case .sampleCode:
            return "badge-sample"
        default:
            return "badge-other"
        }
    }
}

// MARK: - TopicRenderReference Extension

extension TopicRenderReference {
    /// Extracts the symbol kind from this reference.
    ///
    /// This looks at the fragments to find the keyword token that indicates the symbol type.
    public var symbolKind: SymbolKind? {
        // Check the kind first
        switch kind {
        case .article:
            return .article
        case .tutorial:
            return .tutorial
        case .overview:
            return .collection
        case .section:
            return nil
        case .symbol:
            break
        @unknown default:
            break
        }

        // For symbols, try to extract from fragments
        if let fragments = fragments,
           let keywordToken = fragments.first(where: { $0.kind == .keyword }),
           let symbolKind = SymbolKind(keyword: keywordToken.text) {
            return symbolKind
        }

        // Fall back to unknown symbol
        return kind == .symbol ? .unknown : nil
    }
}
