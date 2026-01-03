//
// GenerationResult.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// The result of a documentation generation operation.
///
/// This type contains information about the generated documentation, including
/// the number of pages created, any warnings encountered, and paths to key files.
public struct GenerationResult: Sendable, Equatable, Hashable {
    /// The directory where documentation was written.
    public let outputDirectory: URL

    /// The total number of HTML pages generated.
    public let generatedPages: Int

    /// The number of modules documented.
    public let modulesDocumented: Int

    /// The number of symbols documented.
    public let symbolsDocumented: Int

    /// The number of articles generated.
    public let articlesGenerated: Int

    /// The number of tutorials generated.
    public let tutorialsGenerated: Int

    /// Warnings encountered during generation.
    public let warnings: [Warning]

    /// The path to the generated search index, if search was enabled.
    public let searchIndexPath: URL?

    /// The path to the main index.html file.
    public var indexPath: URL {
        outputDirectory.appendingPathComponent("index.html")
    }

    /// Creates a new generation result.
    ///
    /// - Parameters:
    ///   - outputDirectory: The directory where documentation was written.
    ///   - generatedPages: The total number of HTML pages generated.
    ///   - modulesDocumented: The number of modules documented.
    ///   - symbolsDocumented: The number of symbols documented.
    ///   - articlesGenerated: The number of articles generated.
    ///   - tutorialsGenerated: The number of tutorials generated.
    ///   - warnings: Warnings encountered during generation.
    ///   - searchIndexPath: The path to the search index, if generated.
    public init(
        outputDirectory: URL,
        generatedPages: Int,
        modulesDocumented: Int,
        symbolsDocumented: Int,
        articlesGenerated: Int,
        tutorialsGenerated: Int,
        warnings: [Warning],
        searchIndexPath: URL?
    ) {
        self.outputDirectory = outputDirectory
        self.generatedPages = generatedPages
        self.modulesDocumented = modulesDocumented
        self.symbolsDocumented = symbolsDocumented
        self.articlesGenerated = articlesGenerated
        self.tutorialsGenerated = tutorialsGenerated
        self.warnings = warnings
        self.searchIndexPath = searchIndexPath
    }
}

/// A warning generated during documentation generation.
public struct Warning: Sendable, Equatable, Hashable, CustomStringConvertible {
    /// The severity of the warning.
    public enum Severity: String, Sendable, Equatable, Hashable {
        case warning
        case note
    }

    /// The severity level.
    public let severity: Severity

    /// A brief summary of the warning.
    public let summary: String

    /// The source location where the warning occurred, if applicable.
    public let source: SourceLocation?

    /// Additional explanation or context.
    public let explanation: String?

    /// A textual description of the warning.
    public var description: String {
        var result = "[\(severity.rawValue)] \(summary)"
        if let source = source {
            result += " at \(source)"
        }
        if let explanation = explanation {
            result += "\n  \(explanation)"
        }
        return result
    }

    /// Creates a new warning.
    ///
    /// - Parameters:
    ///   - severity: The severity level.
    ///   - summary: A brief summary of the warning.
    ///   - source: The source location, if applicable.
    ///   - explanation: Additional context or explanation.
    public init(
        severity: Severity,
        summary: String,
        source: SourceLocation? = nil,
        explanation: String? = nil
    ) {
        self.severity = severity
        self.summary = summary
        self.source = source
        self.explanation = explanation
    }
}

/// A location in source code.
public struct SourceLocation: Sendable, Equatable, Hashable, CustomStringConvertible {
    /// The file path.
    public let file: String

    /// The line number (1-based).
    public let line: Int

    /// The column number (1-based).
    public let column: Int?

    /// A textual description of the source location.
    public var description: String {
        if let column = column {
            return "\(file):\(line):\(column)"
        } else {
            return "\(file):\(line)"
        }
    }

    /// Creates a new source location.
    ///
    /// - Parameters:
    ///   - file: The file path.
    ///   - line: The line number (1-based).
    ///   - column: The column number (1-based), if known.
    public init(file: String, line: Int, column: Int? = nil) {
        self.file = file
        self.line = line
        self.column = column
    }
}
