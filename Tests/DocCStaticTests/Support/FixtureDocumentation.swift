//
// FixtureDocumentation.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
@testable import DocCStatic

/// Documentation generated from the bundled fixture package.
///
/// The fixture package lives in `Tests/Fixtures/SidebarFixture` and contains two
/// library modules with a representative mix of symbols, a documentation catalogue
/// with articles, and a minimal tutorial.  End-to-end tests use this type to obtain
/// the output of the real generation pipeline (symbol graph build, `docc convert`
/// and static rendering) without repeating the expensive work for every test.
struct GeneratedFixture: Sendable {
    /// The directory that contains the generated static site.
    let outputDirectory: URL

    /// The statistics reported by the generator.
    let result: GenerationResult

    /// Returns the path of a file relative to ``outputDirectory``.
    ///
    /// - Parameter file: A file URL inside the output directory.
    /// - Returns: The relative path using `/` as the separator.
    func relativePath(of file: URL) -> String {
        let root = outputDirectory.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let components = file.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        return components.dropFirst(root.count).joined(separator: "/")
    }

    /// Returns all generated files with the given extension, sorted by relative path.
    ///
    /// - Parameter pathExtension: The file extension to look for, such as `html`.
    /// - Returns: The matching file URLs.
    func files(withExtension pathExtension: String) -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: outputDirectory,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == pathExtension { files.append(url) }
        }
        return files.sorted { relativePath(of: $0) < relativePath(of: $1) }
    }

    /// Returns every generated file, sorted by relative path.
    func allFiles() -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: outputDirectory,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            if isFile { files.append(url) }
        }
        return files.sorted { relativePath(of: $0) < relativePath(of: $1) }
    }

    /// Reads a generated file as UTF-8 text.
    ///
    /// - Parameter relativePath: The path relative to ``outputDirectory``.
    /// - Returns: The file contents.
    /// - Throws: An error if the file cannot be read.
    func text(at relativePath: String) throws -> String {
        try String(contentsOf: outputDirectory.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

/// Generates and caches documentation for the bundled fixture package.
///
/// Each distinct variant (a theme configuration with a name) is generated at most once per
/// test process; concurrent requests for the same variant share one generation task.
/// All scratch and output directories live in this checkout's own directory in the
/// system temporary directory (see ``TemporaryLocation``), so nothing is written into
/// the repository and other checkouts do not interfere.  The package build cache is
/// kept between test runs to keep repeated runs fast, whereas generated output is
/// replaced.
actor FixtureDocumentation {
    /// The process-wide shared instance for the sidebar fixture package.
    static let shared = FixtureDocumentation()

    /// The process-wide shared instance for the link fixture package.
    ///
    /// The package in `Tests/Fixtures/LinkFixture` has two documented modules that
    /// use the types of a module provided by a dependency package, so that pages
    /// refer to symbols outside the generated site.
    static let links = FixtureDocumentation(
        fixture: linkFixtureName,
        workspace: TemporaryLocation.fixtureWorkspace(for: linkFixtureName)
    )

    /// The name of the link fixture package directory.
    static let linkFixtureName = "LinkFixture"

    /// The name of the fixture package directory below `Tests/Fixtures`.
    let fixture: String

    /// The directory that holds the copied package, its build cache and the outputs.
    let workspaceRoot: URL

    /// Creates a generator of the documentation of a fixture package.
    ///
    /// - Parameters:
    ///   - fixture: The name of the fixture package directory below `Tests/Fixtures`.
    ///   - workspace: The temporary directory the package is copied to.
    init(fixture: String = "SidebarFixture", workspace: URL = TemporaryLocation.fixtureWorkspace) {
        self.fixture = fixture
        self.workspaceRoot = workspace
    }

    /// The in-flight or completed generation tasks, keyed by variant.
    private var tasks: [String: Task<GeneratedFixture, any Error>] = [:]

    /// The prepared working directory, once the fixture package has been copied.
    private var workspace: URL?

    /// Returns documentation generated from the fixture package.
    ///
    /// - Parameters:
    ///   - theme: The built-in theme to generate with.
    ///   - run: Distinguishes repeated generations of the same theme, for example
    ///     to check that the output is deterministic.
    /// - Returns: The generated fixture output.
    /// - Throws: Any error raised while preparing the package or generating documentation.
    func output(
        theme: ThemeSettings.BuiltInTheme = .default,
        run: Int = 0
    ) async throws -> GeneratedFixture {
        try await output(
            configuration: ThemeConfiguration(builtInTheme: theme, includeDarkMode: true, customCSS: nil),
            variant: "\(theme.rawValue)-\(run)"
        )
    }

    /// Returns documentation of only one module of the fixture package, whose
    /// navigator then shows that module's title above its rows, like swift-docc-render.
    ///
    /// - Parameter theme: The built-in theme to generate with.
    /// - Returns: The generated fixture output.
    /// - Throws: Any error raised while preparing the package or generating documentation.
    func singleModuleOutput(theme: ThemeSettings.BuiltInTheme = .default) async throws -> GeneratedFixture {
        try await output(
            configuration: ThemeConfiguration(builtInTheme: theme, includeDarkMode: true, customCSS: nil),
            variant: "\(theme.rawValue)-single-module",
            targets: [Self.singleModuleTarget]
        )
    }

    /// The module documented by ``singleModuleOutput(theme:)``.
    static let singleModuleTarget = "FixtureCore"

    /// Returns documentation generated from the fixture package with any theme configuration.
    ///
    /// - Parameters:
    ///   - configuration: The theme configuration to generate with.
    ///   - variant: A name that identifies this configuration; requests with the
    ///     same name share one generation.
    ///   - targets: The targets to document, or all targets if empty.
    /// - Returns: The generated fixture output.
    /// - Throws: Any error raised while preparing the package or generating documentation.
    func output(configuration: ThemeConfiguration, variant: String, targets: [String] = []) async throws -> GeneratedFixture {
        try await output(variant: variant) {
            $0.theme = configuration
            $0.targets = targets
        }
    }

    /// Returns documentation generated with an adjusted configuration.
    ///
    /// - Parameters:
    ///   - variant: A name that identifies this configuration; requests with the
    ///     same name share one generation.
    ///   - adjust: Changes the default configuration, which documents all targets
    ///     with the default theme and search enabled.
    /// - Returns: The generated fixture output.
    /// - Throws: Any error raised while preparing the package or generating documentation.
    func output(
        variant: String,
        adjust: @escaping @Sendable (inout Configuration) -> Void
    ) async throws -> GeneratedFixture {
        if let task = tasks[variant] {
            return try await task.value
        }
        let root = try prepareWorkspace()
        let task = Task {
            try await Self.generate(in: root, outputName: "output-\(variant)", adjust: adjust)
        }
        tasks[variant] = task
        return try await task.value
    }

    /// Copies the fixture package into a fresh temporary workspace.
    ///
    /// - Returns: The workspace root.
    /// - Throws: A file system error if copying fails.
    private func prepareWorkspace() throws -> URL {
        if let workspace { return workspace }
        let fileManager = FileManager.default
        let root = workspaceRoot
        let package = root.appendingPathComponent("package")
        let outputs = root.appendingPathComponent("outputs")
        for directory in [package, outputs] where fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: outputs, withIntermediateDirectories: true)
        try fileManager.copyItem(at: Self.fixturesDirectory.appendingPathComponent(fixture), to: package)
        workspace = root
        return root
    }

    /// Runs the full generation pipeline on the copied fixture package.
    ///
    /// - Parameters:
    ///   - root: The workspace root prepared by ``prepareWorkspace()``.
    ///   - outputName: The name of the output directory below the workspace.
    ///   - adjust: Changes the default configuration.
    /// - Returns: The generated fixture output.
    /// - Throws: Any generation error.
    private static func generate(
        in root: URL,
        outputName: String,
        adjust: @Sendable (inout Configuration) -> Void
    ) async throws -> GeneratedFixture {
        let output = root.appendingPathComponent("outputs").appendingPathComponent(outputName)
        var configuration = Configuration(
            packageDirectory: root.appendingPathComponent("package"),
            outputDirectory: output,
            includeSearch: true,
            scratchPath: root.appendingPathComponent("scratch")
        )
        adjust(&configuration)
        let result = try await StaticDocumentationGenerator(configuration: configuration).generate()
        return GeneratedFixture(outputDirectory: output, result: result)
    }

    /// The location of the sidebar fixture package in the source tree.
    static var fixturePackageSource: URL {
        fixturesDirectory.appendingPathComponent("SidebarFixture")
    }

    /// The location of the fixture packages in the source tree.
    static var fixturesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Support
            .deletingLastPathComponent()  // DocCStaticTests
            .deletingLastPathComponent()  // Tests
            .appendingPathComponent("Fixtures")
    }
}
