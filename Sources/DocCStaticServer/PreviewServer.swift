//
// PreviewServer.swift
// DocCStaticServer
//
//  Created by Rene Hexel on 13/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix

/// An HTTP/1.1 server for previewing static documentation locally.
///
/// This actor provides a simple, development-focused HTTP server that serves
/// files from a specified directory. It uses SwiftNIO with async/await for
/// modern Swift concurrency support.
///
/// ## Overview
///
/// `PreviewServer` is designed for local development use only. It binds to
/// localhost and serves static files without TLS encryption. The server uses
/// `NIOAsyncChannel` to bridge NIO's event-driven architecture with Swift's
/// structured concurrency.
///
/// ## Usage
///
/// Create a server instance and call `run()` to start serving:
///
/// ```swift
/// let server = PreviewServer(
///     rootDirectory: URL(fileURLWithPath: "/path/to/docs"),
///     port: 8080
/// )
/// try await server.run()
/// ```
///
/// The server runs until the process is terminated (typically via Ctrl+C).
///
/// ## Topics
///
/// ### Creating a Server
///
/// - ``init(rootDirectory:port:)``
///
/// ### Running the Server
///
/// - ``run()``
///
/// ### Properties
///
/// - ``rootDirectory``
/// - ``port``
public actor PreviewServer {
    /// The directory containing files to serve.
    ///
    /// All file requests are resolved relative to this directory.
    public let rootDirectory: URL

    /// The port to listen on for incoming HTTP connections.
    ///
    /// Common development ports include 8080, 8000, and 3000.
    public let port: Int

    /// Creates a new preview server.
    ///
    /// - Parameters:
    ///   - rootDirectory: The directory containing documentation files to serve.
    ///     Should be an absolute path.
    ///   - port: The TCP port to bind to (default: 8080). Must be in the
    ///     range 1-65535, and not already in use.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let server = PreviewServer(
    ///     rootDirectory: URL(fileURLWithPath: ".build/documentation"),
    ///     port: 8080
    /// )
    /// ```
    public init(rootDirectory: URL, port: Int = 8080) {
        self.rootDirectory = rootDirectory
        self.port = port
    }

    /// Starts the HTTP server and processes connections until termination.
    ///
    /// This method binds to the specified port and begins accepting HTTP
    /// connections. It runs indefinitely until the process receives a
    /// termination signal (e.g., SIGINT from Ctrl+C).
    ///
    /// The server handles each connection concurrently using structured
    /// concurrency, allowing multiple simultaneous clients.
    ///
    /// - Throws: An error if the server fails to bind to the port (e.g.,
    ///   port already in use, insufficient permissions).
    ///
    /// ## Implementation Notes
    ///
    /// This method uses `NIOAsyncChannel` to bridge SwiftNIO's channel
    /// pipeline with Swift's async/await model. Each accepted connection
    /// is handled in a separate task within a task group.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let server = PreviewServer(rootDirectory: docsURL, port: 8080)
    /// print("Starting server at http://localhost:8080/")
    /// try await server.run()
    /// ```
    public func run() async throws {
        let handler = StaticFileHandler(rootDirectory: rootDirectory)

        let bootstrap = ServerBootstrap(group: NIOSingletons.posixEventLoopGroup)
            .serverChannelOption(.backlog, value: 256)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.maxMessagesPerRead, value: 1)

        let server = try await bootstrap.bind(host: "127.0.0.1", port: port) {
            channel in
            channel.eventLoop.makeCompletedFuture {
                // Configure HTTP/1.1 pipeline
                let handlers: [any ChannelHandler] = [
                    HTTPResponseEncoder(),
                    ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .dropBytes)),
                ]
                try channel.pipeline.syncOperations.addHandlers(handlers)

                // Wrap in NIOAsyncChannel for async/await
                return try NIOAsyncChannel<
                    HTTPServerRequestPart,
                    HTTPServerResponsePart
                >(
                    wrappingChannelSynchronously: channel,
                    configuration: .init()
                )
            }
        }

        print("Server started at http://127.0.0.1:\(port)/")
        print("Press Ctrl+C to stop.")

        try await server.executeThenClose { inbound in
            try await withThrowingTaskGroup(of: Void.self) { group in
                for try await client in inbound {
                    group.addTask {
                        await self.handleConnection(client, handler: handler)
                    }
                }
            }
        }
    }

    /// Handles a single client connection.
    ///
    /// This method processes all HTTP requests from a connected client until
    /// the connection closes. Each request is forwarded to the static file
    /// handler, and the response is written back to the client.
    ///
    /// - Parameters:
    ///   - connection: The NIO async channel representing the client connection.
    ///   - handler: The static file handler for serving content.
    ///
    /// ## Implementation Notes
    ///
    /// The method uses `executeThenClose` to ensure the connection is properly
    /// closed when processing completes, either successfully or due to an error.
    /// Connection errors are silently ignored, as they're expected during normal
    /// operation (e.g., client disconnections).
    private func handleConnection(
        _ connection: NIOAsyncChannel<HTTPServerRequestPart, HTTPServerResponsePart>,
        handler: StaticFileHandler
    ) async {
        do {
            try await connection.executeThenClose { inbound, outbound in
                for try await part in inbound {
                    guard case .head(let head) = part else { continue }

                    // Only handle GET and HEAD requests
                    let response: HTTPResponse
                    switch head.method {
                    case .GET:
                        response = await handler.handleRequest(uri: head.uri, includeBody: true)
                    case .HEAD:
                        response = await handler.handleRequest(uri: head.uri, includeBody: false)
                    default:
                        response = .methodNotAllowed
                    }

                    try await outbound.write(.head(response.head))
                    if let body = response.body {
                        try await outbound.write(.body(.byteBuffer(body)))
                    }
                    try await outbound.write(.end(nil))

                    // Close connection after response (simple implementation)
                    if !head.isKeepAlive {
                        break
                    }
                }
            }
        } catch {
            // Connection closed or error - silently ignore for preview server
        }
    }
}
