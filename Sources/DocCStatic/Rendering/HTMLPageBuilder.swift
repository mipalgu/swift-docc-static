//
// HTMLPageBuilder.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import DocCStaticThemes
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
    let contentRenderer: RenderContentHTMLRenderer
}

// MARK: - Shared Class Names

public extension HTMLPageBuilder {
    /// The class of the element that wraps a page's abstract in the hero.
    ///
    /// This mirrors swift-docc-render's `abstract content` wrapper and is also
    /// used to read module abstracts back from generated module pages.
    static let heroAbstractClass = "abstract content"

    /// The class of the sticky "On This Page" navigator column.
    static let onThisPageContainerClass = "OnThisPageStickyContainer"

    /// The identifier of the checkbox that shows or hides the documentation navigator.
    ///
    /// The navigator is shown by default on wide viewports and hidden by default on
    /// narrow ones, where it opens as a full-screen overlay; checking the box toggles
    /// it from its default state.  The navigation bar's toggle and the overlay's close
    /// button are labels for this checkbox, so the navigator works without JavaScript.
    static let sidebarToggleIdentifier = "sidebar-toggle"

    /// The number of parents from which the breadcrumbs always collapse the farthest ones.
    ///
    /// Like swift-docc-render, the breadcrumbs show the root and at most three further
    /// parents; items farther away than this from the current page are listed in the
    /// collapsed menu.  The stylesheet collapses nearer items on narrower viewports.
    static let breadcrumbCollapseLimit = 4

    /// The identifier of the checkbox that opens the navigation bar menu on narrow viewports.
    static let navigationMenuToggleIdentifier = "nav-menu-toggle"

    /// The checkboxes that hold the open or closed state of the page chrome.
    ///
    /// They precede the documentation layout so that the stylesheet can reach the
    /// navigator and the navigation bar menu with sibling selectors.  They are
    /// visually hidden but stay keyboard accessible; the stylesheet draws the focus
    /// ring on their visible labels.
    static var chromeToggles: String {
        """
        <input type="checkbox" id="\(sidebarToggleIdentifier)" class="sidebar-toggle-checkbox visuallyhidden" aria-label="Toggle Documentation Navigator">
            <input type="checkbox" id="\(navigationMenuToggleIdentifier)" class="nav-menu-toggle-checkbox visuallyhidden" aria-label="Toggle Menu">
        """
    }
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
        <body \(ColourSchemeToggle.bodyAttribute)>
            <div id="app">
            <div id="app-top"></div>
            <a href="#app-main" id="skip-nav">Skip Navigation</a>
            \(Self.chromeToggles)
        """

        html += """

            <div class="documentation-layout">
        """

        // Add header bar
        html += buildHeader(depth: depth)

        html += """

            <div class="adjustable-sidebar-width full-width-container topic-wrapper">
        """

        // Add sidebar navigation
        html += buildSidebar(for: renderNode, references: references, depth: depth, moduleName: moduleName)

        // Add main content area
        html += """

                <div class="content">
                <div class="doc-topic">
                <main class="main" id="app-main">
        """

        // Add main content (breadcrumbs are rendered inside the hero section)
        html += buildMainContent(from: renderNode, references: references, depth: depth)

        html += """

                </main>
                </div>
                </div>
            </div>
            </div>
        """

        // Add footer
        html += buildFooter()
        html += "\n    </div>"

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
}

// MARK: - Private Methods

extension HTMLPageBuilder {
    /// Builds the navigation bar at the top of documentation pages.
    ///
    /// The bar mirrors swift-docc-render's `DocumentationNav`: the navigator toggle,
    /// the "Documentation" title linking to the index page, and a menu with the
    /// language setting.  On narrow viewports the menu collapses behind a chevron
    /// that opens it, which works without JavaScript through
    /// ``navigationMenuToggleIdentifier``.
    ///
    /// - Parameter depth: The number of directories between the output root and the page.
    /// - Returns: The `<nav>` element.
    func buildHeader(depth: Int) -> String {
        Self.navigationBarMarkup(depth: depth)
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
        <div class="navigator">
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
        </div>
        """

        return SidebarDocument.containerMarkup(content: html)
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

    /// Builds the breadcrumbs of a page (swift-docc-render's `Hierarchy`).
    ///
    /// The breadcrumbs list the page's ancestors as links, followed by the page's own
    /// title, in the menu item structure swift-docc-render uses.
    ///
    /// - Parameters:
    ///   - renderNode: The render node of the page.
    ///   - references: The references used to resolve the ancestors.
    ///   - depth: The number of directories between the output root and the page.
    /// - Returns: The `<ul>` element, or an empty string if the page has no hierarchy.
    func buildBreadcrumbs(
        for renderNode: RenderNode,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        guard let hierarchy = renderNode.hierarchyVariants.defaultValue else {
            return ""
        }

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

        // The root, then the other parents with their distance from the current page
        let root = firstPath[0]
        let parents = Array(firstPath.dropFirst())
        let currentTitle = extractTitle(from: renderNode)
        func link(_ identifier: String, classes: String) -> String {
            guard let reference = references[identifier] as? TopicRenderReference else {
                return "<span class=\"\(classes)\">\(escapeHTML(identifier))</span>"
            }
            let relativeURL = makeRelativeURL(reference.url, depth: depth)
            return "<a href=\"\(escapeHTML(relativeURL))\" class=\"\(classes) nav-menu-link\">\(escapeHTML(reference.title))</a>"
        }
        func distance(_ index: Int) -> Int {
            min(parents.count - index, Self.breadcrumbCollapseLimit)
        }

        var html = "\n<ul class=\"nav-menu-items hierarchy\" data-parents=\"\(min(parents.count, Self.breadcrumbCollapseLimit))\" aria-label=\"Breadcrumbs\">"
        html += "<li class=\"nav-menu-item hierarchy-item root-hierarchy\">\(link(root, classes: "parent item"))</li>"

        // The menu listing the items that do not fit
        html += "<li class=\"hierarchy-collapsed-items\"><details><summary class=\"toggle\" aria-label=\"Show more\">"
        html += "<span class=\"indicator\"><svg class=\"svg-icon icon-inline toggle-icon\" viewBox=\"0 0 14 14\" aria-hidden=\"true\">"
        html += "<path d=\"m12.439 7.777v-1.554h-1.554v1.554zm-4.662 0v-1.554h-1.554v1.554zm-4.662 0v-1.554h-1.554v1.554z\"/></svg></span>"
        html += "</summary><ul class=\"dropdown\">"
        for (index, identifier) in parents.enumerated() {
            html += "<li class=\"dropdown-item\" data-from-end=\"\(distance(index))\">\(link(identifier, classes: "item"))</li>"
        }
        html += "<li class=\"dropdown-item\" data-from-end=\"0\"><span class=\"current item nav-menu-link\">\(escapeHTML(currentTitle))</span></li>"
        html += "</ul></details></li>"

        for (index, identifier) in parents.enumerated() {
            html += "<li class=\"nav-menu-item hierarchy-item\" data-from-end=\"\(distance(index))\">\(link(identifier, classes: "parent item"))</li>"
        }
        html += "<li class=\"nav-menu-item hierarchy-item\" data-from-end=\"0\"><span class=\"current item\">\(escapeHTML(currentTitle))</span></li>"
        html += "</ul>"
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

    /// Builds the main content of a documentation page.
    ///
    /// The structure mirrors swift-docc-render's `DocumentationTopic`: the hero with
    /// the breadcrumbs, title, abstract and declaration, followed by the content
    /// column with the primary content, the topics, relationships and see also
    /// sections, and the "On This Page" column.
    ///
    /// - Parameters:
    ///   - renderNode: The render node of the page.
    ///   - references: The references used to resolve links.
    ///   - depth: The number of directories between the output root and the page.
    /// - Returns: The HTML placed inside the page's `<main>` element.
    func buildMainContent(
        from renderNode: RenderNode,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = ""

        let title = extractTitle(from: renderNode)
        let roleLabel = roleLabel(for: renderNode)

        // Modules and articles get the enhanced hero with a background and an icon;
        // other symbol pages get a plain hero, like swift-docc-render's
        // `enhanceBackground`.
        let isModule = renderNode.kind == .symbol && renderNode.metadata.symbolKind == "module"
        let isSymbol = renderNode.metadata.symbolKind != nil
        let enhanceBackground = !isSymbol || isModule
        let heroClass = enhanceBackground
            ? "documentation-hero"
            : "documentation-hero documentation-hero--disabled"

        html += "\n<div class=\"\(heroClass)\">"
        html += "<div class=\"icon\">"
        if enhanceBackground {
            let iconType = isModule ? "module" : (renderNode.metadata.role ?? "article")
            html += TopicTypeIcon.markup(for: iconType, additionalClass: "background-icon first-icon")
        }
        html += "</div>"
        html += "<div class=\"documentation-hero__above-content\"></div>"
        html += "\n<div class=\"documentation-hero__content\">"
        html += buildBreadcrumbs(for: renderNode, references: references, depth: depth)
        html += "\n<div class=\"topictitle\"><span class=\"eyebrow\">\(escapeHTML(roleLabel))</span>"
        html += "<h1 class=\"title\">\(escapeHTML(title))</h1></div>"

        if let abstract = renderNode.abstract {
            let abstractHTML = contentRenderer.renderInlineContent(abstract, references: references, depth: depth)
            html += "\n<div class=\"\(Self.heroAbstractClass)\"><p>\(abstractHTML.html)</p></div>"
        }

        if renderNode.kind == .symbol {
            html += buildDeclaration(from: renderNode, references: references, depth: depth)
        }
        html += "\n</div>\n</div>"

        // The content column and the "On This Page" column
        let primarySections = renderNode.primaryContentSections.filter { !($0 is DeclarationsRenderSection) }
        var primaryHTML = ""
        for section in primarySections {
            primaryHTML += buildSection(section, references: references, depth: depth)
        }
        for section in renderNode.sections {
            primaryHTML += buildSection(section, references: references, depth: depth)
        }
        let noPrimaryContent = primaryHTML.isEmpty && enhanceBackground
        html += "\n<div class=\"doc-content-wrapper\">\n<div class=\"doc-content\(noPrimaryContent ? " no-primary-content" : "")\">"
        if !primaryHTML.isEmpty {
            let border = enhanceBackground ? "" : " with-border"
            html += "\n<div class=\"container\">"
            html += "<div class=\"description\(enhanceBackground ? " after-enhanced-hero" : "")\"></div>"
            html += "\n<div class=\"primary-content\(border)\">\(primaryHTML)\n</div>\n</div>"
        }

        if !renderNode.topicSections.isEmpty {
            html += buildContentTable(
                title: "Topics", anchor: "topics", className: "topics",
                body: renderNode.topicSections.map { buildTaskGroup($0, references: references, depth: depth) }.joined()
            )
        }
        if !renderNode.relationshipSections.isEmpty {
            html += buildContentTable(
                title: "Relationships", anchor: "relationships", className: "relationships",
                body: renderNode.relationshipSections.map {
                    buildRelationshipSection($0, references: references, depth: depth)
                }.joined()
            )
        }
        if !renderNode.seeAlsoSections.isEmpty {
            html += buildContentTable(
                title: "See Also", anchor: "see-also", className: "see-also",
                body: renderNode.seeAlsoSections.map { buildTaskGroup($0, references: references, depth: depth) }.joined()
            )
        }

        html += "\n</div>"
        html += buildOnThisPageNav(for: renderNode, title: title)
        html += "\n</div>"

        return html
    }

    /// Builds a content table section such as Topics, Relationships or See Also.
    ///
    /// - Parameters:
    ///   - title: The section title.
    ///   - anchor: The identifier of the section heading.
    ///   - className: An additional class naming the kind of section.
    ///   - body: The HTML of the groups listed in the section.
    /// - Returns: The `<section>` element (swift-docc-render's `ContentTable`).
    func buildContentTable(title: String, anchor: String, className: String, body: String) -> String {
        """

        <section class="contenttable alt-light \(className)">
        <div class="container">
        <h2 id="\(anchor)" class="title">\(RenderContentHTMLRenderer.headerAnchor(anchor: anchor, title: escapeHTML(title)))</h2>\(body)
        </div>
        </section>
        """
    }

    /// Builds the sticky on-this-page navigation sidebar shown to the right of the main content.
    ///
    /// Generates links to major sections present on the current page, matching
    /// swift-docc-render's `OnThisPageStickyContainer` / `OnThisPageNav` components.
    /// The first item (page title) is pre-marked active; when JavaScript is available,
    /// the page script moves the mark to the section in view while scrolling.
    ///
    /// - Parameters:
    ///   - renderNode: The render node for the current page.
    ///   - title: The page title (used as the first nav item label).
    /// - Returns: HTML string for the sticky container, which lists the sections only
    ///   when there are at least two besides the title, or an empty string if the
    ///   theme disables the navigator (``ThemeFeatureFlag/onThisPageNavigatorDisabled``).
    func buildOnThisPageNav(for renderNode: RenderNode, title: String) -> String {
        guard !configuration.theme.isEnabled(.onThisPageNavigatorDisabled) else { return "" }

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
            if let parametersSection = section as? ParametersRenderSection,
               !parametersSection.parameters.isEmpty {
                items.append(NavItem(anchor: "parameters", label: "Parameters", isChild: false))
            } else if let mentionsSection = section as? MentionsRenderSection,
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

        // Like swift-docc-render, the column is always there, but it lists the
        // sections only when the page has at least two besides its title
        var html = "\n<div class=\"\(Self.onThisPageContainerClass)\">"
        if items.count > 2 {
            html += "<nav class=\"OnThisPageNav\" aria-label=\"On This Page\"><ul class=\"items\">"
            for (index, item) in items.enumerated() {
                let activeClass = index == 0 ? " active" : ""
                let itemClass = (item.isChild ? "child-item" : "parent-item") + activeClass
                html += "<li class=\"\(itemClass)\"><a href=\"#\(escapeHTML(item.anchor))\" class=\"base-link\">"
                    + "<span>\(escapeHTML(item.label))</span></a></li>"
            }
            html += "</ul></nav>"
        }
        html += "</div>"
        return html
    }

    /// Returns the role label for a render node (e.g., "Framework", "Structure", "Class").
    func roleLabel(for renderNode: RenderNode) -> String {
        // The role heading is the eyebrow swift-docc-render shows
        if let heading = renderNode.metadata.roleHeading, !heading.isEmpty {
            return heading
        }

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

    /// Builds the declaration of a symbol page, if the page has one.
    ///
    /// - Parameters:
    ///   - renderNode: The render node of the page.
    ///   - references: The references used to link type names.
    ///   - depth: The number of directories between the output root and the page.
    /// - Returns: The declarations container, or an empty string.
    func buildDeclaration(from renderNode: RenderNode, references: [String: any RenderReference], depth: Int) -> String {
        for section in renderNode.primaryContentSections {
            if let declarationSection = section as? DeclarationsRenderSection {
                return buildDeclarationsSection(declarationSection, references: references, depth: depth)
            }
        }
        return ""
    }

    /// Builds the declarations of a symbol (swift-docc-render's `Declaration`).
    ///
    /// Each declaration is a `pre.source` box inside the declaration pill structure of
    /// swift-docc-render.  Swift declarations are formatted like swift-docc-render
    /// does (see ``formattedSwiftTokens(_:)``), and every token is rendered like
    /// swift-docc-render's `DeclarationToken`.
    ///
    /// - Parameters:
    ///   - section: The declarations section.
    ///   - references: The references used to link type names.
    ///   - depth: The number of directories between the output root and the page.
    /// - Returns: The declarations container.
    func buildDeclarationsSection(_ section: DeclarationsRenderSection, references: [String: any RenderReference], depth: Int) -> String {
        var html = "\n<div class=\"declarations-container\"><section class=\"declaration\"><div class=\"declaration-list\">"
        for declaration in section.declarations {
            let isSwift = declaration.languages?.contains("swift") ?? true
            let tokens = isSwift
                ? Self.formattedSwiftTokens(declaration.tokens.map { ($0.kind, $0.text, $0.identifier) })
                : declaration.tokens.map { ($0.kind, $0.text, $0.identifier) }
            let multiline = tokens.contains { $0.text.contains("\n") }
            html += "<div class=\"declaration-pill selected-declaration\"><div class=\"declaration-group-wrapper\"><div class=\"declaration-group\">"
            html += "<pre class=\"source\(multiline ? " displays-multiple-lines" : "")\"><code>"
            for token in tokens {
                html += declarationTokenMarkup(kind: token.kind, text: token.text, identifier: token.identifier, references: references, depth: depth)
            }
            html += "</code></pre></div></div></div>"
        }
        html += "</div></section></div>"
        return html
    }

    /// Renders one declaration token like swift-docc-render's `DeclarationToken`.
    ///
    /// Type names become `type-identifier-link` elements, linked to their page when
    /// the page is documented; plain text stays unmarked; every other token is a span
    /// with the class `token-<kind>`.
    ///
    /// - Parameters:
    ///   - kind: The token kind.
    ///   - text: The token text.
    ///   - identifier: The reference identifier of the token, if any.
    ///   - references: The references used to resolve the identifier.
    ///   - depth: The number of directories between the output root and the page.
    /// - Returns: The token HTML.
    func declarationTokenMarkup(
        kind: DeclarationRenderSection.Token.Kind,
        text: String,
        identifier: String?,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        let escapedText = escapeHTML(text)
        let linkURL = identifier.flatMap { references[$0] as? TopicRenderReference }.map { makeRelativeURL($0.url, depth: depth) }
        switch kind {
        case .text:
            return escapedText
        case .typeIdentifier:
            if let linkURL {
                return "<a href=\"\(escapeHTML(linkURL))\" class=\"type-identifier-link\"><code><span>\(escapedText)</span></code></a>"
            }
            return "<span class=\"type-identifier-link\"><span>\(escapedText)</span></span>"
        case .attribute where linkURL != nil:
            return "<a href=\"\(escapeHTML(linkURL ?? ""))\" class=\"attribute-link\">\(escapedText)</a>"
        default:
            return "<span class=\"\(tokenCSSClass(for: kind) ?? "")\">\(escapedText)</span>"
        }
    }

    /// Returns the class of a declaration token: `token-` followed by the token kind.
    ///
    /// - Parameter kind: The token kind.
    /// - Returns: The class, or `nil` for plain text.
    func tokenCSSClass(for kind: DeclarationRenderSection.Token.Kind) -> String? {
        switch kind {
        case .text:
            return nil
        default:
            return "token-\(kind.rawValue)"
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
                var html = "\n<div class=\"content\"><h2 id=\"discussion\">"
                html += RenderContentHTMLRenderer.headerAnchor(anchor: "discussion", title: "Discussion") + "</h2>"
                for block in contentSection.content {
                    html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
                }
                return html + "\n</div>"
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

    /// Builds a content section of the primary content.
    ///
    /// - Parameters:
    ///   - section: The content section.
    ///   - references: The references used to resolve links.
    ///   - depth: The number of directories between the output root and the page.
    /// - Returns: The blocks of the section in a `.content` wrapper.
    func buildContentSection(
        _ section: ContentRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = "\n<div class=\"content\">"
        for block in section.content {
            html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
        }
        return html + "\n</div>"
    }

    /// Builds the parameters section of a symbol (swift-docc-render's `Parameters`).
    ///
    /// - Parameters:
    ///   - section: The parameters section.
    ///   - references: The references used to resolve links.
    ///   - depth: The number of directories between the output root and the page.
    /// - Returns: The `<section>` element, or an empty string without parameters.
    func buildParametersSection(
        _ section: ParametersRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        guard !section.parameters.isEmpty else { return "" }

        var html = "\n<section class=\"parameters\">"
        html += "<h2 id=\"parameters\">\(RenderContentHTMLRenderer.headerAnchor(anchor: "parameters", title: "Parameters"))</h2><dl>"
        for param in section.parameters {
            html += "\n<dt class=\"param-name\"><code>\(escapeHTML(param.name))</code></dt>"
            html += "<dd class=\"param-content\"><div class=\"content\">"
            for block in param.content {
                html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
            }
            html += "</div></dd>"
        }
        html += "</dl></section>"
        return html
    }

    /// Builds a group of topics in a content table section.
    ///
    /// - Parameters:
    ///   - taskGroup: The group.
    ///   - references: The references of the listed topics.
    ///   - depth: The number of directories between the output root and the page.
    /// - Returns: The `.contenttable-section` element.
    func buildTaskGroup(
        _ taskGroup: TaskGroupRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = "\n<div class=\"contenttable-section\(taskGroup.title == nil ? " no-title" : "")\">"
        if let title = taskGroup.title {
            let anchor = taskGroup.anchor ?? slugify(title)
            html += "<div class=\"section-title\"><h3 id=\"\(escapeHTML(anchor))\" class=\"contenttable-title\">"
            html += RenderContentHTMLRenderer.headerAnchor(anchor: anchor, title: escapeHTML(title))
            html += "</h3></div>"
        }
        html += "<div class=\"section-content\">"
        for identifier in taskGroup.identifiers {
            if let reference = references[identifier] as? TopicRenderReference {
                html += buildSymbolCard(for: reference, depth: depth)
            }
        }
        html += "</div></div>"
        return html
    }

    /// Builds the link block of one topic (swift-docc-render's `TopicsLinkBlock`).
    ///
    /// Articles, collections, tutorials and sample code show an icon, like
    /// swift-docc-render; symbols show their declaration fragments.  Every block
    /// carries the topic type and role in ``TopicTypeIcon/typeAttribute`` and
    /// `data-topic-role`, and a hidden `.topic-kind-badge` with the letters of the
    /// kind, so that a theme can show a kind indicator for every topic.
    ///
    /// - Parameters:
    ///   - reference: The topic reference.
    ///   - depth: The number of directories between the output root and the page.
    /// - Returns: The `.link-block` element.
    func buildSymbolCard(for reference: TopicRenderReference, depth: Int) -> String {
        let relativeURL = makeRelativeURL(reference.url, depth: depth)
        let abstract = contentRenderer.renderInlineContent(reference.abstract, references: [:], depth: 0).plainText
        let role = reference.role ?? reference.kind.rawValue
        let type = TopicTypeIcon.normalisedType(reference.symbolKind?.id ?? role)

        let titleHTML: String
        if let fragments = reference.fragments, !fragments.isEmpty {
            titleHTML = renderDecoratedTitle(fragments)
        } else {
            titleHTML = "<span>\(escapeHTML(reference.title))</span>"
        }

        var html = "\n<div class=\"link-block topic\" \(TopicTypeIcon.typeAttribute)=\"\(escapeHTML(type))\" data-topic-role=\"\(escapeHTML(role))\">"
        html += "<a href=\"\(escapeHTML(relativeURL))\" class=\"link has-adjacent-elements\">"
        if let icon = TopicTypeIcon.topicListIcon(forRole: role) {
            html += "<div class=\"topic-icon-wrapper\">\(icon)</div>"
        }
        let letters = TopicTypeIcon.letters(for: type) ?? ""
        html += "<span class=\"topic-kind-badge\" \(TopicTypeIcon.typeAttribute)=\"\(escapeHTML(type))\" aria-hidden=\"true\">\(escapeHTML(letters))</span>"
        html += titleHTML + "</a>"
        if !abstract.isEmpty {
            html += "<div class=\"abstract\"><div class=\"content\">\(escapeHTML(abstract))</div></div>"
        }
        html += "</div>"
        return html
    }

    /// Builds a group of relationships, such as the protocols a type conforms to.
    ///
    /// Documented types are linked; other types are listed as code, like
    /// swift-docc-render's `RelationshipsList`.
    ///
    /// - Parameters:
    ///   - section: The relationships group.
    ///   - references: The references of the related types.
    ///   - depth: The number of directories between the output root and the page.
    /// - Returns: The `.contenttable-section` element.
    func buildRelationshipSection(
        _ section: RelationshipsRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        let anchor = slugify(section.title)
        var html = "\n<div class=\"contenttable-section\"><div class=\"section-title\">"
        html += "<h3 id=\"\(escapeHTML(anchor))\" class=\"contenttable-title\">"
        html += RenderContentHTMLRenderer.headerAnchor(anchor: anchor, title: escapeHTML(section.title)) + "</h3></div>"
        html += "<div class=\"section-content\"><ul class=\"relationships-list column\">"
        for identifier in section.identifiers {
            if let reference = references[identifier] as? TopicRenderReference {
                let relativeURL = makeRelativeURL(reference.url, depth: depth)
                html += "<li class=\"relationships-item\"><a href=\"\(escapeHTML(relativeURL))\" class=\"link\"><code>\(escapeHTML(reference.title))</code></a></li>"
            } else if let reference = references[identifier] as? UnresolvedRenderReference {
                html += "<li class=\"relationships-item\"><code>\(escapeHTML(reference.title))</code></li>"
            }
        }
        html += "</ul></div></div>"
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

    /// Builds the "Mentioned in" section of a symbol (swift-docc-render's `Mentions`).
    ///
    /// Like swift-docc-render, at most five articles are listed.
    ///
    /// - Parameters:
    ///   - section: The mentions section.
    ///   - references: The references of the mentioning articles.
    ///   - depth: The number of directories between the output root and the page.
    /// - Returns: The `<section>` element, or an empty string without mentions.
    func buildMentionsSection(
        _ section: MentionsRenderSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        guard !section.mentions.isEmpty else {
            return ""
        }
        var html = "\n<section class=\"mentions\">"
        html += "<h2 id=\"mentions\">\(RenderContentHTMLRenderer.headerAnchor(anchor: "mentions", title: "Mentioned in"))</h2>"
        for mentionURL in section.mentions.prefix(5) {
            if let reference = references[mentionURL.absoluteString] as? TopicRenderReference {
                let relativeURL = makeRelativeURL(reference.url, depth: depth)
                let icon = TopicTypeIcon.topicListIcon(forRole: "article") ?? ""
                html += "<div class=\"link-block\"><a href=\"\(escapeHTML(relativeURL))\" class=\"link\">"
                html += "<div class=\"topic-icon-wrapper mention-icon\">\(icon)</div>\(escapeHTML(reference.title))</a></div>"
            }
        }
        html += "</section>"
        return html
    }

    /// Builds the page footer with the custom footer content and the colour scheme toggle.
    ///
    /// - Returns: The footer built by ``ColourSchemeToggle/footerMarkup(content:)``.
    func buildFooter() -> String {
        ColourSchemeToggle.footerMarkup(content: configuration.footerHTML ?? Configuration.defaultFooter)
    }

    /// JavaScript for the colour scheme toggle and the embedded sidebar.
    ///
    /// The script runs ``ColourSchemeToggle/script``, which remembers the reader's
    /// colour scheme and forwards it to the embedded sidebar document, and forwards the
    /// keyboard shortcuts that focus the sidebar filter (`/`, and Command-F or
    /// Control-F while the sidebar is shown) to the embedded sidebar document using
    /// `postMessage`, which also works for pages opened from local files.  Without
    /// JavaScript the toggle still switches the colour scheme of the page.
    var appearanceSelectorScript: String {
        """

            <script>
            \(ColourSchemeToggle.script)
            (function () {
                // Mark the "On This Page" item of the first section in the upper half
                // of the window, like swift-docc-render
                var items = document.querySelectorAll('.OnThisPageNav li');
                if (!items.length || !('IntersectionObserver' in window)) {
                    return;
                }
                var sections = [];
                var visibility = new Map();
                for (var i = 0; i < items.length; i++) {
                    var link = items[i].querySelector('a');
                    var id = link ? decodeURIComponent(link.getAttribute('href').slice(1)) : '';
                    var target = id === 'app-top' ? document.querySelector('.documentation-hero') : document.getElementById(id);
                    if (target && target.parentElement && /^H[1-6]$/.test(target.tagName)) {
                        target = target.parentElement.closest('section, .content') || target;
                    }
                    sections.push(target);
                }
                var nav = document.querySelector('.nav');
                var top = nav ? nav.getBoundingClientRect().height : 0;
                var observer = new IntersectionObserver(function (entries) {
                    entries.forEach(function (entry) {
                        visibility.set(entry.target, entry.intersectionRatio);
                    });
                    for (var j = 0; j < sections.length; j++) {
                        if (sections[j] && visibility.get(sections[j]) > 0) {
                            for (var k = 0; k < items.length; k++) {
                                items[k].classList.toggle('active', k === j);
                            }
                            return;
                        }
                    }
                }, { rootMargin: '-' + top + 'px 0% -50% 0%' });
                sections.forEach(function (section) {
                    if (section) {
                        observer.observe(section);
                    }
                });
            })();
            (function () {
                var focusMessage = '\(SidebarDocument.focusFilterMessage)';
                var frame = document.querySelector('iframe.\(SidebarDocument.frameClass)');
                var toggle = document.getElementById('\(Self.sidebarToggleIdentifier)');
                if (!frame) {
                    return;
                }
                document.addEventListener('keydown', function (e) {
                    var focused = document.activeElement;
                    var editing = focused && (focused.tagName === 'INPUT' && focused.type === 'text' || focused.tagName === 'TEXTAREA' || focused.isContentEditable);
                    var hidden = frame.getClientRects().length === 0 || frame.getBoundingClientRect().width === 0;
                    var slash = e.key === '/' && !editing;
                    var find = (e.metaKey || e.ctrlKey) && e.key === 'f' && !hidden;
                    if (slash || find) {
                        e.preventDefault();
                        if (hidden && toggle) {
                            toggle.checked = !toggle.checked;
                        }
                        frame.focus();
                        frame.contentWindow.postMessage({ type: focusMessage }, '*');
                    }
                });
            })();
            </script>
        """
    }
}

// MARK: - Shared Page Chrome

extension HTMLPageBuilder {
    /// Builds the navigation bar shared by documentation pages and the index page.
    ///
    /// - Parameter depth: The number of directories between the output root and the page.
    /// - Returns: The `<nav>` element (swift-docc-render's `DocumentationNav`).
    static func navigationBarMarkup(depth: Int) -> String {
        let homeURL = String(repeating: "../", count: depth) + "index.html"
        return """

            <nav class="nav documentation-nav nav--fullwidth-border nav--is-wide-format" aria-label="API Reference">
                <div class="nav__wrapper">
                    <div class="nav__background"></div>
                    <div class="nav-content">
                        <div class="pre-title">
                            <div class="sidenav-toggle-wrapper">
                                <label for="\(Self.sidebarToggleIdentifier)" class="sidenav-toggle" aria-hidden="true">
                                    <span class="sidenav-icon-wrapper">
                                        <svg class="sidenav-icon svg-icon" viewBox="0 0 14 14" width="19" height="19" fill="currentColor" aria-hidden="true">
                                            <path d="M6.533 1.867h-6.533v10.267h14v-10.267zM0.933 11.2v-8.4h4.667v8.4zM13.067 11.2h-6.533v-8.4h6.533z"></path>
                                            <path d="M1.867 5.133h2.8v0.933h-2.8z"></path>
                                            <path d="M1.867 7.933h2.8v0.933h-2.8z"></path>
                                        </svg>
                                    </span>
                                </label>
                            </div>
                        </div>
                        <div class="nav-title"><h2 class="nav-title"><a href="\(homeURL)">Documentation</a></h2></div>
                        <div class="nav-menu">
                            <div class="nav-menu-tray">
                                <ul class="nav-menu-items nav-menu-settings">
                                    <li class="nav-menu-item nav-menu-setting language-container nav-menu-item--animated">
                                        <div><span class="nav-menu-setting-label">Language: </span><span class="current-language" aria-current="page">Swift</span></div>
                                    </li>
                                </ul>
                            </div>
                        </div>
                        <div class="nav-actions">
                            <label for="\(Self.navigationMenuToggleIdentifier)" class="nav-menucta" aria-label="Toggle Menu"><span class="nav-menucta-chevron"></span></label>
                        </div>
                    </div>
                </div>
            </nav>
        """
    }
}

// MARK: - Declaration Formatting

extension HTMLPageBuilder {
    /// A declaration token: its kind, its text and the identifier of the page it refers to.
    typealias DeclarationToken = (kind: DeclarationRenderSection.Token.Kind, text: String, identifier: String?)

    /// The indentation swift-docc-render uses for parameters on their own lines.
    static let declarationIndentation = "    "

    /// Formats the tokens of a Swift declaration like swift-docc-render.
    ///
    /// When a function or initialiser has more than one parameter, every parameter is
    /// moved onto its own indented line and the closing parenthesis onto a line of its
    /// own; attributes before the declaration keyword get a line of their own.  This
    /// is the algorithm of swift-docc-render's `DeclarationSource`.
    ///
    /// - Parameter tokens: The declaration tokens.
    /// - Returns: The tokens with line breaks and indentation added to their text.
    static func formattedSwiftTokens(_ tokens: [DeclarationToken]) -> [DeclarationToken] {
        var result: [DeclarationToken] = []
        var indentedParameters = false
        var openParenthesisToken: Int?
        var closeParenthesisToken: Int?
        var closeParenthesisOffset: String.Index?
        var unclosedParentheses = 0
        var firstKeywordToken: Int?

        for (index, token) in tokens.enumerated() {
            var newToken = token
            let previous = index > 0 ? tokens[index - 1] : nil
            let next = index + 1 < tokens.count ? tokens[index + 1] : nil

            if firstKeywordToken == nil && token.kind == .keyword {
                firstKeywordToken = index
            }
            if firstKeywordToken != nil {
                for position in token.text.indices {
                    let character = token.text[position]
                    if character == "(" {
                        unclosedParentheses += 1
                        if openParenthesisToken == nil {
                            openParenthesisToken = index
                        }
                    } else if character == ")" {
                        unclosedParentheses -= 1
                        if openParenthesisToken != nil && closeParenthesisToken == nil && unclosedParentheses == 0 {
                            closeParenthesisToken = index
                            closeParenthesisOffset = position
                            break
                        }
                    }
                }
            }

            // Attributes before the declaration get a line of their own
            if token.kind == .text && unclosedParentheses == 0
                && previous?.kind == .attribute && next?.kind == .keyword {
                newToken.text = token.text.trimmingTrailingWhitespace() + "\n"
            }

            // Every parameter after the first starts a new indented line
            if token.text.hasSuffix(", "), let next, next.kind == .attribute || next.kind == .externalParam {
                newToken.text = token.text.trimmingTrailingWhitespace() + "\n" + declarationIndentation
                indentedParameters = true
            }
            result.append(newToken)
        }

        if indentedParameters, let open = openParenthesisToken {
            result[open].text += "\n" + declarationIndentation
        }
        if indentedParameters, let close = closeParenthesisToken, let offset = closeParenthesisOffset {
            let characters = tokens[close].text.distance(from: tokens[close].text.startIndex, to: offset)
            let text = result[close].text
            let split = text.index(text.startIndex, offsetBy: min(characters, text.count))
            result[close].text = text[..<split] + "\n" + text[split...]
        }
        return result
    }
}

private extension String {
    /// The string without trailing spaces, tabs and line breaks.
    func trimmingTrailingWhitespace() -> String {
        var result = self
        while let last = result.last, last.isWhitespace {
            result.removeLast()
        }
        return result
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
