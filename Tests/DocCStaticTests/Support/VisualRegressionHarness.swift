//
// VisualRegressionHarness.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing

/// Access to the visual regression harness in `Tests/VisualRegression`.
///
/// The harness consists of Node scripts that measure rendered pages in a browser
/// (through playwright-core), the golden reference data of each built-in theme, and
/// the checked-in lists of currently known issues.  This type locates those files,
/// decides whether the browser-based checks can run on this machine, runs the
/// scripts, and applies the known-issue lists.
enum VisualRegressionHarness {
    /// The harness directory in the source tree.
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Support
        .deletingLastPathComponent()  // DocCStaticTests
        .deletingLastPathComponent()  // Tests
        .appendingPathComponent("VisualRegression")

    /// The environment variable that, when set to `1`, skips the browser-based checks.
    static let skipEnvironmentVariable = "DOCC_STATIC_SKIP_BROWSER_TESTS"

    /// The known issues of one theme, as stored in `known-issues/<theme>.json`.
    struct KnownIssues: Codable, Sendable {
        /// Role and property pairs (`role.property`) whose browser measurements currently
        /// differ from the golden data.
        var mismatches: [String] = []

        /// Custom properties the theme settings define but no stylesheet rule reads.
        var unusedProperties: [String] = []

        /// Custom properties a rule reads without a fallback although nothing defines them.
        var undefinedProperties: [String] = []
    }

    /// Reads the known issues of a theme.
    ///
    /// - Parameter theme: The theme name.
    /// - Returns: The known issues, or empty lists if the theme has no file.
    /// - Throws: A decoding error if the file exists but is malformed.
    static func knownIssues(for theme: String) throws -> KnownIssues {
        let file = directory.appendingPathComponent("known-issues").appendingPathComponent("\(theme).json")
        guard FileManager.default.fileExists(atPath: file.path) else { return KnownIssues() }
        return try JSONDecoder().decode(KnownIssues.self, from: Data(contentsOf: file))
    }

    /// A difference from the golden data that a theme deliberately keeps.
    ///
    /// Accepted deviations are listed in `accepted-deviations/<theme>.json`.  Each
    /// one names a role and a property (`*` for every role or property), may be
    /// restricted to some pages, viewports and colour schemes, and states why the
    /// theme differs from its reference, for example because the reference is
    /// broken there.  The mismatches a deviation covers are reported separately and
    /// are neither known issues nor unexpected.
    struct AcceptedDeviation: Codable, Sendable {
        /// The role the deviation concerns, or `*` for all roles.
        var role: String

        /// The measured property, `presence`, `box.x`, `box.width`, or `*` for all.
        var property: String

        /// The page identifiers the deviation is restricted to, if any.
        var pages: [String]?

        /// The viewports (such as `390x844`) the deviation is restricted to, if any.
        var viewports: [String]?

        /// The colour schemes (`light` or `dark`) the deviation is restricted to, if any.
        var schemes: [String]?

        /// Why the theme deliberately differs from its reference.
        var reason: String
    }

    /// The accepted deviations of one theme, as stored in `accepted-deviations/<theme>.json`.
    struct AcceptedDeviations: Codable, Sendable {
        /// The deviations, each covering the mismatches it describes.
        var deviations: [AcceptedDeviation] = []
    }

    /// Reads the accepted deviations of a theme.
    ///
    /// - Parameter theme: The theme name.
    /// - Returns: The accepted deviations, or an empty list if the theme has no file.
    /// - Throws: A decoding error if the file exists but is malformed.
    static func acceptedDeviations(for theme: String) throws -> [AcceptedDeviation] {
        let file = directory.appendingPathComponent("accepted-deviations").appendingPathComponent("\(theme).json")
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode(AcceptedDeviations.self, from: Data(contentsOf: file)).deviations
    }

    /// Reads a JSON file of the harness directory.
    ///
    /// - Parameter name: The file name inside the harness directory.
    /// - Returns: The decoded JSON value.
    /// - Throws: A file or JSON error.
    static func json(_ name: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent(name)))
    }

    /// Records the difference between the issues that occur and the known issues.
    ///
    /// Every occurring issue that is listed is recorded as one known issue, so the test
    /// passes; an occurring issue that is not listed fails the test, and so does a listed
    /// issue that no longer occurs, so that the list can only shrink.
    ///
    /// - Parameters:
    ///   - occurring: The issue keys that occur now, with a description of each.
    ///   - known: The listed issue keys.
    ///   - kind: A short description of the kind of issue, used in messages.
    ///   - listName: The name of the list in the known-issue file, used in messages.
    ///   - theme: The theme name, used in messages.
    static func reconcile(
        occurring: [String: String],
        known: [String],
        kind: String,
        listName: String,
        theme: String
    ) {
        let knownSet = Set(known)
        let expected = occurring.keys.filter { knownSet.contains($0) }.sorted()
        if !expected.isEmpty {
            withKnownIssue("\(expected.count) known \(kind) for \(theme) (\(listName) in known-issues/\(theme).json)") {
                Issue.record("\(expected.count) known \(kind): \(expected.prefix(20).joined(separator: ", "))")
            }
        }
        for key in occurring.keys.filter({ !knownSet.contains($0) }).sorted() {
            Issue.record("Unexpected \(kind) for \(theme): \(key)\(occurring[key].map { " (\($0))" } ?? "")")
        }
        for key in knownSet.subtracting(occurring.keys).sorted() {
            Issue.record("\(key) no longer occurs for \(theme); remove it from \(listName) in known-issues/\(theme).json")
        }
    }

    // MARK: - Running the Scripts

    /// The Node executable, if one is on the search path.
    static let nodeExecutable: URL? = {
        let names = ["node", "node.exe"]
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        #if os(Windows)
            let separator: Character = ";"
        #else
            let separator: Character = ":"
        #endif
        for directory in path.split(separator: separator) {
            for name in names {
                let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(name)
                if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
            }
        }
        return nil
    }()

    /// Whether the browser-based checks can run on this machine.
    ///
    /// They need Node on the search path, playwright-core and a browser it can launch
    /// (checked by `check.mjs`), and the golden data.  They can also be switched off
    /// with ``skipEnvironmentVariable``.
    static let isAvailable: Bool = {
        guard ProcessInfo.processInfo.environment[skipEnvironmentVariable] != "1",
            FileManager.default.fileExists(atPath: directory.appendingPathComponent("golden").path),
            let result = try? runNode(script: "check.mjs", arguments: [])
        else { return false }
        return result.status == 0
    }()

    /// The outcome of running a harness script.
    struct ScriptResult: Sendable {
        /// The exit status of the script.
        let status: Int32

        /// The standard output of the script.
        let output: String
    }

    /// Runs one of the harness scripts with Node.
    ///
    /// - Parameters:
    ///   - script: The script file name inside the harness directory.
    ///   - arguments: The arguments passed to the script.
    /// - Returns: The exit status and standard output.
    /// - Throws: An error if Node is missing or cannot be started.
    static func runNode(script: String, arguments: [String]) throws -> ScriptResult {
        guard let node = nodeExecutable else { throw CocoaError(.fileNoSuchFile) }
        let process = Process()
        process.executableURL = node
        process.arguments = [directory.appendingPathComponent(script).path] + arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return ScriptResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }

    /// Creates a fresh temporary directory for script results.
    ///
    /// - Returns: The directory URL.
    /// - Throws: A file system error.
    static func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("docc-static-visual-regression-tests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
