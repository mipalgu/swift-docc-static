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

    /// The shared sidebar document embedded by documentation pages.
    ///
    /// This is `nil` when the navigation index is missing or lists no modules, in
    /// which case pages render a small inline fallback sidebar instead.
    public let sidebarDocument: SidebarDocument?

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
        self.sidebarDocument = SidebarDocument.isAvailable(for: navigationIndex)
            ? navigationIndex.map { SidebarDocument(navigationIndex: $0) }
            : nil
        self.contentRenderer = RenderContentHTMLRenderer()
    }

    /// Builds a complete HTML page from a render node.
    ///
    /// - Parameters:
    ///   - renderNode: The render node to convert.
    ///   - references: The references dictionary for resolving links.
    /// - Returns: The complete HTML document as a string.
    func buildPage(from renderNode: RenderNode, references: [String: any RenderReference]) throws -> String {
        // Use specialized layout for tutorials
        if renderNode.kind == .tutorial {
            return buildTutorialPage(from: renderNode, references: references)
        }

        if renderNode.kind == .overview {
            return buildTutorialOverviewPage(from: renderNode, references: references)
        }

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
        <body data-color-scheme="auto">
            <input type="checkbox" id="sidebar-toggle" class="sidebar-toggle-checkbox" aria-hidden="true">
        """

        // Add header bar
        html += buildHeader(depth: depth)

        html += """

            <div class="documentation-layout">
        """

        // Add sidebar navigation
        html += buildSidebar(for: renderNode, references: references, depth: depth, moduleName: moduleName)

        // Add main content area
        html += """

                <main class="doc-topic" id="app-top">
        """

        // Add main content (breadcrumbs are rendered inside the hero section)
        html += buildMainContent(from: renderNode, references: references, depth: depth)

        html += """

                </main>
            </div>
        """

        // Add footer
        html += buildFooter()

        // The shared sidebar document loads the search and filter scripts itself;
        // pages with an inline fallback sidebar load them directly.
        if sidebarDocument == nil {
            if configuration.includeSearch {
                let lunrPath = String(repeating: "../", count: depth) + "js/lunr.min.js"
                html += """

                <script src="\(lunrPath)" defer></script>
                <script src="\(jsPath)" defer></script>
                """
            }
            html += "\n    <script>\(NavigationSidebarBuilder.sidebarScript)</script>"
        }

        // Add appearance selector script
        html += appearanceSelectorScript

        html += """

        </body>
        </html>
        """

        return html
    }

    /// Builds a complete HTML page for tutorials with specialized navigation and layout.
    ///
    /// Builds a tutorial overview page showing all available tutorials grouped by chapter.
    func buildTutorialOverviewPage(from renderNode: RenderNode, references: [String: any RenderReference]) -> String {
        let title = extractTitle(from: renderNode)
        let description = extractDescription(from: renderNode)
        let depth = calculateDepth(for: renderNode)

        let cssPath = String(repeating: "../", count: depth) + "css/main.css"

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

        html += """

            <link rel="stylesheet" href="\(cssPath)">
        </head>
        <body class="tutorial-overview-page" data-color-scheme="auto">
            <main class="tutorial-overview-main">
        """

        // Build hero section
        for section in renderNode.sections {
            if let introSection = section as? IntroRenderSection {
                html += buildOverviewHero(introSection, references: references, depth: depth)
            } else if let volumeSection = section as? VolumeRenderSection {
                html += buildOverviewVolume(volumeSection, references: references, depth: depth)
            }
        }

        html += """

            </main>
        """

        // Add footer
        html += buildFooter()

        // Add search scripts if enabled
        if configuration.includeSearch {
            let lunrPath = String(repeating: "../", count: depth) + "js/lunr.min.js"
            let jsPath = String(repeating: "../", count: depth) + "js/search.js"
            html += """

            <script src="\(lunrPath)" defer></script>
            <script src="\(jsPath)" defer></script>
            """
        }

        html += appearanceSelectorScript

        html += """

        </body>
        </html>
        """

        return html
    }

    /// Builds the hero section for tutorial overview.
    private func buildOverviewHero(
        _ hero: IntroRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                <section class="overview-hero">
                    <div class="overview-hero-content">
                        <h1 class="overview-title">\(escapeHTML(hero.title))</h1>
        """

        for block in hero.content {
            html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
        }

        html += """

                    </div>
                </section>
        """

        return html
    }

    /// Builds the volume section with chapters and tutorials.
    private func buildOverviewVolume(
        _ volume: VolumeRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                <section class="overview-volume">
        """

        for chapter in volume.chapters {
            let chapterTitle = chapter.name ?? "Untitled Chapter"
            html += """

                    <div class="overview-chapter">
                        <h2 class="chapter-title">\(escapeHTML(chapterTitle))</h2>
            """

            if !chapter.content.isEmpty {
                html += "<div class=\"chapter-description\">"
                for block in chapter.content {
                    html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
                }
                html += "</div>"
            }

            html += """

                        <div class="chapter-tutorials">
            """

            for tutorialRefId in chapter.tutorials {
                if let topicRef = references[tutorialRefId.identifier] as? TopicRenderReference {
                    let tutorialURL = makeRelativeURL(topicRef.url, depth: depth)
                    html += """

                            <a href="\(tutorialURL)" class="tutorial-card">
                                <span class="tutorial-card-title">\(escapeHTML(topicRef.title))</span>
                    """

                    if !topicRef.abstract.isEmpty {
                        let abstractText = topicRef.abstract.map { renderInlineContentAsText($0) }.joined()
                        html += """

                                <span class="tutorial-card-abstract">\(escapeHTML(abstractText))</span>
                        """
                    }

                    html += """

                            </a>
                    """
                }
            }

            html += """

                        </div>
                    </div>
            """
        }

        html += """

                </section>
        """

        return html
    }

    /// Renders inline content to plain text for abstracts.
    private func renderInlineContentAsText(_ content: RenderInlineContent) -> String {
        switch content {
        case .text(let text):
            return text
        case .codeVoice(let code):
            return code
        case .emphasis(let children), .strong(let children), .strikethrough(let children):
            return children.map { renderInlineContentAsText($0) }.joined()
        case .reference, .image:
            return ""
        default:
            return ""
        }
    }

    /// Tutorials use a different layout from regular documentation:
    /// - No sidebar navigation
    /// - Top navigation bar with: overview link, tutorial dropdown, section dropdown
    /// - Side-by-side layout for content and media/code
    func buildTutorialPage(from renderNode: RenderNode, references: [String: any RenderReference]) -> String {
        let title = extractTitle(from: renderNode)
        let description = extractDescription(from: renderNode)
        let depth = calculateDepth(for: renderNode)

        let cssPath = String(repeating: "../", count: depth) + "css/main.css"

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

        html += """

            <link rel="stylesheet" href="\(cssPath)">
        </head>
        <body class="tutorial-page" data-color-scheme="auto">
        """

        // Add tutorial navigation bar
        html += buildTutorialNavigation(for: renderNode, references: references, depth: depth)

        // Add main content area (no sidebar wrapper)
        html += """

            <main class="tutorial-main">
        """

        // Add tutorial content
        html += buildTutorialContent(from: renderNode, references: references, depth: depth)

        html += """

            </main>
        """

        // Add footer
        html += buildFooter()

        // Add search scripts if enabled
        if configuration.includeSearch {
            let lunrPath = String(repeating: "../", count: depth) + "js/lunr.min.js"
            let jsPath = String(repeating: "../", count: depth) + "js/search.js"
            html += """

            <script src="\(lunrPath)" defer></script>
            <script src="\(jsPath)" defer></script>
            """
        }

        // Add appearance selector and dropdown scripts
        html += tutorialDropdownScript
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

            <header class="documentation-nav">
                <div class="header-content">
                    <label for="sidebar-toggle" class="sidenav-toggle" aria-label="Toggle sidebar">
                        <span class="sidenav-icon-wrapper">
                            <svg class="sidenav-icon" viewBox="0 0 14 14" width="19" height="19" fill="currentColor">
                                <path d="M6.533 1.867h-6.533v10.267h14v-10.267zM0.933 11.2v-8.4h4.667v8.4zM13.067 11.2h-6.533v-8.4h6.533z"></path>
                                <path d="M1.867 5.133h2.8v0.933h-2.8z"></path>
                                <path d="M1.867 7.933h2.8v0.933h-2.8z"></path>
                            </svg>
                        </span>
                    </label>
                    <a href="\(homeURL)" class="header-title">Documentation</a>
                    <span class="header-language">Language: Swift</span>
                </div>
            </header>
        """
    }

    /// Builds the sidebar navigation of a page.
    ///
    /// Pages embed the shared sidebar document when one is available, selecting their
    /// own row through the URL fragment.  Otherwise a small inline sidebar is built.
    ///
    /// - Parameters:
    ///   - renderNode: The render node of the page.
    ///   - references: The references used to build the inline fallback sidebar.
    ///   - depth: The number of directories between the output root and the page.
    ///   - moduleName: The module name shown by the inline fallback sidebar.
    /// - Returns: The sidebar HTML.
    func buildSidebar(
        for renderNode: RenderNode,
        references: [String: any RenderReference],
        depth: Int,
        moduleName: String
    ) -> String {
        // Embed the shared sidebar document if there is one
        if let sidebarDocument {
            return sidebarDocument.embeddingMarkup(forPagePath: renderNode.identifier.path, depth: depth)
        }

        // A navigation index without modules yields an empty inline sidebar
        if navigationIndex != nil {
            return NavigationSidebarBuilder.buildFallbackSidebar()
        }

        // Fallback to building sidebar from current page's topic sections
        // Use the title for display if available, otherwise use the module name
        let displayTitle = renderNode.metadata.title ?? moduleName
        var html = """

                <nav class="sidebar">
                    <div class="sidebar-content">
                        <h2 class="sidebar-module">\(escapeHTML(displayTitle))</h2>
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

                                <li class="navigator-card">
                                    <span class="badge \(badgeClass)">\(badge)</span>
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

    /// Returns the topic icon SVG for the reference type.
    ///
    /// The icons match swift-docc's icons. Themes can override the appearance via CSS.
    /// For custom SVG icons, themes should provide their own CSS rules for `.topic-icon`.
    func topicIcon(for reference: TopicRenderReference) -> String {
        // For articles, use the article icon
        if reference.symbolKind == nil || reference.symbolKind?.id == "article" {
            return """
<svg aria-hidden="true" class="svg-icon article-icon topic-icon" viewBox="0 0 14 14">
<path d="M8.033 1l3.967 4.015v7.985h-10v-12zM7.615 2h-4.615v10h8v-6.574z"></path>
<path d="M7 1h1v4h-1z"></path>
<path d="M7 5h5v1h-5z"></path>
</svg>
"""
        }

        // For tutorials, use tutorial icon
        if reference.symbolKind?.id == "tutorial" {
            return """
<svg aria-hidden="true" class="svg-icon tutorial-icon topic-icon" viewBox="0 0 14 14">
<path d="M2 2h10v10h-10z"></path>
<path d="M6 5l4 2-4 2z" fill="currentColor"></path>
</svg>
"""
        }

        // For symbols (struct, enum, class, etc.), swift-docc doesn't show icons in Topics section
        // The icon type is indicated by the symbol kind badge instead
        return ""
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
            // Always return the path component for module matching (not the title)
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

                            <ul class="hierarchy" aria-label="Breadcrumbs">
        """

        // Build breadcrumb trail from hierarchy using list items
        // (separators rendered via CSS ::before on li + li)
        for identifier in firstPath {
            if let reference = references[identifier] as? TopicRenderReference {
                let title = reference.title
                let relativeURL = makeRelativeURL(reference.url, depth: depth)
                html += "\n                                <li><a href=\"\(escapeHTML(relativeURL))\">\(escapeHTML(title))</a></li>"
            } else {
                html += "\n                                <li><span>\(escapeHTML(identifier))</span></li>"
            }
        }

        // Add current page title as the last (non-linked) breadcrumb item
        let currentTitle = extractTitle(from: renderNode)
        html += "\n                                <li><span>\(escapeHTML(currentTitle))</span></li>"

        html += """

                            </ul>
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

    /// Builds a relative path for image/media assets (no index.html suffix).
    func makeRelativeAssetURL(_ url: String, depth: Int) -> String {
        // Remove leading slash and create relative path for assets
        let cleanPath = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let prefix = String(repeating: "../", count: depth)
        return "\(prefix)\(cleanPath)"
    }

    /// Converts an image path to its dark variant path.
    /// For example: `images/foo.svg` becomes `images/foo~dark.svg`
    /// If the path already contains `~dark`, returns it unchanged.
    func makeDarkVariantPath(_ path: String) -> String {
        // Don't add ~dark if it's already there
        if path.contains("~dark") {
            return path
        }
        guard let dotIndex = path.lastIndex(of: ".") else {
            return path + "~dark"
        }
        let name = path[..<dotIndex]
        let ext = path[dotIndex...]
        return "\(name)~dark\(ext)"
    }

    /// Converts an image path to its light variant path by removing `~dark` suffix.
    /// For example: `images/foo~dark.svg` becomes `images/foo.svg`
    /// If the path doesn't contain `~dark`, returns it unchanged.
    func makeLightVariantPath(_ path: String) -> String {
        path.replacingOccurrences(of: "~dark", with: "")
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

        // Modules and articles get the enhanced (coloured) hero background;
        // all other symbol pages get the --disabled hero (no background fill),
        // matching swift-docc-render's DocumentationHero.vue `enhanceBackground` logic.
        let isModule = renderNode.kind == .symbol && renderNode.metadata.symbolKind == "module"
        let isSymbol = renderNode.metadata.symbolKind != nil
        let enhanceBackground = !isSymbol || isModule
        let heroClass = enhanceBackground
            ? "documentation-hero"
            : "documentation-hero documentation-hero--disabled"

        html += """

                    <div class="\(heroClass)">
        """

        // Add technology icon for modules/frameworks
        if isModule {
            html += """

                        <div class="icon">
                            <div class="background-icon">
                                <svg viewBox="0 0 14 14" class="technology-icon">
                                    <path d="M3.39,9l3.16,1.84.47.28.47-.28L10.61,9l.45.26,1.08.63L7,12.91l-5.16-3,1.08-.64L3.39,9M7,0,0,4.1,2.47,5.55,0,7,2.47,8.44,0,9.9,7,14l7-4.1L11.53,8.45,14,7,11.53,5.56,14,4.1ZM7,7.12,5.87,6.45l-1.54-.9L3.39,5,1.85,4.1,7,1.08l5.17,3L10.6,5l-.93.55-1.54.91ZM7,10,3.39,7.9,1.85,7,3.4,6.09,4.94,7,7,8.2,9.06,7,10.6,6.1,12.15,7l-1.55.9Z" fill="currentColor"/>
                                </svg>
                            </div>
                        </div>
        """
        }

        html += """

                        <div class="documentation-hero__content">
        """

        // Insert breadcrumb hierarchy inside hero content
        html += buildBreadcrumbs(for: renderNode, references: references, depth: depth)

        html += """
                            <span class="eyebrow">\(escapeHTML(roleLabel))</span>
                            <h1>\(escapeHTML(title))</h1>
        """

        // Abstract — uses <div class="abstract content"> wrapper matching docc-render
        if let abstract = renderNode.abstract {
            let abstractHTML = contentRenderer.renderInlineContent(abstract, references: references, depth: depth)
            html += """

                            <div class="abstract content"><p>\(abstractHTML.html)</p></div>
            """
        }

        // Declaration inside the hero — matches swift-docc-render's DocumentationHero.vue layout
        // where the declarations-container lives inside documentation-hero__content.
        if renderNode.kind == .symbol {
            html += buildDeclaration(from: renderNode, references: references, depth: depth)
        }

        html += """

                        </div>
                    </div>
        """

        // Flex wrapper: doc-content (main column) + OnThisPageStickyContainer (right column)
        html += """

                    <div class="doc-content-wrapper">
                        <div class="doc-content">
                            <div class="primary-content-container">
        """

        // Primary content sections — skip declarations (already rendered inside the hero)
        for section in renderNode.primaryContentSections {
            if section is DeclarationsRenderSection { continue }
            html += buildSection(section, references: references, depth: depth)
        }

        // Sections array (used by tutorials and tutorial articles)
        for section in renderNode.sections {
            html += buildSection(section, references: references, depth: depth)
        }

        html += """

                            </div>
        """

        // Topic sections — contenttable structure matching swift-docc-render ContentTable.vue
        if !renderNode.topicSections.isEmpty {
            html += """

                        <section class="contenttable alt-light">
                            <div class="container">
                                <h2 id="topics" class="title">Topics</h2>
            """

            for taskGroup in renderNode.topicSections {
                html += buildTaskGroup(taskGroup, references: references, depth: depth)
            }

            html += """

                            </div>
                        </section>
            """
        }

        // Relationships (for symbols) — contenttable structure
        if !renderNode.relationshipSections.isEmpty {
            html += """

                        <section class="contenttable alt-light">
                            <div class="container">
                                <h2 id="relationships" class="title">Relationships</h2>
            """

            for relationship in renderNode.relationshipSections {
                html += buildRelationshipSection(relationship, references: references, depth: depth)
            }

            html += """

                            </div>
                        </section>
            """
        }

        // See Also — contenttable structure
        if !renderNode.seeAlsoSections.isEmpty {
            html += """

                        <section class="contenttable alt-light">
                            <div class="container">
                                <h2 id="see-also" class="title">See Also</h2>
            """

            for seeAlso in renderNode.seeAlsoSections {
                html += buildTaskGroup(seeAlso, references: references, depth: depth)
            }

            html += """

                            </div>
                        </section>
            """
        }

        // Close doc-content
        html += """

                        </div>
        """

        // On-this-page navigation sidebar (right column, sticky)
        html += buildOnThisPageNav(for: renderNode, title: title)

        // Close doc-content-wrapper
        html += """

                    </div>
        """

        return html
    }

    /// Builds the sticky on-this-page navigation sidebar shown to the right of the main content.
    ///
    /// Generates links to major sections present on the current page, matching
    /// swift-docc-render's `OnThisPageStickyContainer` / `OnThisPageNav` components.
    /// The first item (page title) is pre-marked active; active tracking during scroll
    /// would require JavaScript and is omitted in this pure-HTML implementation.
    ///
    /// - Parameters:
    ///   - renderNode: The render node for the current page.
    ///   - title: The page title (used as the first nav item label).
    /// - Returns: HTML string for the sticky container, or an empty string if there
    ///   are no sections to navigate to.
    func buildOnThisPageNav(for renderNode: RenderNode, title: String) -> String {
        // Nav items carry both their anchor/label and whether they are a child (H3) or parent (H2).
        struct NavItem {
            let anchor: String
            let label: String
            let isChild: Bool
        }
        var items: [NavItem] = []

        // Always include the page title as the first item (links to top)
        items.append(NavItem(anchor: "app-top", label: title, isChild: false))

        // Check primary content sections for mentions and content headings
        for section in renderNode.primaryContentSections {
            if let mentionsSection = section as? MentionsRenderSection,
               !mentionsSection.mentions.isEmpty {
                items.append(NavItem(anchor: "mentions", label: "Mentioned in", isChild: false))
            } else if let contentSection = section as? ContentRenderSection {
                // Collect all H2 headings (parent-item) and H3 headings (child-item)
                for block in contentSection.content {
                    if case .heading(let heading) = block {
                        if heading.level == 2 {
                            let anchor = heading.anchor ?? slugify(heading.text)
                            items.append(NavItem(anchor: anchor, label: heading.text, isChild: false))
                        } else if heading.level == 3 {
                            let anchor = heading.anchor ?? slugify(heading.text)
                            items.append(NavItem(anchor: anchor, label: heading.text, isChild: true))
                        }
                    }
                }
            }
        }

        if !renderNode.topicSections.isEmpty {
            items.append(NavItem(anchor: "topics", label: "Topics", isChild: false))
        }
        if !renderNode.relationshipSections.isEmpty {
            items.append(NavItem(anchor: "relationships", label: "Relationships", isChild: false))
        }
        if !renderNode.seeAlsoSections.isEmpty {
            items.append(NavItem(anchor: "see-also", label: "See Also", isChild: false))
        }

        // Only render the sidebar when there are navigation targets beyond the title
        guard items.count > 1 else { return "" }

        var html = """

                        <div class="OnThisPageStickyContainer">
                            <div class="OnThisPageNav">
                                <ul class="items">
        """

        for (index, item) in items.enumerated() {
            let activeClass = index == 0 ? " active" : ""
            let itemClass = item.isChild ? "child-item" : "parent-item\(activeClass)"
            html += """

                                    <li class="\(itemClass)">
                                        <a href="#\(escapeHTML(item.anchor))" class="base-link">
                                            <span>\(escapeHTML(item.label))</span>
                                        </a>
                                    </li>
            """
        }

        html += """

                                </ul>
                            </div>
                        </div>
        """

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

    func buildDeclaration(from renderNode: RenderNode, references: [String: any RenderReference], depth: Int) -> String {
        // Look for declaration section in primary content
        for section in renderNode.primaryContentSections {
            if let declarationSection = section as? DeclarationsRenderSection {
                return buildDeclarationsSection(declarationSection, references: references, depth: depth)
            }
        }
        return ""
    }

    func buildDeclarationsSection(_ section: DeclarationsRenderSection, references: [String: any RenderReference], depth: Int) -> String {
        // Match swift-docc-render structure:
        // section.declaration > div.declaration-list > div.declaration-pill > div.declaration-group-wrapper > div.declaration-group > pre.source > code
        var html = """

                <section class="declaration">
                    <div class="declaration-list">
        """

        for declaration in section.declarations {
            html += """

                        <div class="declaration-pill selected-declaration">
                            <div class="declaration-group-wrapper">
                                <div class="declaration-group">
                                    <pre class="source"><code>
            """

            for token in declaration.tokens {
                let tokenClass = tokenCSSClass(for: token.kind)
                let escapedText = escapeHTML(token.text)

                // Check if this token has a reference we can link to
                var linkedText = escapedText
                if let identifier = token.identifier,
                   let reference = references[identifier] as? TopicRenderReference {
                    let relativeURL = makeRelativeURL(reference.url, depth: depth)
                    linkedText = "<a href=\"\(escapeHTML(relativeURL))\">\(escapedText)</a>"
                }

                if let tokenClass = tokenClass {
                    html += "<span class=\"\(tokenClass)\">\(linkedText)</span>"
                } else {
                    html += linkedText
                }
            }

            html += "</code></pre>\n                                </div>\n                            </div>\n                        </div>"
        }

        html += """

                    </div>
                </section>
        """

        return html
    }

    func tokenCSSClass(for kind: DeclarationRenderSection.Token.Kind) -> String? {
        // Class names match swift-docc-render's token-* naming convention
        switch kind {
        case .keyword:
            return "token-keyword"
        case .typeIdentifier:
            return "token-type"
        case .genericParameter:
            return "token-type"
        case .text:
            return nil
        case .internalParam:
            return "token-param"
        case .externalParam:
            return "token-param"
        case .identifier:
            return "token-identifier"
        case .label:
            return "token-label"
        case .number:
            return "token-number"
        case .string:
            return "token-string"
        case .attribute:
            return "token-attribute"
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
        case .hero, .intro:
            if let introSection = section as? IntroRenderSection {
                return buildIntroSection(introSection, references: references, depth: depth)
            }
        case .tasks:
            if let tasksSection = section as? TutorialSectionsRenderSection {
                return buildTutorialTasksSection(tasksSection, references: references, depth: depth)
            }
        case .assessments:
            if let assessmentsSection = section as? TutorialAssessmentsRenderSection {
                return buildAssessmentsSection(assessmentsSection, references: references, depth: depth)
            }
        case .callToAction:
            if let ctaSection = section as? CallToActionSection {
                return buildCallToActionSection(ctaSection, references: references, depth: depth)
            }
        case .articleBody:
            if let articleSection = section as? TutorialArticleSection {
                return buildTutorialArticleSection(articleSection, references: references, depth: depth)
            }
        case .contentAndMedia:
            if let camSection = section as? ContentAndMediaSection {
                return buildContentAndMediaSection(camSection, references: references, depth: depth)
            }
        case .volume:
            if let volumeSection = section as? VolumeRenderSection {
                return buildVolumeSection(volumeSection, references: references, depth: depth)
            }
        case .resources:
            if let resourcesSection = section as? ResourcesRenderSection {
                return buildResourcesSection(resourcesSection, references: references, depth: depth)
            }
        case .mentions:
            if let mentionsSection = section as? MentionsRenderSection {
                return buildMentionsSection(mentionsSection, references: references, depth: depth)
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
        var html = """

                        <div class="contenttable-section">
        """

        if let title = taskGroup.title {
            html += """

                            <div class="section-title">
                                <h3 class="contenttable-title">\(escapeHTML(title))</h3>
                            </div>
            """
        }

        html += """

                            <div class="section-content">
        """

        for identifier in taskGroup.identifiers {
            if let reference = references[identifier] as? TopicRenderReference {
                html += buildSymbolCard(for: reference, depth: depth)
            }
        }

        html += """

                            </div>
                        </div>
        """

        return html
    }

    func buildSymbolCard(for reference: TopicRenderReference, depth: Int) -> String {
        let relativeURL = makeRelativeURL(reference.url, depth: depth)
        let abstract = contentRenderer.renderInlineContent(reference.abstract, references: [:], depth: 0).plainText

        // Get icon SVG for the reference type
        let iconSVG = topicIcon(for: reference)
        let hasIcon = !iconSVG.isEmpty

        // Render title: use fragments if available, fall back to plain title
        let titleHTML: String
        if let fragments = reference.fragments, !fragments.isEmpty {
            titleHTML = renderDecoratedTitle(fragments)
        } else {
            titleHTML = "<span>\(escapeHTML(reference.title))</span>"
        }

        // Only include icon wrapper when icon SVG is present (avoids 0px collapsed wrapper)
        let iconBlock: String
        if hasIcon {
            iconBlock = """

                                        <div class="topic-icon-wrapper">
                                            \(iconSVG)
                                        </div>
            """
        } else {
            iconBlock = ""
        }

        let linkBlockClass = hasIcon ? "link-block topic" : "link-block topic no-icon"

        return """

                                <div class="\(linkBlockClass)">
                                    <a href="\(escapeHTML(relativeURL))" class="link has-adjacent-elements">\(iconBlock)
                                        \(titleHTML)
                                    </a>
                                    <div class="abstract">
                                        <p>\(escapeHTML(abstract))</p>
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

    // MARK: - Tutorial Section Rendering

    /// Builds an intro/hero section for tutorials.
    func buildIntroSection(
        _ section: IntroRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                    <section class="tutorial-intro">
        """

        // Chapter label if available
        if let chapter = section.chapter {
            html += """

                        <p class="tutorial-chapter">\(escapeHTML(chapter))</p>
            """
        }

        // Title
        html += """

                        <h2 class="tutorial-title">\(escapeHTML(section.title))</h2>
        """

        // Estimated time
        if let time = section.estimatedTimeInMinutes {
            html += """

                        <p class="tutorial-time">\(time) mins</p>
            """
        }

        // Content
        for block in section.content {
            html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
        }

        html += """

                    </section>
        """

        return html
    }

    /// Builds the tasks section for tutorials.
    func buildTutorialTasksSection(
        _ section: TutorialSectionsRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                    <section class="tutorial-tasks">
        """

        for (index, task) in section.tasks.enumerated() {
            html += """

                        <section class="tutorial-task" id="\(escapeHTML(task.anchor))">
                            <h3>Section \(index + 1)</h3>
                            <h4>\(escapeHTML(task.title))</h4>
            """

            // Content section
            for layout in task.contentSection {
                html += buildContentLayout(layout, references: references, depth: depth)
            }

            // Steps section
            if !task.stepsSection.isEmpty {
                html += """

                            <div class="tutorial-steps">
                """

                for (stepIndex, step) in task.stepsSection.enumerated() {
                    html += """

                                <div class="tutorial-step">
                                    <span class="step-number">Step \(stepIndex + 1)</span>
                    """
                    html += contentRenderer.renderBlockContent(step, references: references, depth: depth)
                    html += """

                                </div>
                    """
                }

                html += """

                            </div>
                """
            }

            html += """

                        </section>
            """
        }

        html += """

                    </section>
        """

        return html
    }

    /// Builds a content layout (fullWidth, contentAndMedia, columns).
    func buildContentLayout(
        _ layout: ContentLayout,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        switch layout {
        case .fullWidth(let content):
            var html = """

                            <div class="content-full-width">
            """
            for block in content {
                html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
            }
            html += """

                            </div>
            """
            return html

        case .contentAndMedia(let section):
            return buildContentAndMediaSection(section, references: references, depth: depth)

        case .columns(let sections):
            var html = """

                            <div class="content-columns">
            """
            for section in sections {
                html += buildContentAndMediaSection(section, references: references, depth: depth)
            }
            html += """

                            </div>
            """
            return html
        }
    }

    /// Builds a content and media section.
    func buildContentAndMediaSection(
        _ section: ContentAndMediaSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                            <div class="content-and-media">
                                <div class="content-side">
        """

        for block in section.content {
            html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
        }

        html += """

                                </div>
        """

        // Media side
        if let mediaRef = section.media {
            if let imageRef = references[mediaRef.identifier] as? ImageReference {
                // Use the identifier as the image path - it's typically the relative path from the archive
                let imagePath = "images/\(mediaRef.identifier)"
                let relativeURL = makeRelativeAssetURL(imagePath, depth: depth)
                html += """

                                <div class="media-side">
                                    <img src="\(escapeHTML(relativeURL))" alt="\(escapeHTML(imageRef.altText ?? ""))">
                                </div>
                """
            }
        }

        html += """

                            </div>
        """

        return html
    }

    /// Builds the assessments (quiz) section for tutorials.
    func buildAssessmentsSection(
        _ section: TutorialAssessmentsRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                    <section class="tutorial-assessments">
                        <h3>Check Your Understanding</h3>
        """

        for (index, assessment) in section.assessments.enumerated() {
            let questionId = "q\(index)"
            html += """

                        <div class="assessment">
                            <p class="question-number">Question \(index + 1) of \(section.assessments.count)</p>
                            <div class="question">
            """

            // Question title (the main question text)
            for block in assessment.title {
                html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
            }

            // Optional additional question content
            if let content = assessment.content {
                for block in content {
                    html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
                }
            }

            html += """

                            </div>
                            <fieldset class="choices">
            """

            // Choices - use hidden radio inputs for pure CSS interaction
            for (choiceIndex, choice) in assessment.choices.enumerated() {
                let choiceId = "\(questionId)c\(choiceIndex)"
                let correctClass = choice.isCorrect ? " correct-answer" : " incorrect-answer"
                html += """

                                <label class="choice\(correctClass)" for="\(choiceId)">
                                    <input type="radio" id="\(choiceId)" name="\(questionId)" class="choice-input">
                                    <span class="choice-indicator"></span>
                                    <span class="choice-content">
                """
                for block in choice.content {
                    html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
                }
                // Add justification if available (shown when selected)
                if let justification = choice.justification {
                    html += """

                                        <span class="choice-justification">
                    """
                    for block in justification {
                        html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
                    }
                    html += """

                                        </span>
                    """
                }
                html += """

                                    </span>
                                </label>
                """
            }

            html += """

                            </fieldset>
                        </div>
            """
        }

        html += """

                    </section>
        """

        return html
    }

    /// Builds the call to action section for tutorials.
    func buildCallToActionSection(
        _ section: CallToActionSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                    <section class="tutorial-cta">
        """

        html += """

                        <h3>\(escapeHTML(section.title))</h3>
        """

        if !section.abstract.isEmpty {
            html += """

                        <p class="cta-abstract">
            """
            html += contentRenderer.renderInlineContent(section.abstract, references: references, depth: depth).html
            html += """

                        </p>
            """
        }

        // Action link
        html += """

                        <div class="cta-action">
        """
        html += contentRenderer.renderInlineContent([section.action], references: references, depth: depth).html
        html += """

                        </div>
        """

        html += """

                    </section>
        """

        return html
    }

    /// Builds a tutorial article section.
    func buildTutorialArticleSection(
        _ section: TutorialArticleSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                    <section class="tutorial-article">
        """

        for layout in section.content {
            html += buildContentLayout(layout, references: references, depth: depth)
        }

        html += """

                    </section>
        """

        return html
    }

    /// Builds a volume section (used in tutorial table of contents).
    func buildVolumeSection(
        _ section: VolumeRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                    <section class="tutorial-volume">
        """

        if let name = section.name {
            html += """

                        <h3>\(escapeHTML(name))</h3>
            """
        }

        // Content
        if let content = section.content {
            for block in content {
                html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
            }
        }

        // Chapters
        for chapter in section.chapters {
            html += """

                        <div class="volume-chapter">
            """

            if let name = chapter.name {
                html += """

                            <h4>\(escapeHTML(name))</h4>
                """
            }

            // Chapter content
            for block in chapter.content {
                html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
            }

            // Tutorial references
            if !chapter.tutorials.isEmpty {
                html += """

                            <ul class="chapter-tutorials">
                """

                for tutorialRef in chapter.tutorials {
                    if let ref = references[tutorialRef.identifier] as? TopicRenderReference {
                        let url = makeRelativeURL(ref.url, depth: depth)
                        html += """

                                <li><a href="\(escapeHTML(url))">\(escapeHTML(ref.title))</a></li>
                        """
                    }
                }

                html += """

                            </ul>
                """
            }

            html += """

                        </div>
            """
        }

        html += """

                    </section>
        """

        return html
    }

    /// Builds a resources section.
    func buildResourcesSection(
        _ section: ResourcesRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                    <section class="resources">
                        <h3>Resources</h3>
        """

        for tile in section.tiles {
            html += """

                        <div class="resource-tile">
            """

            if !tile.title.isEmpty {
                html += """

                            <h4>\(escapeHTML(tile.title))</h4>
                """
            }

            for block in tile.content {
                html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
            }

            html += """

                        </div>
            """
        }

        html += """

                    </section>
        """

        return html
    }

    func buildMentionsSection(
        _ section: MentionsRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        guard !section.mentions.isEmpty else {
            return ""
        }

        var html = """

                <section class="mentions">
                    <h2 id="mentions"><a href="#mentions">Mentioned in</a></h2>
                    <div class="symbol-list">
        """

        // Limit to top 5 mentions (matching swift-docc-render behavior)
        for mentionURL in section.mentions.prefix(5) {
            let urlString = mentionURL.absoluteString
            // Look up the reference to get the title
            if let reference = references[urlString] as? TopicRenderReference {
                let relativeURL = makeRelativeURL(reference.url, depth: depth)
                let title = reference.title
                html += """

                        <div class="topic-link-container">
                            <span class="symbol-icon"><svg viewBox="0 0 14 14" fill="none"><path d="M3 1.5A.5.5 0 013.5 1h5.793a.5.5 0 01.353.146l2.208 2.208a.5.5 0 01.146.353V12.5a.5.5 0 01-.5.5h-8a.5.5 0 01-.5-.5v-11z" stroke="currentColor" stroke-width="1"/><path d="M9 1v3h3" stroke="currentColor" stroke-width="1"/></svg></span>
                            <div class="symbol-info">
                                <a href="\(escapeHTML(relativeURL))" class="symbol-name">\(escapeHTML(title))</a>
                            </div>
                        </div>
                """
            }
        }

        html += """

                    </div>
                </section>
        """

        return html
    }

    /// Builds the page footer with configurable content and appearance selector.
    func buildFooter() -> String {
        let footerContent = configuration.footerHTML ?? Configuration.defaultFooter
        return """

            <footer class="documentation-footer">
                <div class="footer-content">\(footerContent)</div>
                <div class="appearance-selector" id="appearance-selector">
                    <button type="button" class="appearance-btn" data-color-scheme="light" aria-label="Light mode">Light</button>
                    <button type="button" class="appearance-btn" data-color-scheme="dark" aria-label="Dark mode">Dark</button>
                    <button type="button" class="appearance-btn active" data-color-scheme="auto" aria-label="Auto mode">Auto</button>
                </div>
            </footer>
        """
    }

    /// JavaScript for the appearance selector and the embedded sidebar.
    ///
    /// The script restores and stores the reader's colour scheme, forwards it to the
    /// embedded sidebar document, and forwards the keyboard shortcuts that focus the
    /// sidebar filter (`/`, and Command-F or Control-F while the sidebar is shown) to
    /// the embedded sidebar document using `postMessage`, which also works for pages
    /// opened from local files.
    var appearanceSelectorScript: String {
        """

            <script>
            (function() {
                var storageKey = '\(SidebarDocument.colourSchemeStorageKey)';
                var schemeMessage = '\(SidebarDocument.colourSchemeMessage)';
                var focusMessage = '\(SidebarDocument.focusFilterMessage)';
                var readyMessage = '\(SidebarDocument.readyMessage)';
                var body = document.body;
                var frame = document.querySelector('iframe.\(SidebarDocument.frameClass)');

                function postToSidebar(message) {
                    if (frame && frame.contentWindow) {
                        frame.contentWindow.postMessage(message, '*');
                    }
                }

                function currentScheme() {
                    return body.getAttribute('data-color-scheme') || 'auto';
                }

                // --- Appearance Selector ---
                var selector = document.getElementById('appearance-selector');
                if (selector) {
                    // Show the selector (hidden by default for no-JS fallback)
                    selector.style.visibility = 'visible';

                    var buttons = selector.querySelectorAll('.appearance-btn');

                    function applyColorScheme(scheme) {
                        body.setAttribute('data-color-scheme', scheme);
                        buttons.forEach(function (btn) {
                            btn.classList.toggle('active', btn.dataset.colorScheme === scheme);
                        });
                        postToSidebar({ type: schemeMessage, scheme: scheme });
                    }

                    var saved = 'auto';
                    try {
                        saved = localStorage.getItem(storageKey) || 'auto';
                    } catch (error) {
                        // Storage may be unavailable, for example for local files.
                    }
                    applyColorScheme(saved);

                    buttons.forEach(function (btn) {
                        btn.addEventListener('click', function () {
                            var scheme = btn.dataset.colorScheme;
                            try {
                                localStorage.setItem(storageKey, scheme);
                            } catch (error) {
                                // The choice then only applies to this page.
                            }
                            applyColorScheme(scheme);
                        });
                    });
                }

                // --- Embedded Sidebar ---
                if (frame) {
                    window.addEventListener('message', function (event) {
                        var data = event.data;
                        if (event.source === frame.contentWindow && data && data.type === readyMessage) {
                            postToSidebar({ type: schemeMessage, scheme: currentScheme() });
                        }
                    });

                    var toggle = document.getElementById('sidebar-toggle');

                    document.addEventListener('keydown', function (e) {
                        var focused = document.activeElement;
                        var editing = focused && (focused.tagName === 'INPUT' || focused.tagName === 'TEXTAREA' || focused.isContentEditable);
                        var hidden = toggle && toggle.checked;
                        var slash = e.key === '/' && !editing;
                        var find = (e.metaKey || e.ctrlKey) && e.key === 'f' && !hidden;
                        if (slash || find) {
                            e.preventDefault();
                            if (hidden) {
                                toggle.checked = false;
                            }
                            frame.focus();
                            postToSidebar({ type: focusMessage });
                        }
                    });
                }
            })();
            </script>
        """
    }

    // MARK: - Tutorial-Specific Methods

    /// Builds the tutorial navigation bar with overview link and dropdowns.
    func buildTutorialNavigation(
        for renderNode: RenderNode,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        let title = extractTitle(from: renderNode)

        // Extract tutorial overview link from hierarchy
        var overviewTitle = "Tutorials"
        var overviewURL = makeRelativeURL("/tutorials/tutorials/index.html", depth: depth)

        if let hierarchy = renderNode.hierarchyVariants.defaultValue {
            switch hierarchy {
            case .tutorials(let tutorialsHierarchy):
                if let paths = tutorialsHierarchy.paths.first,
                   let firstPath = paths.first,
                   let ref = references[firstPath] as? TopicRenderReference {
                    overviewTitle = ref.title
                    overviewURL = makeRelativeURL(ref.url, depth: depth)
                }
            case .reference:
                break
            }
        }

        // Build section list for the dropdown
        var sectionItems: [(title: String, anchor: String)] = []
        sectionItems.append(("Introduction", ""))

        for section in renderNode.sections {
            if let tasksSection = section as? TutorialSectionsRenderSection {
                for (index, task) in tasksSection.tasks.enumerated() {
                    sectionItems.append((task.title, task.anchor))
                    _ = index // Silence unused variable warning
                }
            } else if let assessmentSection = section as? TutorialAssessmentsRenderSection {
                sectionItems.append(("Check Your Understanding", assessmentSection.anchor))
            }
        }

        var html = """

            <nav class="tutorial-nav">
                <div class="tutorial-nav-content">
                    <a href="\(overviewURL)" class="tutorial-nav-title">\(escapeHTML(overviewTitle))</a>
                    <div class="tutorial-nav-dropdowns">
                        <details class="tutorial-dropdown">
                            <summary class="tutorial-dropdown-toggle">
                                <span class="dropdown-label">\(escapeHTML(title))</span>
                                <svg class="dropdown-chevron" width="12" height="12" viewBox="0 0 12 12">
                                    <path d="M2 4l4 4 4-4" fill="none" stroke="currentColor" stroke-width="1.5"/>
                                </svg>
                            </summary>
                            <div class="tutorial-dropdown-menu" role="menu">
        """

        // Build tutorials dropdown from hierarchy - show ALL tutorials organized by chapter
        let currentPath = renderNode.identifier.path
        var hasContent = false

        if let hierarchy = renderNode.hierarchyVariants.defaultValue,
           case .tutorials(let tutorialsHierarchy) = hierarchy,
           let chapters = tutorialsHierarchy.modules {
            // Show all chapters with their tutorials
            for chapter in chapters {
                // Get chapter name from reference
                let chapterTitle: String
                if let chapterRef = references[chapter.reference.identifier] as? TopicRenderReference {
                    chapterTitle = chapterRef.title
                } else {
                    chapterTitle = chapter.reference.identifier.components(separatedBy: "/").last ?? "Chapter"
                }

                // Only show chapter header if there are tutorials
                guard !chapter.tutorials.isEmpty else { continue }
                hasContent = true

                html += """
                                <div class="dropdown-chapter">
                                    <span class="dropdown-chapter-title">\(escapeHTML(chapterTitle))</span>

                """

                for tutorial in chapter.tutorials {
                    if let tutorialRef = references[tutorial.reference.identifier] as? TopicRenderReference {
                        let isSelected = tutorialRef.url == currentPath
                        let selectedClass = isSelected ? " selected" : ""
                        html += """
                                    <a href="\(makeRelativeURL(tutorialRef.url, depth: depth))" class="dropdown-item\(selectedClass)" role="menuitem">\(escapeHTML(tutorialRef.title))</a>

                """
                    }
                }

                html += """
                                </div>

                """
            }
        }

        // Fallback if no tutorials found
        if !hasContent {
            html += """
                                <a href="#" class="dropdown-item selected" role="menuitem">\(escapeHTML(title))</a>

            """
        }

        html += """
                            </div>
                        </details>
                        <span class="nav-separator">›</span>
                        <details class="tutorial-dropdown section-dropdown">
                            <summary class="tutorial-dropdown-toggle">
                                <span class="dropdown-label">Introduction</span>
                                <svg class="dropdown-chevron" width="12" height="12" viewBox="0 0 12 12">
                                    <path d="M2 4l4 4 4-4" fill="none" stroke="currentColor" stroke-width="1.5"/>
                                </svg>
                            </summary>
                            <div class="tutorial-dropdown-menu" role="menu">
        """

        for (sectionTitle, anchor) in sectionItems {
            let href = anchor.isEmpty ? "#" : "#\(anchor)"
            let selectedClass = anchor.isEmpty ? " selected" : ""
            html += """
                                <a href="\(href)" class="dropdown-item\(selectedClass)" role="menuitem">\(escapeHTML(sectionTitle))</a>

            """
        }

        html += """
                            </div>
                        </details>
                    </div>
                </div>
            </nav>
        """

        return html
    }

    /// Builds the tutorial content with side-by-side layouts.
    func buildTutorialContent(
        from renderNode: RenderNode,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = ""

        // Hero section with dark background (includes intro content)
        html += buildTutorialHero(from: renderNode, references: references, depth: depth)

        // Tutorial sections with side-by-side layout
        // Skip intro section as its content is now in the hero
        for section in renderNode.sections {
            if section is IntroRenderSection {
                // Skip - intro content is rendered in the hero
                continue
            } else if let tasksSection = section as? TutorialSectionsRenderSection {
                html += buildTutorialTasksSectionSideBySide(tasksSection, references: references, depth: depth)
            } else if let assessmentSection = section as? TutorialAssessmentsRenderSection {
                html += buildAssessmentsSection(assessmentSection, references: references, depth: depth)
            } else if let ctaSection = section as? CallToActionSection {
                html += buildCallToActionSection(ctaSection, references: references, depth: depth)
            }
        }

        return html
    }

    /// Builds the tutorial hero section with dark background.
    func buildTutorialHero(
        from renderNode: RenderNode,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        let title = extractTitle(from: renderNode)

        // Get chapter name, time, and intro content from intro section
        var chapterName = ""
        var estimatedTime = ""
        var heroImage: String?
        var introContent: [RenderBlockContent] = []

        for section in renderNode.sections {
            if let intro = section as? IntroRenderSection {
                chapterName = intro.chapter ?? ""
                if let time = intro.estimatedTimeInMinutes {
                    estimatedTime = "\(time) mins"
                }
                if let imageRef = intro.backgroundImage,
                   let imgReference = references[imageRef.identifier] as? ImageReference,
                   let variant = imgReference.asset.variants.first {
                    heroImage = variant.value.absoluteString
                }
                introContent = intro.content
                break
            }
        }

        var html = """

                <section class="tutorial-hero">
                    <div class="tutorial-hero-content">
        """

        if !chapterName.isEmpty {
            html += "\n                        <p class=\"tutorial-chapter\">\(escapeHTML(chapterName))</p>"
        }

        html += "\n                        <h1 class=\"tutorial-title\">\(escapeHTML(title))</h1>"

        // Render intro content as the description in the hero
        if !introContent.isEmpty {
            html += "\n                        <div class=\"tutorial-abstract\">"
            for block in introContent {
                html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
            }
            html += "\n                        </div>"
        } else if let abstract = renderNode.abstract {
            // Fallback to abstract if no intro content
            let abstractHTML = contentRenderer.renderInlineContent(abstract, references: references, depth: depth)
            html += "\n                        <p class=\"tutorial-abstract\">\(abstractHTML.html)</p>"
        }

        if !estimatedTime.isEmpty {
            html += """

                        <div class="tutorial-time">
                            <span class="time-value">\(estimatedTime)</span>
                            <span class="time-label">Estimated Time</span>
                        </div>
            """
        }

        html += "\n                    </div>"

        // Hero background/decoration - hero is always dark, so prefer dark variant
        if let image = heroImage {
            let imagePath = makeRelativeAssetURL(image, depth: depth)
            let darkImagePath = makeDarkVariantPath(imagePath)
            html += """

                    <div class="tutorial-hero-background">
                        <picture>
                            <source srcset="\(escapeHTML(darkImagePath))" media="(prefers-color-scheme: dark)">
                            <source srcset="\(escapeHTML(darkImagePath))">
                            <img src="\(escapeHTML(darkImagePath))" alt="" aria-hidden="true">
                        </picture>
                    </div>
            """
        }

        html += "\n                </section>"

        return html
    }

    /// Builds tutorial intro section.
    func buildTutorialIntroSection(
        _ section: IntroRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                <section class="tutorial-intro-section">
        """

        // Render intro content
        for block in section.content {
            html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
        }

        // Render image if present
        if let imageRef = section.image,
           let imageReference = references[imageRef.identifier] as? ImageReference,
           let variant = imageReference.asset.variants.first {
            let rawSrc = makeRelativeAssetURL(variant.value.absoluteString, depth: depth)
            let lightSrc = makeLightVariantPath(rawSrc)
            let darkSrc = makeDarkVariantPath(lightSrc)
            let alt = imageReference.altText ?? ""
            html += """

                    <div class="intro-media">
                        <picture>
                            <source srcset="\(escapeHTML(darkSrc))" media="(prefers-color-scheme: dark)">
                            <img src="\(escapeHTML(lightSrc))" alt="\(escapeHTML(alt))">
                        </picture>
                    </div>
            """
        }

        html += """

                </section>
        """

        return html
    }

    /// Builds tutorial tasks section with side-by-side layout for steps.
    func buildTutorialTasksSectionSideBySide(
        _ section: TutorialSectionsRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = ""

        for (taskIndex, task) in section.tasks.enumerated() {
            html += """

                <section class="tutorial-section" id="\(task.anchor)">
                    <div class="section-header">
                        <p class="section-number">Section \(taskIndex + 1)</p>
                        <h2 class="section-title">\(escapeHTML(task.title))</h2>
                    </div>
            """

            // Content section (intro text with optional media) - side by side
            if !task.contentSection.isEmpty {
                html += "\n                    <div class=\"section-content-row\">\n                        <div class=\"section-text\">"

                // Render content from each layout - just the text part
                for layout in task.contentSection {
                    switch layout {
                    case .fullWidth(let content):
                        for block in content {
                            html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
                        }
                    case .contentAndMedia(let section):
                        for block in section.content {
                            html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
                        }
                    case .columns(let sections):
                        for section in sections {
                            for block in section.content {
                                html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
                            }
                        }
                    }
                }

                html += "\n                        </div>"

                // Check if there's media in the content section - render on the right
                for layout in task.contentSection {
                    if case .contentAndMedia(let contentAndMedia) = layout {
                        if let mediaRef = contentAndMedia.media,
                           let imageReference = references[mediaRef.identifier] as? ImageReference,
                           let variant = imageReference.asset.variants.first {
                            let rawSrc = makeRelativeAssetURL(variant.value.absoluteString, depth: depth)
                            // Ensure we use the light variant for img src, dark variant for source
                            let lightSrc = makeLightVariantPath(rawSrc)
                            let darkSrc = makeDarkVariantPath(lightSrc)
                            let alt = imageReference.altText ?? ""
                            html += """

                        <div class="section-media">
                            <picture>
                                <source srcset="\(escapeHTML(darkSrc))" media="(prefers-color-scheme: dark)">
                                <img src="\(escapeHTML(lightSrc))" alt="\(escapeHTML(alt))">
                            </picture>
                        </div>
                """
                        }
                    }
                }

                html += "\n                    </div>"
            }

            // Steps section - each step is a card with code on the right
            if !task.stepsSection.isEmpty {
                html += """

                    <div class="tutorial-steps-container">
                """

                for (stepIndex, step) in task.stepsSection.enumerated() {
                    html += buildTutorialStepSideBySide(
                        step,
                        stepNumber: stepIndex + 1,
                        references: references,
                        depth: depth
                    )
                }

                html += """

                    </div>
                """
            }

            html += """

                </section>
            """
        }

        return html
    }

    /// Builds a single tutorial step with side-by-side layout (step card + code panel).
    func buildTutorialStepSideBySide(
        _ step: RenderBlockContent,
        stepNumber: Int,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        guard case .step(let tutorialStep) = step else {
            return contentRenderer.renderBlockContent(step, references: references, depth: depth)
        }

        var html = """

                        <div class="tutorial-step-row">
                            <div class="step-card">
                                <p class="step-label">Step \(stepNumber)</p>
                                <div class="step-content">
        """

        // Step description
        for block in tutorialStep.content {
            html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
        }

        // Caption (if present)
        if !tutorialStep.caption.isEmpty {
            html += """

                                    <div class="step-caption">
            """
            for block in tutorialStep.caption {
                html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
            }
            html += """

                                    </div>
            """
        }

        html += """

                                </div>
                            </div>
        """

        // Code panel (if present) - displayed on the right
        if let codeIdentifier = tutorialStep.code,
           let codeRef = references[codeIdentifier.identifier] as? FileReference {
            html += """

                            <div class="step-code-panel">
                                <div class="code-panel-header">
                                    <span class="file-icon">
                                        <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
                                            <path d="M4 1h5l4 4v9a1 1 0 01-1 1H4a1 1 0 01-1-1V2a1 1 0 011-1z"/>
                                            <path d="M9 1v4h4" fill="none" stroke="currentColor"/>
                                        </svg>
                                    </span>
                                    <span class="file-name">\(escapeHTML(codeRef.fileName))</span>
                                </div>
                                <div class="code-panel-content">
                                    <pre><code>
            """

            // Add line numbers and code - each line on its own row
            let lines = codeRef.content
            for (lineIndex, line) in lines.enumerated() {
                let lineNum = lineIndex + 1
                let escapedLine = escapeHTML(line)
                html += "<div class=\"line\"><span class=\"line-number\">\(lineNum)</span><span class=\"line-content\">\(escapedLine)</span></div>"
            }

            html += "</code></pre>\n                                </div>\n                            </div>"
        } else if let mediaIdentifier = tutorialStep.media,
                  let mediaRef = references[mediaIdentifier.identifier] as? ImageReference,
                  let variant = mediaRef.asset.variants.first {
            // Media panel instead of code
            let rawSrc = makeRelativeAssetURL(variant.value.absoluteString, depth: depth)
            let lightSrc = makeLightVariantPath(rawSrc)
            let darkSrc = makeDarkVariantPath(lightSrc)
            let alt = mediaRef.altText ?? ""
            html += """

                            <div class="step-media-panel">
                                <picture>
                                    <source srcset="\(escapeHTML(darkSrc))" media="(prefers-color-scheme: dark)">
                                    <img src="\(escapeHTML(lightSrc))" alt="\(escapeHTML(alt))">
                                </picture>
                            </div>
            """
        }

        html += """

                        </div>
        """

        return html
    }

    /// JavaScript for tutorial dropdown menus.
    var tutorialDropdownScript: String {
        """

            <script>
            (function() {
                // --- Tutorial Dropdowns ---
                const dropdowns = document.querySelectorAll('.tutorial-dropdown');
                dropdowns.forEach(dropdown => {
                    const toggle = dropdown.querySelector('.tutorial-dropdown-toggle');
                    const menu = dropdown.querySelector('.tutorial-dropdown-menu');

                    if (toggle && menu) {
                        toggle.addEventListener('click', (e) => {
                            e.stopPropagation();
                            const isExpanded = toggle.getAttribute('aria-expanded') === 'true';
                            closeAllDropdowns();
                            if (!isExpanded) {
                                toggle.setAttribute('aria-expanded', 'true');
                                menu.classList.add('open');
                            }
                        });

                        // Handle menu item clicks for section navigation
                        menu.querySelectorAll('.dropdown-item').forEach(item => {
                            item.addEventListener('click', (e) => {
                                const href = item.getAttribute('href');
                                if (href && href.startsWith('#')) {
                                    // Update dropdown label
                                    const label = toggle.querySelector('.dropdown-label');
                                    if (label) {
                                        label.textContent = item.textContent;
                                    }
                                    // Update selected state
                                    menu.querySelectorAll('.dropdown-item').forEach(i => i.classList.remove('selected'));
                                    item.classList.add('selected');
                                }
                                closeAllDropdowns();
                            });
                        });
                    }
                });

                function closeAllDropdowns() {
                    dropdowns.forEach(d => {
                        const t = d.querySelector('.tutorial-dropdown-toggle');
                        const m = d.querySelector('.tutorial-dropdown-menu');
                        if (t) t.setAttribute('aria-expanded', 'false');
                        if (m) m.classList.remove('open');
                    });
                }

                // Close dropdowns when clicking outside
                document.addEventListener('click', closeAllDropdowns);
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

/// Renders a decorated title from declaration tokens.
///
/// Maps token kinds to CSS classes matching swift-docc-render's
/// `DecoratedTopicTitle` component:
/// - `keyword`, `attribute`, `text`, `number`, `string` → `decorator`
/// - `identifier`, `typeIdentifier`, `genericParameter`, `externalParam`, `internalParam` → `identifier`
/// - `label` → `label`
///
/// - Parameter tokens: The declaration fragment tokens to render.
/// - Returns: An HTML string containing a `<code class="decorated-title">` element.
func renderDecoratedTitle(_ tokens: [DeclarationRenderSection.Token]) -> String {
    var html = "<code class=\"decorated-title\">"
    for token in tokens {
        let cssClass: String
        switch token.kind {
        case .identifier, .typeIdentifier, .genericParameter, .externalParam, .internalParam:
            cssClass = "identifier"
        case .label:
            cssClass = "label"
        case .keyword, .attribute, .text, .number, .string:
            cssClass = "decorator"
        }
        html += "<span class=\"\(cssClass)\">\(escapeHTML(token.text))</span>"
    }
    html += "</code>"
    return html
}
