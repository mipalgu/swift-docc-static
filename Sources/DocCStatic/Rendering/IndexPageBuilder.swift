//
// IndexPageBuilder.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import Markdown
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

    /// The standard filename for the index page introduction content.
    ///
    /// Place an `INDEX.md` file in the root of your package to customise
    /// the content displayed at the top of the documentation index page.
    /// This filename is chosen to avoid conflicts with:
    /// - Swift Package Manager (`Package.swift`, `README.md`)
    /// - DocC (`.docc` directories)
    /// - Standard Git files (`README.md`, `CONTRIBUTING.md`)
    public static let indexMarkdownFilename = "INDEX.md"

    /// The content extracted from an INDEX.md file.
    public struct IndexContent: Sendable {
        /// The page title (from the H1 heading, if present).
        public let title: String?
        /// The HTML content to display after the title.
        public let bodyHTML: String
    }

    /// Loads and parses the `INDEX.md` file if it exists.
    ///
    /// If the file starts with an H1 heading, it is extracted as the page title
    /// and removed from the body content.
    ///
    /// - Parameter packageDirectory: The root directory of the package.
    /// - Returns: The parsed index content, or `nil` if no `INDEX.md` exists.
    public func loadIndexContent(from packageDirectory: URL) -> IndexContent? {
        let indexPath = packageDirectory.appendingPathComponent(Self.indexMarkdownFilename)
        guard let markdownContent = try? String(contentsOf: indexPath, encoding: .utf8) else {
            return nil
        }
        return parseIndexMarkdown(markdownContent)
    }

    /// Parses INDEX.md content, extracting the title from the first H1 if present.
    ///
    /// - Parameter markdown: The Markdown source text.
    /// - Returns: The parsed index content with optional title and body HTML.
    private func parseIndexMarkdown(_ markdown: String) -> IndexContent {
        let document = Document(parsing: markdown)

        // Check if the first block element is an H1
        var title: String?
        var remainingChildren: [Markup] = []
        var foundFirstElement = false

        for child in document.children {
            if !foundFirstElement, let heading = child as? Heading, heading.level == 1 {
                // Extract the title text from the H1
                title = heading.plainText
                foundFirstElement = true
            } else {
                remainingChildren.append(child)
                foundFirstElement = true
            }
        }

        // Render the remaining content (without the H1)
        var bodyHTML = ""
        for child in remainingChildren {
            var htmlFormatter = HTMLFormatter()
            htmlFormatter.visit(child)
            bodyHTML += htmlFormatter.result
        }

        return IndexContent(title: title, bodyHTML: bodyHTML)
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

    /// A tutorial collection entry.
    struct TutorialEntry: Sendable {
        /// The tutorial collection title.
        public let title: String
        /// The relative URL path to the tutorial overview.
        public let path: String
        /// The number of tutorials in the collection.
        public let tutorialCount: Int

        /// Creates a new tutorial entry.
        public init(title: String, path: String, tutorialCount: Int) {
            self.title = title
            self.path = path
            self.tutorialCount = tutorialCount
        }
    }

    /// Builds the combined index page HTML.
    ///
    /// - Parameters:
    ///   - modules: The documented modules to include.
    ///   - tutorials: The tutorial collections to include.
    ///   - indexContent: Optional content from an `INDEX.md` file. If provided,
    ///                   the title (if any) and body content are used. If `nil`,
    ///                   a default title and subtitle are shown instead.
    /// - Returns: The complete HTML document as a string.
    func buildIndexPage(
        modules: [ModuleEntry],
        tutorials: [TutorialEntry] = [],
        indexContent: IndexContent? = nil
    ) -> String {
        let packageName = configuration.packageDirectory.lastPathComponent
        let defaultTitle = "\(packageName) Documentation"
        let title = indexContent?.title ?? defaultTitle

        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(title))</title>
            <link rel="stylesheet" href="css/main.css">
        </head>
        <body class="index-page">
            <div class="container">
                <header class="index-header">
                    <h1>\(escapeHTML(title))</h1>
        """

        // Add either the custom intro content or the default subtitle
        if let indexContent {
            html += """

                </header>
                <section class="index-intro">
                    \(indexContent.bodyHTML)
                </section>

            """
        } else {
            html += """

                    <p class="subtitle">API Reference Documentation</p>
                </header>

            """
        }

        // Module list - only add heading if no custom index content
        // (INDEX.md should provide its own "## Modules" heading)
        if indexContent != nil {
            html += """

                    <section class="modules">
                        <div class="module-list">
            """
        } else {
            html += """

                    <section class="modules">
                        <h2>Modules</h2>
                        <div class="module-list">
            """
        }

        // Modules are already in Package.swift order from filterNavigationIndex
        for module in modules {
            html += buildModuleCard(module)
        }

        html += """

                    </div>
                </section>

        """

        // Tutorials section if available
        if !tutorials.isEmpty {
            html += """

                <section class="tutorials-section">
                    <h2>Tutorials</h2>
                    <div class="tutorial-list">
            """

            for tutorial in tutorials {
                html += buildTutorialCard(tutorial)
            }

            html += """

                    </div>
                </section>

            """
        }

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

    func buildTutorialCard(_ tutorial: TutorialEntry) -> String {
        let tutorialText = tutorial.tutorialCount == 1 ? "tutorial" : "tutorials"
        return """

                        <div class="tutorial-collection-card">
                            <a href="\(escapeHTML(tutorial.path))" class="tutorial-collection-name">\(escapeHTML(tutorial.title))</a>
                            <p class="tutorial-collection-stats">\(tutorial.tutorialCount) \(tutorialText)</p>
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
