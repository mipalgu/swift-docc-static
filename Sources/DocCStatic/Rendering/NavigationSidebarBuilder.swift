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

    /// Builds the sidebar HTML for a specific module and current page.
    ///
    /// - Parameters:
    ///   - moduleName: The name of the module to display.
    ///   - currentPath: The path of the currently selected page.
    ///   - depth: The depth of the current page for relative URL calculation.
    /// - Returns: The sidebar HTML string.
    mutating func buildSidebar(moduleName: String, currentPath: String, depth: Int) -> String {
        guard let moduleNode = navigationIndex.findModule(moduleName) else {
            // Fallback: try to find any module containing the current path
            return buildFallbackSidebar(currentPath: currentPath, depth: depth)
        }

        return buildSidebarFromNode(moduleNode, currentPath: currentPath, depth: depth)
    }
}

// MARK: - Private
private extension NavigationSidebarBuilder {
    /// Builds the sidebar from a module navigation node.
    mutating func buildSidebarFromNode(_ moduleNode: NavigationNode, currentPath: String, depth: Int) -> String {
        var html = """

                <nav class="doc-sidebar">
                    <div class="sidebar-content">
                        <a href="\(makeRelativeURL(moduleNode.path ?? "", depth: depth))" class="sidebar-module-link">
                            <h2 class="sidebar-module">\(escapeHTML(moduleNode.title))</h2>
                        </a>
        """

        // Build the navigation tree
        if let children = moduleNode.children {
            html += buildNavigationTree(children, currentPath: currentPath, depth: depth, level: 0)
        }

        html += """

                        <div class="sidebar-filter" id="sidebar-filter">
                            <span class="filter-icon">
                                <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor">
                                    <path d="M0 1.5A1.5 1.5 0 011.5 0h11A1.5 1.5 0 0114 1.5v1.75a1.5 1.5 0 01-.44 1.06L9 8.871V13.5a.5.5 0 01-.757.429l-3-1.8A.5.5 0 015 11.7V8.871L.44 4.31A1.5 1.5 0 010 3.25V1.5z"/>
                                </svg>
                            </span>
                            <input type="text" placeholder="Filter" class="filter-input" aria-label="Filter navigation">
                            <span class="filter-shortcut">/</span>
                        </div>
                    </div>
                </nav>
        """

        return html
    }

    /// Builds the navigation tree HTML for a list of nodes.
    mutating func buildNavigationTree(_ nodes: [NavigationNode], currentPath: String, depth: Int, level: Int) -> String {
        var html = ""
        var currentSection: String? = nil

        for node in nodes {
            if node.isGroupMarker {
                // Start a new section
                currentSection = node.title
                html += """

                        <div class="sidebar-section">
                            <h3 class="sidebar-heading">\(escapeHTML(node.title))</h3>
                            <ul class="sidebar-list">
                """
            } else {
                // Regular navigation item
                let isSelected = isPathSelected(node.path, currentPath: currentPath)
                let isExpanded = shouldExpandNode(node, currentPath: currentPath)

                if node.isExpandable {
                    html += buildExpandableItem(
                        node,
                        currentPath: currentPath,
                        depth: depth,
                        level: level,
                        isSelected: isSelected,
                        isExpanded: isExpanded
                    )
                } else {
                    html += buildSimpleItem(
                        node,
                        depth: depth,
                        isSelected: isSelected
                    )
                }
            }
        }

        // Close any open section
        if currentSection != nil {
            html += """

                            </ul>
                        </div>
            """
        }

        return html
    }

    /// Builds an expandable navigation item with disclosure chevron.
    mutating func buildExpandableItem(
        _ node: NavigationNode,
        currentPath: String,
        depth: Int,
        level: Int,
        isSelected: Bool,
        isExpanded: Bool
    ) -> String {
        let checkboxId = "nav-\(checkboxCounter)"
        checkboxCounter += 1

        let nodeType = node.nodeType
        let relativeURL = makeRelativeURL(node.path ?? "", depth: depth)
        let selectedClass = isSelected ? " selected" : ""
        let checkedAttr = isExpanded ? " checked" : ""

        var html = """

                                <li class="sidebar-item expandable\(selectedClass)">
                                    <input type="checkbox" id="\(checkboxId)" class="disclosure-checkbox"\(checkedAttr)>
                                    <label for="\(checkboxId)" class="disclosure-chevron" aria-label="Toggle \(escapeHTML(node.title))">
                                        <svg viewBox="0 0 10 10" fill="currentColor">
                                            <path d="M3 1.5L7 5L3 8.5" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>
                                        </svg>
                                    </label>
        """

        // Add badge or icon
        if nodeType.showsBadge {
            html += """

                                    <span class="symbol-badge \(nodeType.badgeClass)">\(nodeType.badgeCharacter)</span>
            """
        } else if let iconSVG = nodeType.iconSVG {
            html += """

                                    <span class="symbol-icon">\(iconSVG)</span>
            """
        }

        // Add the link
        html += """

                                    <a href="\(escapeHTML(relativeURL))" class="nav-link">\(escapeHTML(node.title))</a>
        """

        // Add children
        if let children = node.children {
            html += """

                                    <ul class="nav-children">
            """
            html += buildChildItems(children, currentPath: currentPath, depth: depth, level: level + 1)
            html += """

                                    </ul>
            """
        }

        html += """

                                </li>
        """

        return html
    }

    /// Builds child items (nested within an expandable item).
    mutating func buildChildItems(
        _ nodes: [NavigationNode],
        currentPath: String,
        depth: Int,
        level: Int
    ) -> String {
        var html = ""
        var currentSection: String? = nil

        for node in nodes {
            if node.isGroupMarker {
                // Close previous section if any
                if currentSection != nil {
                    // No explicit close needed for nested sections
                }
                currentSection = node.title
                html += """

                                        <li class="nav-group-header">\(escapeHTML(node.title))</li>
                """
            } else {
                let isSelected = isPathSelected(node.path, currentPath: currentPath)

                if node.isExpandable {
                    html += buildExpandableItem(
                        node,
                        currentPath: currentPath,
                        depth: depth,
                        level: level,
                        isSelected: isSelected,
                        isExpanded: shouldExpandNode(node, currentPath: currentPath)
                    )
                } else {
                    html += buildNestedSimpleItem(node, depth: depth, isSelected: isSelected)
                }
            }
        }

        return html
    }

    /// Builds a simple (non-expandable) navigation item.
    func buildSimpleItem(_ node: NavigationNode, depth: Int, isSelected: Bool) -> String {
        let nodeType = node.nodeType
        let relativeURL = makeRelativeURL(node.path ?? "", depth: depth)
        let selectedClass = isSelected ? " selected" : ""

        var html = """

                                <li class="sidebar-item\(selectedClass)">
        """

        // Add badge or icon
        if nodeType.showsBadge {
            html += """

                                    <span class="symbol-badge \(nodeType.badgeClass)">\(nodeType.badgeCharacter)</span>
            """
        } else if let iconSVG = nodeType.iconSVG {
            html += """

                                    <span class="symbol-icon">\(iconSVG)</span>
            """
        }

        html += """

                                    <a href="\(escapeHTML(relativeURL))" class="nav-link">\(escapeHTML(node.title))</a>
                                </li>
        """

        return html
    }

    /// Builds a nested simple item (inside an expandable parent).
    func buildNestedSimpleItem(_ node: NavigationNode, depth: Int, isSelected: Bool) -> String {
        let nodeType = node.nodeType
        let relativeURL = makeRelativeURL(node.path ?? "", depth: depth)
        let selectedClass = isSelected ? " selected" : ""

        var html = """

                                        <li class="nav-child-item\(selectedClass)">
        """

        // Add badge or icon
        if nodeType.showsBadge {
            html += """

                                            <span class="symbol-badge \(nodeType.badgeClass)">\(nodeType.badgeCharacter)</span>
            """
        }

        html += """

                                            <a href="\(escapeHTML(relativeURL))">\(escapeHTML(node.title))</a>
                                        </li>
        """

        return html
    }

    /// Checks if a path matches the current path.
    func isPathSelected(_ path: String?, currentPath: String) -> Bool {
        guard let path = path else { return false }
        // Normalise paths for comparison
        let normalisedPath = path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalisedCurrent = currentPath.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return normalisedPath == normalisedCurrent
    }

    /// Determines if a node should be expanded (contains the current path).
    func shouldExpandNode(_ node: NavigationNode, currentPath: String) -> Bool {
        // Check if this node or any descendant matches the current path
        if isPathSelected(node.path, currentPath: currentPath) {
            return true
        }

        guard let children = node.children else { return false }

        for child in children {
            if isPathSelected(child.path, currentPath: currentPath) {
                return true
            }
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

                <nav class="doc-sidebar">
                    <div class="sidebar-content">
                        <h2 class="sidebar-module">Documentation</h2>
                        <div class="sidebar-filter" id="sidebar-filter">
                            <input type="text" placeholder="Filter" class="filter-input" aria-label="Filter navigation">
                        </div>
                    </div>
                </nav>
        """
    }
}
