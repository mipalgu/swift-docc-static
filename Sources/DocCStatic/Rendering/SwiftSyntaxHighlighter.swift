//
// SwiftSyntaxHighlighter.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// A simple Swift syntax highlighter for static HTML output.
///
/// This provides basic syntax highlighting without requiring JavaScript.
/// It handles common Swift constructs like keywords, strings, numbers,
/// and comments.
public struct SwiftSyntaxHighlighter: Sendable {
    /// Swift keywords that should be highlighted.
    private static let keywords: Set<String> = [
        // Declarations
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate",
        "func", "import", "init", "inout", "internal", "let", "open", "operator",
        "private", "precedencegroup", "protocol", "public", "rethrows", "static",
        "struct", "subscript", "typealias", "var", "actor", "macro", "nonisolated",
        "package", "consuming", "borrowing", "sending",
        // Statements
        "break", "case", "catch", "continue", "default", "defer", "do", "else",
        "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch",
        "throw", "throws", "try", "where", "while", "async", "await",
        // Expressions and types
        "as", "Any", "catch", "false", "is", "nil", "self", "Self", "super",
        "throw", "throws", "true", "try", "some", "any",
        // Attributes
        "associativity", "convenience", "didSet", "dynamic", "final", "get",
        "indirect", "infix", "lazy", "left", "mutating", "none", "nonmutating",
        "optional", "override", "postfix", "prefix", "Protocol", "required",
        "right", "set", "Type", "unowned", "weak", "willSet", "isolated",
        "distributed"
    ]
    /// Creates a new syntax highlighter.
    public init() {}
}

// MARK: - Highlight

public extension SwiftSyntaxHighlighter {
    /// Highlights Swift code and returns HTML with syntax highlighting spans.
    ///
    /// - Parameter code: The Swift code to highlight.
    /// - Returns: HTML string with syntax highlighting applied.
    func highlight(_ code: String) -> String {
        var result = ""
        var index = code.startIndex

        while index < code.endIndex {
            let remaining = code[index...]

            // Check for multi-line comments
            if remaining.hasPrefix("/*") {
                let endIndex = findMultiLineCommentEnd(in: remaining)
                let comment = String(code[index..<endIndex])
                result += "<span class=\"syntax-comment\">\(escapeHTML(comment))</span>"
                index = endIndex
                continue
            }

            // Check for single-line comments
            if remaining.hasPrefix("//") {
                let endIndex = remaining.firstIndex(of: "\n") ?? code.endIndex
                let comment = String(code[index..<endIndex])
                result += "<span class=\"syntax-comment\">\(escapeHTML(comment))</span>"
                index = endIndex
                continue
            }

            // Check for strings
            if remaining.hasPrefix("\"") {
                let (stringContent, endIndex) = extractString(from: remaining, startingWith: "\"")
                result += "<span class=\"syntax-string\">\(escapeHTML(stringContent))</span>"
                index = endIndex
                continue
            }

            // Check for multi-line strings
            if remaining.hasPrefix("\"\"\"") {
                let (stringContent, endIndex) = extractMultilineString(from: remaining)
                result += "<span class=\"syntax-string\">\(escapeHTML(stringContent))</span>"
                index = endIndex
                continue
            }

            // Check for numbers
            if let firstChar = remaining.first, firstChar.isNumber || (firstChar == "." && remaining.dropFirst().first?.isNumber == true) {
                let (number, endIndex) = extractNumber(from: remaining)
                result += "<span class=\"syntax-number\">\(escapeHTML(number))</span>"
                index = endIndex
                continue
            }

            // Check for identifiers (keywords or regular)
            if let firstChar = remaining.first, firstChar.isLetter || firstChar == "_" || firstChar == "@" || firstChar == "#" {
                let (identifier, endIndex) = extractIdentifier(from: remaining)

                if identifier.hasPrefix("@") || identifier.hasPrefix("#") {
                    // Attribute or directive
                    result += "<span class=\"syntax-attribute\">\(escapeHTML(identifier))</span>"
                } else if Self.keywords.contains(identifier) {
                    result += "<span class=\"syntax-keyword\">\(escapeHTML(identifier))</span>"
                } else if identifier.first?.isUppercase == true {
                    // Type name (starts with uppercase)
                    result += "<span class=\"syntax-type\">\(escapeHTML(identifier))</span>"
                } else {
                    result += escapeHTML(identifier)
                }
                index = endIndex
                continue
            }

            // Other characters (operators, punctuation, whitespace)
            result += escapeHTML(String(code[index]))
            index = code.index(after: index)
        }

        return result
    }

    // MARK: - Private Extraction Helpers

    private func findMultiLineCommentEnd(in substring: Substring) -> String.Index {
        var depth = 0
        var index = substring.startIndex

        while index < substring.endIndex {
            if substring[index...].hasPrefix("/*") {
                depth += 1
                index = substring.index(index, offsetBy: 2, limitedBy: substring.endIndex) ?? substring.endIndex
            } else if substring[index...].hasPrefix("*/") {
                depth -= 1
                index = substring.index(index, offsetBy: 2, limitedBy: substring.endIndex) ?? substring.endIndex
                if depth == 0 {
                    return index
                }
            } else {
                index = substring.index(after: index)
            }
        }

        return substring.endIndex
    }

    private func extractString(from substring: Substring, startingWith delimiter: String) -> (String, String.Index) {
        var index = substring.index(after: substring.startIndex)
        var escaped = false

        while index < substring.endIndex {
            let char = substring[index]

            if escaped {
                escaped = false
                index = substring.index(after: index)
                continue
            }

            if char == "\\" {
                escaped = true
                index = substring.index(after: index)
                continue
            }

            if char == "\"" {
                let endIndex = substring.index(after: index)
                return (String(substring[substring.startIndex..<endIndex]), endIndex)
            }

            // String ended at newline (for single-line strings)
            if char == "\n" {
                return (String(substring[substring.startIndex..<index]), index)
            }

            index = substring.index(after: index)
        }

        return (String(substring), substring.endIndex)
    }

    private func extractMultilineString(from substring: Substring) -> (String, String.Index) {
        // Skip opening """
        var index = substring.index(substring.startIndex, offsetBy: 3, limitedBy: substring.endIndex) ?? substring.endIndex

        while index < substring.endIndex {
            if substring[index...].hasPrefix("\"\"\"") {
                let endIndex = substring.index(index, offsetBy: 3, limitedBy: substring.endIndex) ?? substring.endIndex
                return (String(substring[substring.startIndex..<endIndex]), endIndex)
            }
            index = substring.index(after: index)
        }

        return (String(substring), substring.endIndex)
    }

    private func extractNumber(from substring: Substring) -> (String, String.Index) {
        var index = substring.startIndex
        var hasDecimal = false
        var hasExponent = false

        // Handle hex, octal, binary prefixes
        if substring.hasPrefix("0x") || substring.hasPrefix("0o") || substring.hasPrefix("0b") {
            index = substring.index(index, offsetBy: 2, limitedBy: substring.endIndex) ?? substring.endIndex
        }

        while index < substring.endIndex {
            let char = substring[index]

            if char.isNumber || char == "_" {
                index = substring.index(after: index)
            } else if char == "." && !hasDecimal && !hasExponent {
                // Check if next char is a digit (to avoid method calls)
                let nextIndex = substring.index(after: index)
                if nextIndex < substring.endIndex && substring[nextIndex].isNumber {
                    hasDecimal = true
                    index = nextIndex
                } else {
                    break
                }
            } else if (char == "e" || char == "E") && !hasExponent {
                hasExponent = true
                index = substring.index(after: index)
                // Handle optional +/- after exponent
                if index < substring.endIndex && (substring[index] == "+" || substring[index] == "-") {
                    index = substring.index(after: index)
                }
            } else if char.isHexDigit && substring.startIndex < index {
                // For hex numbers
                let prefixEnd = substring.index(substring.startIndex, offsetBy: 2, limitedBy: index) ?? index
                if String(substring[substring.startIndex..<prefixEnd]) == "0x" {
                    index = substring.index(after: index)
                } else {
                    break
                }
            } else {
                break
            }
        }

        return (String(substring[substring.startIndex..<index]), index)
    }

    private func extractIdentifier(from substring: Substring) -> (String, String.Index) {
        var index = substring.startIndex

        // Handle @ or # prefix
        if let first = substring.first, first == "@" || first == "#" {
            index = substring.index(after: index)
        }

        // Consume identifier characters
        while index < substring.endIndex {
            let char = substring[index]
            if char.isLetter || char.isNumber || char == "_" {
                index = substring.index(after: index)
            } else {
                break
            }
        }

        return (String(substring[substring.startIndex..<index]), index)
    }
}
