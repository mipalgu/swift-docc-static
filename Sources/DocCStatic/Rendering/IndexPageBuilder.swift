//
// IndexPageBuilder.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import SwiftDocC

/// Builds a combined index page listing all documented modules.
///
/// This type creates a landing page that provides navigation to all
/// modules and packages documented in the output.
public struct IndexPageBuilder: Sendable {
    /// The configuration for page building.
    public let configuration: Configuration
    /// Creates a new index page builder.
    ///
    /// - Parameter configuration: The generation configuration.
    public init(configuration: Configuration) {
        self.configuration = configuration
    }
}

// MARK: - Public

public extension IndexPageBuilder {
    /// A documented module entry.
    struct ModuleEntry: Sendable {
        /// The module name.
        public let name: String

        /// The module's abstract/summary.
        public let abstract: String

        /// The relative URL path to the module's documentation.
        public let path: String

        /// The number of documented symbols.
        public let symbolCount: Int

        /// Creates a new module entry.
        public init(name: String, abstract: String, path: String, symbolCount: Int) {
            self.name = name
            self.abstract = abstract
            self.path = path
            self.symbolCount = symbolCount
        }
    }

    /// Builds the combined index page HTML.
    ///
    /// - Parameter modules: The documented modules to include.
    /// - Returns: The complete HTML document as a string.
    func buildIndexPage(modules: [ModuleEntry]) -> String {
        let packageName = configuration.packageDirectory.lastPathComponent
        let title = "\(packageName) Documentation"

        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(title))</title>
            <link rel="stylesheet" href="css/main.css">
        </head>
        <body>
            <div class="container">
                <header class="index-header">
                    <h1>\(escapeHTML(title))</h1>
                    <p class="subtitle">API Reference Documentation</p>
                </header>

        """

        // Add search form if enabled
        if configuration.includeSearch {
            html += """

                <form id="search-form" class="search-form">
                    <input type="search" id="search-input" placeholder="Search documentation..." aria-label="Search">
                    <div id="search-results" class="search-results"></div>
                </form>

            """
        }

        // Module list
        html += """

                <section class="modules">
                    <h2>Modules</h2>
                    <div class="module-list">
        """

        for module in modules.sorted(by: { $0.name < $1.name }) {
            html += buildModuleCard(module)
        }

        html += """

                    </div>
                </section>

        """

        html += """

            </div>
        """

        // Footer with configurable content and appearance selector
        html += buildFooter()

        // Add search scripts if enabled
        if configuration.includeSearch {
            html += """

            <script src="js/lunr.min.js" defer></script>
            <script src="js/search.js" defer></script>
            """
        }

        // Add appearance selector script
        html += appearanceSelectorScript

        html += """

        </body>
        </html>
        """

        return html
    }
}

// MARK: - Private
private extension IndexPageBuilder {
    func buildModuleCard(_ module: ModuleEntry) -> String {
        """

                        <div class="module-card">
                            <a href="\(escapeHTML(module.path))" class="module-name">\(escapeHTML(module.name))</a>
                            <p class="module-abstract">\(escapeHTML(module.abstract))</p>
                            <p class="module-stats">\(module.symbolCount) symbols</p>
                        </div>
        """
    }

    /// Builds the page footer with configurable content and appearance selector.
    func buildFooter() -> String {
        let footerContent = configuration.footerHTML ?? Configuration.defaultFooter
        return """

            <footer class="doc-footer">
                <div class="footer-content">\(footerContent)</div>
                <div class="appearance-selector" id="appearance-selector">
                    <button type="button" class="appearance-btn" data-theme="light" aria-label="Light mode">Light</button>
                    <button type="button" class="appearance-btn" data-theme="dark" aria-label="Dark mode">Dark</button>
                    <button type="button" class="appearance-btn active" data-theme="auto" aria-label="Auto mode">Auto</button>
                </div>
            </footer>
        """
    }

    /// JavaScript for the appearance selector.
    var appearanceSelectorScript: String {
        """

            <script>
            (function() {
                const selector = document.getElementById('appearance-selector');
                if (!selector) return;

                // Show the selector (hidden by default for no-JS fallback)
                selector.style.visibility = 'visible';

                const buttons = selector.querySelectorAll('.appearance-btn');
                const html = document.documentElement;

                // Load saved preference
                const saved = localStorage.getItem('docc-theme') || 'auto';
                applyTheme(saved);
                updateButtons(saved);

                // Add click handlers
                buttons.forEach(btn => {
                    btn.addEventListener('click', () => {
                        const theme = btn.dataset.theme;
                        localStorage.setItem('docc-theme', theme);
                        applyTheme(theme);
                        updateButtons(theme);
                    });
                });

                function applyTheme(theme) {
                    if (theme === 'auto') {
                        html.removeAttribute('data-theme');
                    } else {
                        html.setAttribute('data-theme', theme);
                    }
                }

                function updateButtons(theme) {
                    buttons.forEach(btn => {
                        btn.classList.toggle('active', btn.dataset.theme === theme);
                    });
                }
            })();
            </script>
        """
    }
}
