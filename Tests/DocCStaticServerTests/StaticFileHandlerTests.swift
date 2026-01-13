//
// StaticFileHandlerTests.swift
// DocCStaticServerTests
//
//  Created by Rene Hexel on 13/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing

@testable import DocCStaticServer

@Suite("Static File Handler Tests")
struct StaticFileHandlerTests {

    /// Creates a temporary test directory structure.
    func createTestDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("docc-static-tests-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create test files
        let indexHTML = tempDir.appendingPathComponent("index.html")
        try "<html><body>Index</body></html>".write(
            to: indexHTML, atomically: true, encoding: .utf8)

        let styles = tempDir.appendingPathComponent("styles.css")
        try "body { margin: 0; }".write(to: styles, atomically: true, encoding: .utf8)

        let script = tempDir.appendingPathComponent("app.js")
        try "console.log('test');".write(to: script, atomically: true, encoding: .utf8)

        // Create subdirectory with files
        let docsDir = tempDir.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)

        let apiHTML = docsDir.appendingPathComponent("api.html")
        try "<html><body>API</body></html>".write(to: apiHTML, atomically: true, encoding: .utf8)

        let docsIndex = docsDir.appendingPathComponent("index.html")
        try "<html><body>Docs Index</body></html>".write(
            to: docsIndex, atomically: true, encoding: .utf8)

        return tempDir
    }

    /// Removes the test directory.
    func cleanupTestDirectory(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Basic File Serving Tests

    @Test("Handler serves existing file successfully")
    func serveExistingFile() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let handler = StaticFileHandler(rootDirectory: testDir)
        let response = await handler.handleRequest(uri: "/styles.css", includeBody: true)

        #expect(response.head.status == .ok)
        #expect(response.head.headers["content-type"].first == "text/css; charset=utf-8")
        #expect(response.body != nil)
    }

    @Test("Handler returns 404 for non-existent file")
    func nonExistentFile() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let handler = StaticFileHandler(rootDirectory: testDir)
        let response = await handler.handleRequest(uri: "/missing.html", includeBody: true)

        #expect(response.head.status == .notFound)
    }

    @Test("Handler serves subdirectory files")
    func serveSubdirectoryFile() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let handler = StaticFileHandler(rootDirectory: testDir)
        let response = await handler.handleRequest(uri: "/docs/api.html", includeBody: true)

        #expect(response.head.status == .ok)
        #expect(response.head.headers["content-type"].first == "text/html; charset=utf-8")
    }

    @Test("Handler serves index.html for directory root")
    func serveRootIndex() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let handler = StaticFileHandler(rootDirectory: testDir)
        let response = await handler.handleRequest(uri: "/", includeBody: true)

        #expect(response.head.status == .ok)
        #expect(response.body != nil)

        if let body = response.body {
            let content = String(buffer: body)
            #expect(content.contains("Index"))
        }
    }

    @Test("Handler serves index.html for subdirectory")
    func serveSubdirectoryIndex() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let handler = StaticFileHandler(rootDirectory: testDir)
        let response = await handler.handleRequest(uri: "/docs/", includeBody: true)

        #expect(response.head.status == .ok)
        if let body = response.body {
            let content = String(buffer: body)
            #expect(content.contains("Docs Index"))
        }
    }

    @Test("Handler returns 404 for directory without index")
    func directoryWithoutIndex() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        // Create a directory without index.html
        let emptyDir = testDir.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)

        let handler = StaticFileHandler(rootDirectory: testDir)
        let response = await handler.handleRequest(uri: "/empty/", includeBody: true)

        #expect(response.head.status == .notFound)
    }

    // MARK: - HEAD Request Tests

    @Test("HEAD request omits body but includes headers")
    func headRequestOmitsBody() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let handler = StaticFileHandler(rootDirectory: testDir)
        let response = await handler.handleRequest(uri: "/styles.css", includeBody: false)

        #expect(response.head.status == .ok)
        #expect(response.head.headers["content-type"].first == "text/css; charset=utf-8")
        #expect(response.body == nil)
    }

    // MARK: - Path Sanitisation Security Tests

    @Test("Handler prevents directory traversal with ..")
    func preventDirectoryTraversal() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let handler = StaticFileHandler(rootDirectory: testDir)

        // Try various traversal attacks
        let traversalAttempts = [
            "/../../../etc/passwd",
            "/docs/../../secret.txt",
            "/./../.hidden/file",
            "/./../../etc/passwd",
        ]

        for attempt in traversalAttempts {
            let response = await handler.handleRequest(uri: attempt, includeBody: true)
            // Should either be forbidden (if normalised path escapes root) or not found
            #expect(response.head.status == .forbidden || response.head.status == .notFound)
        }
    }

    @Test("Handler strips query parameters")
    func stripsQueryParameters() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let handler = StaticFileHandler(rootDirectory: testDir)
        let response = await handler.handleRequest(uri: "/styles.css?v=1.0.0", includeBody: true)

        #expect(response.head.status == .ok)
        #expect(response.head.headers["content-type"].first == "text/css; charset=utf-8")
    }

    @Test("Handler handles URL encoding correctly")
    func handleURLEncoding() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        // Create a file with space in name
        let fileWithSpace = testDir.appendingPathComponent("my file.html")
        try "<html><body>Spaced</body></html>".write(
            to: fileWithSpace, atomically: true, encoding: .utf8)

        let handler = StaticFileHandler(rootDirectory: testDir)
        let response = await handler.handleRequest(uri: "/my%20file.html", includeBody: true)

        #expect(response.head.status == .ok)
    }

    @Test("Handler rejects malformed URL encoding")
    func rejectMalformedEncoding() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let handler = StaticFileHandler(rootDirectory: testDir)
        let response = await handler.handleRequest(uri: "/file%ZZ.html", includeBody: true)

        #expect(response.head.status == .badRequest)
    }

    @Test("Handler normalises redundant path components")
    func normalisesRedundantComponents() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let handler = StaticFileHandler(rootDirectory: testDir)

        // These should all resolve to the same file
        let variants = [
            "/./styles.css",
            "/docs/../styles.css",
            "/docs/./././../styles.css",
        ]

        for variant in variants {
            let response = await handler.handleRequest(uri: variant, includeBody: true)
            #expect(response.head.status == .ok)
            #expect(response.head.headers["content-type"].first == "text/css; charset=utf-8")
        }
    }

    // MARK: - MIME Type Tests

    @Test("Handler sets correct MIME types for various files")
    func correctMIMETypes() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let handler = StaticFileHandler(rootDirectory: testDir)

        let tests: [(file: String, expected: String)] = [
            ("index.html", "text/html; charset=utf-8"),
            ("styles.css", "text/css; charset=utf-8"),
            ("app.js", "text/javascript; charset=utf-8"),
        ]

        for test in tests {
            let response = await handler.handleRequest(uri: "/\(test.file)", includeBody: false)
            #expect(response.head.status == .ok)
            #expect(response.head.headers["content-type"].first == test.expected)
        }
    }

    // MARK: - Empty and Root Path Tests

    @Test("Empty path serves root index")
    func emptyPathServesRoot() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let handler = StaticFileHandler(rootDirectory: testDir)
        let response = await handler.handleRequest(uri: "", includeBody: true)

        #expect(response.head.status == .ok)
    }
}
