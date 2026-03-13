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
/// This builder creates a hierarchical sidebar with:
/// - Disclosure chevrons for expandable items (pure CSS, no JavaScript)
/// - Selected item highlighting
/// - Proper icons/badges for different symbol types
/// - Flat list structure (matches swift-docc-render architecture)
///
/// ## Architecture
///
/// Unlike the previous nested `<ul>` approach, this builder generates a flat list
/// where all items are siblings in a single `<ul>`. Visual hierarchy is achieved
/// through CSS using the `--nesting-index` custom property for indentation.
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
}

// MARK: - Public
public extension NavigationSidebarBuilder {
    /// Creates a new navigation sidebar builder.
    ///
    /// - Parameter navigationIndex: The navigation index to build from.
    init(navigationIndex: NavigationIndex) {
        self.navigationIndex = navigationIndex
    }

    /// Builds the sidebar HTML showing all modules with the current module expanded.
    ///
    /// - Parameters:
    ///   - moduleName: The name of the current module (will be expanded).
    ///   - currentPath: The path of the currently selected page.
    ///   - depth: The depth of the current page for relative URL calculation.
    /// - Returns: The sidebar HTML string.
    mutating func buildSidebar(moduleName: String, currentPath: String, depth: Int) -> String {
        let allModules = navigationIndex.allModules()

        // If we have multiple modules, show them all
        if allModules.count > 1 {
            return buildMultiModuleSidebar(
                allModules: allModules,
                currentModuleName: moduleName,
                currentPath: currentPath,
                depth: depth
            )
        }

        // Single module: show its navigation tree
        guard let moduleNode = navigationIndex.findModule(moduleName) else {
            return buildFallbackSidebar(currentPath: currentPath, depth: depth)
        }

        return buildSidebarFromNode(moduleNode, currentPath: currentPath, depth: depth)
    }

    /// Builds a sidebar showing all modules with expandable navigation.
    ///
    /// Modules are shown in Package.swift order. The current module is expanded,
    /// while other modules are collapsed.
    mutating func buildMultiModuleSidebar(
        allModules: [NavigationNode],
        currentModuleName: String,
        currentPath: String,
        depth: Int
    ) -> String {
        var html = """

                <nav class="sidebar">
                    <div class="sidebar-content">
        """

        // Modules are already in Package.swift order from filterNavigationIndex
        // Add each module as an expandable section
        for moduleNode in allModules {
            let isCurrent = isCurrentModule(moduleNode, currentModuleName: currentModuleName)
            html += buildModuleSection(
                moduleNode,
                isCurrentModule: isCurrent,
                currentPath: currentPath,
                depth: depth
            )
        }

        html += """

                    </div>
                    <div class="sidebar-filter" id="sidebar-filter">
                        <span class="filter-icon">
                            <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor">
                                <path d="M0 1.5A1.5 1.5 0 011.5 0h11A1.5 1.5 0 0114 1.5v1.75a1.5 1.5 0 01-.44 1.06L9 8.871V13.5a.5.5 0 01-.757.429l-3-1.8A.5.5 0 015 11.7V8.871L.44 4.31A1.5 1.5 0 010 3.25V1.5z"/>
                            </svg>
                        </span>
                        <input type="text" placeholder="Filter" class="filter-input" aria-label="Filter navigation">
                        <span class="filter-shortcut">/</span>
                    </div>
                </nav>
        """

        return html
    }

    /// Builds a module section in the multi-module sidebar.
    mutating func buildModuleSection(
        _ moduleNode: NavigationNode,
        isCurrentModule: Bool,
        currentPath: String,
        depth: Int
    ) -> String {
        let checkboxId = "nav-\(checkboxCounter)"
        checkboxCounter += 1

        let relativeURL = makeRelativeURL(moduleNode.path ?? "", depth: depth)
        // Expand current module by default
        let isExpanded = isCurrentModule || shouldExpandNode(moduleNode, currentPath: currentPath)
        let checkedAttr = isExpanded ? " checked" : ""
        let activeClass = isCurrentModule ? " active" : ""

        var html = """

                        <div class="sidebar-section module-section">
                            <input type="checkbox" id="\(checkboxId)" class="disclosure-checkbox"\(checkedAttr)>
                            <div class="module-header">
                                <a href="\(escapeHTML(relativeURL))" class="technology-title\(activeClass)">
                                    <h2 class="card-link">\(escapeHTML(moduleNode.title))</h2>
                                    <label for="\(checkboxId)" class="disclosure-chevron" aria-label="Toggle \(escapeHTML(moduleNode.title))">
                                        <svg viewBox="0 0 10 10" fill="currentColor">
                                            <path d="M3 1.5L7 5L3 8.5" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
                                        </svg>
                                    </label>
                                </a>
                            </div>
        """

        // Add module's navigation tree (flat list structure)
        if let children = moduleNode.children {
            html += """

                            <ul class="sidebar-list module-contents">
            """
            // Flatten all items with depth tracking
            html += buildFlatNavigationList(children, currentPath: currentPath, depth: depth, nestingLevel: 0)
            html += """

                            </ul>
            """
        }

        html += """

                        </div>
        """

        return html
    }
}

// MARK: - Private
private extension NavigationSidebarBuilder {
    /// Builds the sidebar from a module navigation node.
    mutating func buildSidebarFromNode(_ moduleNode: NavigationNode, currentPath: String, depth: Int) -> String {
        var html = """

                <nav class="sidebar">
                    <div class="sidebar-content">
                        <a href="\(makeRelativeURL(moduleNode.path ?? "", depth: depth))" class="technology-title">
                            <h2 class="card-link">\(escapeHTML(moduleNode.title))</h2>
                        </a>
        """

        // Build the flat navigation list
        if let children = moduleNode.children {
            html += """

                        <ul class="sidebar-list">
            """
            html += buildFlatNavigationList(children, currentPath: currentPath, depth: depth, nestingLevel: 0)
            html += """

                        </ul>
            """
        }

        html += """

                    </div>
                    <div class="sidebar-filter" id="sidebar-filter">
                        <span class="filter-icon">
                            <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor">
                                <path d="M0 1.5A1.5 1.5 0 011.5 0h11A1.5 1.5 0 0114 1.5v1.75a1.5 1.5 0 01-.44 1.06L9 8.871V13.5a.5.5 0 01-.757.429l-3-1.8A.5.5 0 015 11.7V8.871L.44 4.31A1.5 1.5 0 010 3.25V1.5z"/>
                            </svg>
                        </span>
                        <input type="text" placeholder="Filter" class="filter-input" aria-label="Filter navigation">
                        <span class="filter-shortcut">/</span>
                    </div>
                </nav>
        """

        return html
    }

    /// Builds a flat navigation list where all items are siblings.
    ///
    /// This method recursively flattens the navigation tree into a single list,
    /// using `--nesting-index` for visual hierarchy via CSS indentation.
    /// Children are wrapped in a `.nav-children-wrapper` div for CSS-based disclosure.
    ///
    /// - Parameters:
    ///   - nodes: The navigation nodes to render.
    ///   - currentPath: The current page path for selection highlighting.
    ///   - depth: The depth for relative URL calculation.
    ///   - nestingLevel: The nesting level for indentation (matches docc-render's `depth`).
    /// - Returns: HTML string with flat list items.
    mutating func buildFlatNavigationList(
        _ nodes: [NavigationNode],
        currentPath: String,
        depth: Int,
        nestingLevel: Int
    ) -> String {
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

                // Render group marker with children wrapper
                html += buildGroupMarkerItemWithChildren(
                    node,
                    children: groupChildren,
                    currentPath: currentPath,
                    depth: depth,
                    nestingLevel: nestingLevel + 1
                )

                i = j  // Skip to next group or end
            } else {
                // Regular item
                let isSelected = isPathSelected(node.path, currentPath: currentPath)
                let isExpanded = shouldExpandNode(node, currentPath: currentPath)

                html += buildNavigatorItemWithChildren(
                    node,
                    currentPath: currentPath,
                    depth: depth,
                    nestingLevel: nestingLevel,
                    isSelected: isSelected,
                    isExpanded: isExpanded
                )

                i += 1
            }
        }

        return html
    }

    /// Builds a group marker item with its children always visible.
    ///
    /// Group markers are rendered as non-interactive `<li>` items with the `.is-group`
    /// class — plain flat section headers with no disclosure chevron, matching
    /// swift-docc-render's behaviour where groups are always expanded.
    mutating func buildGroupMarkerItemWithChildren(
        _ node: NavigationNode,
        children: [NavigationNode],
        currentPath: String,
        depth: Int,
        nestingLevel: Int
    ) -> String {
        var html = """

                                <li class="navigator-card is-group" style="--nesting-index: \(nestingLevel)">
                                    <div class="depth-spacer"></div>
                                    <span class="group-title">\(escapeHTML(node.title))</span>
                                </li>
        """

        // Children are always visible (no disclosure toggle for groups)
        if !children.isEmpty {
            html += """

                                <li class="nav-children-wrapper">
                                    <ul class="sidebar-list">
            """
            html += buildFlatNavigationList(
                children,
                currentPath: currentPath,
                depth: depth,
                nestingLevel: nestingLevel + 1
            )
            html += """

                                    </ul>
                                </li>
            """
        }

        return html
    }

    /// Builds a regular navigator item with its children wrapped for disclosure.
    mutating func buildNavigatorItemWithChildren(
        _ node: NavigationNode,
        currentPath: String,
        depth: Int,
        nestingLevel: Int,
        isSelected: Bool,
        isExpanded: Bool
    ) -> String {
        let nodeType = node.nodeType
        let relativeURL = makeRelativeURL(node.path ?? "", depth: depth)
        let selectedClass = isSelected ? " selected" : ""
        let expandableClass = node.isExpandable ? " expandable" : ""
        let checkedAttr = isExpanded ? " checked" : ""

        var html = """

                                <li class="navigator-card\(expandableClass)\(selectedClass)" style="--nesting-index: \(nestingLevel)">
        """

        // Add checkbox first if expandable (needed for sibling selector)
        if node.isExpandable {
            let checkboxId = "nav-\(checkboxCounter)"
            checkboxCounter += 1

            html += """

                                    <input type="checkbox" id="\(checkboxId)" class="disclosure-checkbox"\(checkedAttr)>
            """
        }

        html += """

                                    <div class="depth-spacer">
        """

        // Add disclosure chevron label if expandable
        if node.isExpandable {
            html += """

                                        <label for="nav-\(checkboxCounter - 1)" class="disclosure-chevron" aria-label="Toggle \(escapeHTML(node.title))">
                                            <svg viewBox="0 0 10 10" fill="currentColor">
                                                <path d="M3 1.5L7 5L3 8.5" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
                                            </svg>
                                        </label>
            """
        }

        html += """

                                    </div>
        """

        // Add badge or icon
        if nodeType.showsBadge {
            html += """

                                    <span class="badge \(nodeType.badgeClass)">\(nodeType.badgeCharacter)</span>
            """
        } else if let iconSVG = nodeType.iconSVG {
            html += """

                                    <span class="symbol-icon">\(iconSVG)</span>
            """
        }

        // Add the link
        html += """

                                    <a href="\(escapeHTML(relativeURL))" class="leaf-link">\(escapeHTML(node.title))</a>
                                </li>
        """

        // Wrap children in a container for CSS disclosure
        if let children = node.children, !children.isEmpty {
            html += """

                                <li class="nav-children-wrapper">
                                    <ul class="sidebar-list">
            """
            html += buildFlatNavigationList(
                children,
                currentPath: currentPath,
                depth: depth,
                nestingLevel: nestingLevel + 1
            )
            html += """

                                    </ul>
                                </li>
            """
        }

        return html
    }

    /// Checks if a module node is the current module.
    ///
    /// The `currentModuleName` is typically extracted from the page path (e.g., "doccstatic")
    /// while the module node's path contains the full documentation path.
    func isCurrentModule(_ moduleNode: NavigationNode, currentModuleName: String) -> Bool {
        guard let path = moduleNode.path else { return false }

        // Extract module name from the navigation node's path
        // Path format: /documentation/modulename
        let pathComponents = path.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .components(separatedBy: "/")

        guard pathComponents.count >= 2,
              pathComponents[0] == "documentation" else {
            return false
        }

        let nodeModuleName = pathComponents[1]
        let normalizedCurrentName = currentModuleName.lowercased()
            .replacingOccurrences(of: "-", with: "_")

        // Compare the module names (both normalised)
        return nodeModuleName == normalizedCurrentName ||
               nodeModuleName == currentModuleName.lowercased()
    }

    /// Checks if a path matches the current path.
    func isPathSelected(_ path: String?, currentPath: String) -> Bool {
        guard let path = path else { return false }
        // Normalise paths for comparison
        let normalisedPath = path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalisedCurrent = currentPath.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return normalisedPath == normalisedCurrent
    }

    /// Determines if a node should be expanded (i.e., its disclosure checkbox checked).
    ///
    /// Returns `true` when this node or any descendant matches the current path,
    /// so that the path from the root to the current page is pre-opened on load.
    func shouldExpandNode(_ node: NavigationNode, currentPath: String) -> Bool {
        if isPathSelected(node.path, currentPath: currentPath) {
            return true
        }

        guard let children = node.children else { return false }

        for child in children {
            if shouldExpandNode(child, currentPath: currentPath) {
                return true
            }
        }

        return false
    }

    /// Converts an absolute DocC URL to a relative URL.
    func makeRelativeURL(_ url: String, depth: Int) -> String {
        let cleanPath = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let prefix = String(repeating: "../", count: depth)
        return "\(prefix)\(cleanPath)/index.html"
    }

    /// Builds a fallback sidebar when the module isn't found.
    func buildFallbackSidebar(currentPath: String, depth: Int) -> String {
        return """

                <nav class="sidebar">
                    <div class="sidebar-content">
                    </div>
                    <div class="sidebar-filter" id="sidebar-filter">
                        <input type="text" placeholder="Filter" class="filter-input" aria-label="Filter navigation">
                    </div>
                </nav>
        """
    }
}
