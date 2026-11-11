//
// ExecutableSearchTests.swift
// DocCStaticTests
//
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing
@testable import DocCStatic

@Suite("Executable Search")
struct ExecutableSearchTests {
    /// Creates a directory holding an executable and a non-executable file.
    func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("docc-static-executable-search-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "tool" + (StaticDocumentationGenerator.executableExtensions.first ?? "")
        let tool = directory.appendingPathComponent(name)
        try Data("#!/bin/sh\n".utf8).write(to: tool)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
        return directory
    }

    @Test("An executable is found in a later directory of the search path")
    func findsExecutable() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let separator = String(StaticDocumentationGenerator.searchPathSeparator)
        let searchPath = ["", directory.deletingLastPathComponent().appendingPathComponent("missing").path, directory.path]
            .joined(separator: separator)
        let found = try #require(StaticDocumentationGenerator.executable(named: "tool", searchPath: searchPath))
        #expect(URL(fileURLWithPath: found).deletingLastPathComponent().standardizedFileURL.path
            == directory.standardizedFileURL.path)
    }

    @Test("Missing executables and search paths give no result")
    func missingExecutable() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(StaticDocumentationGenerator.executable(named: "absent", searchPath: directory.path) == nil)
        #expect(StaticDocumentationGenerator.executable(named: "tool", searchPath: nil) == nil)
        #expect(StaticDocumentationGenerator.executable(named: "tool", searchPath: "") == nil)
    }
}
