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

    /// Whether the shared navigation sidebar document exists and is embedded.
    public let embedsSidebar: Bool

    /// Creates a new index page builder.
    ///
    /// - Parameters:
    ///   - configuration: The generation configuration.
    ///   - embedsSidebar: Whether to embed the shared navigation sidebar document
    ///     (see ``SidebarDocument``), which must then exist in the output directory.
    public init(configuration: Configuration, embedsSidebar: Bool = false) {
        self.configuration = configuration
        self.embedsSidebar = embedsSidebar
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
    /// The class of the hidden element in a module card that states the module's
    /// number of symbols, for themes that show it.
    static let moduleStatisticsClass = "module-stats"

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
        <body class="index-page" \(ColourSchemeToggle.bodyAttribute)>
            <div id="app">
            <div id="app-top"></div>
            <a href="#app-main" id="skip-nav">Skip Navigation</a>
            \(HTMLPageBuilder.chromeToggles)
            <div class="documentation-layout">
        """
        html += HTMLPageBuilder.navigationBarMarkup(depth: 0)
        html += "\n<div class=\"adjustable-sidebar-width full-width-container topic-wrapper\">"
        if embedsSidebar {
            html += SidebarDocument.containerMarkup(
                content: "<iframe class=\"\(SidebarDocument.frameClass)\" title=\"\(escapeHTML(SidebarDocument.frameTitle))\" src=\"\(SidebarDocument.fileName)\"></iframe>"
            )
        }
        html += "\n<div class=\"content\"><div class=\"doc-topic\"><main class=\"main\" id=\"app-main\">"

        // Hero, like the root page of a swift-docc-render site
        html += "\n<div class=\"documentation-hero index-header\"><div class=\"icon\">"
        html += TopicTypeIcon.markup(for: "module", additionalClass: "background-icon first-icon")
        html += "</div><div class=\"documentation-hero__above-content\"></div>"
        html += "\n<div class=\"documentation-hero__content\"><div class=\"topictitle\"><span class=\"eyebrow\">Package</span>"
        html += "<h1 class=\"title\">\(escapeHTML(title))</h1></div>"
        if indexContent == nil {
            html += "<div class=\"\(HTMLPageBuilder.heroAbstractClass) subtitle\"><p>API Reference Documentation</p></div>"
        }
        html += "</div></div>"

        html += "\n<div class=\"doc-content-wrapper\"><div class=\"doc-content\(indexContent == nil ? " no-primary-content" : "")\">"
        if let indexContent {
            html += "\n<div class=\"container\"><div class=\"primary-content index-intro\"><div class=\"content\">"
            html += indexContent.bodyHTML
            html += "</div></div></div>"
        }

        // Modules and tutorial collections as cards, like swift-docc-render's topic card grids
        html += "\n<section class=\"contenttable alt-light topics\"><div class=\"container\">"
        html += "<h2 id=\"topics\" class=\"title\">\(RenderContentHTMLRenderer.headerAnchor(anchor: "topics", title: "Topics"))</h2>"
        html += buildCardSection(title: "Modules", anchor: "modules", listClass: "module-list", cards: modules.map(buildModuleCard))
        if !tutorials.isEmpty {
            html += buildCardSection(title: "Tutorials", anchor: "tutorials", listClass: "tutorial-list", cards: tutorials.map(buildTutorialCard))
        }
        html += "\n</div></section>\n</div>"
        if !configuration.theme.isEnabled(.onThisPageNavigatorDisabled) {
            html += "<div class=\"\(HTMLPageBuilder.onThisPageContainerClass)\"></div>"
        }
        html += "</div>\n</main></div></div>\n</div>\n</div>"

        // Footer with configurable content and appearance selector
        html += buildFooter()
        html += "\n    </div>"

        // The embedded sidebar document loads the search scripts for its filter field;
        // without it, the scripts offer search on this page
        if configuration.includeSearch && !embedsSidebar {
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
    /// Builds a group of cards in the topics section.
    ///
    /// - Parameters:
    ///   - title: The group title.
    ///   - anchor: The identifier of the group heading.
    ///   - listClass: An additional class naming the kind of cards.
    ///   - cards: The cards.
    /// - Returns: The `.contenttable-section` element with a two-column card grid.
    func buildCardSection(title: String, anchor: String, listClass: String, cards: [String]) -> String {
        var html = "\n<div class=\"contenttable-section\"><div class=\"section-title\">"
        html += "<h3 id=\"\(anchor)\" class=\"contenttable-title\">\(RenderContentHTMLRenderer.headerAnchor(anchor: anchor, title: title))</h3></div>"
        html += "<div class=\"section-content\"><div class=\"TopicsLinkCardGrid \(listClass)\">"
        html += "<div class=\"row with-columns\" style=\"--col-count-large: 2; --col-count-medium: 2; --col-count-small: 1;\">"
        html += cards.map { "<div class=\"column\">\($0)</div>" }.joined()
        html += "</div></div></div></div>"
        return html
    }

    /// Builds a card (swift-docc-render's reference card grid item).
    ///
    /// - Parameters:
    ///   - path: The link target.
    ///   - title: The card title.
    ///   - abstract: The card text, or `nil`.
    ///   - statistics: A hidden line of statistics after the text, or `nil`.
    ///   - iconType: The topic type whose icon fills the card cover.
    ///   - linkText: The call to action at the bottom of the card.
    ///   - classes: Additional classes of the card, of its title and of its text.
    /// - Returns: The `a.card` element.
    func buildCard(
        path: String, title: String, abstract: String?, statistics: String? = nil, iconType: String, linkText: String,
        classes: (card: String, title: String, text: String)
    ) -> String {
        var html = "<a href=\"\(escapeHTML(path))\" class=\"card reference-card-grid-item large floating-style \(classes.card)\">"
        html += "<div class=\"card-cover-wrap rounded\" aria-hidden=\"true\"><div class=\"reference-card-grid-item__image card-cover\">"
        html += TopicTypeIcon.markup(for: iconType, additionalClass: "reference-card-grid-item__icon") + "</div></div>"
        html += "<div class=\"details\"><div class=\"title \(classes.title)\">\(escapeHTML(title))</div>"
        if let abstract, !abstract.isEmpty {
            html += "<div class=\"card-content \(classes.text)\"><div class=\"content\">\(escapeHTML(abstract))</div></div>"
        }
        if let statistics {
            html += "<div class=\"\(Self.moduleStatisticsClass)\">\(escapeHTML(statistics))</div>"
        }
        html += "<div class=\"link\">\(escapeHTML(linkText))"
        html += "<svg class=\"svg-icon link-icon icon-inline inline-chevron-right-icon\" viewBox=\"0 0 14 14\" aria-hidden=\"true\"><path d=\"M2.964 1.366l0.649-0.76 7.426 6.343-7.423 6.445-0.655-0.755 6.545-5.683-6.542-5.59z\"></path></svg>"
        html += "</div></div></a>"
        return html
    }

    /// Builds the card of a module, with its number of symbols as hidden statistics.
    func buildModuleCard(_ module: ModuleEntry) -> String {
        let symbolText = module.symbolCount == 1 ? "symbol" : "symbols"
        return buildCard(
            path: module.path, title: module.name, abstract: module.abstract,
            statistics: "\(module.symbolCount) \(symbolText)", iconType: "collectionGroup",
            linkText: "View API collection", classes: ("module-card", "module-name", "module-abstract")
        )
    }

    /// Builds the card of a tutorial collection.
    func buildTutorialCard(_ tutorial: TutorialEntry) -> String {
        let tutorialText = tutorial.tutorialCount == 1 ? "tutorial" : "tutorials"
        return buildCard(
            path: tutorial.path, title: tutorial.title, abstract: "\(tutorial.tutorialCount) \(tutorialText)",
            iconType: "tutorial", linkText: "Get started",
            classes: ("tutorial-collection-card", "tutorial-collection-name", "tutorial-collection-stats")
        )
    }

    /// Builds the page footer with the custom footer content and the colour scheme toggle.
    ///
    /// - Returns: The footer built by ``ColourSchemeToggle/footerMarkup(content:)``.
    func buildFooter() -> String {
        ColourSchemeToggle.footerMarkup(content: configuration.footerHTML ?? Configuration.defaultFooter)
    }

    /// JavaScript for the colour scheme toggle.
    ///
    /// Without JavaScript the toggle still switches the colour scheme of the page;
    /// the script remembers the choice across pages.
    var appearanceSelectorScript: String {
        """

            <script>
            \(ColourSchemeToggle.script)
            </script>
        """
    }
}
