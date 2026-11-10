//
// NavigationSidebarBuilder.swift
// DocCStatic
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// Builds the navigation sidebar HTML from a navigation index.
///
/// The builder renders the complete navigation tree of all documented modules once,
/// as the shared sidebar document described by ``SidebarDocument``.  The tree has:
/// - Disclosure chevrons for expandable items (pure CSS, no JavaScript)
/// - A stable `id` on every row, derived from the row's documentation path, so that
///   the page embedding the document can select its row with a URL fragment
/// - Proper icons/badges for different symbol types
/// - Flat list structure (matches swift-docc-render architecture)
///
/// The shared document carries no per-page state: highlighting the current page and
/// expanding its ancestors is done by the stylesheet through the `:target` pseudo-class.
///
/// ## Architecture
///
/// The builder generates a flat list where items are siblings in a single `<ul>`, and
/// the children of an item follow it in a `.nav-children-wrapper` list item.  Visual
/// hierarchy is achieved through CSS using the `--nesting-index` custom property for
/// indentation.
///
/// Group markers (e.g., "Initializers", "Instance Methods") are regular `<li>` items
/// with the `.is-group` class, rendered at `depth + 1` relative to their parent.
///
/// This matches the swift-docc-render Vue.js implementation where items are flattened
/// during rendering with depth-based indentation.
public struct NavigationSidebarBuilder: Sendable {
    /// The navigation index.
    private let navigationIndex: NavigationIndex

    /// Counter for generating unique checkbox IDs.
    private var checkboxCounter: Int = 0

    /// The normalised paths that have already been given a row identifier.
    private var identifiedPaths: Set<String> = []
}

// MARK: - Public
public extension NavigationSidebarBuilder {
    /// Creates a new navigation sidebar builder.
    ///
    /// - Parameter navigationIndex: The navigation index to build from.
    init(navigationIndex: NavigationIndex) {
        self.navigationIndex = navigationIndex
    }

    /// Builds the standalone sidebar document shared by all documentation pages.
    ///
    /// The document contains the navigation tree of every module with links relative
    /// to the output root, the filter field, and the scripts that enhance it when
    /// JavaScript is available.  Its `<base target="_top">` makes every link, including
    /// links created by scripts, navigate the window that embeds the document.
    ///
    /// - Parameter includeSearch: Whether to load the client-side search scripts that
    ///   add content matches below the tree while filtering.
    /// - Returns: The complete HTML document.
    mutating func buildSidebarDocument(includeSearch: Bool) -> String {
        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta name="robots" content="noindex">
            <title>\(escapeHTML(SidebarDocument.frameTitle))</title>
            <base target="_top">
            <link rel="stylesheet" href="css/main.css">
        </head>
        <body class="\(SidebarDocument.documentClass)" data-color-scheme="auto">
        """
        html += buildNavigationTree()
        if includeSearch {
            html += """

                <script src="js/lunr.min.js" defer></script>
                <script src="js/search.js" defer></script>
            """
        }
        html += """

            <script>\(Self.sidebarScript)</script>
        </body>
        </html>

        """
        return html
    }

    /// Builds the navigation tree with its filter field.
    ///
    /// Links are relative to the output root.  Every row representing a page carries
    /// the identifier returned by ``SidebarDocument/rowIdentifier(forPath:)``; if a
    /// page is listed more than once, only its first row carries the identifier.
    ///
    /// - Returns: The tree inside a `.sidebar` container, or an empty sidebar
    ///   structure if the index contains no modules.
    mutating func buildNavigationTree() -> String {
        let allModules = navigationIndex.allModules()
        var html = """

            <div class="sidebar">
                <div class="sidebar-content">
        """
        if allModules.count > 1 {
            for moduleNode in allModules {
                html += buildModuleSection(moduleNode)
            }
        } else if let moduleNode = allModules.first {
            html += buildSingleModuleTree(moduleNode)
        }
        html += """

                </div>
        \(Self.filterMarkup)
            </div>
        """
        return html
    }

    /// Builds the inline sidebar used when no navigation tree is available.
    ///
    /// - Returns: An empty sidebar container with a filter field.
    static func buildFallbackSidebar() -> String {
        """

                <nav class="sidebar">
                    <div class="sidebar-content">
                    </div>
        \(filterMarkup)
                </nav>
        """
    }

    /// Returns the normalised paths of all rows that carry an identifier.
    ///
    /// The result contains the path of every module and of every listed page in the
    /// tree built by ``buildNavigationTree()``, normalised with
    /// ``SidebarDocument/pagePathKey(_:)``.
    ///
    /// - Parameter navigationIndex: The navigation index.
    /// - Returns: The set of normalised row paths.
    static func rowPaths(in navigationIndex: NavigationIndex) -> Set<String> {
        var paths: Set<String> = []
        func collect(_ node: NavigationNode) {
            if !node.isGroupMarker, let path = node.path {
                paths.insert(SidebarDocument.pagePathKey(path))
            }
            node.children?.forEach(collect)
        }
        navigationIndex.allModules().forEach(collect)
        return paths
    }

    /// The script that enhances the shared sidebar document when JavaScript is available.
    ///
    /// The script applies the reader's colour scheme (from local storage and from
    /// messages posted by the embedding page), marks the target row as the current
    /// page for assistive technologies, reveals the filter field and filters the tree
    /// by title, and focuses the filter on request of the embedding page or when `/`
    /// is pressed.
    static var sidebarScript: String {
        """

            (function () {
                'use strict';
                var storageKey = '\(SidebarDocument.colourSchemeStorageKey)';
                var schemeMessage = '\(SidebarDocument.colourSchemeMessage)';
                var focusMessage = '\(SidebarDocument.focusFilterMessage)';
                var readyMessage = '\(SidebarDocument.readyMessage)';
                var schemes = ['light', 'dark', 'auto'];
                var body = document.body;

                function applyScheme(scheme) {
                    if (schemes.indexOf(scheme) !== -1) {
                        body.setAttribute('data-color-scheme', scheme);
                    }
                }

                try {
                    applyScheme(window.localStorage.getItem(storageKey) || 'auto');
                } catch (error) {
                    // Storage may be unavailable, for example for local files.
                }

                window.addEventListener('storage', function (event) {
                    if (event.key === storageKey) {
                        applyScheme(event.newValue || 'auto');
                    }
                });

                var filterBox = document.getElementById('sidebar-filter');
                var input = filterBox ? filterBox.querySelector('.filter-input') : null;
                var content = document.querySelector('.sidebar-content');

                function focusFilter() {
                    if (input) {
                        input.focus();
                        input.select();
                    }
                }

                window.addEventListener('message', function (event) {
                    var data = event.data;
                    if (event.source !== window.parent || !data || typeof data !== 'object') {
                        return;
                    }
                    if (data.type === schemeMessage) {
                        applyScheme(data.scheme);
                    } else if (data.type === focusMessage) {
                        focusFilter();
                    }
                });

                if (window.parent !== window) {
                    window.parent.postMessage({ type: readyMessage }, '*');
                }

                function markCurrentPage() {
                    var marked = document.querySelectorAll('[aria-current]');
                    for (var i = 0; i < marked.length; i++) {
                        marked[i].removeAttribute('aria-current');
                    }
                    var target = document.querySelector(':target');
                    var link = target ? (target.tagName === 'A' ? target : target.querySelector('a')) : null;
                    if (link) {
                        link.setAttribute('aria-current', 'page');
                    }
                }

                markCurrentPage();
                window.addEventListener('hashchange', markCurrentPage);

                if (!filterBox || !input || !content) {
                    return;
                }

                filterBox.style.display = 'flex';

                var rows = content.querySelectorAll('.navigator-card');
                var wrappers = content.querySelectorAll('.nav-children-wrapper');
                var sections = content.querySelectorAll('.module-section');

                function reset(elements) {
                    for (var i = 0; i < elements.length; i++) {
                        elements[i].classList.remove('filter-hidden', 'filter-match', 'filter-open');
                    }
                }

                function hideAllBut(elements, shown) {
                    for (var i = 0; i < elements.length; i++) {
                        if (!shown.has(elements[i])) {
                            elements[i].classList.add('filter-hidden');
                        }
                    }
                }

                function matches(element, needle) {
                    return element !== null && element.textContent.toLowerCase().indexOf(needle) !== -1;
                }

                function applyFilter(query) {
                    var needle = query.trim().toLowerCase();
                    reset(rows);
                    reset(wrappers);
                    reset(sections);
                    content.classList.toggle('filtering', needle !== '');
                    if (!needle) {
                        return;
                    }
                    var shown = new Set();
                    for (var i = 0; i < rows.length; i++) {
                        var row = rows[i];
                        if (row.classList.contains('is-group') || !matches(row.querySelector('a'), needle)) {
                            continue;
                        }
                        row.classList.add('filter-match');
                        shown.add(row);
                        for (var node = row.parentElement; node && node !== content; node = node.parentElement) {
                            if (node.classList.contains('nav-children-wrapper')) {
                                node.classList.add('filter-open');
                                shown.add(node);
                                if (node.previousElementSibling) {
                                    shown.add(node.previousElementSibling);
                                }
                            } else if (node.classList.contains('module-section')) {
                                node.classList.add('filter-open');
                                shown.add(node);
                            }
                        }
                    }
                    for (var j = 0; j < sections.length; j++) {
                        if (matches(sections[j].querySelector('.card-link'), needle)) {
                            shown.add(sections[j]);
                        }
                    }
                    hideAllBut(rows, shown);
                    hideAllBut(wrappers, shown);
                    hideAllBut(sections, shown);
                }

                var timer = null;
                input.addEventListener('input', function () {
                    clearTimeout(timer);
                    timer = setTimeout(function () {
                        applyFilter(input.value);
                    }, 100);
                });

                input.addEventListener('keydown', function (event) {
                    if (event.key === 'Escape') {
                        input.value = '';
                        input.dispatchEvent(new Event('input'));
                        input.blur();
                    }
                });

                document.addEventListener('keydown', function (event) {
                    var focused = document.activeElement;
                    var editing = focused && (focused.tagName === 'INPUT' || focused.tagName === 'TEXTAREA' || focused.isContentEditable);
                    if (event.key === '/' && !editing) {
                        event.preventDefault();
                        focusFilter();
                    }
                });
            })();

        """
    }
}

// MARK: - Private
private extension NavigationSidebarBuilder {
    /// The filter field shown at the bottom of the sidebar when JavaScript is available.
    static let filterMarkup = """
                <div class="sidebar-filter" id="sidebar-filter">
                    <span class="filter-icon">
                        <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor">
                            <path d="M0 1.5A1.5 1.5 0 011.5 0h11A1.5 1.5 0 0114 1.5v1.75a1.5 1.5 0 01-.44 1.06L9 8.871V13.5a.5.5 0 01-.757.429l-3-1.8A.5.5 0 015 11.7V8.871L.44 4.31A1.5 1.5 0 010 3.25V1.5z"/>
                        </svg>
                    </span>
                    <input type="text" placeholder="Filter" class="filter-input" aria-label="Filter navigation">
                    <span class="filter-shortcut">/</span>
                </div>
    """

    /// The chevron drawn by disclosure labels.
    static let chevronSVG = """
    <svg viewBox="0 0 10 10" fill="currentColor"><path d="M3 1.5L7 5L3 8.5" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>
    """

    /// Builds a module section in the multi-module sidebar.
    ///
    /// Every module starts collapsed; the stylesheet expands the module that contains
    /// the target row.
    ///
    /// - Parameter moduleNode: The module's navigation node.
    /// - Returns: The HTML for the module section.
    mutating func buildModuleSection(_ moduleNode: NavigationNode) -> String {
        let checkboxId = nextCheckboxId()
        let relativeURL = makeRelativeURL(moduleNode.path ?? "")
        let title = escapeHTML(moduleNode.title)

        var html = """

                    <div class="sidebar-section module-section">
                        <input type="checkbox" id="\(checkboxId)" class="disclosure-checkbox">
                        <div class="module-header"\(identifierAttribute(for: moduleNode))>
                            <a href="\(escapeHTML(relativeURL))" class="technology-title">
                                <h2 class="card-link">\(title)</h2>
                                <label for="\(checkboxId)" class="disclosure-chevron" aria-label="Toggle \(title)">\(Self.chevronSVG)</label>
                            </a>
                        </div>
        """

        if let children = moduleNode.children {
            html += "\n<ul class=\"sidebar-list module-contents\">"
            html += buildFlatNavigationList(children, nestingLevel: 0)
            html += "\n</ul>"
        }

        html += """

                    </div>
        """
        return html
    }

    /// Builds the tree of the only module of a single-module sidebar.
    ///
    /// - Parameter moduleNode: The module's navigation node.
    /// - Returns: The HTML for the module title and its tree.
    mutating func buildSingleModuleTree(_ moduleNode: NavigationNode) -> String {
        let relativeURL = makeRelativeURL(moduleNode.path ?? "")
        var html = """

                    <a href="\(escapeHTML(relativeURL))" class="technology-title"\(identifierAttribute(for: moduleNode))>
                        <h2 class="card-link">\(escapeHTML(moduleNode.title))</h2>
                    </a>
        """

        if let children = moduleNode.children {
            html += "\n<ul class=\"sidebar-list\">"
            html += buildFlatNavigationList(children, nestingLevel: 0)
            html += "\n</ul>"
        }
        return html
    }

    /// Builds a flat navigation list where all items are siblings.
    ///
    /// This method recursively flattens the navigation tree into a single list,
    /// using `--nesting-index` for visual hierarchy via CSS indentation.
    /// Children are wrapped in a `.nav-children-wrapper` list item for CSS-based disclosure.
    ///
    /// - Parameters:
    ///   - nodes: The navigation nodes to render.
    ///   - nestingLevel: The nesting level for indentation (matches docc-render's `depth`).
    /// - Returns: HTML string with flat list items.
    mutating func buildFlatNavigationList(_ nodes: [NavigationNode], nestingLevel: Int) -> String {
        var html = ""
        var i = 0

        while i < nodes.count {
            let node = nodes[i]

            if node.isGroupMarker {
                // Collect all items in this group
                var groupChildren: [NavigationNode] = []
                var j = i + 1
                while j < nodes.count && !nodes[j].isGroupMarker {
                    groupChildren.append(nodes[j])
                    j += 1
                }

                html += buildGroupMarkerItemWithChildren(
                    node,
                    children: groupChildren,
                    nestingLevel: nestingLevel + 1
                )

                i = j  // Skip to next group or end
            } else {
                html += buildNavigatorItemWithChildren(node, nestingLevel: nestingLevel)
                i += 1
            }
        }

        return html
    }

    /// Builds a group marker item with its children always visible.
    ///
    /// Group markers are rendered as non-interactive `<li>` items with the `.is-group`
    /// class: plain flat section headers with no disclosure chevron, matching
    /// swift-docc-render's behaviour where groups are always expanded.
    ///
    /// - Parameters:
    ///   - node: The group marker node.
    ///   - children: The nodes listed under the group marker.
    ///   - nestingLevel: The nesting level of the group marker.
    /// - Returns: The HTML for the group marker and its children.
    mutating func buildGroupMarkerItemWithChildren(
        _ node: NavigationNode,
        children: [NavigationNode],
        nestingLevel: Int
    ) -> String {
        var html = "\n<li class=\"navigator-card is-group\" style=\"--nesting-index: \(nestingLevel)\">"
            + "<div class=\"depth-spacer\"></div>"
            + "<span class=\"group-title\">\(escapeHTML(node.title))</span></li>"

        if !children.isEmpty {
            html += "\n<li class=\"nav-children-wrapper\"><ul class=\"sidebar-list\">"
            html += buildFlatNavigationList(children, nestingLevel: nestingLevel + 1)
            html += "\n</ul></li>"
        }

        return html
    }

    /// Builds a regular navigator item with its children wrapped for disclosure.
    ///
    /// Expandable items start collapsed; the stylesheet expands the target row and its
    /// ancestors.
    ///
    /// - Parameters:
    ///   - node: The navigation node.
    ///   - nestingLevel: The nesting level for indentation.
    /// - Returns: The HTML for the item and its children.
    mutating func buildNavigatorItemWithChildren(_ node: NavigationNode, nestingLevel: Int) -> String {
        let nodeType = node.nodeType
        let relativeURL = makeRelativeURL(node.path ?? "")
        let expandableClass = node.isExpandable ? " expandable" : ""

        var html = "\n<li class=\"navigator-card\(expandableClass)\" style=\"--nesting-index: \(nestingLevel)\""
            + "\(identifierAttribute(for: node))>"

        if node.isExpandable {
            // The checkbox precedes the depth spacer so sibling selectors can reach the chevron
            let checkboxId = nextCheckboxId()
            html += "<input type=\"checkbox\" id=\"\(checkboxId)\" class=\"disclosure-checkbox\">"
            html += "<div class=\"depth-spacer\">"
            html += "<label for=\"\(checkboxId)\" class=\"disclosure-chevron\" aria-label=\"Toggle \(escapeHTML(node.title))\">"
            html += Self.chevronSVG
            html += "</label></div>"
        } else {
            html += "<div class=\"depth-spacer\"></div>"
        }

        if nodeType.showsBadge {
            html += "<span class=\"badge \(nodeType.badgeClass)\">\(nodeType.badgeCharacter)</span>"
        } else if let iconSVG = nodeType.iconSVG {
            html += "<span class=\"symbol-icon\">\(iconSVG)</span>"
        }

        html += "<a href=\"\(escapeHTML(relativeURL))\" class=\"leaf-link\">\(escapeHTML(node.title))</a></li>"

        if let children = node.children, !children.isEmpty {
            html += "\n<li class=\"nav-children-wrapper\"><ul class=\"sidebar-list\">"
            html += buildFlatNavigationList(children, nestingLevel: nestingLevel + 1)
            html += "\n</ul></li>"
        }

        return html
    }

    /// Returns the ` id="…"` attribute for a node's row, if the row should carry one.
    ///
    /// Only the first row of each page carries an identifier, so identifiers stay unique.
    ///
    /// - Parameter node: The navigation node.
    /// - Returns: The attribute, including its leading space, or an empty string.
    mutating func identifierAttribute(for node: NavigationNode) -> String {
        guard !node.isGroupMarker, let path = node.path else { return "" }
        let key = SidebarDocument.pagePathKey(path)
        guard identifiedPaths.insert(key).inserted else { return "" }
        return " id=\"\(escapeHTML(SidebarDocument.rowIdentifier(forPath: key)))\""
    }

    /// Returns a new unique checkbox identifier.
    mutating func nextCheckboxId() -> String {
        defer { checkboxCounter += 1 }
        return "nav-\(checkboxCounter)"
    }

    /// Converts an absolute DocC URL to a URL relative to the output root.
    ///
    /// - Parameter url: The DocC path, such as `/documentation/module/symbol`.
    /// - Returns: The relative URL of the page's `index.html`.
    func makeRelativeURL(_ url: String) -> String {
        "\(SidebarDocument.pagePathKey(url))/index.html"
    }
}
