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

        // Footer with generation info
        html += """

                <footer class="index-footer">
                    <p>Generated with <a href="https://github.com/swiftlang/swift-docc">Swift-DocC</a>
                    and <a href="https://github.com/rhx/swift-docc-static">swift-docc-static</a></p>
                </footer>
            </div>
        """

        // Add search scripts if enabled
        if configuration.includeSearch {
            html += """

            <script src="js/lunr.min.js" defer></script>
            <script src="js/search.js" defer></script>
            """
        }

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
}
