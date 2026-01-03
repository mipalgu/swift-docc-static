//
// HTMLPageBuilder.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import SwiftDocC

/// Builds complete HTML pages from render nodes.
///
/// This type constructs the full HTML document structure including
/// the `<head>` and `<body>` elements, navigation, and content.
public struct HTMLPageBuilder: Sendable {
    /// The configuration for page building.
    public let configuration: Configuration

    /// The navigation index for building the sidebar.
    public let navigationIndex: NavigationIndex?

    /// The content renderer for converting render node content to HTML.
    private let contentRenderer: RenderContentHTMLRenderer
}

// MARK: - Public Methods

public extension HTMLPageBuilder {
    /// Creates a new page builder.
    ///
    /// - Parameters:
    ///   - configuration: The generation configuration.
    ///   - navigationIndex: The navigation index for the sidebar (optional).
    init(configuration: Configuration, navigationIndex: NavigationIndex? = nil) {
        self.configuration = configuration
        self.navigationIndex = navigationIndex
        self.contentRenderer = RenderContentHTMLRenderer()
    }

    /// Builds a complete HTML page from a render node.
    ///
    /// - Parameters:
    ///   - renderNode: The render node to convert.
    ///   - references: The references dictionary for resolving links.
    /// - Returns: The complete HTML document as a string.
    func buildPage(from renderNode: RenderNode, references: [String: any RenderReference]) throws -> String {
        let title = extractTitle(from: renderNode)
        let description = extractDescription(from: renderNode)
        let depth = calculateDepth(for: renderNode)
        let moduleName = extractModuleName(from: renderNode)

        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(title))</title>
        """

        if let description = description {
            html += """

                <meta name="description" content="\(escapeHTML(description))">
            """
        }

        // Calculate relative path to CSS (depth already calculated above)
        let cssPath = String(repeating: "../", count: depth) + "css/main.css"
        let jsPath = String(repeating: "../", count: depth) + "js/search.js"

        html += """

            <link rel="stylesheet" href="\(cssPath)">
        </head>
        <body>
            <input type="checkbox" id="sidebar-toggle" class="sidebar-toggle-checkbox" aria-hidden="true">
        """

        // Add header bar
        html += buildHeader(depth: depth)

        html += """

            <div class="doc-layout">
        """

        // Add sidebar navigation
        html += buildSidebar(for: renderNode, references: references, depth: depth, moduleName: moduleName)

        // Add main content area
        html += """

                <main class="doc-main">
        """

        // Add breadcrumb navigation
        html += buildBreadcrumbs(for: renderNode, references: references, depth: depth)

        // Add main content
        html += buildMainContent(from: renderNode, references: references, depth: depth)

        html += """

                </main>
            </div>
        """

        // Add footer
        html += buildFooter()

        // Add search scripts if enabled
        if configuration.includeSearch {
            let lunrPath = String(repeating: "../", count: depth) + "js/lunr.min.js"
            html += """

            <script src="\(lunrPath)" defer></script>
            <script src="\(jsPath)" defer></script>
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

// MARK: - Private Methods

private extension HTMLPageBuilder {
    /// Builds the header bar.
    func buildHeader(depth: Int) -> String {
        let homeURL = String(repeating: "../", count: depth) + "index.html"
        return """

            <header class="doc-header">
                <div class="header-content">
                    <label for="sidebar-toggle" class="sidebar-toggle-button" aria-label="Toggle sidebar">
                        <span class="toggle-icon">
                            <span class="bar"></span>
                            <span class="bar"></span>
                            <span class="bar"></span>
                        </span>
                    </label>
                    <a href="\(homeURL)" class="header-title">
                        <span class="header-icon">
                            <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor">
                                <rect x="2" y="3" width="6" height="14" rx="1"/>
                                <rect x="10" y="3" width="6" height="14" rx="1"/>
                            </svg>
                        </span>
                        Documentation
                    </a>
                    <span class="header-language">Language: Swift</span>
                </div>
            </header>
        """
    }

    /// Builds the sidebar navigation.
    func buildSidebar(
        for renderNode: RenderNode,
        references: [String: any RenderReference],
        depth: Int,
        moduleName: String
    ) -> String {
        // Use NavigationSidebarBuilder if navigation index is available
        if let navIndex = navigationIndex {
            var sidebarBuilder = NavigationSidebarBuilder(navigationIndex: navIndex)
            return sidebarBuilder.buildSidebar(
                moduleName: moduleName,
                currentPath: renderNode.identifier.path,
                depth: depth
            )
        }

        // Fallback to building sidebar from current page's topic sections
        var html = """

                <nav class="doc-sidebar">
                    <div class="sidebar-content">
                        <h2 class="sidebar-module">\(escapeHTML(moduleName))</h2>
        """

        // Build sidebar from topic sections
        for taskGroup in renderNode.topicSections {
            html += buildSidebarSection(taskGroup, references: references, depth: depth)
        }

        html += """

                    </div>
                    <div class="sidebar-filter" id="sidebar-filter">
                        <input type="text" placeholder="Filter" class="filter-input" aria-label="Filter navigation">
                    </div>
                </nav>
        """

        return html
    }

    /// Builds a sidebar section from a task group.
    func buildSidebarSection(
        _ taskGroup: TaskGroupRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = ""

        if let title = taskGroup.title {
            html += """

                        <div class="sidebar-section">
                            <h3 class="sidebar-heading">\(escapeHTML(title))</h3>
                            <ul class="sidebar-list">
            """

            for identifier in taskGroup.identifiers {
                if let reference = references[identifier] as? TopicRenderReference {
                    let relativeURL = makeRelativeURL(reference.url, depth: depth)
                    let title = reference.title
                    let badge = symbolBadge(for: reference)
                    let badgeClass = symbolBadgeClass(for: reference)

                    html += """

                                <li class="sidebar-item">
                                    <span class="symbol-badge \(badgeClass)">\(badge)</span>
                                    <a href="\(escapeHTML(relativeURL))">\(escapeHTML(title))</a>
                                </li>
                    """
                }
            }

            html += """

                            </ul>
                        </div>
            """
        }

        return html
    }

    /// Returns the badge character for a symbol type.
    func symbolBadge(for reference: TopicRenderReference) -> String {
        reference.symbolKind?.badgeCharacter ?? "·"
    }

    /// Returns the CSS class for a symbol badge.
    func symbolBadgeClass(for reference: TopicRenderReference) -> String {
        reference.symbolKind?.badgeClass ?? "badge-other"
    }

    /// Extracts the module name from the render node.
    func extractModuleName(from renderNode: RenderNode) -> String {
        // Try to extract from identifier path
        let path = renderNode.identifier.path
        let components = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .components(separatedBy: "/")
            .filter { !$0.isEmpty }

        // The module name is typically the second component after "documentation"
        if components.count >= 2, components[0].lowercased() == "documentation" {
            // Return the title if available, otherwise use the path component
            if let title = renderNode.metadata.title, components.count == 2 {
                return title
            }
            return components[1]
        }

        return renderNode.metadata.title ?? "Documentation"
    }

    func extractTitle(from renderNode: RenderNode) -> String {
        // Try to get title from metadata
        if let title = renderNode.metadata.title {
            return title
        }

        // Fall back to extracting from the reference path
        let pathComponents = renderNode.identifier.path.components(separatedBy: "/")
        return pathComponents.last ?? "Documentation"
    }

    func extractDescription(from renderNode: RenderNode) -> String? {
        guard let abstract = renderNode.abstract else { return nil }
        return contentRenderer.renderInlineContent(abstract, references: [:]).plainText
    }

    func calculateDepth(for renderNode: RenderNode) -> Int {
        let path = renderNode.identifier.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        return components.count
    }

    func buildBreadcrumbs(
        for renderNode: RenderNode,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        guard let hierarchy = renderNode.hierarchyVariants.defaultValue else {
            return ""
        }

        // Extract paths from the hierarchy enum
        let paths: [[String]]
        switch hierarchy {
        case .reference(let referenceHierarchy):
            paths = referenceHierarchy.paths
        case .tutorials(let tutorialsHierarchy):
            paths = tutorialsHierarchy.paths
        }

        guard let firstPath = paths.first, !firstPath.isEmpty else {
            return ""
        }

        var html = """

                <nav class="breadcrumbs" aria-label="Breadcrumbs">
        """

        // Build breadcrumb trail from hierarchy
        for (index, identifier) in firstPath.enumerated() {
            if index > 0 {
                html += " <span class=\"separator\">/</span> "
            }

            if let reference = references[identifier] as? TopicRenderReference {
                let title = reference.title
                let relativeURL = makeRelativeURL(reference.url, depth: depth)
                html += "<a href=\"\(escapeHTML(relativeURL))\">\(escapeHTML(title))</a>"
            } else {
                html += "<span>\(escapeHTML(identifier))</span>"
            }
        }

        html += """

                </nav>
        """

        return html
    }

    /// Converts an absolute DocC URL to a relative URL.
    ///
    /// - Parameters:
    ///   - url: The absolute URL from the DocC reference (e.g., "/documentation/module/symbol").
    ///   - depth: The depth of the current page in the directory structure.
    /// - Returns: A relative URL with index.html suffix.
    func makeRelativeURL(_ url: String, depth: Int) -> String {
        // Remove leading slash and create relative path
        let cleanPath = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let prefix = String(repeating: "../", count: depth)
        return "\(prefix)\(cleanPath)/index.html"
    }

    func buildMainContent(
        from renderNode: RenderNode,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = ""

        // Hero section with framework label and title
        let title = extractTitle(from: renderNode)
        let roleLabel = roleLabel(for: renderNode)

        html += """

                    <div class="hero-section">
                        <div class="hero-content">
                            <p class="eyebrow">\(escapeHTML(roleLabel))</p>
                            <h1>\(escapeHTML(title))</h1>
        """

        // Abstract
        if let abstract = renderNode.abstract {
            let abstractHTML = contentRenderer.renderInlineContent(abstract, references: references, depth: depth)
            html += """

                            <p class="abstract">\(abstractHTML.html)</p>
            """
        }

        // Add decorative hero image based on content type
        let decorationSVG = heroDecorationSVG(for: renderNode.kind)
        if let svg = decorationSVG {
            html += """

                        </div>
                        <div class="hero-decoration">
                            \(svg)
                        </div>
                    </div>
            """
        } else {
            html += """

                        </div>
                    </div>
            """
        }

        // Declaration (for symbols)
        if renderNode.kind == .symbol {
            html += buildDeclaration(from: renderNode, references: references)
        }

        // Primary content sections
        for section in renderNode.primaryContentSections {
            html += buildSection(section, references: references, depth: depth)
        }

        // Topic sections (children)
        if !renderNode.topicSections.isEmpty {
            html += """

                    <section class="topics">
                        <h2>Topics</h2>
            """

            for taskGroup in renderNode.topicSections {
                html += buildTaskGroup(taskGroup, references: references, depth: depth)
            }

            html += """

                    </section>
            """
        }

        // Relationships (for symbols)
        if !renderNode.relationshipSections.isEmpty {
            html += """

                    <section class="relationships">
                        <h2>Relationships</h2>
            """

            for relationship in renderNode.relationshipSections {
                html += buildRelationshipSection(relationship, references: references, depth: depth)
            }

            html += """

                    </section>
            """
        }

        // See Also
        if !renderNode.seeAlsoSections.isEmpty {
            html += """

                    <section class="see-also">
                        <h2>See Also</h2>
            """

            for seeAlso in renderNode.seeAlsoSections {
                html += buildTaskGroup(seeAlso, references: references, depth: depth)
            }

            html += """

                    </section>
            """
        }

        return html
    }

    /// Returns the role label for a render node (e.g., "Framework", "Structure", "Class").
    func roleLabel(for renderNode: RenderNode) -> String {
        // Check metadata role first
        if let role = renderNode.metadata.role {
            switch role {
            case "collection":
                return "Framework"
            case "article":
                return "Article"
            case "tutorial":
                return "Tutorial"
            default:
                break
            }
        }

        // Fall back to symbol kind
        if let symbolKind = renderNode.metadata.symbolKind {
            switch symbolKind {
            case "class":
                return "Class"
            case "struct":
                return "Structure"
            case "enum":
                return "Enumeration"
            case "protocol":
                return "Protocol"
            case "typealias":
                return "Type Alias"
            case "func":
                return "Function"
            case "var", "property":
                return "Property"
            case "init":
                return "Initializer"
            case "macro":
                return "Macro"
            default:
                return symbolKind.capitalized
            }
        }

        // Default for modules/frameworks
        if renderNode.kind == .symbol {
            return "Symbol"
        }

        return "Framework"
    }

    /// Returns the appropriate hero decoration SVG for a render node kind.
    func heroDecorationSVG(for kind: RenderNode.Kind) -> String? {
        switch kind {
        case .article, .tutorial:
            // Document with code brackets - matches DocC's article decoration
            return """
            <svg width="180" height="180" viewBox="0 0 180 180" fill="none">
                <rect x="30" y="15" width="120" height="150" rx="6" stroke="currentColor" stroke-width="4"/>
                <path d="M30 40h90" stroke="currentColor" stroke-width="4"/>
                <path d="M65 85L50 100L65 115" stroke="currentColor" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
                <path d="M115 85L130 100L115 115" stroke="currentColor" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
            """
        case .overview:
            // Overlapping angle brackets - matches DocC's framework decoration
            return """
            <svg width="180" height="180" viewBox="0 0 180 180" fill="none">
                <path d="M55 40L20 90L55 140" stroke="currentColor" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
                <path d="M75 50L45 90L75 130" stroke="currentColor" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" opacity="0.6"/>
                <path d="M125 40L160 90L125 140" stroke="currentColor" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
                <path d="M105 50L135 90L105 130" stroke="currentColor" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" opacity="0.6"/>
            </svg>
            """
        default:
            // No decoration for symbols
            return nil
        }
    }

    func buildDeclaration(from renderNode: RenderNode, references: [String: any RenderReference]) -> String {
        // Look for declaration section in primary content
        for section in renderNode.primaryContentSections {
            if let declarationSection = section as? DeclarationsRenderSection {
                return buildDeclarationsSection(declarationSection)
            }
        }
        return ""
    }

    func buildDeclarationsSection(_ section: DeclarationsRenderSection) -> String {
        var html = """

                <div class="declaration">
        """

        for declaration in section.declarations {
            html += "\n                <pre><code>"

            for token in declaration.tokens {
                let tokenClass = tokenCSSClass(for: token.kind)
                if let tokenClass = tokenClass {
                    html += "<span class=\"\(tokenClass)\">\(escapeHTML(token.text))</span>"
                } else {
                    html += escapeHTML(token.text)
                }
            }

            html += "</code></pre>"
        }

        html += """

                </div>
        """

        return html
    }

    func tokenCSSClass(for kind: DeclarationRenderSection.Token.Kind) -> String? {
        switch kind {
        case .keyword:
            return "keyword"
        case .typeIdentifier:
            return "type"
        case .genericParameter:
            return "type"
        case .text:
            return nil
        case .internalParam:
            return "param"
        case .externalParam:
            return "param"
        case .identifier:
            return "identifier"
        case .label:
            return "label"
        case .number:
            return "number"
        case .string:
            return "string"
        case .attribute:
            return "attribute"
        @unknown default:
            return nil
        }
    }

    func buildSection(
        _ section: any RenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        switch section.kind {
        case .content:
            if let contentSection = section as? ContentRenderSection {
                return buildContentSection(contentSection, references: references, depth: depth)
            }
        case .discussion:
            if let contentSection = section as? ContentRenderSection {
                var html = """

                <section class="discussion">
                    <h2>Discussion</h2>
                """
                html += buildContentSection(contentSection, references: references, depth: depth)
                html += """

                </section>
                """
                return html
            }
        case .parameters:
            if let parametersSection = section as? ParametersRenderSection {
                return buildParametersSection(parametersSection, references: references, depth: depth)
            }
        default:
            break
        }
        return ""
    }

    func buildContentSection(
        _ section: ContentRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = ""
        for block in section.content {
            html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
        }
        return html
    }

    func buildParametersSection(
        _ section: ParametersRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        guard !section.parameters.isEmpty else { return "" }

        var html = """

                <section class="parameters">
                    <h2>Parameters</h2>
                    <dl>
        """

        for param in section.parameters {
            html += "\n                    <dt><code>\(escapeHTML(param.name))</code></dt>"
            html += "\n                    <dd>"

            for block in param.content {
                html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
            }

            html += "</dd>"
        }

        html += """

                    </dl>
                </section>
        """

        return html
    }

    func buildTaskGroup(
        _ taskGroup: TaskGroupRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = ""

        if let title = taskGroup.title {
            html += """

                        <h3>\(escapeHTML(title))</h3>
            """
        }

        html += """

                        <div class="symbol-list">
        """

        for identifier in taskGroup.identifiers {
            if let reference = references[identifier] as? TopicRenderReference {
                html += buildSymbolCard(for: reference, depth: depth)
            }
        }

        html += """

                        </div>
        """

        return html
    }

    func buildSymbolCard(for reference: TopicRenderReference, depth: Int) -> String {
        let relativeURL = makeRelativeURL(reference.url, depth: depth)
        let title = reference.title
        let abstract = contentRenderer.renderInlineContent(reference.abstract, references: [:], depth: 0).plainText
        let badge = symbolBadge(for: reference)
        let badgeClass = symbolBadgeClass(for: reference)

        return """

                            <div class="symbol-card">
                                <span class="symbol-badge \(badgeClass)">\(badge)</span>
                                <div class="symbol-info">
                                    <a href="\(escapeHTML(relativeURL))" class="symbol-name">\(escapeHTML(title))</a>
                                    <p class="symbol-summary">\(escapeHTML(abstract))</p>
                                </div>
                            </div>
        """
    }

    func buildRelationshipSection(
        _ section: RelationshipsRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                        <h3>\(escapeHTML(section.title))</h3>
                        <ul class="relationships-list">
        """

        for identifier in section.identifiers {
            if let reference = references[identifier] as? TopicRenderReference {
                let relativeURL = makeRelativeURL(reference.url, depth: depth)
                let title = reference.title
                html += "\n                        <li><a href=\"\(escapeHTML(relativeURL))\">\(escapeHTML(title))</a></li>"
            }
        }

        html += """

                        </ul>
        """

        return html
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

    /// JavaScript for the appearance selector and sidebar filter.
    var appearanceSelectorScript: String {
        """

            <script>
            (function() {
                // --- Appearance Selector ---
                const selector = document.getElementById('appearance-selector');
                if (selector) {
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
                }

                // --- Sidebar Filter ---
                const sidebarFilter = document.getElementById('sidebar-filter');
                if (sidebarFilter) {
                    // Show the filter (hidden by default for no-JS fallback)
                    sidebarFilter.style.display = 'flex';

                    const filterInput = sidebarFilter.querySelector('.filter-input');
                    const sidebarItems = document.querySelectorAll('.sidebar-item, .nav-link');

                    // Filter functionality
                    if (filterInput) {
                        filterInput.addEventListener('input', () => {
                            const query = filterInput.value.toLowerCase();
                            sidebarItems.forEach(item => {
                                const text = item.textContent.toLowerCase();
                                item.style.display = text.includes(query) ? '' : 'none';
                            });
                        });

                        // Keyboard shortcut: / or Cmd+F (Mac) / Ctrl+F (Windows)
                        document.addEventListener('keydown', (e) => {
                            // Forward slash when not in an input
                            if (e.key === '/' && !isInputFocused()) {
                                e.preventDefault();
                                filterInput.focus();
                            }
                            // Cmd+F or Ctrl+F
                            if ((e.metaKey || e.ctrlKey) && e.key === 'f') {
                                // Only if sidebar is visible
                                if (sidebarFilter.offsetParent !== null) {
                                    e.preventDefault();
                                    filterInput.focus();
                                }
                            }
                            // Escape to clear and blur
                            if (e.key === 'Escape' && document.activeElement === filterInput) {
                                filterInput.value = '';
                                filterInput.dispatchEvent(new Event('input'));
                                filterInput.blur();
                            }
                        });
                    }
                }

                function isInputFocused() {
                    const active = document.activeElement;
                    return active && (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA' || active.isContentEditable);
                }
            })();
            </script>
        """
    }
}

// MARK: - HTML Utilities

/// Escapes special HTML characters in a string.
func escapeHTML(_ string: String) -> String {
    string
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}
