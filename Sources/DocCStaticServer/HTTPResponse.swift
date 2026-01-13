//
// HTTPResponse.swift
// DocCStaticServer
//
//  Created by Rene Hexel on 13/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import NIOCore
import NIOHTTP1

/// An HTTP response structure for static file serving.
///
/// This type encapsulates an HTTP response head (status code and headers)
/// along with an optional response body. All instances are `Sendable`, making
/// them safe to pass across concurrency boundaries.
///
/// ## Overview
///
/// `HTTPResponse` provides factory methods for common HTTP status codes,
/// making it easy to construct appropriate responses for various scenarios
/// encountered during static file serving.
///
/// ## Topics
///
/// ### Creating Success Responses
///
/// - ``ok(body:contentType:includeBody:)``
///
/// ### Creating Error Responses
///
/// - ``badRequest``
/// - ``forbidden``
/// - ``notFound``
/// - ``methodNotAllowed``
/// - ``internalServerError``
///
/// ### Response Properties
///
/// - ``head``
/// - ``body``
public struct HTTPResponse: Sendable {
    /// The HTTP response head containing status and headers.
    ///
    /// This includes the HTTP version, status code, and all response headers.
    public let head: HTTPResponseHead

    /// The optional response body as a byte buffer.
    ///
    /// Set to `nil` for HEAD requests or responses without a body.
    public let body: ByteBuffer?

    /// Creates an HTTP response with a status and optional body.
    ///
    /// This initialiser automatically sets the `Content-Length` and `Connection`
    /// headers based on the provided body.
    ///
    /// - Parameters:
    ///   - status: The HTTP status code for the response.
    ///   - headers: Additional HTTP headers to include (default: empty).
    ///   - body: Optional response body as a byte buffer.
    private init(
        status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders(), body: ByteBuffer? = nil
    ) {
        var responseHeaders = headers

        if let body = body {
            responseHeaders.add(name: "content-length", value: "\(body.readableBytes)")
        } else {
            responseHeaders.add(name: "content-length", value: "0")
        }
        responseHeaders.add(name: "connection", value: "close")

        let responseHead = HTTPResponseHead(
            version: .http1_1, status: status, headers: responseHeaders)
        self.head = responseHead
        self.body = body
    }

    // MARK: - Success Responses

    /// Creates a 200 OK response with file content.
    ///
    /// This method constructs a successful response containing the file data
    /// with appropriate content type and length headers.
    ///
    /// - Parameters:
    ///   - body: The file data to include in the response body.
    ///   - contentType: The MIME type of the content.
    ///   - includeBody: Whether to include the body content. Set to `false`
    ///     for HEAD requests.
    /// - Returns: A configured HTTP response.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let fileData = try Data(contentsOf: fileURL)
    /// let response = HTTPResponse.ok(
    ///     body: fileData,
    ///     contentType: .html,
    ///     includeBody: true
    /// )
    /// ```
    public static func ok(body data: Data, contentType: MIMEType, includeBody: Bool) -> HTTPResponse
    {
        var headers = HTTPHeaders()
        headers.add(name: "content-type", value: contentType.rawValue)
        headers.add(name: "content-length", value: "\(data.count)")
        headers.add(name: "connection", value: "close")

        let buffer: ByteBuffer?
        if includeBody {
            var buf = ByteBufferAllocator().buffer(capacity: data.count)
            buf.writeBytes(data)
            buffer = buf
        } else {
            buffer = nil
        }

        let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
        return HTTPResponse(head: head, body: buffer)
    }

    /// Direct initialiser for custom response head and body combinations.
    ///
    /// - Parameters:
    ///   - head: The configured HTTP response head.
    ///   - body: Optional response body buffer.
    private init(head: HTTPResponseHead, body: ByteBuffer?) {
        self.head = head
        self.body = body
    }

    // MARK: - Error Responses

    /// 400 Bad Request response.
    ///
    /// Returned when the request URI is malformed or invalid.
    public static var badRequest: HTTPResponse {
        HTTPResponse(status: .badRequest, body: textBuffer("Bad Request"))
    }

    /// 403 Forbidden response.
    ///
    /// Returned when the requested path is outside the allowed directory
    /// or otherwise inaccessible for security reasons.
    public static var forbidden: HTTPResponse {
        HTTPResponse(status: .forbidden, body: textBuffer("Forbidden"))
    }

    /// 404 Not Found response.
    ///
    /// Returned when the requested file or resource does not exist.
    public static var notFound: HTTPResponse {
        HTTPResponse(status: .notFound, body: textBuffer("Not Found"))
    }

    /// 405 Method Not Allowed response.
    ///
    /// Returned when a request method other than GET or HEAD is used.
    /// Includes an `Allow` header indicating supported methods.
    public static var methodNotAllowed: HTTPResponse {
        var headers = HTTPHeaders()
        headers.add(name: "allow", value: "GET, HEAD")
        return HTTPResponse(
            status: .methodNotAllowed, headers: headers, body: textBuffer("Method Not Allowed"))
    }

    /// 500 Internal Server Error response.
    ///
    /// Returned when an unexpected error occurs while processing the request.
    public static var internalServerError: HTTPResponse {
        HTTPResponse(status: .internalServerError, body: textBuffer("Internal Server Error"))
    }

    // MARK: - Helpers

    /// Creates a byte buffer containing UTF-8 encoded text.
    ///
    /// - Parameter text: The text string to encode.
    /// - Returns: A byte buffer containing the text.
    private static func textBuffer(_ text: String) -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: text.utf8.count)
        buffer.writeString(text)
        return buffer
    }
}
