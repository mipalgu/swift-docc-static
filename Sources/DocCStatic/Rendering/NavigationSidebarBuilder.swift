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
/// - The topic type icon of every row (see ``TopicTypeIcon``)
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
/// with the `.is-group` class, at the same depth as the rows they group.
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
        <body class="\(SidebarDocument.documentClass)" \(ColourSchemeToggle.bodyAttribute)>
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
    /// The structure mirrors swift-docc-render's `Navigator` and `NavigatorCard`: a
    /// `nav.navigator` holding the card with the technology title and the rows, and
    /// the filter field at the bottom.  A single module's title stays above the
    /// scrolling rows like swift-docc-render's; with several modules, each module's
    /// title and rows scroll together.  Links are relative to the output root.  Every
    /// row representing a page carries the identifier returned by
    /// ``SidebarDocument/rowIdentifier(forPath:)``; if a page is listed more than once,
    /// only its first row carries the identifier.
    ///
    /// - Returns: The navigator, with an empty card if the index contains no modules.
    mutating func buildNavigationTree() -> String {
        let allModules = navigationIndex.allModules()
        var html = """

            <nav class="navigator" aria-label="Documentation Navigator">
                <div class="navigator-card">
                    <div class="navigator-card-full-height">
                        <div class="navigator-card-inner">
                            <div class="card-body">
        """
        if allModules.count > 1 {
            html += "\n<div class=\"sidebar-content scroller\">"
            for moduleNode in allModules {
                html += buildModuleSection(moduleNode)
            }
            html += "\n</div>"
        } else if let moduleNode = allModules.first {
            html += buildSingleModuleTree(moduleNode)
        } else {
            html += "\n<div class=\"sidebar-content scroller\"></div>"
        }
        html += """

                            </div>
                        </div>
                    </div>
        \(Self.filterMarkup)
                </div>
            </nav>
        """
        return html
    }

    /// Builds the inline sidebar used when no navigation tree is available.
    ///
    /// - Returns: An empty sidebar container with a filter field.
    static func buildFallbackSidebar() -> String {
        SidebarDocument.containerMarkup(content: """
        <div class="navigator"><div class="sidebar-content"></div>
        \(filterMarkup)
        </div>
        """)
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
    /// page for assistive technologies, scrolls the list only when the target row
    /// would otherwise be out of view, reveals the filter field and filters the tree
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
                var schemes = [\(ColourSchemeToggle.Scheme.allCases.map { "'\($0.rawValue)'" }.joined(separator: ", "))];
                var body = document.body;

                function applyScheme(scheme) {
                    if (schemes.indexOf(scheme) !== -1) {
                        body.setAttribute('\(ColourSchemeToggle.schemeAttribute)', scheme);
                    }
                }

                try {
                    applyScheme(window.localStorage.getItem(storageKey) || '\(ColourSchemeToggle.defaultScheme.rawValue)');
                } catch (error) {
                    // Storage may be unavailable, for example for local files.
                }

                window.addEventListener('storage', function (event) {
                    if (event.key === storageKey) {
                        applyScheme(event.newValue || '\(ColourSchemeToggle.defaultScheme.rawValue)');
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

                function currentRow() {
                    var fragment = window.location.hash.slice(1);
                    var target = fragment ? document.getElementById(fragment) : null;
                    if (!target && fragment) {
                        try {
                            target = document.getElementById(decodeURIComponent(fragment));
                        } catch (error) {
                            target = null;
                        }
                    }
                    return target;
                }

                function markCurrentPage() {
                    var marked = document.querySelectorAll('[aria-current]');
                    for (var i = 0; i < marked.length; i++) {
                        marked[i].removeAttribute('aria-current');
                    }
                    var target = currentRow();
                    var link = target ? (target.tagName === 'A' ? target : target.querySelector('a')) : null;
                    if (link) {
                        link.setAttribute('aria-current', 'page');
                    }
                }

                // Like swift-docc-render, scroll the current row to the top of the
                // list, below the title of its module, only if it would not be
                // visible otherwise.
                function revealCurrentRow(initial) {
                    var target = currentRow();
                    var scroller = target ? target.closest('.scroller') : null;
                    if (!scroller || scroller.clientHeight === 0) {
                        return;
                    }
                    var section = target.closest('.module-section');
                    var header = section ? section.querySelector('.module-header') : null;
                    var titleHeight = header && !header.contains(target) ? header.offsetHeight : 0;
                    var area = scroller.getBoundingClientRect();
                    var row = target.getBoundingClientRect();
                    var offset = row.top - area.top + scroller.scrollTop;
                    if (initial && offset + row.height <= scroller.clientHeight) {
                        scroller.scrollTop = 0;
                    } else if (row.top < area.top + titleHeight || row.bottom > area.bottom) {
                        scroller.scrollTop = offset - titleHeight;
                    }
                }

                markCurrentPage();
                window.addEventListener('hashchange', markCurrentPage);
                window.addEventListener('load', function () {
                    revealCurrentRow(true);
                });
                window.addEventListener('resize', function () {
                    revealCurrentRow(false);
                });

                if (!filterBox || !input || !content) {
                    return;
                }

                filterBox.hidden = false;

                var rows = content.querySelectorAll('.navigator-card-item');
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
    /// The filter field at the bottom of the navigator.
    ///
    /// It starts hidden, because filtering needs JavaScript; the sidebar script shows it.
    static let filterMarkup = """
                <div class="filter-wrapper" id="sidebar-filter" hidden>
                    <div class="navigator-filter">
                        <div class="input-wrapper">
                            <div class="filter filter-component" role="search">
                                <div class="filter__wrapper filter__wrapper--reversed">
                                    <div class="filter__top-wrapper">
                                        <span class="filter__filter-button" aria-hidden="true">
                                            <svg class="svg-icon filter-icon" width="14" height="14" viewBox="0 0 14 14"><path d="m2 6.5h10v1h-10z"/><path d="m1 3h12v1h-12z"/><path d="m3 10h8v1h-8z"/></svg>
                                        </span>
                                        <div class="filter__input-box-wrapper">
                                            <label class="filter__input-label">
                                                <input type="text" placeholder="Filter" class="filter__input filter-input" aria-label="Filter navigation" autocomplete="off" spellcheck="false">
                                            </label>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <span class="quick-navigation-open" title="Type / to filter">/</span>
                    </div>
                </div>
    """

    /// The chevron drawn by disclosure toggles (swift-docc-render's `InlineChevronRightIcon`).
    static let chevronSVG = """
    <svg class="svg-icon inline-chevron-right-icon icon-inline chevron" viewBox="0 0 14 14" aria-hidden="true"><path d="M2.964 1.366l0.649-0.76 7.426 6.343-7.423 6.445-0.655-0.755 6.545-5.683-6.542-5.59z"></path></svg>
    """

    /// Builds a module section in the multi-module sidebar.
    ///
    /// Every module starts collapsed; the stylesheet expands the module that contains
    /// the target row.  The disclosure toggle sits beside the technology title link.
    ///
    /// - Parameter moduleNode: The module's navigation node.
    /// - Returns: The HTML for the module section.
    mutating func buildModuleSection(_ moduleNode: NavigationNode) -> String {
        let checkboxId = nextCheckboxId()
        let relativeURL = makeRelativeURL(moduleNode.path ?? "")
        let title = escapeHTML(moduleNode.title)

        var html = """

                    <div class="module-section">
                        <input type="checkbox" id="\(checkboxId)" class="disclosure-checkbox">
                        <div class="module-header"\(identifierAttribute(for: moduleNode))>
                            <a href="\(escapeHTML(relativeURL))" class="technology-title"><h2 class="card-link">\(title)</h2></a>
                            <label for="\(checkboxId)" class="tree-toggle module-toggle" aria-label="Toggle \(title)">\(Self.chevronSVG)</label>
                        </div>
        """

        if let children = moduleNode.children {
            html += "\n<ul class=\"navigator-tree module-contents\">"
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
    /// The technology title stays above the scrolling rows.
    ///
    /// - Parameter moduleNode: The module's navigation node.
    /// - Returns: The HTML for the module title and its tree.
    mutating func buildSingleModuleTree(_ moduleNode: NavigationNode) -> String {
        let relativeURL = makeRelativeURL(moduleNode.path ?? "")
        var html = """

                    <a href="\(escapeHTML(relativeURL))" class="technology-title"\(identifierAttribute(for: moduleNode))><h2 class="card-link">\(escapeHTML(moduleNode.title))</h2></a>
                    <div class="sidebar-content scroller">
        """

        if let children = moduleNode.children {
            html += "\n<ul class=\"navigator-tree\">"
            html += buildFlatNavigationList(children, nestingLevel: 0)
            html += "\n</ul>"
        }
        html += "\n</div>"
        return html
    }

    /// Builds a flat navigation list where all items are siblings.
    ///
    /// This method recursively flattens the navigation tree into a single list,
    /// using `--nesting-index` for visual hierarchy via CSS indentation.  Like
    /// swift-docc-render, a group heading has the same nesting index as the rows
    /// listed under it.  Children are wrapped in a `.nav-children-wrapper` list item
    /// for CSS-based disclosure.
    ///
    /// - Parameters:
    ///   - nodes: The navigation nodes to render.
    ///   - nestingLevel: The nesting level for indentation (swift-docc-render's `depth`).
    /// - Returns: HTML string with flat list items.
    mutating func buildFlatNavigationList(_ nodes: [NavigationNode], nestingLevel: Int) -> String {
        var html = ""
        for node in nodes {
            html += node.isGroupMarker
                ? buildGroupMarker(node, nestingLevel: nestingLevel)
                : buildNavigatorItemWithChildren(node, nestingLevel: nestingLevel)
        }
        return html
    }

    /// Builds a group heading row.
    ///
    /// Group headings are plain, non-interactive rows (swift-docc-render renders them
    /// as `h3.leaf-link` in an `.is-group` row) followed by the rows they group.
    ///
    /// - Parameters:
    ///   - node: The group marker node.
    ///   - nestingLevel: The nesting level of the group and its rows.
    /// - Returns: The HTML for the group heading.
    func buildGroupMarker(_ node: NavigationNode, nestingLevel: Int) -> String {
        "\n<li class=\"navigator-card-item is-group\" data-nesting-index=\"\(nestingLevel)\" style=\"--nesting-index: \(nestingLevel)\">"
            + "<div class=\"head-wrapper\"><div class=\"depth-spacer\"></div>"
            + "<div class=\"title-container\"><h3 class=\"leaf-link\">\(escapeHTML(node.title))</h3></div></div></li>"
    }

    /// Builds a regular navigator row with its children wrapped for disclosure.
    ///
    /// Expandable rows start collapsed; the stylesheet expands the target row and its
    /// ancestors.  Deprecated and beta rows end with a ``Badge``.  The disclosure checkbox precedes the row's content, so that sibling
    /// selectors can reach the chevron, whose label fills the row's depth spacer.
    ///
    /// - Parameters:
    ///   - node: The navigation node.
    ///   - nestingLevel: The nesting level for indentation.
    /// - Returns: The HTML for the item and its children.
    mutating func buildNavigatorItemWithChildren(_ node: NavigationNode, nestingLevel: Int) -> String {
        let relativeURL = makeRelativeURL(node.path ?? "")
        let expandableClass = node.isExpandable ? " expandable" : ""

        var html = "\n<li class=\"navigator-card-item\(expandableClass)\" data-nesting-index=\"\(nestingLevel)\""
            + " style=\"--nesting-index: \(nestingLevel)\"\(identifierAttribute(for: node))>"

        var toggle = ""
        if node.isExpandable {
            let checkboxId = nextCheckboxId()
            html += "<input type=\"checkbox\" id=\"\(checkboxId)\" class=\"disclosure-checkbox\">"
            toggle = "<label for=\"\(checkboxId)\" class=\"tree-toggle\" aria-label=\"Toggle \(escapeHTML(node.title))\">"
                + Self.chevronSVG + "</label>"
        }
        html += "<div class=\"head-wrapper\"><div class=\"depth-spacer\">\(toggle)</div>"
        html += "<div class=\"navigator-icon-wrapper\">"
            + TopicTypeIcon.markup(for: node.type ?? node.nodeType.rawValue, additionalClass: "navigator-icon")
            + "</div>"
        html += "<div class=\"title-container\"><a href=\"\(escapeHTML(relativeURL))\" class=\"leaf-link\">"
            + "\(escapeHTML(node.title))</a>\(Self.badgeMarkup(for: node))</div></div></li>"

        if let children = node.children, !children.isEmpty {
            html += "\n<li class=\"nav-children-wrapper\"><ul class=\"navigator-tree\">"
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

// MARK: - Badges

extension NavigationSidebarBuilder {
    /// Returns the badge after the title of a deprecated or beta row, like
    /// swift-docc-render's `NavigatorCardItem`.
    ///
    /// - Parameter node: The navigation node.
    /// - Returns: The ``Badge`` markup, or an empty string for other rows.
    static func badgeMarkup(for node: NavigationNode) -> String {
        if node.isDeprecated == true {
            return Badge.markup(.deprecated)
        }
        if node.isBeta == true {
            return Badge.markup(.beta)
        }
        return ""
    }
}
