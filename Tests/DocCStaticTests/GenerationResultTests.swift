//
// GenerationResultTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Testing
import Foundation
@testable import DocCStatic

@Suite("Generation Result Tests")
struct GenerationResultTests {
    @Test("Result provides correct index path")
    func indexPath() {
        let outputDir = URL(fileURLWithPath: "/tmp/docs")
        let result = GenerationResult(
            outputDirectory: outputDir,
            generatedPages: 10,
            modulesDocumented: 2,
            symbolsDocumented: 50,
            articlesGenerated: 3,
            tutorialsGenerated: 1,
            warnings: [],
            searchIndexPath: nil
        )

        #expect(result.indexPath == outputDir.appendingPathComponent("index.html"))
    }

    @Test("Result tracks statistics correctly")
    func statistics() {
        let result = GenerationResult(
            outputDirectory: URL(fileURLWithPath: "/tmp"),
            generatedPages: 100,
            modulesDocumented: 5,
            symbolsDocumented: 200,
            articlesGenerated: 10,
            tutorialsGenerated: 2,
            warnings: [],
            searchIndexPath: nil
        )

        #expect(result.generatedPages == 100)
        #expect(result.modulesDocumented == 5)
        #expect(result.symbolsDocumented == 200)
        #expect(result.articlesGenerated == 10)
        #expect(result.tutorialsGenerated == 2)
    }

    @Test("Result includes search index path when enabled")
    func searchIndexPath() {
        let searchPath = URL(fileURLWithPath: "/tmp/docs/search-index.json")
        let result = GenerationResult(
            outputDirectory: URL(fileURLWithPath: "/tmp/docs"),
            generatedPages: 10,
            modulesDocumented: 1,
            symbolsDocumented: 20,
            articlesGenerated: 0,
            tutorialsGenerated: 0,
            warnings: [],
            searchIndexPath: searchPath
        )

        #expect(result.searchIndexPath == searchPath)
    }
}

@Suite("Warning Tests")
struct WarningTests {
    @Test("Warning description includes summary")
    func warningDescription() {
        let warning = Warning(
            severity: .warning,
            summary: "Broken link detected"
        )

        #expect(warning.description.contains("Broken link detected"))
        #expect(warning.description.contains("[warning]"))
    }

    @Test("Warning description includes source location")
    func warningWithSource() {
        let warning = Warning(
            severity: .warning,
            summary: "Invalid reference",
            source: SourceLocation(file: "MyFile.swift", line: 42, column: 10)
        )

        #expect(warning.description.contains("MyFile.swift:42:10"))
    }

    @Test("Warning description includes explanation")
    func warningWithExplanation() {
        let warning = Warning(
            severity: .note,
            summary: "Consider adding documentation",
            explanation: "Public symbols should be documented"
        )

        #expect(warning.description.contains("[note]"))
        #expect(warning.description.contains("Consider adding documentation"))
        #expect(warning.description.contains("Public symbols should be documented"))
    }
}

@Suite("Source Location Tests")
struct SourceLocationTests {
    @Test("Source location with line only")
    func lineOnly() {
        let location = SourceLocation(file: "Test.swift", line: 10)
        #expect(location.description == "Test.swift:10")
    }

    @Test("Source location with line and column")
    func lineAndColumn() {
        let location = SourceLocation(file: "Test.swift", line: 10, column: 5)
        #expect(location.description == "Test.swift:10:5")
    }
}
