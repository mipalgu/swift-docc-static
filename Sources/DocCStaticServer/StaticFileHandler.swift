//
// StaticFileHandler.swift
// DocCStaticServer
//
//  Created by Rene Hexel on 13/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import NIOCore
import NIOHTTP1

/// Handler for serving static files from a directory.
///
/// This type provides secure file serving with path sanitisation to prevent
/// directory traversal attacks. It supports automatic index file resolution
/// for directory requests.
///
/// ## Overview
///
/// `StaticFileHandler` validates and sanitises all incoming request paths,
/// ensuring they remain within the configured root directory. Directory
/// requests are automatically redirected to `index.html` if present.
///
/// ## Security
///
/// The handler implements several security measures:
/// - Path normalisation to prevent `..` traversal
/// - Verification that resolved paths stay within the root directory
/// - URL decoding with malformed input rejection
/// - Query string stripping
///
/// ## Topics
///
/// ### Creating a Handler
///
/// - ``init(rootDirectory:)``
///
/// ### Handling Requests
///
/// - ``handleRequest(uri:includeBody:)``
///
/// ### Properties
///
/// - ``rootDirectory``
public struct StaticFileHandler: Sendable {
    /// The root directory for serving files.
    ///
    /// All file paths are resolved relative to this directory. Requests
    /// for files outside this directory are rejected with a 403 Forbidden
    /// response.
    public let rootDirectory: URL

    /// Creates a new static file handler.
    ///
    /// The root directory is standardised to ensure consistent path resolution.
    ///
    /// - Parameter rootDirectory: The directory containing files to serve.
    ///   This should be an absolute path.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let handler = StaticFileHandler(
    ///     rootDirectory: URL(fileURLWithPath: "/var/www/docs")
    /// )
    /// ```
    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory.standardizedFileURL
    }

    /// Handles an HTTP request and returns an appropriate response.
    ///
    /// This method processes the request URI, validates the path, locates
    /// the requested file, and constructs an HTTP response with the file
    /// content or an appropriate error status.
    ///
    /// - Parameters:
    ///   - uri: The request URI path, potentially including query parameters.
    ///   - includeBody: Whether to include the response body. Set to `false`
    ///     for HEAD requests to omit the body while preserving headers.
    /// - Returns: An HTTP response containing the file data or error status.
    ///
    /// ## Response Codes
    ///
    /// - 200 OK: File found and served successfully
    /// - 400 Bad Request: Malformed URI or invalid path encoding
    /// - 403 Forbidden: Path escapes root directory (security violation)
    /// - 404 Not Found: File or directory index does not exist
    /// - 500 Internal Server Error: File read failure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let response = await handler.handleRequest(
    ///     uri: "/documentation/index.html",
    ///     includeBody: true
    /// )
    /// ```
    public func handleRequest(uri: String, includeBody: Bool) async -> HTTPResponse {
        // Parse and sanitise the path
        guard let path = sanitizePath(uri) else {
            return .badRequest
        }

        let filePath = rootDirectory.appendingPathComponent(path)

        // Security: Ensure path is within root directory
        guard filePath.standardizedFileURL.path.hasPrefix(rootDirectory.path) else {
            return .forbidden
        }

        // Check if path exists
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: filePath.path, isDirectory: &isDirectory)
        else {
            return .notFound
        }

        // If directory, try index.html
        let targetPath: URL
        if isDirectory.boolValue {
            let indexPath = filePath.appendingPathComponent("index.html")
            if fileManager.fileExists(atPath: indexPath.path) {
                targetPath = indexPath
            } else {
                return .notFound
            }
        } else {
            targetPath = filePath
        }

        // Read file and determine MIME type
        do {
            let data = includeBody ? try Data(contentsOf: targetPath) : Data()
            let mimeType = MIMEType.from(fileExtension: targetPath.pathExtension)
            return .ok(body: data, contentType: mimeType, includeBody: includeBody)
        } catch {
            return .internalServerError
        }
    }

    /// Sanitises a URI path to prevent directory traversal attacks.
    ///
    /// This method performs several operations:
    /// 1. Strips query parameters
    /// 2. URL-decodes the path
    /// 3. Normalises path components, removing `.` and `..`
    /// 4. Validates the result
    ///
    /// - Parameter uri: The raw URI from the HTTP request.
    /// - Returns: A sanitised relative path, or `nil` if the URI is invalid.
    ///
    /// ## Security Notes
    ///
    /// Path normalisation prevents attacks using sequences like:
    /// - `/../../../etc/passwd`
    /// - `/docs/../../secret.txt`
    /// - `/./../.hidden/file`
    ///
    /// ## Example
    ///
    /// ```swift
    /// sanitizePath("/docs/api/index.html?v=1.0")  // "docs/api/index.html"
    /// sanitizePath("/docs/../admin/secret.html")  // "admin/secret.html"
    /// sanitizePath("/../etc/passwd")              // "" (prevented)
    /// ```
    private func sanitizePath(_ uri: String) -> String? {
        // Extract path component (remove query string)
        let path = uri.split(separator: "?", maxSplits: 1).first.map(String.init) ?? uri

        // URL decode
        guard let decoded = path.removingPercentEncoding else {
            return nil
        }

        // Remove leading slash and normalise
        var components: [String] = []
        for component in decoded.split(separator: "/") {
            let str = String(component)
            switch str {
            case ".", "":
                continue
            case "..":
                // Prevent directory traversal
                if !components.isEmpty {
                    components.removeLast()
                }
            default:
                components.append(str)
            }
        }

        return components.isEmpty ? "" : components.joined(separator: "/")
    }
}
