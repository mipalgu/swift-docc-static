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

    /// The navigator types of the pages in the navigation index, keyed by normalised
    /// page path (see ``SidebarDocument/pagePathKey(_:)``).
    let topicTypes: [String: String]

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

    /// The class of the empty element before the text of the navigation bar title.
    ///
    /// The base stylesheet hides the element; a theme can show an icon in it, for
    /// example as a mask or background image.
    static let navigationTitleIconClass = "header-icon"

    /// The class of the line breaks and indentation that formatting adds to a declaration.
    ///
    /// The line breaks are part of the declaration text, so that the declaration reads
    /// like swift-docc-render's; a theme that shows declarations on a single line can
    /// collapse them (for example with `white-space: normal`).
    static let declarationBreakClass = "declaration-break"

    /// The additional class of a declaration line break after an opening or before a
    /// closing parenthesis, which a single-line declaration leaves out entirely.
    static let declarationParenthesisBreakClass = "declaration-parenthesis-break"

    /// The class of the hidden element in every topic that names the topic's kind.
    ///
    /// The element has no content; it carries the topic type in
    /// ``TopicTypeIcon/typeAttribute`` and, for symbols, the letters of
    /// swift-docc-render's icon in ``TopicTypeIcon/lettersAttribute``, so that a
    /// theme can show a letter badge for every topic.
    static let topicKindBadgeClass = "topic-kind-badge"

    /// The class of the hidden plain title of a topic that shows its declaration.
    ///
    /// A theme that lists topics by name rather than by declaration can show this
    /// element and hide the `.decorated-title`.
    static let topicTitleClass = "topic-title"

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
        self.topicTypes = navigationIndex.map(NavigationSidebarBuilder.rowTypes(in:)) ?? [:]
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

            <link rel="stylesheet" href="\(cssPath)">\(OnThisPageNavigation.headingRules(anchors: onThisPageItems(for: renderNode, title: title).map(\.anchor)))
        </head>
        <body \(ColourSchemeToggle.bodyAttribute)>
            <div id="app">
            <div id="\(OnThisPageNavigation.topAnchor)"></div>
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
    /// title and the ``Badge`` of a deprecated or beta page, in the menu item
    /// structure swift-docc-render uses.
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

        // The badges of the current page; like swift-docc-render, one parent fewer
        // stays visible beside them, so every parent counts one step further away
        let badges = Badge.status(of: renderNode).map(Badge.markup) ?? ""
        let badgeOffset = badges.isEmpty ? 0 : 1
        func link(_ identifier: String, classes: String) -> String {
            guard let reference = references[identifier] as? TopicRenderReference else {
                return "<span class=\"\(classes)\">\(escapeHTML(identifier))</span>"
            }
            let relativeURL = makeRelativeURL(reference.url, depth: depth)
            return "<a href=\"\(escapeHTML(relativeURL))\" class=\"\(classes) nav-menu-link\">\(escapeHTML(reference.title))</a>"
        }
        func distance(_ index: Int) -> Int {
            min(parents.count - index + badgeOffset, Self.breadcrumbCollapseLimit)
        }

        let parentCount = parents.isEmpty ? 0 : min(parents.count + badgeOffset, Self.breadcrumbCollapseLimit)
        let badgeClass = badges.isEmpty ? "" : " has-badge"
        var html = "\n<ul class=\"nav-menu-items hierarchy\(badgeClass)\" data-parents=\"\(parentCount)\" aria-label=\"Breadcrumbs\">"
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
        html += "<li class=\"nav-menu-item hierarchy-item\" data-from-end=\"0\"><span class=\"current item\">\(escapeHTML(currentTitle))</span>\(badges)</li>"
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
        // Like swift-docc-render, symbol titles break at readable places and the title
        // of a deprecated or beta symbol is followed by a tag
        let status = Badge.status(of: renderNode)
        let titleText = enhanceBackground ? escapeHTML(title) : WordBreak.markup(title)
        html += buildBreadcrumbs(for: renderNode, references: references, depth: depth)
        html += "\n<div class=\"topictitle\"><span class=\"eyebrow\">\(escapeHTML(roleLabel))</span>"
        html += "<h1 class=\"title\"><span>\(titleText)</span>\(status.map(Badge.titleTag) ?? "")</h1></div>"

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
        let deprecationSummary = renderNode.deprecationSummary ?? []
        let noPrimaryContent = primaryHTML.isEmpty && deprecationSummary.isEmpty && enhanceBackground
        let onThisPage = onThisPageItems(for: renderNode, title: title)
        let scope = onThisPage.isEmpty ? "" : " style=\"\(OnThisPageNavigation.timelineScope(count: onThisPage.count))\""
        html += "\n<div class=\"doc-content-wrapper\"\(scope)>\n<div class=\"doc-content\(noPrimaryContent ? " no-primary-content" : "")\">"
        if !primaryHTML.isEmpty || !deprecationSummary.isEmpty {
            let border = enhanceBackground ? "" : " with-border"
            html += "\n<div class=\"container\">"
            html += "<div class=\"description\(enhanceBackground ? " after-enhanced-hero" : "")\">"
            html += buildDeprecationSummary(deprecationSummary, references: references, depth: depth) + "</div>"
            if !primaryHTML.isEmpty {
                html += "\n<div class=\"primary-content\(border)\">\(primaryHTML)\n</div>"
            }
            html += "\n</div>"
        }

        if !renderNode.topicSections.isEmpty {
            html += buildContentTable(
                title: "Topics", anchor: "topics", className: "topics",
                body: renderNode.topicSections.map {
                    buildTaskGroup($0, references: references, depth: depth, pageStatuses: Badge.statuses(of: renderNode))
                }.joined()
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
                body: renderNode.seeAlsoSections.map {
                    buildTaskGroup($0, references: references, depth: depth, pageStatuses: Badge.statuses(of: renderNode))
                }.joined()
            )
        }

        html += "\n</div>"
        html += buildOnThisPageNav(items: onThisPage)
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

    /// An entry of the "On This Page" column.
    struct OnThisPageItem {
        /// The identifier of the section heading the entry links to.
        let anchor: String

        /// The text of the entry.
        let label: String

        /// Whether the entry is a subsection (a level 3 heading) rather than a section.
        let isChild: Bool

        /// Whether the entry is the title of a symbol, which gets ``WordBreak``
        /// opportunities like swift-docc-render.
        var isSymbol = false
    }

    /// Returns the entries of the "On This Page" column of a page.
    ///
    /// The entries are the page title, followed by the parameters, mentions, level 2
    /// and level 3 content headings, and the Topics, Relationships and See Also
    /// sections, like swift-docc-render's `OnThisPageNav`.
    ///
    /// - Parameters:
    ///   - renderNode: The render node for the current page.
    ///   - title: The page title (used as the first entry).
    /// - Returns: The entries, or an empty array if the column lists no sections: when
    ///   the page has fewer than two besides its title, or the theme disables the
    ///   navigator (``ThemeFeatureFlag/onThisPageNavigatorDisabled``).
    func onThisPageItems(for renderNode: RenderNode, title: String) -> [OnThisPageItem] {
        guard !configuration.theme.isEnabled(.onThisPageNavigatorDisabled) else { return [] }
        var items = [OnThisPageItem(
            anchor: OnThisPageNavigation.topAnchor, label: title, isChild: false, isSymbol: renderNode.kind == .symbol
        )]
        for section in renderNode.primaryContentSections {
            if let parametersSection = section as? ParametersRenderSection,
               !parametersSection.parameters.isEmpty {
                items.append(OnThisPageItem(anchor: "parameters", label: "Parameters", isChild: false))
            } else if let mentionsSection = section as? MentionsRenderSection,
               !mentionsSection.mentions.isEmpty {
                items.append(OnThisPageItem(anchor: "mentions", label: "Mentioned in", isChild: false))
            } else if let contentSection = section as? ContentRenderSection {
                for block in contentSection.content {
                    if case .heading(let heading) = block, heading.level == 2 || heading.level == 3 {
                        let anchor = heading.anchor ?? slugify(heading.text)
                        items.append(OnThisPageItem(anchor: anchor, label: heading.text, isChild: heading.level == 3))
                    }
                }
            }
        }
        if !renderNode.topicSections.isEmpty {
            items.append(OnThisPageItem(anchor: "topics", label: "Topics", isChild: false))
        }
        if !renderNode.relationshipSections.isEmpty {
            items.append(OnThisPageItem(anchor: "relationships", label: "Relationships", isChild: false))
        }
        if !renderNode.seeAlsoSections.isEmpty {
            items.append(OnThisPageItem(anchor: "see-also", label: "See Also", isChild: false))
        }
        return items.count > 2 ? items : []
    }

    /// Builds the sticky "On This Page" column shown to the right of the main content.
    ///
    /// The column matches swift-docc-render's `OnThisPageStickyContainer` and
    /// `OnThisPageNav` components.  Each item names the view timelines it follows (see
    /// ``OnThisPageNavigation``), so that the highlight follows the section in view
    /// without JavaScript.  The first item is marked active for browsers without
    /// scroll-driven animations, where the page script moves the mark if it runs.
    ///
    /// - Parameter items: The entries from ``onThisPageItems(for:title:)``.
    /// - Returns: HTML for the sticky container, which lists the entries if there are
    ///   any, or an empty string if the theme disables the navigator.
    func buildOnThisPageNav(items: [OnThisPageItem]) -> String {
        guard !configuration.theme.isEnabled(.onThisPageNavigatorDisabled) else { return "" }
        // Like swift-docc-render, the column is always there, but it lists the
        // sections only when the page has at least two besides its title
        var html = "\n<div class=\"\(Self.onThisPageContainerClass)\">"
        if !items.isEmpty {
            html += "<nav class=\"\(OnThisPageNavigation.navigationClass)\" aria-label=\"On This Page\"><ul class=\"items\">"
            for (index, item) in items.enumerated() {
                let activeClass = index == 0 ? " active" : ""
                let itemClass = (item.isChild ? "child-item" : "parent-item") + activeClass
                let timelines = OnThisPageNavigation.itemTimelines(index: index, count: items.count)
                html += "<li class=\"\(itemClass)\" style=\"\(timelines)\"><a href=\"#\(escapeHTML(item.anchor))\" class=\"base-link\">"
                    + "<span>\(item.isSymbol ? WordBreak.markup(item.label) : escapeHTML(item.label))</span></a></li>"
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
    /// the page is documented; like linked attributes, they get ``WordBreak``
    /// opportunities.  Plain text stays unmarked apart from its line breaks (see
    /// ``markingLineBreaks(in:)``); every other token is a span with the class
    /// `token-<kind>`.
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
            return Self.markingLineBreaks(in: text)
        case .typeIdentifier:
            let brokenText = WordBreak.markup(text)
            if let linkURL {
                return "<a href=\"\(escapeHTML(linkURL))\" class=\"type-identifier-link\"><code><span>\(brokenText)</span></code></a>"
            }
            return "<span class=\"type-identifier-link\"><span>\(brokenText)</span></span>"
        case .attribute where linkURL != nil:
            return "<a href=\"\(escapeHTML(linkURL ?? ""))\" class=\"attribute-link\"><span>\(WordBreak.markup(text))</span></a>"
        default:
            return "<span class=\"\(tokenCSSClass(for: kind) ?? "")\">\(escapedText)</span>"
        }
    }

    /// Escapes the plain text of a declaration and marks its line breaks.
    ///
    /// Every line break and the indentation after it becomes an element with the class
    /// ``declarationBreakClass``; a break directly after an opening or before a closing
    /// parenthesis also gets ``declarationParenthesisBreakClass``.
    ///
    /// - Parameter text: The text of a plain text token.
    /// - Returns: The escaped text with its line breaks marked.
    static func markingLineBreaks(in text: String) -> String {
        guard text.contains("\n") else { return escapeHTML(text) }
        var html = ""
        var remainder = Substring(text)
        while let newline = remainder.firstIndex(of: "\n") {
            let before = remainder[..<newline]
            let afterNewline = remainder[remainder.index(after: newline)...]
            let indentation = afterNewline.prefix { $0 == " " }
            let after = afterNewline.dropFirst(indentation.count)
            let besideParenthesis = before.last == "(" || after.first == ")"
            let classes = besideParenthesis
                ? "\(declarationBreakClass) \(declarationParenthesisBreakClass)" : declarationBreakClass
            html += escapeHTML(String(before)) + "<span class=\"\(classes)\">\n\(indentation)</span>"
            remainder = after
        }
        return html + escapeHTML(String(remainder))
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

    /// Builds the deprecation summary of a symbol (swift-docc-render's deprecated `Aside`).
    ///
    /// - Parameters:
    ///   - summary: The blocks of the deprecation summary.
    ///   - references: The references used to resolve links.
    ///   - depth: The number of directories between the output root and the page.
    /// - Returns: The `aside.deprecated` element, or an empty string without a summary.
    func buildDeprecationSummary(
        _ summary: [RenderBlockContent],
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        guard !summary.isEmpty else { return "" }
        let kind = Badge.Variant.deprecated
        var html = "<aside class=\"\(kind.rawValue)\" aria-label=\"\(kind.rawValue)\"><p class=\"label\">\(kind.label)</p>"
        html += "<div class=\"content\">"
        for block in summary {
            html += contentRenderer.renderBlockContent(block, references: references, depth: depth)
        }
        return html + "</div></aside>"
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
    ///   - pageStatuses: The statuses of the page that lists the topics.
    /// - Returns: The `.contenttable-section` element.
    func buildTaskGroup(
        _ taskGroup: TaskGroupRenderSection,
        references: [String: any RenderReference],
        depth: Int,
        pageStatuses: Set<Badge.Variant> = []
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
                html += buildSymbolCard(for: reference, references: references, depth: depth, pageStatuses: pageStatuses)
            }
        }
        html += "</div></div>"
        return html
    }

    /// Builds the link block of one topic (swift-docc-render's `TopicsLinkBlock`).
    ///
    /// Articles, collections, tutorials and sample code show an icon, like
    /// swift-docc-render; symbols show their declaration fragments, followed by their
    /// plain title in a hidden ``topicTitleClass`` element.  Every block carries the
    /// topic type (the page's navigator type, or the declaration keyword before the
    /// symbol's name) and role in ``TopicTypeIcon/typeAttribute`` and
    /// `data-topic-role`, and a hidden ``topicKindBadgeClass`` element with the type
    /// and its letters, so that a theme can show a kind indicator for every topic.
    ///
    /// Like swift-docc-render, a topic with an abstract has its link padded
    /// (`has-adjacent-elements`), while a topic without one shows its badge on the
    /// same line (`has-inline-element`).  A deprecated topic is struck through and,
    /// unless the listing page is deprecated itself, followed by a ``Badge``; so is a
    /// beta topic on a page that is not beta.
    ///
    /// - Parameters:
    ///   - reference: The topic reference.
    ///   - references: The references used to resolve links in the abstract.
    ///   - depth: The number of directories between the output root and the page.
    ///   - pageStatuses: The statuses of the page that lists the topic.
    /// - Returns: The `.link-block` element.
    func buildSymbolCard(
        for reference: TopicRenderReference,
        references: [String: any RenderReference] = [:],
        depth: Int,
        pageStatuses: Set<Badge.Variant> = []
    ) -> String {
        let relativeURL = makeRelativeURL(reference.url, depth: depth)
        let abstract = contentRenderer.renderInlineContent(reference.abstract, references: references, depth: depth).html
        let role = reference.role ?? reference.kind.rawValue
        let navigatorType = topicTypes[SidebarDocument.pagePathKey(reference.url)]
        let type = TopicTypeIcon.normalisedType(navigatorType ?? Self.declarationKeyword(in: reference.fragments) ?? role)

        let titleHTML: String
        if let fragments = reference.fragments, !fragments.isEmpty {
            titleHTML = renderDecoratedTitle(fragments)
                + "<span class=\"\(Self.topicTitleClass)\">\(WordBreak.markup(reference.title))</span>"
        } else {
            let tag = reference.kind == .symbol && !Self.plainTitleRoles.contains(role) ? "code" : "span"
            titleHTML = "<\(tag)>\(WordBreak.markup(reference.title))</\(tag)>"
        }

        let badge = Badge.topicMarkup(for: reference, pageStatuses: pageStatuses)
        let blockClass = abstract.isEmpty ? " has-inline-element" : ""
        var linkClasses = abstract.isEmpty ? "link" : "link has-adjacent-elements"
        if reference.isDeprecated {
            linkClasses += " deprecated"
        }
        var html = "\n<div class=\"link-block topic\(blockClass)\" \(TopicTypeIcon.typeAttribute)=\"\(escapeHTML(type))\" data-topic-role=\"\(escapeHTML(role))\">"
        html += "<a href=\"\(escapeHTML(relativeURL))\" class=\"\(linkClasses)\">"
        if let icon = TopicTypeIcon.topicListIcon(forRole: role) {
            html += "<div class=\"topic-icon-wrapper\">\(icon)</div>"
        }
        let letters = TopicTypeIcon.letters(for: type).map { " \(TopicTypeIcon.lettersAttribute)=\"\(escapeHTML($0))\"" } ?? ""
        html += "<span class=\"\(Self.topicKindBadgeClass)\" \(TopicTypeIcon.typeAttribute)=\"\(escapeHTML(type))\"\(letters) aria-hidden=\"true\"></span>"
        html += titleHTML + "</a>"
        if !abstract.isEmpty {
            html += "<div class=\"abstract\"><div class=\"content\">\(abstract)</div></div>"
        }
        html += badge + "</div>"
        return html
    }

    /// Returns the declaration keyword that names the kind of a symbol.
    ///
    /// This is the last keyword before the symbol's name, which skips modifiers such
    /// as `static` or `class`; without a name, as for initialisers, it is the last
    /// keyword of the declaration.
    ///
    /// - Parameter fragments: The declaration fragments of the symbol.
    /// - Returns: The keyword, or `nil` if the fragments contain none.
    static func declarationKeyword(in fragments: [DeclarationRenderSection.Token]?) -> String? {
        guard let fragments else { return nil }
        let beforeName = fragments.prefix { $0.kind != .identifier }
        return beforeName.last { $0.kind == .keyword }?.text
    }

    /// The largest number of related types that swift-docc-render lists on one line.
    static let maximumInlineRelationships = 3

    /// The roles of topics whose titles show as plain text rather than code in topic
    /// lists, like swift-docc-render's `TopicsLinkBlock`.
    static let plainTitleRoles: Set<String> = ["collection", "dictionarySymbol"]

    /// Builds a group of relationships, such as the protocols a type conforms to.
    ///
    /// Documented types are linked; other types are listed as code, like
    /// swift-docc-render's `RelationshipsList`.  Up to
    /// ``maximumInlineRelationships`` types without availability constraints are
    /// listed on one line, separated by commas; longer lists have one type per line.
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
        var items: [String] = []
        var hasConstraints = false
        for identifier in section.identifiers {
            if let reference = references[identifier] as? TopicRenderReference {
                let relativeURL = makeRelativeURL(reference.url, depth: depth)
                hasConstraints = hasConstraints || reference.conformance != nil
                items.append("<li class=\"relationships-item\"><a href=\"\(escapeHTML(relativeURL))\" class=\"link\"><code>\(WordBreak.markup(reference.title))</code></a></li>")
            } else if let reference = references[identifier] as? UnresolvedRenderReference {
                items.append("<li class=\"relationships-item\"><code>\(WordBreak.markup(reference.title))</code></li>")
            }
        }
        let layout = items.count <= Self.maximumInlineRelationships && !hasConstraints ? "inline" : "column"
        html += "<div class=\"section-content\"><ul class=\"relationships-list \(layout)\">" + items.joined()
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
    /// JavaScript the toggle still switches the colour scheme of the page.  In browsers
    /// without scroll-driven animations, the script also marks the "On This Page" item
    /// of the section in view (see ``OnThisPageNavigation``).
    var appearanceSelectorScript: String {
        """

            <script>
            \(ColourSchemeToggle.script)
            (function () {
                // Without scroll-driven animations, mark the "On This Page" item of the
                // section in view like swift-docc-render: the first item at the top, the
                // last item at the bottom, otherwise the last item whose heading has
                // passed the tracking line
                if (window.CSS && CSS.supports('animation-timeline: view()')) {
                    return;
                }
                var items = document.querySelectorAll('.\(OnThisPageNavigation.navigationClass) li');
                if (!items.length) {
                    return;
                }
                var headings = [];
                for (var i = 0; i < items.length; i++) {
                    var link = items[i].querySelector('a');
                    headings.push(link ? document.getElementById(decodeURIComponent(link.hash.slice(1))) : null);
                }
                var scheduled = false;
                function update() {
                    scheduled = false;
                    var root = document.documentElement;
                    var current = 0;
                    if (window.scrollY + window.innerHeight >= root.scrollHeight && window.scrollY > 0) {
                        current = items.length - 1;
                    } else if (window.scrollY > 0) {
                        var line = window.scrollY + window.innerHeight * \(Double(OnThisPageNavigation.trackingLinePercentage) / 100);
                        for (var j = 0; j < headings.length; j++) {
                            if (headings[j] && headings[j].getBoundingClientRect().top + window.scrollY < line) {
                                current = j;
                            }
                        }
                    }
                    for (var k = 0; k < items.length; k++) {
                        items[k].classList.toggle('active', k === current);
                    }
                }
                window.addEventListener('scroll', function () {
                    if (!scheduled) {
                        scheduled = true;
                        window.requestAnimationFrame(update);
                    }
                }, { passive: true });
                update();
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
                        <div class="nav-title"><h2 class="nav-title"><a href="\(homeURL)"><span class="\(Self.navigationTitleIconClass)" aria-hidden="true"></span>Documentation</a></h2></div>
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
/// Like swift-docc-render, every token is followed by a word break opportunity and
/// the text of every token that is not only white space gets ``WordBreak``
/// opportunities; a token that is a single space carries the class `empty-token`.
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
        let isWhiteSpace = token.text.allSatisfy(\.isWhitespace)
        let text = isWhiteSpace ? escapeHTML(token.text) : WordBreak.markup(token.text)
        let classes = token.text == " " ? "\(cssClass) empty-token" : cssClass
        html += "<span class=\"\(classes)\">\(text)</span>" + WordBreak.opportunity
    }
    html += "</code>"
    return html
}
