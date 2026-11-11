//
// TutorialsOverviewPageBuilder.swift
// DocCStatic
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import SwiftDocC

/// The content of a tutorials overview (table of contents) page.
///
/// A tutorials overview introduces a technology's tutorials with a hero and lists
/// them in volumes and chapters.  The content is independent of where it came from,
/// so that the same markup is produced for a DocC `@Tutorials` page and for the
/// overview that is generated when a module's tutorials have none.
public struct TutorialsOverview: Sendable, Equatable {
    /// One tutorial or article listed in a chapter.
    public struct Topic: Sendable, Equatable {
        /// The title of the topic.
        public var title: String
        /// The relative URL of the topic's page.
        public var url: String
        /// The estimated time to complete the topic, such as `20min`, if known.
        public var estimatedTime: String?
        /// Whether the topic is an article rather than a tutorial.
        public var isArticle: Bool
        /// The abstract of the topic as plain text, if known.
        public var abstract: String?

        /// Creates a topic.
        ///
        /// - Parameters:
        ///   - title: The title of the topic.
        ///   - url: The relative URL of the topic's page.
        ///   - estimatedTime: The estimated time to complete the topic, if known.
        ///   - isArticle: Whether the topic is an article rather than a tutorial.
        ///   - abstract: The abstract of the topic as plain text, if known.
        public init(title: String, url: String, estimatedTime: String? = nil, isArticle: Bool = false, abstract: String? = nil) {
            self.title = title
            self.url = url
            self.estimatedTime = estimatedTime
            self.isArticle = isArticle
            self.abstract = abstract
        }
    }

    /// One chapter of a volume.
    public struct Chapter: Sendable, Equatable {
        /// The name of the chapter.
        public var name: String
        /// The rendered HTML of the chapter's introduction.
        public var contentHTML: String
        /// The rendered HTML of the chapter's image, if any.
        public var imageHTML: String
        /// The topics of the chapter, in order.
        public var topics: [Topic]

        /// Creates a chapter.
        ///
        /// - Parameters:
        ///   - name: The name of the chapter.
        ///   - contentHTML: The rendered HTML of the chapter's introduction.
        ///   - imageHTML: The rendered HTML of the chapter's image, if any.
        ///   - topics: The topics of the chapter, in order.
        public init(name: String, contentHTML: String = "", imageHTML: String = "", topics: [Topic]) {
            self.name = name
            self.contentHTML = contentHTML
            self.imageHTML = imageHTML
            self.topics = topics
        }
    }

    /// A volume: an optionally named group of chapters.
    public struct Volume: Sendable, Equatable {
        /// The name of the volume, if it has one.
        public var name: String?
        /// The rendered HTML of the volume's introduction.
        public var contentHTML: String
        /// The rendered HTML of the volume's image, if any.
        public var imageHTML: String
        /// The chapters of the volume, in order.
        public var chapters: [Chapter]

        /// Creates a volume.
        ///
        /// - Parameters:
        ///   - name: The name of the volume, if it has one.
        ///   - contentHTML: The rendered HTML of the volume's introduction.
        ///   - imageHTML: The rendered HTML of the volume's image, if any.
        ///   - chapters: The chapters of the volume, in order.
        public init(name: String? = nil, contentHTML: String = "", imageHTML: String = "", chapters: [Chapter]) {
            self.name = name
            self.contentHTML = contentHTML
            self.imageHTML = imageHTML
            self.chapters = chapters
        }
    }

    /// The name of the technology the tutorials teach, shown in the navigation bar.
    public var technology: String
    /// The title of the hero.
    public var title: String
    /// The rendered HTML of the hero's introduction.
    public var contentHTML: String
    /// The total estimated time of all tutorials, such as `1hr 20min`, if known.
    public var estimatedTime: String?
    /// The title and relative URL of the hero's call to action, if any.
    public var action: (title: String, url: String)?
    /// The rendered HTML of the hero's image, if any.
    public var imageHTML: String
    /// The volumes, in order.
    public var volumes: [Volume]

    /// Creates the content of a tutorials overview page.
    ///
    /// - Parameters:
    ///   - technology: The name of the technology, shown in the navigation bar.
    ///   - title: The title of the hero.
    ///   - contentHTML: The rendered HTML of the hero's introduction.
    ///   - estimatedTime: The total estimated time of all tutorials, if known.
    ///   - action: The title and relative URL of the hero's call to action, if any.
    ///   - imageHTML: The rendered HTML of the hero's image, if any.
    ///   - volumes: The volumes, in order.
    public init(
        technology: String,
        title: String,
        contentHTML: String = "",
        estimatedTime: String? = nil,
        action: (title: String, url: String)? = nil,
        imageHTML: String = "",
        volumes: [Volume]
    ) {
        self.technology = technology
        self.title = title
        self.contentHTML = contentHTML
        self.estimatedTime = estimatedTime
        self.action = action
        self.imageHTML = imageHTML
        self.volumes = volumes
    }

    /// Returns whether two overviews have the same content.
    ///
    /// - Parameters:
    ///   - lhs: The first overview.
    ///   - rhs: The second overview.
    /// - Returns: `true` if all properties, including the call to action, are equal.
    public static func == (lhs: TutorialsOverview, rhs: TutorialsOverview) -> Bool {
        lhs.technology == rhs.technology && lhs.title == rhs.title && lhs.contentHTML == rhs.contentHTML
            && lhs.estimatedTime == rhs.estimatedTime && lhs.action?.title == rhs.action?.title
            && lhs.action?.url == rhs.action?.url && lhs.imageHTML == rhs.imageHTML && lhs.volumes == rhs.volumes
    }

    /// The chapters of all volumes, in order.
    var allChapters: [Chapter] { volumes.flatMap(\.chapters) }
}

// MARK: - Building from a Render Node

extension HTMLPageBuilder {
    /// Collects the content of a tutorials overview page from its render node.
    ///
    /// - Parameters:
    ///   - renderNode: The render node of a DocC `@Tutorials` page.
    ///   - references: The references of the render node.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The overview content.
    func tutorialsOverview(
        from renderNode: RenderNode,
        references: [String: any RenderReference],
        depth: Int
    ) -> TutorialsOverview {
        let hero = renderNode.sections.compactMap { $0 as? IntroRenderSection }.first
        let title = hero?.title ?? extractTitle(from: renderNode)
        var overview = TutorialsOverview(
            technology: renderNode.metadata.category ?? title,
            title: title,
            contentHTML: hero.map { renderBlocks($0.content, references: references, depth: depth) } ?? "",
            estimatedTime: renderNode.metadata.estimatedTime,
            action: hero?.action.flatMap { actionLink($0, references: references, depth: depth) },
            imageHTML: hero?.image.map { assetHTML($0, references: references, depth: depth) } ?? "",
            volumes: []
        )
        for volume in renderNode.sections.compactMap({ $0 as? VolumeRenderSection }) {
            let chapters = volume.chapters.map { chapter in
                TutorialsOverview.Chapter(
                    name: chapter.name ?? "",
                    contentHTML: renderBlocks(chapter.content, references: references, depth: depth),
                    imageHTML: chapter.image.map { assetHTML($0, references: references, depth: depth) } ?? "",
                    topics: chapter.tutorials.compactMap { identifier in
                        guard let reference = references[identifier.identifier] as? TopicRenderReference else {
                            return nil
                        }
                        let abstract = contentRenderer.renderInlineContent(reference.abstract, references: [:]).plainText
                        return TutorialsOverview.Topic(
                            title: reference.title,
                            url: makeRelativeURL(reference.url, depth: depth),
                            estimatedTime: reference.estimatedTime,
                            isArticle: reference.kind == .article,
                            abstract: abstract.isEmpty ? nil : abstract
                        )
                    }
                )
            }
            overview.volumes.append(TutorialsOverview.Volume(
                name: volume.name,
                contentHTML: volume.content.map { renderBlocks($0, references: references, depth: depth) } ?? "",
                imageHTML: volume.image.map { assetHTML($0, references: references, depth: depth) } ?? "",
                chapters: chapters
            ))
        }
        return overview
    }

    /// Builds a complete tutorials overview page from a render node.
    ///
    /// - Parameters:
    ///   - renderNode: The render node of a DocC `@Tutorials` page.
    ///   - references: The references of the render node.
    /// - Returns: The complete HTML document.
    func buildTutorialOverviewPage(from renderNode: RenderNode, references: [String: any RenderReference]) -> String {
        let depth = calculateDepth(for: renderNode)
        let overview = tutorialsOverview(from: renderNode, references: references, depth: depth)
        return buildTutorialsOverviewPage(
            overview,
            pageTitle: extractTitle(from: renderNode),
            description: extractDescription(from: renderNode, references: references),
            depth: depth
        )
    }
}

// MARK: - Markup

extension HTMLPageBuilder {
    /// Builds a complete tutorials overview page.
    ///
    /// The page reproduces swift-docc-render's tutorials overview: a dark navigation
    /// bar, a hero with the estimated time and a call to action, and the learning path
    /// with an in-page navigation column and one tile per chapter.  The chapter link
    /// of the in-page navigation is highlighted while its chapter is in view, using a
    /// scroll driven animation.
    ///
    /// - Parameters:
    ///   - overview: The content of the page.
    ///   - pageTitle: The title of the HTML document.
    ///   - description: The description of the HTML document, if any.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The complete HTML document.
    func buildTutorialsOverviewPage(
        _ overview: TutorialsOverview,
        pageTitle: String,
        description: String?,
        depth: Int
    ) -> String {
        let chapters = overview.allChapters
        let scope = chapters.indices.map { TutorialDocument.sectionTimeline($0) }.joined(separator: ", ")
        let scopeStyle = scope.isEmpty ? "" : " style=\"timeline-scope: \(scope)\""
        var html = tutorialPageHead(title: pageTitle, description: description, bodyClass: TutorialDocument.overviewPageClass, depth: depth)
        html += """

            <div class="\(TutorialDocument.overviewClass)"\(scopeStyle)>
        """
        html += tutorialsNavigationBar(
            technology: overview.technology,
            overviewURL: "index.html",
            classes: "theme-dark",
            menu: """
                <ul class="nav-menu-items">
                    <li class="nav-menu-item in-page-navigation">\(chapterNavigation(chapters, label: nil))</li>
                </ul>
            """,
            actions: true
        )
        html += """

                <main id="app-main" class="main" tabindex="0">
                    <div class="radial-gradient">
                        <section class="\(TutorialDocument.overviewHeroClass)">
                            <div class="copy-container">
                                <h1 class="title">\(escapeHTML(overview.title))</h1>
        """
        if !overview.contentHTML.isEmpty {
            html += "\n                    <div class=\"content\">\(overview.contentHTML)</div>"
        }
        if let time = overview.estimatedTime {
            html += """

                                <p class="meta">\(TutorialIcon.timer.svg())<span class="meta-content"><strong class="time">\(escapeHTML(time))</strong><span> \(TutorialDocument.Text.estimatedTime)</span></span></p>
            """
        }
        if let action = overview.action {
            html += """

                                <a href="\(escapeHTML(action.url))" class="\(TutorialDocument.buttonClass) is-dark">\(escapeHTML(action.title))</a>
            """
        }
        html += "\n                </div>"
        html += overview.imageHTML
        html += """

                        </section>
                    </div>
                    <div class="\(TutorialDocument.learningPathClass)">
                        <div class="main-container">
                            <div class="secondary-content-container">\(chapterNavigation(chapters, label: TutorialDocument.Text.onThisPage))</div>
                            <div class="primary-content-container">
                                <div class="content-sections-container">
        """
        var chapterIndex = 0
        for volume in overview.volumes {
            html += "\n                    <section class=\"volume content-section\">"
            if let name = volume.name {
                html += """

                                        <div class="volume-name">\(volume.imageHTML)<h2 class="name">\(escapeHTML(name))</h2>\(volume.contentHTML.isEmpty ? "" : "<div class=\"content\">\(volume.contentHTML)</div>")</div>
                """
            }
            for (number, chapter) in volume.chapters.enumerated() {
                html += chapterTile(chapter, number: number + 1, timeline: TutorialDocument.sectionTimeline(chapterIndex), volumeHasName: volume.name != nil)
                chapterIndex += 1
            }
            html += "\n                    </section>"
        }
        html += """

                                </div>
                            </div>
                        </div>
                    </div>
                </main>
            </div>
        """
        html += tutorialPageTail(depth: depth)
        return html
    }

    /// Builds the in-page navigation of a tutorials overview: one link per chapter.
    ///
    /// - Parameters:
    ///   - chapters: The chapters of the page, in order.
    ///   - label: The accessible label of the navigation, if any.
    /// - Returns: The `<nav class="tutorials-navigation">` element.
    func chapterNavigation(_ chapters: [TutorialsOverview.Chapter], label: String?) -> String {
        let labelAttribute = label.map { " aria-label=\"\(escapeHTML($0))\"" } ?? ""
        let links = chapters.enumerated().map { index, chapter in
            "<li style=\"\(TutorialDocument.sectionTimelineProperty): \(TutorialDocument.sectionTimeline(index))\"><a href=\"#\(escapeHTML(TutorialDocument.anchor(for: chapter.name)))\" class=\"tutorials-navigation-link\">\(escapeHTML(chapter.name))</a></li>"
        }.joined()
        return "<nav class=\"tutorials-navigation\"\(labelAttribute)><ol class=\"tutorials-navigation-list\"><li class=\"volume\"><ol class=\"tutorials-navigation-list\" aria-label=\"\(TutorialDocument.Text.chapters)\">\(links)</ol></li></ol></nav>"
    }

    /// Builds the tile of one chapter of a tutorials overview.
    ///
    /// Each topic shows its title and estimated time, like swift-docc-render, and
    /// carries its abstract in a hidden ``TutorialDocument/topicAbstractClass``
    /// element for themes that show it.
    ///
    /// - Parameters:
    ///   - chapter: The chapter.
    ///   - number: The one-based number of the chapter within its volume.
    ///   - timeline: The view timeline name that tracks whether the chapter is in view.
    ///   - volumeHasName: Whether the chapter's volume has a name, which makes the
    ///     chapter title a level 3 rather than a level 2 heading.
    /// - Returns: The `<section class="chapter tile">` element.
    func chapterTile(_ chapter: TutorialsOverview.Chapter, number: Int, timeline: String, volumeHasName: Bool) -> String {
        let heading = volumeHasName ? "h3" : "h2"
        let eyebrow = TutorialDocument.Text.chapter(number)
        var html = """

                                        <section class="\(TutorialDocument.chapterClass) tile" id="\(escapeHTML(TutorialDocument.anchor(for: chapter.name)))" tabindex="-1" style="\(TutorialDocument.sectionTimelineProperty): \(timeline)">
                                            <div class="info">\(chapter.imageHTML.isEmpty ? "<div class=\"asset\"></div>" : chapter.imageHTML)
                                                <div class="intro">
                                                    <\(heading) class="name" aria-label="\(escapeHTML(chapter.name)) - \(eyebrow)"><span class="eyebrow" aria-hidden="true">\(eyebrow)</span><span class="name-text" aria-hidden="true">\(escapeHTML(chapter.name))</span></\(heading)>
        """
        if !chapter.contentHTML.isEmpty {
            html += "\n                                    <div class=\"content\">\(chapter.contentHTML)</div>"
        }
        html += """

                                                </div>
                                            </div>
                                            <ol class="\(TutorialDocument.topicListClass)">
        """
        for topic in chapter.topics {
            let kind = topic.isArticle ? "article" : "tutorial"
            let icon = topic.isArticle ? TutorialIcon.article : TutorialIcon.tutorial
            var label = [topic.title, topic.isArticle ? TutorialDocument.Text.article : TutorialDocument.Text.tutorial]
            if let time = topic.estimatedTime {
                label.append("\(TutorialDocument.Text.spokenTime(time)) \(TutorialDocument.Text.estimatedTime)")
            }
            let timeClass = topic.estimatedTime == nil ? " no-time-estimate" : ""
            let timeHTML = topic.estimatedTime.map {
                "<div class=\"time\">\(TutorialIcon.timer.svg())<span class=\"time-label\">\(escapeHTML($0))</span></div>"
            } ?? ""
            let abstractHTML = topic.abstract.map {
                "<div class=\"\(TutorialDocument.topicAbstractClass)\">\(escapeHTML($0))</div>"
            } ?? ""
            html += """

                                                <li class="topic \(kind)\(timeClass)"><div class="topic-icon">\(icon.svg())</div><a href="\(escapeHTML(topic.url))" class="container" aria-label="\(escapeHTML(label.joined(separator: " - ")))"><div class="link">\(escapeHTML(topic.title))</div>\(abstractHTML)\(timeHTML)</a></li>
            """
        }
        html += """

                                            </ol>
                                        </section>
        """
        return html
    }
}
