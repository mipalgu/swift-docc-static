//
// NavigationIndex.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// Represents the navigation index for documentation.
///
/// This type parses the `index.json` file from a DocC archive to build
/// a hierarchical navigation tree for the sidebar.
public struct NavigationIndex: Codable, Equatable, Hashable, Sendable {
    /// The schema version of the index.
    public let schemaVersion: SchemaVersion?

    /// The included archive identifiers.
    public let includedArchiveIdentifiers: [String]?

    /// The navigation trees organised by interface language.
    public let interfaceLanguages: [String: [NavigationNode]]

    /// The schema version structure.
    public struct SchemaVersion: Codable, Equatable, Hashable, Sendable {
        public let major: Int
        public let minor: Int
        public let patch: Int
    }
}

/// A node in the navigation tree.
public struct NavigationNode: Codable, Equatable, Hashable, Sendable, Identifiable {
    /// The display title for this node.
    public let title: String

    /// The URL path for this node (nil for group markers).
    public let path: String?

    /// The type of this node (e.g., "module", "struct", "article", "groupMarker").
    public let type: String?

    /// Child nodes (for expandable items).
    public let children: [NavigationNode]?

    /// Return whether this node is deprecated.
    public let isDeprecated: Bool?

    /// Return whether this node is external.
    public let isExternal: Bool?

    /// Return whether this node is beta.
    public let isBeta: Bool?

    /// Coding keys to match JSON property names.
    enum CodingKeys: String, CodingKey {
        case title
        case path
        case type
        case children
        case isDeprecated = "deprecated"
        case isExternal = "external"
        case isBeta = "beta"
    }

    /// A unique identifier for this node.
    public var id: String {
        path ?? title
    }

    /// Return whether this node is a group marker (section header).
    public var isGroupMarker: Bool {
        type == "groupMarker"
    }

    /// Return whether this node has children that can be expanded.
    public var isExpandable: Bool {
        guard let children = children else { return false }
        return children.contains { !$0.isGroupMarker }
    }

    /// The navigation node type.
    public var nodeType: NodeType {
        NodeType(rawValue: type ?? "")
    }
}

/// The type of a navigation node.
public enum NodeType: String, Codable, Sendable {
    // Documentation types
    case module
    case article
    case tutorial
    case overview
    case section
    case groupMarker
    case languageGroup

    // Symbol types - containers
    case `class`
    case `struct`
    case `enum`
    case `protocol`
    case `extension`
    case namespace
    case union
    case dictionary

    // Symbol types - members
    case `init`
    case `deinit`
    case `func`
    case method
    case property
    case `var`
    case `let`
    case `case`
    case `subscript`
    case `operator`
    case macro
    case `typealias`
    case `associatedtype`

    // Other
    case unknown

    public init(rawValue: String) {
        switch rawValue {
        case "module": self = .module
        case "article": self = .article
        case "tutorial": self = .tutorial
        case "overview": self = .overview
        case "section": self = .section
        case "groupMarker": self = .groupMarker
        case "languageGroup": self = .languageGroup
        case "class": self = .class
        case "struct", "structure": self = .struct
        case "enum", "enumeration": self = .enum
        case "protocol": self = .protocol
        case "extension": self = .extension
        case "namespace": self = .namespace
        case "union": self = .union
        case "dictionary": self = .dictionary
        case "init", "initializer": self = .`init`
        case "deinit", "deinitializer": self = .`deinit`
        case "func", "function", "method", "instanceMethod", "typeMethod": self = .func
        case "property", "instanceProperty", "typeProperty": self = .property
        case "var", "variable", "globalVariable", "localVariable": self = .`var`
        case "let", "constant": self = .`let`
        case "case", "enumerationCase": self = .`case`
        case "subscript", "instanceSubscript", "typeSubscript": self = .`subscript`
        case "operator": self = .`operator`
        case "macro": self = .macro
        case "typealias": self = .`typealias`
        case "associatedtype": self = .`associatedtype`
        default: self = .unknown
        }
    }

    /// The badge character for this node type.
    public var badgeCharacter: String {
        switch self {
        case .class: return "C"
        case .struct: return "S"
        case .enum, .case: return "E"
        case .protocol: return "Pr"
        case .extension: return "Ex"
        case .func, .`init`, .`deinit`: return "M"
        case .property, .var, .let: return "P"
        case .subscript: return "Su"
        case .operator: return "Op"
        case .macro: return "Ma"
        case .`typealias`, .`associatedtype`: return "T"
        case .module: return "Mo"
        case .article, .tutorial, .overview: return ""
        default: return ""
        }
    }

    /// The CSS class for this node type's badge.
    public var badgeClass: String {
        switch self {
        case .class: return "badge-class"
        case .struct: return "badge-struct"
        case .enum, .case: return "badge-enum"
        case .protocol: return "badge-protocol"
        case .extension: return "badge-module"
        case .func, .`init`, .`deinit`, .subscript, .operator: return "badge-func"
        case .property, .var, .let: return "badge-var"
        case .macro: return "badge-macro"
        case .`typealias`, .`associatedtype`: return "badge-typealias"
        case .module: return "badge-module"
        case .article, .tutorial, .overview: return "badge-article"
        default: return "badge-other"
        }
    }

    /// Whether this type should show a letter badge.
    public var showsBadge: Bool {
        switch self {
        case .article, .tutorial, .overview, .groupMarker, .section, .languageGroup, .unknown:
            return false
        default:
            return true
        }
    }

    /// The SVG icon for non-badge types (articles, tutorials).
    public var iconSVG: String? {
        switch self {
        case .article, .overview:
            // Simple document icon
            // FIXME: this should match DocC
            return """
            <svg viewBox="0 0 14 14" fill="none">
                <path d="M3 1.5A.5.5 0 013.5 1h5.793a.5.5 0 01.353.146l2.208 2.208a.5.5 0 01.146.353V12.5a.5.5 0 01-.5.5h-8a.5.5 0 01-.5-.5v-11z" stroke="currentColor" stroke-width="1"/>
                <path d="M9 1v3h3" stroke="currentColor" stroke-width="1"/>
            </svg>
            """
        case .tutorial:
            // Tutorial/learning icon
            // FIXME: this should match DocC
            return """
            <svg viewBox="0 0 14 14" fill="none">
                <path d="M7 2L2 4.5l5 2.5 5-2.5L7 2z" stroke="currentColor" stroke-width="1"/>
                <path d="M2 7l5 2.5L12 7" stroke="currentColor" stroke-width="1"/>
                <path d="M2 9.5l5 2.5 5-2.5" stroke="currentColor" stroke-width="1"/>
            </svg>
            """
        default:
            return nil
        }
    }
}

// MARK: - Loading

public extension NavigationIndex {
    /// Loads a navigation index from a JSON file.
    ///
    /// - Parameter url: The URL of the index.json file.
    /// - Returns: The parsed navigation index.
    static func load(from url: URL) throws -> NavigationIndex {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(NavigationIndex.self, from: data)
    }

    /// Finds the navigation tree for a specific module.
    ///
    /// - Parameters:
    ///   - moduleName: The name of the module to find.
    ///   - language: The interface language (default: "swift").
    /// - Returns: The navigation node for the module, or nil if not found.
    func findModule(_ moduleName: String, language: String = "swift") -> NavigationNode? {
        guard let nodes = interfaceLanguages[language] else { return nil }
        return nodes.first { node in
            guard let path = node.path else { return false }
            return path.lowercased().hasSuffix("/\(moduleName.lowercased())")
        }
    }

    /// Returns all module nodes in this index.
    ///
    /// - Parameter language: The interface language (default: "swift").
    /// - Returns: All module navigation nodes.
    func allModules(language: String = "swift") -> [NavigationNode] {
        guard let nodes = interfaceLanguages[language] else { return [] }
        return nodes.filter { $0.type == "module" || $0.path?.contains("/documentation/") == true }
    }

    /// Merges multiple navigation indices into a single combined index.
    ///
    /// This is used to combine navigation from multiple DocC archives into
    /// a single sidebar that shows all modules.
    ///
    /// - Parameter indices: The navigation indices to merge.
    /// - Returns: A combined navigation index containing all modules.
    static func merge(_ indices: [NavigationIndex]) -> NavigationIndex {
        guard !indices.isEmpty else {
            return NavigationIndex(
                schemaVersion: nil,
                includedArchiveIdentifiers: nil,
                interfaceLanguages: [:]
            )
        }

        // Collect all modules from all indices, grouped by language
        var mergedLanguages: [String: [NavigationNode]] = [:]

        for index in indices {
            for (language, nodes) in index.interfaceLanguages {
                var existingNodes = mergedLanguages[language] ?? []
                // Add nodes that aren't already present (by path)
                let existingPaths = Set(existingNodes.compactMap { $0.path?.lowercased() })
                for node in nodes {
                    if let path = node.path?.lowercased(), !existingPaths.contains(path) {
                        existingNodes.append(node)
                    } else if node.path == nil {
                        // Include non-path nodes (like group markers at root level)
                        existingNodes.append(node)
                    }
                }
                mergedLanguages[language] = existingNodes
            }
        }

        // Sort modules alphabetically by title
        for (language, nodes) in mergedLanguages {
            mergedLanguages[language] = nodes.sorted { $0.title.lowercased() < $1.title.lowercased() }
        }

        // Use the schema version from the first index
        return NavigationIndex(
            schemaVersion: indices.first?.schemaVersion,
            includedArchiveIdentifiers: indices.flatMap { $0.includedArchiveIdentifiers ?? [] },
            interfaceLanguages: mergedLanguages
        )
    }
}
