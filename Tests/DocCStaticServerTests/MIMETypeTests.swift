//
// MIMETypeTests.swift
// DocCStaticServerTests
//
//  Created by Rene Hexel on 13/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import Testing

@testable import DocCStaticServer

@Suite("MIME Type Detection Tests")
struct MIMETypeTests {

    // MARK: - Text Formats

    @Test("HTML files return HTML MIME type")
    func htmlMIMEType() {
        #expect(MIMEType.from(fileExtension: "html") == .html)
        #expect(MIMEType.from(fileExtension: "htm") == .html)
    }

    @Test("HTML detection is case insensitive")
    func htmlCaseInsensitive() {
        #expect(MIMEType.from(fileExtension: "HTML") == .html)
        #expect(MIMEType.from(fileExtension: "HTM") == .html)
        #expect(MIMEType.from(fileExtension: "HtMl") == .html)
    }

    @Test("CSS files return CSS MIME type")
    func cssMIMEType() {
        #expect(MIMEType.from(fileExtension: "css") == .css)
        #expect(MIMEType.from(fileExtension: "CSS") == .css)
    }

    @Test("JavaScript files return JavaScript MIME type")
    func javaScriptMIMEType() {
        #expect(MIMEType.from(fileExtension: "js") == .javascript)
        #expect(MIMEType.from(fileExtension: "mjs") == .javascript)
        #expect(MIMEType.from(fileExtension: "JS") == .javascript)
    }

    @Test("Plain text files return plain MIME type")
    func plainTextMIMEType() {
        #expect(MIMEType.from(fileExtension: "txt") == .plain)
        #expect(MIMEType.from(fileExtension: "TXT") == .plain)
    }

    @Test("XML files return XML MIME type")
    func xmlMIMEType() {
        #expect(MIMEType.from(fileExtension: "xml") == .xml)
        #expect(MIMEType.from(fileExtension: "XML") == .xml)
    }

    // MARK: - Application Formats

    @Test("JSON files return JSON MIME type")
    func jsonMIMEType() {
        #expect(MIMEType.from(fileExtension: "json") == .json)
        #expect(MIMEType.from(fileExtension: "JSON") == .json)
    }

    @Test("PDF files return PDF MIME type")
    func pdfMIMEType() {
        #expect(MIMEType.from(fileExtension: "pdf") == .pdf)
        #expect(MIMEType.from(fileExtension: "PDF") == .pdf)
    }

    @Test("ZIP files return ZIP MIME type")
    func zipMIMEType() {
        #expect(MIMEType.from(fileExtension: "zip") == .zip)
        #expect(MIMEType.from(fileExtension: "ZIP") == .zip)
    }

    // MARK: - Image Formats

    @Test("PNG files return PNG MIME type")
    func pngMIMEType() {
        #expect(MIMEType.from(fileExtension: "png") == .png)
        #expect(MIMEType.from(fileExtension: "PNG") == .png)
    }

    @Test("JPEG files return JPEG MIME type")
    func jpegMIMEType() {
        #expect(MIMEType.from(fileExtension: "jpg") == .jpeg)
        #expect(MIMEType.from(fileExtension: "jpeg") == .jpeg)
        #expect(MIMEType.from(fileExtension: "JPG") == .jpeg)
        #expect(MIMEType.from(fileExtension: "JPEG") == .jpeg)
    }

    @Test("GIF files return GIF MIME type")
    func gifMIMEType() {
        #expect(MIMEType.from(fileExtension: "gif") == .gif)
        #expect(MIMEType.from(fileExtension: "GIF") == .gif)
    }

    @Test("SVG files return SVG MIME type")
    func svgMIMEType() {
        #expect(MIMEType.from(fileExtension: "svg") == .svg)
        #expect(MIMEType.from(fileExtension: "SVG") == .svg)
    }

    @Test("WebP files return WebP MIME type")
    func webpMIMEType() {
        #expect(MIMEType.from(fileExtension: "webp") == .webp)
        #expect(MIMEType.from(fileExtension: "WEBP") == .webp)
    }

    @Test("ICO files return ICO MIME type")
    func icoMIMEType() {
        #expect(MIMEType.from(fileExtension: "ico") == .ico)
        #expect(MIMEType.from(fileExtension: "ICO") == .ico)
    }

    // MARK: - Font Formats

    @Test("WOFF files return WOFF MIME type")
    func woffMIMEType() {
        #expect(MIMEType.from(fileExtension: "woff") == .woff)
        #expect(MIMEType.from(fileExtension: "WOFF") == .woff)
    }

    @Test("WOFF2 files return WOFF2 MIME type")
    func woff2MIMEType() {
        #expect(MIMEType.from(fileExtension: "woff2") == .woff2)
        #expect(MIMEType.from(fileExtension: "WOFF2") == .woff2)
    }

    @Test("TTF files return TTF MIME type")
    func ttfMIMEType() {
        #expect(MIMEType.from(fileExtension: "ttf") == .ttf)
        #expect(MIMEType.from(fileExtension: "TTF") == .ttf)
    }

    @Test("OTF files return OTF MIME type")
    func otfMIMEType() {
        #expect(MIMEType.from(fileExtension: "otf") == .otf)
        #expect(MIMEType.from(fileExtension: "OTF") == .otf)
    }

    // MARK: - Multimedia Formats

    @Test("MP4 files return MP4 MIME type")
    func mp4MIMEType() {
        #expect(MIMEType.from(fileExtension: "mp4") == .mp4)
        #expect(MIMEType.from(fileExtension: "MP4") == .mp4)
    }

    @Test("WebM files return WebM MIME type")
    func webmMIMEType() {
        #expect(MIMEType.from(fileExtension: "webm") == .webm)
        #expect(MIMEType.from(fileExtension: "WEBM") == .webm)
    }

    @Test("MP3 files return MP3 MIME type")
    func mp3MIMEType() {
        #expect(MIMEType.from(fileExtension: "mp3") == .mp3)
        #expect(MIMEType.from(fileExtension: "MP3") == .mp3)
    }

    @Test("WAV files return WAV MIME type")
    func wavMIMEType() {
        #expect(MIMEType.from(fileExtension: "wav") == .wav)
        #expect(MIMEType.from(fileExtension: "WAV") == .wav)
    }

    // MARK: - Unknown Types

    @Test("Unknown extensions return octet-stream")
    func unknownExtensions() {
        #expect(MIMEType.from(fileExtension: "unknown") == .octetStream)
        #expect(MIMEType.from(fileExtension: "xyz") == .octetStream)
        #expect(MIMEType.from(fileExtension: "123") == .octetStream)
        #expect(MIMEType.from(fileExtension: "random") == .octetStream)
    }

    @Test("Empty extension returns octet-stream")
    func emptyExtension() {
        #expect(MIMEType.from(fileExtension: "") == .octetStream)
    }

    // MARK: - MIME Type Values

    @Test("HTML MIME type includes charset")
    func htmlMIMETypeValue() {
        #expect(MIMEType.html.rawValue == "text/html; charset=utf-8")
    }

    @Test("CSS MIME type includes charset")
    func cssMIMETypeValue() {
        #expect(MIMEType.css.rawValue == "text/css; charset=utf-8")
    }

    @Test("JavaScript MIME type includes charset")
    func javascriptMIMETypeValue() {
        #expect(MIMEType.javascript.rawValue == "text/javascript; charset=utf-8")
    }

    @Test("JSON MIME type includes charset")
    func jsonMIMETypeValue() {
        #expect(MIMEType.json.rawValue == "application/json; charset=utf-8")
    }

    @Test("Image MIME types do not include charset")
    func imageMIMETypeValues() {
        #expect(MIMEType.png.rawValue == "image/png")
        #expect(MIMEType.jpeg.rawValue == "image/jpeg")
        #expect(MIMEType.svg.rawValue == "image/svg+xml")
    }

    @Test("Font MIME types do not include charset")
    func fontMIMETypeValues() {
        #expect(MIMEType.woff.rawValue == "font/woff")
        #expect(MIMEType.woff2.rawValue == "font/woff2")
    }

    @Test("Octet-stream MIME type is correct")
    func octetStreamMIMETypeValue() {
        #expect(MIMEType.octetStream.rawValue == "application/octet-stream")
    }
}
