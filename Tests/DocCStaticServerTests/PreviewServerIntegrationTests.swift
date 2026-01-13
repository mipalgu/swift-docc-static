//
// PreviewServerIntegrationTests.swift
// DocCStaticServerTests
//
//  Created by Rene Hexel on 13/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import AsyncHTTPClient
import Foundation
import NIOCore
import Testing

@testable import DocCStaticServer

/// Shared HTTP client for all integration tests to avoid shutdown issues.
private let sharedHTTPClient = HTTPClient(eventLoopGroupProvider: .singleton)

@Suite("Preview Server Integration Tests", .serialized)
@MainActor
struct PreviewServerIntegrationTests {

    /// Creates a temporary test directory structure with documentation files.
    func createTestDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("docc-server-tests-\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create realistic documentation structure
        let indexHTML = tempDir.appendingPathComponent("index.html")
        try """
        <!DOCTYPE html>
        <html>
        <head><title>Documentation</title></head>
        <body><h1>Welcome to Documentation</h1></body>
        </html>
        """.write(to: indexHTML, atomically: true, encoding: .utf8)

        let cssDir = tempDir.appendingPathComponent("css")
        try FileManager.default.createDirectory(at: cssDir, withIntermediateDirectories: true)

        let styleCSS = cssDir.appendingPathComponent("style.css")
        try "body { font-family: sans-serif; margin: 0; }".write(
            to: styleCSS, atomically: true, encoding: .utf8)

        let jsDir = tempDir.appendingPathComponent("js")
        try FileManager.default.createDirectory(at: jsDir, withIntermediateDirectories: true)

        let appJS = jsDir.appendingPathComponent("app.js")
        try "console.log('Documentation loaded');".write(
            to: appJS, atomically: true, encoding: .utf8)

        let apiDir = tempDir.appendingPathComponent("documentation/MyAPI")
        try FileManager.default.createDirectory(at: apiDir, withIntermediateDirectories: true)

        let apiIndex = apiDir.appendingPathComponent("index.html")
        try """
        <!DOCTYPE html>
        <html>
        <head><title>MyAPI</title></head>
        <body><h1>MyAPI Documentation</h1></body>
        </html>
        """.write(to: apiIndex, atomically: true, encoding: .utf8)

        return tempDir
    }

    /// Removes the test directory.
    func cleanupTestDirectory(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    /// Makes an HTTP request using AsyncHTTPClient (cross-platform).
    func makeHTTPRequest(url: String, client: HTTPClient) async throws -> (
        statusCode: Int, headers: [String: String], body: String?
    ) {
        let request = HTTPClientRequest(url: url)
        let response = try await client.execute(request, timeout: .seconds(5))

        let statusCode = Int(response.status.code)

        var headers: [String: String] = [:]
        for (name, value) in response.headers {
            headers[name.lowercased()] = value
        }

        let bodyBytes = try await response.body.collect(upTo: 1024 * 1024)  // 1MB max
        let body = String(buffer: bodyBytes)

        return (statusCode, headers, body.isEmpty ? nil : body)
    }

    // MARK: - Integration Tests

    @Test("Server starts and serves root index.html")
    func serverServesRootIndex() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        // Use a random high port to avoid conflicts
        let port = Int.random(in: 9000...9999)
        let server = PreviewServer(rootDirectory: testDir, port: port)

        // Start server in background task
        let serverTask = Task {
            try await server.run()
        }

        // Give server time to start
        try await Task.sleep(for: .milliseconds(200))

        do {
            // Make request
            let (status, _, body) = try await makeHTTPRequest(
                url: "http://127.0.0.1:\(port)/", client: sharedHTTPClient)

            #expect(status == 200)
            #expect(body?.contains("Welcome to Documentation") == true)
        } catch {
            Issue.record("HTTP request failed: \(error)")
        }

        // Stop server
        serverTask.cancel()
        try? await Task.sleep(for: .milliseconds(100))
    }

    @Test("Server serves CSS files with correct MIME type")
    func serverServesCSSWithCorrectMIME() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let port = Int.random(in: 9000...9999)
        let server = PreviewServer(rootDirectory: testDir, port: port)

        let serverTask = Task {
            try await server.run()
        }

        try await Task.sleep(for: .milliseconds(200))

        do {
            let (status, headers, body) = try await makeHTTPRequest(
                url: "http://127.0.0.1:\(port)/css/style.css", client: sharedHTTPClient)

            #expect(status == 200)
            #expect(headers["content-type"]?.hasPrefix("text/css") == true)
            #expect(body?.contains("sans-serif") == true)
        } catch {
            Issue.record("HTTP request failed: \(error)")
        }

        serverTask.cancel()
        try? await Task.sleep(for: .milliseconds(100))
    }

    @Test("Server serves JavaScript files with correct MIME type")
    func serverServesJavaScriptWithCorrectMIME() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let port = Int.random(in: 9000...9999)
        let server = PreviewServer(rootDirectory: testDir, port: port)

        let serverTask = Task {
            try await server.run()
        }

        try await Task.sleep(for: .milliseconds(200))

        do {
            let (status, headers, body) = try await makeHTTPRequest(
                url: "http://127.0.0.1:\(port)/js/app.js", client: sharedHTTPClient)

            #expect(status == 200)
            #expect(headers["content-type"]?.hasPrefix("text/javascript") == true)
            #expect(body?.contains("Documentation loaded") == true)
        } catch {
            Issue.record("HTTP request failed: \(error)")
        }

        serverTask.cancel()
        try? await Task.sleep(for: .milliseconds(100))
    }

    @Test("Server returns 404 for non-existent files")
    func serverReturns404ForMissingFiles() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let port = Int.random(in: 9000...9999)
        let server = PreviewServer(rootDirectory: testDir, port: port)

        let serverTask = Task {
            try await server.run()
        }

        try await Task.sleep(for: .milliseconds(200))

        do {
            let (status, _, _) = try await makeHTTPRequest(
                url: "http://127.0.0.1:\(port)/missing.html", client: sharedHTTPClient)

            #expect(status == 404)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        serverTask.cancel()
        try? await Task.sleep(for: .milliseconds(100))
    }

    @Test("Server handles subdirectory index requests")
    func serverHandlesSubdirectoryIndex() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let port = Int.random(in: 9000...9999)
        let server = PreviewServer(rootDirectory: testDir, port: port)

        let serverTask = Task {
            try await server.run()
        }

        try await Task.sleep(for: .milliseconds(200))

        do {
            let (status, _, body) = try await makeHTTPRequest(
                url: "http://127.0.0.1:\(port)/documentation/MyAPI/", client: sharedHTTPClient)

            #expect(status == 200)
            #expect(body?.contains("MyAPI Documentation") == true)
        } catch {
            Issue.record("HTTP request failed: \(error)")
        }

        serverTask.cancel()
        try? await Task.sleep(for: .milliseconds(100))
    }

    @Test("Server handles concurrent requests")
    func serverHandlesConcurrentRequests() async throws {
        let testDir = try createTestDirectory()
        defer { try? cleanupTestDirectory(testDir) }

        let port = Int.random(in: 9000...9999)
        let server = PreviewServer(rootDirectory: testDir, port: port)

        let serverTask = Task {
            try await server.run()
        }

        try await Task.sleep(for: .milliseconds(200))

        // Make multiple concurrent requests
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    do {
                        let paths = ["/", "/css/style.css", "/js/app.js"]
                        let path = paths[i % paths.count]
                        let (status, _, _) = try await self.makeHTTPRequest(
                            url: "http://127.0.0.1:\(port)\(path)", client: sharedHTTPClient)
                        #expect(status == 200)
                    } catch {
                        Issue.record("Concurrent request \(i) failed: \(error)")
                    }
                }
            }
        }

        serverTask.cancel()
        try? await Task.sleep(for: .milliseconds(100))
    }
}

@Suite("Preview Server Basic Tests")
struct PreviewServerBasicTests {

    @Test("PreviewServer initialises with correct properties")
    func serverInitialisation() async {
        let testDir = URL(fileURLWithPath: "/tmp/test")
        let server = PreviewServer(rootDirectory: testDir, port: 8080)

        #expect(await server.rootDirectory == testDir)
        #expect(await server.port == 8080)
    }

    @Test("PreviewServer uses custom port")
    func serverCustomPort() async {
        let testDir = URL(fileURLWithPath: "/tmp/test")
        let server = PreviewServer(rootDirectory: testDir, port: 3000)

        #expect(await server.port == 3000)
    }

    @Test("PreviewServer uses default port when not specified")
    func serverDefaultPort() async {
        let testDir = URL(fileURLWithPath: "/tmp/test")
        let server = PreviewServer(rootDirectory: testDir)

        #expect(await server.port == 8080)
    }
}
