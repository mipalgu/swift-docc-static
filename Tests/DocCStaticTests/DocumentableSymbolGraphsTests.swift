//
// DocumentableSymbolGraphsTests.swift
// DocCStaticTests
//
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing
@testable import DocCStatic

@Suite("Documentable Symbol Graphs")
struct DocumentableSymbolGraphsTests {
    /// Creates an empty temporary directory for symbol graph files.
    func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("docc-static-symbol-graphs-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Writes a minimal symbol graph with the given number of symbols.
    ///
    /// - Parameters:
    ///   - fileName: The name of the symbol graph file.
    ///   - module: The name of the module the graph describes.
    ///   - symbolCount: The number of symbols to include.
    ///   - directory: The directory to write the file to.
    func writeSymbolGraph(_ fileName: String, module: String, symbolCount: Int, in directory: URL) throws {
        let symbols = (0..<symbolCount).map { index in
            """
            {"kind":{"identifier":"swift.struct","displayName":"Structure"},\
            "identifier":{"precise":"s:\(module)\(index)","interfaceLanguage":"swift"},\
            "pathComponents":["Type\(index)"],\
            "names":{"title":"Type\(index)"},\
            "accessLevel":"public"}
            """
        }
        let json = """
            {"metadata":{"formatVersion":{"major":0,"minor":6,"patch":0},"generator":"test"},\
            "module":{"name":"\(module)","platform":{}},\
            "symbols":[\(symbols.joined(separator: ","))],\
            "relationships":[]}
            """
        try Data(json.utf8).write(to: directory.appendingPathComponent(fileName))
    }

    @Test("Module names are derived from primary and extension symbol graph files")
    func moduleNames() {
        #expect(DocumentableSymbolGraphs.moduleName(ofSymbolGraphFile: "Library.symbols.json") == "Library")
        #expect(DocumentableSymbolGraphs.moduleName(ofSymbolGraphFile: "Library@Swift.symbols.json") == "Library")
        #expect(DocumentableSymbolGraphs.moduleName(ofSymbolGraphFile: "my_tool.symbols.json") == "my_tool")
        #expect(DocumentableSymbolGraphs.moduleName(ofSymbolGraphFile: "Library.json") == nil)
        #expect(DocumentableSymbolGraphs.moduleName(ofSymbolGraphFile: ".symbols.json") == nil)
    }

    @Test("The symbols in a symbol graph are counted")
    func countsSymbols() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeSymbolGraph("Empty.symbols.json", module: "Empty", symbolCount: 0, in: directory)
        try writeSymbolGraph("Full.symbols.json", module: "Full", symbolCount: 3, in: directory)
        #expect(try DocumentableSymbolGraphs.symbolCount(
            inSymbolGraphAt: directory.appendingPathComponent("Empty.symbols.json")) == 0)
        #expect(try DocumentableSymbolGraphs.symbolCount(
            inSymbolGraphAt: directory.appendingPathComponent("Full.symbols.json")) == 3)
    }

    @Test("A module without symbols is left out")
    func omitsEmptyModule() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeSymbolGraph("Library.symbols.json", module: "Library", symbolCount: 2, in: directory)
        try writeSymbolGraph("build_tool.symbols.json", module: "build_tool", symbolCount: 0, in: directory)
        let files = DocumentableSymbolGraphs.documentableFiles(
            ["Library.symbols.json", "build_tool.symbols.json"], in: directory)
        #expect(files == ["Library.symbols.json"])
    }

    @Test("A module whose symbols are all in an extension symbol graph is kept whole")
    func keepsModuleWithExtensionSymbols() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeSymbolGraph("Extensions.symbols.json", module: "Extensions", symbolCount: 0, in: directory)
        try writeSymbolGraph("Extensions@Swift.symbols.json", module: "Extensions", symbolCount: 1, in: directory)
        let files = DocumentableSymbolGraphs.documentableFiles(
            ["Extensions.symbols.json", "Extensions@Swift.symbols.json"], in: directory)
        #expect(files == ["Extensions.symbols.json", "Extensions@Swift.symbols.json"])
    }

    @Test("Empty extension symbol graphs of an empty module are left out too")
    func omitsEmptyModuleWithEmptyExtensions() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeSymbolGraph("Tool.symbols.json", module: "Tool", symbolCount: 0, in: directory)
        try writeSymbolGraph("Tool@Swift.symbols.json", module: "Tool", symbolCount: 0, in: directory)
        let files = DocumentableSymbolGraphs.documentableFiles(
            ["Tool.symbols.json", "Tool@Swift.symbols.json"], in: directory)
        #expect(files.isEmpty)
    }

    @Test("Symbol graphs that cannot be read are kept for docc to report")
    func keepsUnreadableSymbolGraphs() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("not json".utf8).write(to: directory.appendingPathComponent("Broken.symbols.json"))
        let files = DocumentableSymbolGraphs.documentableFiles(
            ["Broken.symbols.json", "Missing.symbols.json"], in: directory)
        #expect(files == ["Broken.symbols.json", "Missing.symbols.json"])
    }

    @Test("The order of the documentable files is preserved")
    func preservesOrder() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeSymbolGraph("B.symbols.json", module: "B", symbolCount: 1, in: directory)
        try writeSymbolGraph("A.symbols.json", module: "A", symbolCount: 1, in: directory)
        try writeSymbolGraph("C.symbols.json", module: "C", symbolCount: 0, in: directory)
        let files = DocumentableSymbolGraphs.documentableFiles(
            ["B.symbols.json", "C.symbols.json", "A.symbols.json"], in: directory)
        #expect(files == ["B.symbols.json", "A.symbols.json"])
    }
}
