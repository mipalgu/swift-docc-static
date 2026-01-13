//
// MIMEType.swift
// DocCStaticServer
//
//  Created by Rene Hexel on 13/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// MIME type mapping for static file serving.
///
/// This enumeration provides MIME type mappings for common file types served
/// in static documentation. Each case includes appropriate charset declarations
/// where applicable.
///
/// ## Overview
///
/// The MIME type determines how browsers and HTTP clients interpret file content.
/// This enumeration covers text formats, images, fonts, and multimedia commonly
/// found in documentation sites.
///
/// ## Topics
///
/// ### Getting MIME Types
///
/// - ``from(fileExtension:)``
///
/// ### Text Formats
///
/// - ``html``
/// - ``css``
/// - ``javascript``
/// - ``plain``
/// - ``xml``
///
/// ### Application Formats
///
/// - ``json``
/// - ``pdf``
/// - ``zip``
/// - ``octetStream``
///
/// ### Image Formats
///
/// - ``png``
/// - ``jpeg``
/// - ``gif``
/// - ``svg``
/// - ``webp``
/// - ``ico``
///
/// ### Font Formats
///
/// - ``woff``
/// - ``woff2``
/// - ``ttf``
/// - ``otf``
///
/// ### Multimedia Formats
///
/// - ``mp4``
/// - ``webm``
/// - ``mp3``
/// - ``wav``
public enum MIMEType: String, Sendable {
    // MARK: - Text Formats

    /// HTML document with UTF-8 character encoding.
    case html = "text/html; charset=utf-8"

    /// Cascading Style Sheet with UTF-8 character encoding.
    case css = "text/css; charset=utf-8"

    /// JavaScript source code with UTF-8 character encoding.
    case javascript = "text/javascript; charset=utf-8"

    /// Plain text document with UTF-8 character encoding.
    case plain = "text/plain; charset=utf-8"

    /// XML document with UTF-8 character encoding.
    case xml = "text/xml; charset=utf-8"

    // MARK: - Application Formats

    /// JSON data with UTF-8 character encoding.
    case json = "application/json; charset=utf-8"

    /// Portable Document Format (PDF) file.
    case pdf = "application/pdf"

    /// ZIP archive file.
    case zip = "application/zip"

    /// Generic binary data stream (fallback for unknown types).
    case octetStream = "application/octet-stream"

    // MARK: - Image Formats

    /// Portable Network Graphics (PNG) image.
    case png = "image/png"

    /// JPEG image format.
    case jpeg = "image/jpeg"

    /// Graphics Interchange Format (GIF) image.
    case gif = "image/gif"

    /// Scalable Vector Graphics (SVG) image.
    case svg = "image/svg+xml"

    /// WebP image format.
    case webp = "image/webp"

    /// Icon image format (typically .ico files).
    case ico = "image/x-icon"

    // MARK: - Font Formats

    /// Web Open Font Format (WOFF) font.
    case woff = "font/woff"

    /// Web Open Font Format 2.0 (WOFF2) font.
    case woff2 = "font/woff2"

    /// TrueType Font (TTF) format.
    case ttf = "font/ttf"

    /// OpenType Font (OTF) format.
    case otf = "font/otf"

    // MARK: - Multimedia Formats

    /// MPEG-4 video format.
    case mp4 = "video/mp4"

    /// WebM video format.
    case webm = "video/webm"

    /// MPEG audio format (MP3).
    case mp3 = "audio/mpeg"

    /// Waveform Audio Format (WAV).
    case wav = "audio/wav"

    // MARK: - Type Detection

    /// Determines the MIME type from a file extension.
    ///
    /// This method performs case-insensitive matching of file extensions to
    /// MIME types. Extensions without a leading dot are expected.
    ///
    /// - Parameter fileExtension: The file extension without leading dot
    ///   (e.g., `"html"`, `"png"`).
    /// - Returns: The corresponding MIME type, or ``octetStream`` if the
    ///   extension is not recognised.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let htmlType = MIMEType.from(fileExtension: "html")
    /// // Returns: .html ("text/html; charset=utf-8")
    ///
    /// let pngType = MIMEType.from(fileExtension: "PNG")
    /// // Returns: .png ("image/png") - case insensitive
    ///
    /// let unknownType = MIMEType.from(fileExtension: "xyz")
    /// // Returns: .octetStream ("application/octet-stream")
    /// ```
    public static func from(fileExtension ext: String) -> MIMEType {
        switch ext.lowercased() {
        // Text
        case "html", "htm":
            return .html
        case "css":
            return .css
        case "js", "mjs":
            return .javascript
        case "txt":
            return .plain
        case "xml":
            return .xml

        // Application
        case "json":
            return .json
        case "pdf":
            return .pdf
        case "zip":
            return .zip

        // Images
        case "png":
            return .png
        case "jpg", "jpeg":
            return .jpeg
        case "gif":
            return .gif
        case "svg":
            return .svg
        case "webp":
            return .webp
        case "ico":
            return .ico

        // Fonts
        case "woff":
            return .woff
        case "woff2":
            return .woff2
        case "ttf":
            return .ttf
        case "otf":
            return .otf

        // Video/Audio
        case "mp4":
            return .mp4
        case "webm":
            return .webm
        case "mp3":
            return .mp3
        case "wav":
            return .wav

        default:
            return .octetStream
        }
    }
}
