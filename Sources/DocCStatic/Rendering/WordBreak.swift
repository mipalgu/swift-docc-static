//
// WordBreak.swift
// DocCStatic
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// Safe places to break long names across lines, like swift-docc-render's `WordBreak`.
///
/// Long symbol names, such as `init(basePackage:prefix:packagePrefixes:)`, contain no
/// spaces, so a browser would otherwise break them between arbitrary characters on a
/// narrow screen.  The markup marks the boundaries swift-docc-render uses with `<wbr>`
/// elements, so that names break at readable places when they do not fit:
///
/// - between a lower case and an upper case letter (`foo<wbr>Bar`),
/// - after a colon that is followed by a word character (`x:<wbr>y:`),
/// - before a dot or an underscore between word characters (`Foo<wbr>.Bar`).
///
/// Only ASCII letters, digits and the underscore count as word characters.
public enum WordBreak {
    /// The element that marks a word break opportunity.
    public static let opportunity = "<wbr>"

    /// Returns the escaped HTML of a text with word break opportunities.
    ///
    /// The text is scanned from the start like swift-docc-render's regular expression
    /// `([a-z](?=[A-Z])|(:)\w|\w(?=[._]\w))`: after each match the scan continues
    /// behind the characters the match consumed, and the break is placed after the
    /// first character of the match.
    ///
    /// - Parameter text: The plain text, such as a symbol name.
    /// - Returns: The HTML-escaped text with `<wbr>` elements at the boundaries.
    public static func markup(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var html = ""
        var segment = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            let consumed = matchLength(in: scalars, at: index)
            guard consumed > 0 else {
                segment.append(scalars[index])
                index += 1
                continue
            }
            segment.append(scalars[index])
            html += escapeHTML(String(segment)) + opportunity
            segment = String.UnicodeScalarView()
            for offset in 1..<consumed {
                segment.append(scalars[index + offset])
            }
            index += consumed
        }
        return html + escapeHTML(String(segment))
    }

    /// Returns the number of characters a boundary match consumes at a position.
    ///
    /// - Parameters:
    ///   - scalars: The characters of the text.
    ///   - index: The position to match at.
    /// - Returns: The length of the match, or zero if no boundary starts there.
    static func matchLength(in scalars: [Unicode.Scalar], at index: Int) -> Int {
        let current = scalars[index]
        guard index + 1 < scalars.count else { return 0 }
        let next = scalars[index + 1]
        if isLowercase(current) && isUppercase(next) {
            return 1
        }
        if current == ":" && isWordCharacter(next) {
            return 2
        }
        if isWordCharacter(current), next == "." || next == "_",
           index + 2 < scalars.count, isWordCharacter(scalars[index + 2]) {
            return 1
        }
        return 0
    }

    /// Returns whether a character is an ASCII lower case letter.
    ///
    /// - Parameter scalar: The character.
    /// - Returns: `true` for `a` to `z`.
    static func isLowercase(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar)
    }

    /// Returns whether a character is an ASCII upper case letter.
    ///
    /// - Parameter scalar: The character.
    /// - Returns: `true` for `A` to `Z`.
    static func isUppercase(_ scalar: Unicode.Scalar) -> Bool {
        ("A"..."Z").contains(scalar)
    }

    /// Returns whether a character is a word character of a regular expression.
    ///
    /// - Parameter scalar: The character.
    /// - Returns: `true` for ASCII letters, digits and the underscore.
    static func isWordCharacter(_ scalar: Unicode.Scalar) -> Bool {
        isLowercase(scalar) || isUppercase(scalar) || ("0"..."9").contains(scalar) || scalar == "_"
    }
}
