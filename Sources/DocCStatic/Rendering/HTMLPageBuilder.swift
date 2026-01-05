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
        <body class="tutorial-overview-page">
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
        <body class="tutorial-page">
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
            html += buildDeclaration(from: renderNode, references: references, depth: depth)
        }

        // Primary content sections (used by symbols, articles)
        for section in renderNode.primaryContentSections {
            html += buildSection(section, references: references, depth: depth)
        }

        // Sections array (used by tutorials and tutorial articles)
        for section in renderNode.sections {
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
        var html = """

                <div class="declaration">
        """

        for declaration in section.declarations {
            html += "\n                <pre><code>"

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
