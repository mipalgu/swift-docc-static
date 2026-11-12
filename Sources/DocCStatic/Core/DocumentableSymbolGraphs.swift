//
// DocumentableSymbolGraphs.swift
// DocCStatic
//
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// Selects the symbol graphs of modules that have something to document.
///
/// A module that declares no documentable symbols, such as an executable target
/// that only serves as a build tool, produces a symbol graph without symbols.
/// Converting such a graph would give the module an empty page, a card on the
/// landing page and a sidebar entry, even though there is nothing to read.
/// This type decides, before conversion, which symbol graph files are worth
/// passing on, so that modules with nothing to document never reach the output.
///
/// Symbol graphs are grouped by the module they belong to: a module's primary
/// graph and its extension graphs (named `Module@ExtendedModule.symbols.json`)
/// are kept or left out together.  Modules with a documentation catalogue are
/// not subject to this selection, as their articles are worth documenting even
/// without any symbols.
enum DocumentableSymbolGraphs {
    /// The file name suffix shared by all symbol graph files.
    static let fileSuffix = ".symbols.json"

    /// The character that separates a module name from the name of the module it extends
    /// in the file name of an extension symbol graph.
    static let extensionSeparator: Character = "@"

    /// The part of a symbol graph that holds the symbols it declares.
    private struct SymbolList: Decodable {
        /// A symbol whose content is irrelevant for counting.
        struct Symbol: Decodable {
            /// Creates a symbol without decoding any of its content.
            ///
            /// - Parameter decoder: The decoder to read from (unused).
            init(from decoder: any Decoder) throws {}
        }

        /// The symbols declared in the symbol graph.
        let symbols: [Symbol]
    }

    /// Returns the name of the module a symbol graph file belongs to.
    ///
    /// For an extension symbol graph, this is the name of the extending module,
    /// not the name of the module it extends.
    ///
    /// - Parameter fileName: The file name of the symbol graph, such as
    ///   `Module.symbols.json` or `Module@Swift.symbols.json`.
    /// - Returns: The module name, or `nil` if the file name does not denote a symbol graph.
    static func moduleName(ofSymbolGraphFile fileName: String) -> String? {
        guard fileName.hasSuffix(fileSuffix) else { return nil }
        let baseName = fileName.dropLast(fileSuffix.count)
        let moduleName = baseName.split(
            separator: extensionSeparator, maxSplits: 1, omittingEmptySubsequences: false
        ).first ?? baseName
        return moduleName.isEmpty ? nil : String(moduleName)
    }

    /// Returns the number of symbols declared in a symbol graph file.
    ///
    /// - Parameter url: The location of the symbol graph file.
    /// - Returns: The number of entries in the symbol graph's list of symbols.
    /// - Throws: An error if the file cannot be read or is not a symbol graph.
    static func symbolCount(inSymbolGraphAt url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SymbolList.self, from: data).symbols.count
    }

    /// Returns the symbol graph files of the modules that declare at least one symbol.
    ///
    /// A module is left out only if every one of its symbol graph files could be read
    /// and declares no symbols.  Files that cannot be read are kept, so that `docc`
    /// can report the problem rather than the module silently disappearing.
    ///
    /// - Parameters:
    ///   - fileNames: The file names of the candidate symbol graphs.
    ///   - directory: The directory that contains the symbol graph files.
    /// - Returns: The file names of the documentable modules, in their original order.
    static func documentableFiles(_ fileNames: [String], in directory: URL) -> [String] {
        var documentableModules = Set<String>()
        for fileName in fileNames {
            guard let module = moduleName(ofSymbolGraphFile: fileName),
                !documentableModules.contains(module)
            else { continue }
            let url = directory.appendingPathComponent(fileName)
            let count = (try? symbolCount(inSymbolGraphAt: url)) ?? 1
            if count > 0 {
                documentableModules.insert(module)
            }
        }
        return fileNames.filter { fileName in
            guard let module = moduleName(ofSymbolGraphFile: fileName) else { return true }
            return documentableModules.contains(module)
        }
    }
}
