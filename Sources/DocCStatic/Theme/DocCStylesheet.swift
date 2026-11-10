//
// DocCStylesheet.swift
// DocCStatic
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import DocCStaticThemes
import Foundation

/// A layer of the generated stylesheet.
///
/// The generated `css/main.css` is the concatenation of these layers, in the
/// order of ``allCases``, so that each layer can override the ones before it:
///
/// 1. ``base``: the base stylesheet shared by all themes (structure and layout,
///    with every visual value routed through a custom property);
/// 2. ``sidebarDocument``: the rules for the embedded navigation sidebar;
/// 3. ``accent``: the accent colour, when the theme settings do not set `link`;
/// 4. ``themeSettings``: the custom properties defined by the theme settings;
/// 5. ``theme``: the theme's own stylesheets;
/// 6. ``custom``: custom CSS supplied by the user.
///
/// Every layer starts with a marker comment (see ``marker(part:)``) naming the
/// layer and, for layers made of several files, the part.
public enum StylesheetLayer: String, CaseIterable, Sendable {
    /// The base stylesheet shared by all themes.
    case base

    /// The rules for the embedded navigation sidebar.
    case sidebarDocument = "sidebar-document"

    /// The accent colour set through the configuration rather than theme settings.
    case accent

    /// The custom properties defined by the theme settings.
    case themeSettings = "theme-settings"

    /// The theme's own stylesheets.
    case theme

    /// Custom CSS supplied by the user.
    case custom

    /// The text that starts every layer marker comment.
    public static let markerPrefix = "/* docc-static layer: "

    /// Returns the marker comment that starts this layer, or one part of it.
    ///
    /// - Parameter part: The name of the part (a stylesheet file name without
    ///   extension), or `nil` for layers that consist of a single part.
    /// - Returns: The marker comment, for example `/* docc-static layer: base/00-variables */`.
    public func marker(part: String? = nil) -> String {
        Self.markerPrefix + rawValue + (part.map { "/" + $0 } ?? "") + " */"
    }
}

/// Generates the CSS stylesheet for documentation.
///
/// The stylesheet is assembled from the layers described by ``StylesheetLayer``:
/// the compiled-in base stylesheet, the sidebar rules, the theme's settings and
/// stylesheets, and any custom CSS.
enum DocCStylesheet {
    /// Generates the complete CSS stylesheet.
    ///
    /// - Parameter theme: The theme configuration to use.
    /// - Returns: The CSS content as a string.
    static func generate(theme: ThemeConfiguration) -> String {
        var css = ""
        for part in BaseStylesheet.parts where theme.includeDarkMode || !part.isDarkModeOnly {
            css += layer(.base, part: part.name, css: part.css)
        }
        css += layer(.sidebarDocument, css: SidebarDocument.stylesheet)
        if theme.themeSettings?.theme.color?["link"] == nil {
            css += layer(.accent, css: ":root {\n    --color-link: \(theme.accentColour);\n}\n")
        }
        if let settings = theme.themeSettings {
            css += layer(
                .themeSettings,
                css: ThemeSettingsParser.generateCSS(from: settings, includeDarkMode: theme.includeDarkMode)
            )
        }
        for part in theme.stylesheets where theme.includeDarkMode || !part.isDarkModeOnly {
            css += layer(.theme, part: part.name, css: part.css)
        }
        if let customCSS = theme.customCSS, !customCSS.isEmpty {
            css += layer(.custom, css: customCSS)
        }
        return css
    }

    /// Formats one layer with its marker comment.
    ///
    /// - Parameters:
    ///   - layer: The layer.
    ///   - part: The name of the part within the layer, if the layer has several.
    ///   - css: The CSS text of the layer.
    /// - Returns: The marker, the CSS text and a separating blank line.
    private static func layer(_ layer: StylesheetLayer, part: String? = nil, css: String) -> String {
        let body = css.hasSuffix("\n") ? css : css + "\n"
        return layer.marker(part: part) + "\n" + body + "\n"
    }
}
