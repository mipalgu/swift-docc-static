//
// ColourSchemeToggle.swift
// DocCStatic
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// The colour scheme toggle and page footer shared by all generated pages.
///
/// The toggle mirrors swift-docc-render's `ColorSchemeToggle`: a group of radio
/// buttons labelled Light, Dark and Auto in the page footer.  Choosing a scheme works
/// without JavaScript, because the stylesheet (see ``stylesheet(includeDarkMode:)``)
/// sets the `color-scheme` of the body from the checked radio button, and the colour
/// palette of the base stylesheet consists of `light-dark()` pairs that follow it.
/// When JavaScript is available, ``script`` additionally remembers the choice across
/// pages and forwards it to the embedded navigation sidebar.
///
/// This type is the single authoritative home of the names the footer markup, the
/// stylesheet and the script must agree on.
public enum ColourSchemeToggle {
    /// A colour scheme the reader can choose.
    public enum Scheme: String, CaseIterable, Sendable {
        /// Always use the light appearance.
        case light

        /// Always use the dark appearance.
        case dark

        /// Follow the appearance of the reader's system.
        case auto

        /// The label shown on the toggle for this scheme.
        public var label: String {
            switch self {
            case .light: "Light"
            case .dark: "Dark"
            case .auto: "Auto"
            }
        }
    }
}

// MARK: - Names

public extension ColourSchemeToggle {
    /// The class of the `<fieldset>` that holds the radio buttons.
    static let className = "color-scheme-toggle"

    /// The `name` shared by the radio buttons of the toggle.
    static let inputName = "color-scheme"

    /// The attribute of the `<body>` element that records the chosen scheme.
    ///
    /// Scripts set this attribute on pages and on the embedded sidebar document;
    /// its value is the raw value of a ``Scheme``.
    static let schemeAttribute = "data-color-scheme"

    /// The class of the page footer.
    static let footerClass = "footer"

    /// The class of the element holding the custom footer content.
    static let footerContentClass = "footer-content"

    /// The accessible name of the toggle, as used by swift-docc-render.
    static let legend = "Select a color scheme preference"

    /// The scheme a page uses before the reader chooses one.
    static let defaultScheme = Scheme.auto
}

// MARK: - Markup

public extension ColourSchemeToggle {
    /// The opening `<body>` tag attributes that record the default colour scheme.
    static var bodyAttribute: String {
        "\(schemeAttribute)=\"\(defaultScheme.rawValue)\""
    }

    /// Builds the radio group of the toggle.
    ///
    /// The default scheme's radio button is checked.
    ///
    /// - Returns: The `<fieldset>` element.
    static func toggleMarkup() -> String {
        var html = "<fieldset class=\"\(className)\" role=\"radiogroup\">"
        html += "<legend class=\"visuallyhidden\">\(escapeHTML(legend))</legend>"
        for scheme in Scheme.allCases {
            let checked = scheme == defaultScheme ? " checked" : ""
            html += "<label><input type=\"radio\" name=\"\(inputName)\" value=\"\(scheme.rawValue)\"\(checked)>"
            html += "<span class=\"text\">\(scheme.label)</span></label>"
        }
        html += "</fieldset>"
        return html
    }

    /// Builds the page footer with the colour scheme toggle and custom content.
    ///
    /// The footer spans the full width of the page below the content, like
    /// swift-docc-render's footer.  The custom content shares the row of the toggle,
    /// on the opposite side.
    ///
    /// - Parameter content: The custom footer HTML, inserted verbatim.
    /// - Returns: The `<footer>` element.
    static func footerMarkup(content: String) -> String {
        """

            <footer class="\(footerClass)">
                <div class="row">\(toggleMarkup())<div class="\(footerContentClass)">\(content)</div></div>
            </footer>
        """
    }

    /// The script that remembers the reader's choice and applies it to the page.
    ///
    /// The script restores the scheme stored under
    /// ``SidebarDocument/colourSchemeStorageKey``, checks the matching radio button,
    /// records the scheme in ``schemeAttribute`` and posts it to the embedded sidebar
    /// with ``SidebarDocument/colourSchemeMessage``.  Choosing a scheme stores it.
    static var script: String {
        """
        (function () {
            var storageKey = '\(SidebarDocument.colourSchemeStorageKey)';
            var schemeMessage = '\(SidebarDocument.colourSchemeMessage)';
            var readyMessage = '\(SidebarDocument.readyMessage)';
            var attribute = '\(schemeAttribute)';
            var schemes = [\(Scheme.allCases.map { "'\($0.rawValue)'" }.joined(separator: ", "))];
            var body = document.body;
            var frame = document.querySelector('iframe.\(SidebarDocument.frameClass)');
            var inputs = document.querySelectorAll('.\(className) input[name="\(inputName)"]');

            function postToSidebar(message) {
                if (frame && frame.contentWindow) {
                    frame.contentWindow.postMessage(message, '*');
                }
            }

            function apply(scheme) {
                if (schemes.indexOf(scheme) === -1) {
                    scheme = '\(defaultScheme.rawValue)';
                }
                body.setAttribute(attribute, scheme);
                for (var i = 0; i < inputs.length; i++) {
                    inputs[i].checked = inputs[i].value === scheme;
                }
                postToSidebar({ type: schemeMessage, scheme: scheme });
            }

            var saved = '\(defaultScheme.rawValue)';
            try {
                saved = window.localStorage.getItem(storageKey) || saved;
            } catch (error) {
                // Storage may be unavailable, for example for local files.
            }
            apply(saved);

            for (var i = 0; i < inputs.length; i++) {
                inputs[i].addEventListener('change', function (event) {
                    try {
                        window.localStorage.setItem(storageKey, event.target.value);
                    } catch (error) {
                        // The choice then only applies to this page.
                    }
                    apply(event.target.value);
                });
            }

            if (frame) {
                window.addEventListener('message', function (event) {
                    var data = event.data;
                    if (event.source === frame.contentWindow && data && data.type === readyMessage) {
                        postToSidebar({ type: schemeMessage, scheme: body.getAttribute(attribute) });
                    }
                });
            }
        })();
        """
    }
}

// MARK: - Stylesheet

public extension ColourSchemeToggle {
    /// The stylesheet rules that apply the chosen colour scheme.
    ///
    /// A scheme counts as chosen when the body's ``schemeAttribute`` names it (set by
    /// scripts) or when its radio button in the toggle is checked (without scripts).
    /// Choosing Light or Dark sets the `color-scheme` of the body, which selects the
    /// light or dark half of every `light-dark()` colour of the palette on screen; printed
    /// pages always use the light appearance.  Without dark
    /// mode, the toggle is hidden instead.
    ///
    /// - Parameter includeDarkMode: Whether the stylesheet contains dark mode styles.
    /// - Returns: The CSS rules.
    static func stylesheet(includeDarkMode: Bool) -> String {
        guard includeDarkMode else {
            return """
            /* Without a dark appearance there is no colour scheme to choose */
            .\(className) {
                display: none;
            }

            """
        }
        let rules = [Scheme.light, Scheme.dark].map { scheme in
            """
                body[\(schemeAttribute)="\(scheme.rawValue)"],
                body:has(.\(className) input[value="\(scheme.rawValue)"]:checked) {
                    color-scheme: \(scheme.rawValue);
                }
            """
        }
        return "@media screen {\n" + rules.joined(separator: "\n\n") + "\n}\n"
    }
}
