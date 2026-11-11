//
// TopicTypeIcon.swift
// DocCStatic
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// The icons swift-docc-render shows for the kinds of documentation topics.
///
/// The navigator shows one icon per row (swift-docc-render's `TopicTypeIcon`), and
/// topic lists show an icon for articles, collections, tutorials and sample code
/// (swift-docc-render's `TopicLinkBlockIcon`).  Symbol kinds use a framed letter, such
/// as *S* for a structure or *Pr* for a protocol.  Every icon carries the topic type in
/// a `data-topic-type` attribute and its letters in a `data-topic-letters` attribute,
/// so that a theme can restyle it, for example as a filled letter badge.
public enum TopicTypeIcon {
    /// The attribute that names the topic type of an icon or topic item.
    public static let typeAttribute = "data-topic-type"

    /// The attribute that holds the letters of a symbol icon.
    public static let lettersAttribute = "data-topic-letters"

    /// The class of the element wrapping an icon.
    public static let className = "TopicTypeIcon"
}

// MARK: - Types

public extension TopicTypeIcon {
    /// Returns the swift-docc-render topic type for a navigator or reference type name.
    ///
    /// Synonyms are mapped like swift-docc-render's `TopicTypeAliases` (initialisers
    /// and deinitialisers show as methods, enumeration cases as enumerations), and the
    /// long kind names of symbol graphs (such as `structure` or `instanceMethod`) are
    /// mapped to the short type names of the navigator index.
    ///
    /// - Parameter type: A type name, such as `struct`, `instanceMethod` or `article`.
    /// - Returns: The normalised topic type.
    static func normalisedType(_ type: String) -> String {
        switch type {
        case "init", "initializer", "deinit", "deinitializer", "instanceMethod", "typeMethod", "method":
            return "method"
        case "case", "enumerationCase", "enum", "enumeration":
            return "enum"
        case "structure", "struct":
            return "struct"
        case "instanceProperty", "typeProperty", "property":
            return "property"
        case "variable", "globalVariable", "localVariable", "var", "let", "constant":
            return "var"
        case "function", "func":
            return "func"
        case "operator", "op":
            return "op"
        case "instanceSubscript", "typeSubscript", "subscript":
            return "subscript"
        case "propertyListKeyReference":
            return "propertyListKey"
        case "project":
            return "tutorial"
        case "associatedType":
            return "associatedtype"
        case "typeAlias":
            return "typealias"
        default:
            return type
        }
    }

    /// Returns the letters shown by the framed letter icon of a topic type.
    ///
    /// - Parameter type: A normalised topic type (see ``normalisedType(_:)``).
    /// - Returns: One or two letters, or `nil` if the type uses a drawn icon.
    static func letters(for type: String) -> String? {
        switch type {
        case "class": "C"
        case "dictionarySymbol": "O"
        case "enum", "httpRequest": "E"
        case "extension": "Ex"
        case "method": "M"
        case "macro": "#"
        case "namespace": "N"
        case "protocol": "Pr"
        case "property": "P"
        case "propertyListKey": "K"
        case "struct": "S"
        case "typealias": "T"
        case "union": "U"
        case "var": "V"
        default: nil
        }
    }
}

// MARK: - Markup

public extension TopicTypeIcon {
    /// Builds the icon of a topic type, wrapped like swift-docc-render's `TopicTypeIcon`.
    ///
    /// - Parameters:
    ///   - type: A type name; it is normalised with ``normalisedType(_:)``.
    ///   - additionalClass: Further classes of the wrapper, such as `navigator-icon`.
    /// - Returns: A `<span>` with the class ``className`` holding the SVG icon.
    static func markup(for type: String, additionalClass: String = "") -> String {
        let normalised = normalisedType(type)
        let classes = additionalClass.isEmpty ? className : "\(className) \(additionalClass)"
        var attributes = "class=\"\(classes)\" \(typeAttribute)=\"\(escapeHTML(normalised))\""
        if let letters = letters(for: normalised) {
            attributes += " \(lettersAttribute)=\"\(escapeHTML(letters))\""
        }
        return "<span \(attributes)>\(svg(for: normalised))</span>"
    }

    /// Returns the icon that topic lists show for a reference role, if any.
    ///
    /// Like swift-docc-render's `TopicLinkBlockIcon`, topic lists show icons only for
    /// articles, collections, tutorials, learning paths and sample code; symbols are
    /// identified by their declaration instead.
    ///
    /// - Parameter role: The role of the referenced page, such as `article` or `symbol`.
    /// - Returns: The SVG icon with the class `topic-icon`, or `nil` for other roles.
    static func topicListIcon(forRole role: String) -> String? {
        let icon: String
        switch role {
        case "article":
            icon = articleIcon
        case "collection":
            icon = technologyIcon
        case "collectionGroup":
            icon = apiReferenceIcon
        case "learn", "overview", "resources":
            icon = pathIcon
        case "project", "tutorial":
            icon = tutorialIcon
        case "sampleCode":
            icon = curlyBracketsIcon
        default:
            return nil
        }
        return icon.replacingOccurrences(of: "<svg ", with: "<svg class=\"topic-icon svg-icon\" ")
    }

    /// Returns the SVG icon of a normalised topic type.
    ///
    /// - Parameter type: A normalised topic type.
    /// - Returns: The SVG element.
    static func svg(for type: String) -> String {
        if let letters = letters(for: type) {
            return letters.count == 1 ? singleLetterIcon(letters) : twoLetterIcon(letters)
        }
        switch type {
        case "article": return articleIcon
        case "func": return functionIcon
        case "op": return operatorIcon
        case "module": return technologyIcon
        case "learn", "overview", "resources": return pathIcon
        case "sampleCode": return curlyBracketsIcon
        case "subscript": return subscriptIcon
        case "tutorial": return tutorialIcon
        default: return collectionIcon
        }
    }
}

// MARK: - Icons

private extension TopicTypeIcon {
    /// A framed single letter, such as *S* for a structure.
    static func singleLetterIcon(_ letter: String) -> String {
        """
        <svg class="svg-icon single-letter-icon" width="16" height="16" viewBox="0 0 16 16" aria-hidden="true">\
        <g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">\
        <rect stroke="currentColor" x="1" y="1" width="14" height="14"></rect>\
        <text font-size="11" font-weight="bold" fill="currentColor" x="49%" y="12" text-anchor="middle">\
        <tspan>\(escapeHTML(letter))</tspan></text></g></svg>
        """
    }

    /// A framed pair of letters, such as *Pr* for a protocol.
    static func twoLetterIcon(_ letters: String) -> String {
        let first = escapeHTML(String(letters.prefix(1)))
        let second = escapeHTML(String(letters.dropFirst()))
        return """
        <svg class="svg-icon two-letter-icon" width="16" height="16" viewBox="0 0 16 16" aria-hidden="true">\
        <g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"><g transform="translate(1, 1)">\
        <rect stroke="currentColor" x="0.5" y="0.5" width="13" height="13"></rect>\
        <text font-size="8" font-weight="bold" fill="currentColor"><tspan x="8.2" y="11">\(second)</tspan></text>\
        <text font-size="11" font-weight="bold" fill="currentColor"><tspan x="1.7" y="11">\(first)</tspan></text>\
        </g></g></svg>
        """
    }

    /// The page with a folded corner shown for articles.
    static let articleIcon = """
        <svg class="svg-icon article-icon" viewBox="0 0 14 14" aria-hidden="true">\
        <path d="M8.033 1l3.967 4.015v7.985h-10v-12zM7.615 2h-4.615v10h8v-6.574z"></path>\
        <path d="M7 1h1v4h-1z"></path><path d="M7 5h5v1h-5z"></path></svg>
        """

    /// The framed *f* shown for functions.
    static let functionIcon = """
        <svg class="svg-icon" viewBox="0 0 14 14" height="14" aria-hidden="true">\
        <path d="M13 1v12h-12v-12zM12.077 1.923h-10.154v10.154h10.154z"></path>\
        <path d="M5.191 9.529c0.044 0.002 0.089 0.004 0.133 0.004 0.108 0 0.196-0.025 0.262-0.074s0.122-0.113 0.166-0.188c0.044-0.077 0.078-0.159 0.103-0.247s0.049-0.173 0.074-0.251l0.598-2.186h-0.709l0.207-0.702h0.702l0.288-1.086c0.083-0.384 0.256-0.667 0.517-0.849s0.591-0.273 0.99-0.273c0.108 0 0.212 0.007 0.314 0.022s0.203 0.027 0.306 0.037l-0.207 0.761c-0.054-0.006-0.106-0.011-0.155-0.018s-0.102-0.011-0.155-0.011c-0.108 0-0.196 0.016-0.262 0.048s-0.122 0.075-0.166 0.129-0.080 0.115-0.107 0.185c-0.028 0.068-0.055 0.14-0.085 0.214l-0.222 0.842h0.768l-0.192 0.702h-0.783l-0.628 2.319c-0.059 0.222-0.129 0.419-0.21 0.594s-0.182 0.322-0.303 0.443-0.269 0.214-0.443 0.281-0.385 0.1-0.631 0.1c-0.084 0-0.168-0.004-0.251-0.011s-0.168-0.014-0.251-0.018l0.207-0.768c0.040 0 0.081 0.001 0.126 0.004z"></path></svg>
        """

    /// The framed operator signs shown for operators.
    static let operatorIcon = """
        <svg class="svg-icon" viewBox="0 0 14 14" height="14" aria-hidden="true">\
        <path d="M13 13h-12v-12h12zM1.923 12.077h10.154v-10.154h-10.154z"></path>\
        <path d="M5.098 4.968v-1.477h-0.738v1.477h-1.477v0.738h1.477v1.477h0.738v-1.477h1.477v-0.738z"></path>\
        <path d="M8.030 4.807l-2.031 5.538h0.831l2.031-5.538z"></path>\
        <path d="M8.894 8.805v0.923h2.215v-0.923z"></path></svg>
        """

    /// The framed brackets shown for subscripts.
    static let subscriptIcon = """
        <svg class="svg-icon" viewBox="0 0 14 14" height="14" aria-hidden="true">\
        <path d="M13 13h-12v-12h12zM1.923 12.077h10.154v-10.154h-10.154z"></path>\
        <path d="M4.133 3.633v6.738h1.938v-0.831h-0.923v-5.077h0.923v-0.831z"></path>\
        <path d="M9.856 10.371v-6.738h-1.938v0.831h0.923v5.077h-0.923v0.831z"></path></svg>
        """

    /// The framed list shown for collections and other kinds.
    static let collectionIcon = """
        <svg class="svg-icon collection-icon" viewBox="0 0 14 14" aria-hidden="true">\
        <path d="m1 1v12h12v-12zm11 11h-10v-10h10z"/><path d="m3 4h8v1h-8zm0 2.5h8v1h-8zm0 2.5h8v1h-8z"/></svg>
        """

    /// The stacked layers shown for modules and technologies.
    static let technologyIcon = """
        <svg class="svg-icon technology-icon" viewBox="0 0 14 14" aria-hidden="true">\
        <path d="M3.39,9l3.16,1.84.47.28.47-.28L10.61,9l.45.26,1.08.63L7,12.91l-5.16-3,1.08-.64L3.39,9M7,0,0,4.1,2.47,5.55,0,7,2.47,8.44,0,9.9,7,14l7-4.1L11.53,8.45,14,7,11.53,5.56,14,4.1ZM7,7.12,5.87,6.45l-1.54-.9L3.39,5,1.85,4.1,7,1.08l5.17,3L10.6,5l-.93.55-1.54.91ZM7,10,3.39,7.9,1.85,7,3.4,6.09,4.94,7,7,8.2,9.06,7,10.6,6.1,12.15,7l-1.55.9Z"/></svg>
        """

    /// The API collection icon shown for collection groups.
    static let apiReferenceIcon = """
        <svg class="svg-icon api-reference-icon" viewBox="0 0 14 14" aria-hidden="true">\
        <path d="m1 1v12h12v-12zm11 11h-10v-10h10z"></path>\
        <path d="m3 4h8v1h-8zm0 2.5h8v1h-8zm0 2.5h8v1h-8z"></path></svg>
        """

    /// The path icon shown for learning paths, overviews and resources.
    static let pathIcon = """
        <svg class="svg-icon path-icon" viewBox="0 0 14 14" aria-hidden="true">\
        <path d="M0 0.948h2.8v2.8h-2.8z"></path><path d="M11.2 10.252h2.8v2.8h-2.8z"></path>\
        <path d="M6.533 1.852h0.933v10.267h-0.933z"></path><path d="M2.8 1.852h4.667v0.933h-4.667z"></path>\
        <path d="M6.533 11.186h4.667v0.933h-4.667z"></path></svg>
        """

    /// The tutorial icon.
    static let tutorialIcon = """
        <svg class="svg-icon tutorial-icon" viewBox="0 0 14 14" aria-hidden="true">\
        <path d="M0.933 6.067h3.733v1.867h-3.733v-1.867z"></path><path d="M0.933 1.867h3.733v1.867h-3.733v-1.867z"></path>\
        <path d="M13.067 1.867v10.267h-7.467v-10.267zM12.133 2.8h-5.6v8.4h5.6z"></path>\
        <path d="M0.933 10.267h3.733v1.867h-3.733v-1.867z"></path></svg>
        """

    /// The curly brackets shown for sample code.
    static let curlyBracketsIcon = """
        <svg class="svg-icon curly-brackets-icon" viewBox="0 0 14 14" aria-hidden="true">\
        <path d="M4.827 14h-0.814c-0.442 0-0.788-0.18-1.030-0.538-0.238-0.352-0.358-0.825-0.358-1.409v-2.221c0-0.301-0.015-0.599-0.045-0.886-0.029-0.287-0.085-0.544-0.163-0.764-0.077-0.216-0.184-0.393-0.318-0.522-0.131-0.127-0.296-0.188-0.503-0.188h-0.058v-0.916h0.058c0.208 0 0.373-0.063 0.503-0.188 0.135-0.129 0.242-0.304 0.318-0.522 0.078-0.22 0.134-0.477 0.163-0.765 0.030-0.286 0.045-0.585 0.045-0.886v-2.251c0-0.582 0.12-1.055 0.358-1.407 0.242-0.358 0.588-0.538 1.030-0.538h0.814v0.916h-0.36c-0.138 0-0.252 0.038-0.349 0.116-0.099 0.079-0.179 0.189-0.239 0.327-0.064 0.139-0.11 0.302-0.141 0.483-0.029 0.18-0.044 0.373-0.044 0.572v2.13c0 0.417-0.046 0.782-0.138 1.082-0.092 0.302-0.201 0.556-0.324 0.754-0.123 0.201-0.246 0.356-0.366 0.459-0.086 0.074-0.153 0.13-0.206 0.167 0.052 0.038 0.12 0.093 0.206 0.169 0.12 0.103 0.243 0.258 0.366 0.458s0.232 0.453 0.324 0.754c0.092 0.302 0.138 0.666 0.138 1.083v2.115c0 0.2 0.015 0.394 0.044 0.58 0.030 0.186 0.077 0.349 0.139 0.482 0.062 0.132 0.142 0.239 0.241 0.32 0.096 0.079 0.21 0.116 0.349 0.116h0.36z"></path>\
        <path d="M9.987 14h-0.814v-0.916h0.36c0.137 0 0.253-0.038 0.349-0.116 0.099-0.080 0.179-0.188 0.239-0.318 0.064-0.134 0.11-0.298 0.139-0.483 0.031-0.186 0.045-0.38 0.045-0.58v-2.115c0-0.417 0.046-0.781 0.139-1.083 0.092-0.3 0.2-0.554 0.322-0.754 0.127-0.203 0.246-0.353 0.366-0.458 0.087-0.076 0.155-0.131 0.207-0.169-0.052-0.037-0.12-0.093-0.207-0.167-0.12-0.105-0.239-0.255-0.366-0.459-0.122-0.2-0.23-0.453-0.322-0.754-0.093-0.3-0.139-0.665-0.139-1.082v-2.13c0-0.199-0.014-0.392-0.045-0.572-0.029-0.182-0.076-0.345-0.139-0.483-0.060-0.137-0.141-0.246-0.239-0.328-0.095-0.076-0.212-0.115-0.349-0.115h-0.36v-0.916h0.814c0.442 0 0.788 0.18 1.030 0.538 0.238 0.352 0.358 0.826 0.358 1.407v2.236c0 0.3 0.015 0.597 0.044 0.886 0.030 0.287 0.086 0.544 0.164 0.765 0.077 0.216 0.184 0.392 0.318 0.522 0.129 0.124 0.298 0.188 0.503 0.188h0.058v0.916h-0.058c-0.206 0-0.374 0.064-0.503 0.188-0.134 0.129-0.242 0.305-0.318 0.521-0.078 0.223-0.134 0.48-0.164 0.766-0.029 0.288-0.044 0.587-0.044 0.884v2.236c0 0.582-0.12 1.055-0.358 1.409-0.242 0.358-0.588 0.538-1.030 0.538z"></path></svg>
        """
}
