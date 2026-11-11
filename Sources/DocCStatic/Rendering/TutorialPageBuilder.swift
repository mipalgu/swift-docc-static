//
// TutorialPageBuilder.swift
// DocCStatic
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation
import SwiftDocC

/// The English texts of tutorial pages, as swift-docc-render shows them.
public extension TutorialDocument {
    /// The fixed texts of tutorial and tutorials overview pages.
    enum Text {
        /// The subtitle shown after the technology name in the navigation bar.
        public static let tutorials = "Tutorials"
        /// The kind label of a tutorial.
        public static let tutorial = "Tutorial"
        /// The kind label of an article.
        public static let article = "Article"
        /// The label below an estimated time.
        public static let estimatedTime = "Estimated Time"
        /// The label of the project files download.
        public static let projectFiles = "Project files"
        /// The title of the first entry of the section menu.
        public static let introduction = "Introduction"
        /// The anchor of the hero section of a tutorial.
        public static let introductionAnchor = "introduction"
        /// The title of the assessments section.
        public static let checkYourUnderstanding = "Check Your Understanding"
        /// The legend of the answers of a question.
        public static let possibleAnswers = "Possible answers"
        /// The label of the button that submits an answer.
        public static let submit = "Submit"
        /// The label of the button that shows the next question.
        public static let nextQuestion = "Next question"
        /// The label of the call to action and of the button after the last question.
        public static let next = "Next"
        /// The message shown once all questions are answered.
        public static let successMessage = "Great job, you've answered all the questions for this tutorial."
        /// The label of a code preview without a runtime preview.
        public static let noPreview = "No Preview"
        /// The label of a code preview with a runtime preview.
        public static let preview = "Preview"
        /// The accessible label of the chapter list of the in-page navigation.
        public static let chapters = "Chapters"
        /// The accessible label of the in-page navigation of a tutorials overview.
        public static let onThisPage = "On this page"
        /// The accessible label of the button that opens the navigation menu.
        public static let openMenu = "Open Menu"
        /// The accessible label of the button that closes a full screen view.
        public static let close = "Close"
        /// The accessible label of the tutorial menu.
        public static let currentTutorial = "Current Tutorial"
        /// The accessible label of the section menu.
        public static let currentSection = "Current Section"

        /// Returns the eyebrow of a chapter, such as `Chapter 1`.
        ///
        /// - Parameter number: The one-based number of the chapter.
        /// - Returns: The eyebrow text.
        public static func chapter(_ number: Int) -> String { "Chapter \(number)" }

        /// Returns the eyebrow of a section, such as `Section 1`.
        ///
        /// - Parameter number: The one-based number of the section.
        /// - Returns: The eyebrow text.
        public static func section(_ number: Int) -> String { "Section \(number)" }

        /// Returns the label of a step, such as `Step 1`.
        ///
        /// - Parameter number: The one-based number of the step.
        /// - Returns: The label text.
        public static func step(_ number: Int) -> String { "Step \(number)" }

        /// Returns the progress of the assessments, such as `Question 1 of 2`.
        ///
        /// - Parameters:
        ///   - index: The one-based number of the question.
        ///   - total: The number of questions.
        /// - Returns: The progress text.
        public static func question(_ index: Int, of total: Int) -> String { "Question \(index) of \(total)" }

        /// Returns the section tracker of the section menu, such as `1 of 2`.
        ///
        /// - Parameters:
        ///   - number: The one-based number of the section.
        ///   - total: The number of sections.
        /// - Returns: The tracker text.
        public static func sectionTracker(_ number: Int, of total: Int) -> String { "\(number) of \(total)" }

        /// Returns the short unit of a number of minutes: `min` or `mins`.
        ///
        /// - Parameter minutes: The number of minutes.
        /// - Returns: The unit.
        public static func shortMinutes(_ minutes: Int) -> String { minutes == 1 ? "min" : "mins" }

        /// Returns a number of minutes for assistive technologies, such as `5 minutes`.
        ///
        /// - Parameter minutes: The number of minutes.
        /// - Returns: The spoken duration.
        public static func fullMinutes(_ minutes: Int) -> String { minutes == 1 ? "1 minute" : "\(minutes) minutes" }

        /// Returns an estimated time such as `20min` or `2hrs` for assistive technologies.
        ///
        /// - Parameter time: The estimated time as DocC writes it.
        /// - Returns: The time with spelt out units, such as `20 minutes`.
        public static func spokenTime(_ time: String) -> String {
            time.replacingOccurrences(of: "min", with: " minutes").replacingOccurrences(of: "hrs", with: " hours")
        }
    }
}

// MARK: - Tutorial Page

extension HTMLPageBuilder {
    /// One entry of the section menu of a tutorial page.
    struct TutorialPageSection {
        /// The title shown in the menu.
        var title: String
        /// The anchor of the section, without `#`.
        var anchor: String
        /// The one-based number shown in the section tracker, or `nil` for the introduction.
        var number: Int?
    }

    /// Builds a complete tutorial page.
    ///
    /// The page reproduces swift-docc-render's tutorial page: a navigation bar with a
    /// tutorial menu and a section menu, a dark hero, the sections with their
    /// introduction and steps, the assessments and a call to action.  Next to the
    /// steps, a sticky column shows the code or media of the step that is in focus;
    /// the step in focus is tracked with scroll driven animations.  Every step also
    /// carries its own code or media, which is shown below the step on narrow screens
    /// and in browsers without scroll driven animations.
    ///
    /// - Parameters:
    ///   - renderNode: The render node of the tutorial.
    ///   - references: The references of the render node.
    /// - Returns: The complete HTML document.
    func buildTutorialPage(from renderNode: RenderNode, references: [String: any RenderReference]) -> String {
        let depth = calculateDepth(for: renderNode)
        let sections = tutorialPageSections(of: renderNode)
        let scope = sections.indices.map { TutorialDocument.sectionTimeline($0) }.joined(separator: ", ")
        var html = tutorialPageHead(
            title: extractTitle(from: renderNode),
            description: extractDescription(from: renderNode),
            bodyClass: TutorialDocument.pageClass,
            depth: depth
        )
        html += "\n    <div class=\"\(TutorialDocument.tutorialClass)\" style=\"timeline-scope: \(scope)\">"
        html += tutorialNavigation(for: renderNode, sections: sections, references: references, depth: depth)
        html += "\n        <main id=\"app-main\" tabindex=\"0\">"
        var sectionIndex = 0
        for section in renderNode.sections {
            if let hero = section as? IntroRenderSection {
                html += tutorialHero(hero, renderNode: renderNode, timeline: TutorialDocument.sectionTimeline(sectionIndex), references: references, depth: depth)
                sectionIndex += 1
            } else if let tasks = section as? TutorialSectionsRenderSection {
                html += "\n            <div class=\"\(TutorialDocument.sectionsClass)\">"
                for (number, task) in tasks.tasks.enumerated() {
                    html += tutorialSection(task, number: number + 1, timeline: TutorialDocument.sectionTimeline(sectionIndex), references: references, depth: depth)
                    sectionIndex += 1
                }
                html += "\n            </div>"
            } else if let assessments = section as? TutorialAssessmentsRenderSection {
                html += tutorialAssessments(assessments, timeline: TutorialDocument.sectionTimeline(sectionIndex), references: references, depth: depth)
                sectionIndex += 1
            } else if let callToAction = section as? CallToActionSection {
                html += tutorialCallToAction(callToAction, references: references, depth: depth)
            }
        }
        html += "\n        </main>\n    </div>"
        html += tutorialPageTail(depth: depth)
        return html
    }

    /// Lists the sections of a tutorial page that the section menu offers.
    ///
    /// - Parameter renderNode: The render node of the tutorial.
    /// - Returns: The introduction, the numbered sections and the assessments, in order.
    func tutorialPageSections(of renderNode: RenderNode) -> [TutorialPageSection] {
        var sections: [TutorialPageSection] = []
        for section in renderNode.sections {
            if section is IntroRenderSection {
                sections.append(.init(title: TutorialDocument.Text.introduction, anchor: TutorialDocument.Text.introductionAnchor))
            } else if let tasks = section as? TutorialSectionsRenderSection {
                for (index, task) in tasks.tasks.enumerated() {
                    sections.append(.init(title: task.title, anchor: task.anchor, number: index + 1))
                }
            } else if let assessments = section as? TutorialAssessmentsRenderSection {
                let number = (sections.compactMap(\.number).max() ?? 0) + 1
                sections.append(.init(title: TutorialDocument.Text.checkYourUnderstanding, anchor: assessments.anchor, number: number))
            }
        }
        return sections
    }
}

// MARK: - Page Frame

extension HTMLPageBuilder {
    /// Builds the start of a tutorial or tutorials overview page, up to the opening `<body>` tag.
    ///
    /// - Parameters:
    ///   - title: The title of the document.
    ///   - description: The description of the document, if any.
    ///   - bodyClass: The class of the `<body>` element.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The HTML up to and including the `<body>` tag.
    func tutorialPageHead(title: String, description: String?, bodyClass: String, depth: Int) -> String {
        let cssPath = String(repeating: "../", count: depth) + "css/main.css"
        let descriptionTag = description.map { "\n    <meta name=\"description\" content=\"\(escapeHTML($0))\">" } ?? ""
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(escapeHTML(title))</title>\(descriptionTag)
            <link rel="stylesheet" href="\(cssPath)">
        </head>
        <body class="\(bodyClass)" \(ColourSchemeToggle.bodyAttribute)>
        """
    }

    /// Builds the end of a tutorial or tutorials overview page: the footer, the
    /// optional search scripts and the appearance selector script.
    ///
    /// - Parameter depth: The depth of the page in the output directory.
    /// - Returns: The HTML from the footer to the closing `</html>` tag.
    func tutorialPageTail(depth: Int) -> String {
        var html = buildFooter()
        if configuration.includeSearch {
            let prefix = String(repeating: "../", count: depth)
            html += """

                <script src="\(prefix)js/lunr.min.js" defer></script>
                <script src="\(prefix)js/search.js" defer></script>
            """
        }
        html += appearanceSelectorScript
        html += tutorialMenuScript
        html += "\n</body>\n</html>\n"
        return html
    }

    /// A progressive enhancement that closes the menus once the reader follows a link in them.
    ///
    /// The menus open and close without JavaScript, but following a link to a part of
    /// the same page cannot close them: neither a check box nor a popover reacts to a
    /// link.  Without this script the menus stay open until the reader closes them.
    var tutorialMenuScript: String {
        """

            <script>
            document.addEventListener('click', function (event) {
                var link = event.target.closest && event.target.closest('.\(TutorialDocument.navigationClass) a[href]');
                if (!link) { return; }
                var toggle = document.getElementById('\(TutorialDocument.menuToggleClass)');
                if (toggle) { toggle.checked = false; }
                var menu = link.closest('[popover]');
                if (menu && menu.hidePopover) { menu.hidePopover(); }
            });
            </script>
        """
    }

    /// Renders block content to HTML.
    ///
    /// - Parameters:
    ///   - blocks: The blocks to render.
    ///   - references: The references used to resolve links and media.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The concatenated HTML of the blocks.
    func renderBlocks(_ blocks: [RenderBlockContent], references: [String: any RenderReference], depth: Int) -> String {
        blocks.map { contentRenderer.renderBlockContent($0, references: references, depth: depth) }.joined()
    }

    /// Resolves the destination of a call to action.
    ///
    /// - Parameters:
    ///   - action: The inline reference of the call to action.
    ///   - references: The references used to resolve it.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The title and relative URL, or `nil` if the action is not a resolvable reference.
    func actionLink(
        _ action: RenderInlineContent,
        references: [String: any RenderReference],
        depth: Int
    ) -> (title: String, url: String)? {
        guard case .reference(let identifier, _, let overridingTitle, _) = action else { return nil }
        if let topic = references[identifier.identifier] as? TopicRenderReference {
            return (overridingTitle ?? topic.title, makeRelativeURL(topic.url, depth: depth))
        }
        if let link = references[identifier.identifier] as? LinkReference {
            return (overridingTitle ?? link.title, link.url)
        }
        return nil
    }

    /// Returns the light and dark variants of an asset, with their display scales.
    ///
    /// - Parameters:
    ///   - asset: The asset.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The `srcset` values of the light (or only) variant and of the dark variant, if any.
    func assetSourceSets(_ asset: DataAsset, depth: Int) -> (light: String, dark: String?) {
        func sourceSet(_ style: UserInterfaceStyle?) -> String {
            asset.variants
                .filter { $0.key.userInterfaceStyle == style }
                .sorted { ($0.key.displayScale?.rawValue ?? "") < ($1.key.displayScale?.rawValue ?? "") }
                .map { trait, url in
                    let path = url.absoluteString.hasPrefix("/") ? makeRelativeAssetURL(url.absoluteString, depth: depth) : url.absoluteString
                    return "\(path) \(trait.displayScale?.rawValue ?? "1x")"
                }
                .joined(separator: ", ")
        }
        let light = [sourceSet(.light), sourceSet(nil)].first { !$0.isEmpty } ?? sourceSet(.dark)
        let dark = sourceSet(.dark)
        return (light, dark.isEmpty || dark == light ? nil : dark)
    }

    /// Renders an image or video as swift-docc-render's asset component does.
    ///
    /// - Parameters:
    ///   - identifier: The reference of the image or video.
    ///   - references: The references used to resolve it.
    ///   - depth: The depth of the page in the output directory.
    ///   - classes: Further classes of the asset element.
    /// - Returns: A `<div class="asset">` element, or an empty string if the reference cannot be resolved.
    func assetHTML(
        _ identifier: RenderReferenceIdentifier,
        references: [String: any RenderReference],
        depth: Int,
        classes: String = ""
    ) -> String {
        let assetClass = classes.isEmpty ? "asset" : "asset \(classes)"
        if let image = references[identifier.identifier] as? ImageReference {
            let sets = assetSourceSets(image.asset, depth: depth)
            guard !sets.light.isEmpty else { return "" }
            let dark = sets.dark.map { "<source media=\"(prefers-color-scheme: dark)\" srcset=\"\(escapeHTML($0))\">" } ?? ""
            let src = sets.light.components(separatedBy: " ").first ?? ""
            return "<div class=\"\(assetClass)\"><picture>\(dark)<img decoding=\"async\" loading=\"lazy\" src=\"\(escapeHTML(src))\" srcset=\"\(escapeHTML(sets.light))\" alt=\"\(escapeHTML(image.altText ?? ""))\"></picture></div>"
        }
        if let video = references[identifier.identifier] as? VideoReference {
            let sets = assetSourceSets(video.asset, depth: depth)
            let src = sets.light.components(separatedBy: " ").first ?? ""
            guard !src.isEmpty else { return "" }
            let label = video.altText.map { " aria-label=\"\(escapeHTML($0))\"" } ?? ""
            return "<div class=\"\(assetClass)\"><video src=\"\(escapeHTML(src))\" muted playsinline controls preload=\"metadata\"\(label)></video></div>"
        }
        return ""
    }
}

// MARK: - Navigation Bar

extension HTMLPageBuilder {
    /// Builds the navigation bar shared by tutorial and tutorials overview pages.
    ///
    /// On narrow screens the menu folds into a tray that a hidden check box opens,
    /// so the menu works without JavaScript.
    ///
    /// - Parameters:
    ///   - technology: The name of the technology, shown as the title.
    ///   - overviewURL: The relative URL of the tutorials overview.
    ///   - classes: Further classes of the `<nav>` element.
    ///   - afterTitle: Markup between the title and the menu.
    ///   - menu: The markup of the menu tray.
    ///   - actions: Whether the bar has the button that opens the menu on narrow screens.
    /// - Returns: The `<nav>` element.
    func tutorialsNavigationBar(
        technology: String,
        overviewURL: String,
        classes: String,
        afterTitle: String = "",
        menu: String,
        actions: Bool
    ) -> String {
        let toggle = TutorialDocument.menuToggleClass
        let toggleInput = actions ? "<input type=\"checkbox\" class=\"\(toggle)\" id=\"\(toggle)\" aria-label=\"\(TutorialDocument.Text.openMenu)\">" : ""
        let actionsHTML = actions ? "<div class=\"nav-actions\"><label class=\"nav-menucta\" for=\"\(toggle)\" aria-hidden=\"true\"><span class=\"nav-menucta-chevron\"></span></label></div>" : ""
        return """

                <nav id="nav" class="\(TutorialDocument.navigationClass) \(classes)" aria-label="\(escapeHTML(technology))">\(toggleInput)
                    <div class="nav__wrapper">
                        <div class="nav__background"></div>
                        <div class="nav-overlay"></div>
                        <div class="nav-content">
                            <div class="nav-title"><a href="\(escapeHTML(overviewURL))" class="\(TutorialDocument.navigationTitleClass)"><span class="title">\(escapeHTML(technology))</span><span class="subhead">&nbsp;\(TutorialDocument.Text.tutorials)</span></a></div>\(afterTitle)
                            <div class="nav-menu">
                                <div class="nav-menu-tray">\(menu)</div>
                            </div>
                            \(actionsHTML)
                        </div>
                    </div>
                </nav>
        """
    }

    /// Builds the navigation bar of a tutorial page with its tutorial and section menus.
    ///
    /// The menus are popovers, so they open, close on Escape and close when the reader
    /// clicks elsewhere without JavaScript.  The section menu shows the title of the
    /// section in view, which is tracked with scroll driven animations.
    ///
    /// - Parameters:
    ///   - renderNode: The render node of the tutorial.
    ///   - sections: The sections the section menu offers.
    ///   - references: The references of the render node.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The `<nav>` element.
    func tutorialNavigation(
        for renderNode: RenderNode,
        sections: [TutorialPageSection],
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        let title = extractTitle(from: renderNode)
        var technology = renderNode.metadata.category ?? TutorialDocument.Text.tutorials
        var overviewURL = makeRelativeURL("/tutorials/tutorials", depth: depth)
        var chapters: [(title: String, tutorials: [(title: String, url: String, isCurrent: Bool)])] = []
        if case .tutorials(let hierarchy)? = renderNode.hierarchyVariants.defaultValue {
            if let root = hierarchy.paths.first?.first, let reference = references[root] as? TopicRenderReference {
                overviewURL = makeRelativeURL(reference.url, depth: depth)
                if renderNode.metadata.category == nil { technology = reference.title }
            }
            for chapter in hierarchy.modules ?? [] {
                let chapterTitle = (references[chapter.reference.identifier] as? TopicRenderReference)?.title
                    ?? chapter.reference.identifier.components(separatedBy: "/").last ?? ""
                let tutorials = chapter.tutorials.compactMap { tutorial -> (String, String, Bool)? in
                    guard let reference = references[tutorial.reference.identifier] as? TopicRenderReference else { return nil }
                    return (reference.title, makeRelativeURL(reference.url, depth: depth), reference.url.lowercased() == renderNode.identifier.path.lowercased())
                }
                if !tutorials.isEmpty { chapters.append((chapterTitle, tutorials)) }
            }
        }
        if chapters.isEmpty { chapters = [("", [(title, "index.html", true)])] }
        let numbered = sections.count - 1

        func sectionTitle(_ index: Int, _ section: TutorialPageSection) -> String {
            "<span class=\"tracked\" style=\"\(TutorialDocument.sectionTimelineProperty): \(TutorialDocument.sectionTimeline(index))\">\(escapeHTML(section.title))</span>"
        }
        let trackers = sections.enumerated().map { index, section in
            "<span class=\"tracked\" style=\"\(TutorialDocument.sectionTimelineProperty): \(TutorialDocument.sectionTimeline(index))\">\(section.number.map { TutorialDocument.Text.sectionTracker($0, of: numbered) } ?? "")</span>"
        }.joined()

        // Narrow screens: one list of chapters, tutorials and the current tutorial's sections
        var mobile = "<div class=\"mobile-dropdown-container\"><ul class=\"nav-menu-items mobile-dropdown\">"
        for chapter in chapters {
            mobile += "<li class=\"nav-menu-item chapter-list\" role=\"group\"><p class=\"chapter-name\">\(escapeHTML(chapter.title))</p><ul class=\"tutorial-list\">"
            for tutorial in chapter.tutorials {
                mobile += "<li class=\"tutorial-list-item\"><a href=\"\(escapeHTML(tutorial.url))\" class=\"option tutorial\(tutorial.isCurrent ? " router-link-active" : "")\"\(tutorial.isCurrent ? " aria-current=\"page\"" : "")>\(escapeHTML(tutorial.title))</a>"
                if tutorial.isCurrent {
                    mobile += "<ul class=\"section-list\">"
                    for (index, section) in sections.enumerated() {
                        mobile += "<li><a href=\"#\(escapeHTML(section.anchor))\" class=\"option section depth0\" style=\"\(TutorialDocument.sectionTimelineProperty): \(TutorialDocument.sectionTimeline(index))\">\(escapeHTML(section.title))</a></li>"
                    }
                    mobile += "</ul>"
                }
                mobile += "</li>"
            }
            mobile += "</ul></li>"
        }
        mobile += "</ul></div>"

        // Wide screens: the tutorial menu and the section menu
        var tutorialOptions = ""
        for chapter in chapters {
            tutorialOptions += "<li class=\"chapter-list\" role=\"group\"><p class=\"chapter-name\">\(escapeHTML(chapter.title))</p><ul>"
            for tutorial in chapter.tutorials {
                let active = tutorial.isCurrent ? " option-active" : ""
                let current = tutorial.isCurrent ? " aria-current=\"page\"" : ""
                tutorialOptions += "<li class=\"option\(active)\"><a href=\"\(escapeHTML(tutorial.url))\"\(current)>\(escapeHTML(tutorial.title))</a></li>"
            }
            tutorialOptions += "</ul></li>"
        }
        let sectionOptions = sections.enumerated().map { index, section in
            "<li class=\"option\" style=\"\(TutorialDocument.sectionTimelineProperty): \(TutorialDocument.sectionTimeline(index))\"><a href=\"#\(escapeHTML(section.anchor))\">\(escapeHTML(section.title))</a></li>"
        }.joined()
        let chevron = TutorialIcon.inlineChevronDown.svg("form-icon")
        let menus = """
            <div class="dropdown-container">\
            <div class="form-element dropdown-custom tutorial-dropdown primary-dropdown dropdown-small">\
            <button type="button" class="form-dropdown-toggle form-dropdown no-eyebrow" popovertarget="tutorial-menu" aria-label="\(TutorialDocument.Text.currentTutorial): \(escapeHTML(title))">\
            <span class="form-dropdown-title">\(escapeHTML(title))</span>\(chevron)</button>\
            <ul class="options form-dropdown-content" id="tutorial-menu" popover>\(tutorialOptions)</ul></div>\
            \(TutorialIcon.chevron.svg("icon-inline"))\
            <div class="form-element dropdown-custom tutorial-dropdown secondary-dropdown dropdown-small">\
            <button type="button" class="form-dropdown-toggle form-dropdown no-eyebrow" popovertarget="section-menu" aria-label="\(TutorialDocument.Text.currentSection)">\
            <span class="form-dropdown-title">\(sections.enumerated().map(sectionTitle).joined())</span>\
            <span class="section-tracker">\(trackers)</span>\(chevron)</button>\
            <ul class="options form-dropdown-content" id="section-menu" popover>\(sectionOptions)</ul></div>\
            </div>
            """
        return tutorialsNavigationBar(
            technology: technology,
            overviewURL: overviewURL,
            classes: "nav--solid-background",
            afterTitle: "\n                <div class=\"separator\"></div>",
            menu: mobile + menus,
            actions: true
        )
    }
}

// MARK: - Hero

extension HTMLPageBuilder {
    /// Builds the hero of a tutorial page.
    ///
    /// The background shows the light variant of the background image, like
    /// swift-docc-render; a dark variant is offered to themes in
    /// ``TutorialDocument/heroBackgroundDarkProperty``.
    ///
    /// - Parameters:
    ///   - hero: The hero section.
    ///   - renderNode: The render node of the tutorial.
    ///   - timeline: The view timeline name that tracks whether the hero is in view.
    ///   - references: The references of the render node.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The `<div class="tutorial-hero">` element.
    func tutorialHero(
        _ hero: IntroRenderSection,
        renderNode: RenderNode,
        timeline: String,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                    <div id="\(TutorialDocument.Text.introductionAnchor)" class="\(TutorialDocument.heroClass)" style="\(TutorialDocument.sectionTimelineProperty): \(timeline)">
                        <div class="hero dark">
        """
        if let background = hero.backgroundImage,
           let image = references[background.identifier] as? ImageReference {
            let sourceSets = assetSourceSets(image.asset, depth: depth)
            let url = sourceSets.light.components(separatedBy: " ").first ?? ""
            let darkURL = sourceSets.dark?.components(separatedBy: " ").first ?? ""
            let darkProperty = darkURL.isEmpty
                ? "" : "; \(TutorialDocument.heroBackgroundDarkProperty): url(&quot;\(escapeHTML(darkURL))&quot;)"
            if !url.isEmpty {
                html += "\n                <div class=\"bg\" style=\"background-image: url(&quot;\(escapeHTML(url))&quot;)\(darkProperty)\"></div>"
            }
        }
        html += """

                            <div class="row">
                                <div class="col large-7 medium-9 small-12">
                                    <div class="headline">\(hero.chapter.map { "<span class=\"eyebrow\">\(escapeHTML($0))</span>" } ?? "")<h1 class="heading">\(escapeHTML(hero.title))</h1></div>
        """
        if !hero.content.isEmpty {
            html += "\n                        <div class=\"\(TutorialDocument.heroIntroClass)\"><div class=\"content\">\(renderBlocks(hero.content, references: references, depth: depth))</div></div>"
        }
        html += "\n                        <div class=\"metadata\">"
        if let minutes = hero.estimatedTimeInMinutes {
            html += """
                <div class="item" aria-label="\(TutorialDocument.Text.fullMinutes(minutes)) \(TutorialDocument.Text.estimatedTime)">\
                <div class="content" aria-hidden="true"><div class="duration">\(minutes)<div class="minutes">\(TutorialDocument.Text.shortMinutes(minutes))</div></div></div>\
                <div class="bottom" aria-hidden="true">\(TutorialDocument.Text.estimatedTime)</div></div>
                """
        }
        if let files = hero.projectFiles, let download = references[files.identifier] as? DownloadReference {
            let url = download.url.absoluteString.hasPrefix("/") ? makeRelativeAssetURL(download.url.absoluteString, depth: depth) : download.url.absoluteString
            html += """
                <div class="item">\(TutorialIcon.download.svg("item-large-icon icon-inline"))\
                <div class="content bottom"><a class="content-link project-download" href="\(escapeHTML(url))">\(TutorialDocument.Text.projectFiles)\(TutorialIcon.download.svg("small-icon icon-inline"))</a></div></div>
                """
        }
        if let requirement = hero.xcodeRequirement,
           let xcode = references[requirement.identifier] as? XcodeRequirementReference {
            html += """
                <div class="item">\(TutorialIcon.xcode.svg("item-large-icon icon-inline"))\
                <div class="content bottom"><a href="\(escapeHTML(xcode.url.absoluteString))" class="content-link">\(escapeHTML(xcode.title))\(TutorialIcon.inlineChevronRight.svg("icon-inline small-icon xcode-icon"))</a></div></div>
                """
        }
        html += """
            </div>
                                </div>
                            </div>
                        </div>
                    </div>
            """
        return html
    }
}

// MARK: - Sections and Steps

extension HTMLPageBuilder {
    /// Builds one section of a tutorial: its introduction and its steps.
    ///
    /// - Parameters:
    ///   - task: The section.
    ///   - number: The one-based number of the section.
    ///   - timeline: The view timeline name that tracks whether the section is in view.
    ///   - references: The references of the render node.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The `<div class="section">` element.
    func tutorialSection(
        _ task: TutorialSectionsRenderSection.Section,
        number: Int,
        timeline: String,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var introContent: [RenderBlockContent] = []
        var media: RenderReferenceIdentifier?
        var expanded: [ContentLayout] = []
        for (index, layout) in task.contentSection.enumerated() {
            guard index == 0 else { expanded.append(layout); continue }
            switch layout {
            case .contentAndMedia(let section):
                introContent = section.content
                media = section.media
            case .fullWidth(let content):
                introContent = content
            case .columns:
                expanded.append(layout)
            }
        }
        var html = """

                    <div id="\(escapeHTML(task.anchor))" class="\(TutorialDocument.sectionClass)" style="\(TutorialDocument.sectionTimelineProperty): \(timeline)">
                        <div class="intro-container">
                            <div class="row intro intro-\(number)">
                                <div class="col left large-6 small-12">
                                    <div class="headline"><span class="eyebrow"><a href="#\(escapeHTML(task.anchor))">\(TutorialDocument.Text.section(number))</a></span><h2 class="heading">\(escapeHTML(task.title))</h2></div>
                                    <div class="content">\(renderBlocks(introContent, references: references, depth: depth))</div>
                                </div>
                                <div class="col right large-6 small-12">
                                    <div class="media">\(media.map { assetHTML($0, references: references, depth: depth) } ?? "")</div>
                                </div>
                            </div>
        """
        if !expanded.isEmpty {
            html += "\n                <div class=\"expanded-intro\">"
            for layout in expanded {
                html += buildContentLayout(layout, references: references, depth: depth)
            }
            html += "\n                </div>"
        }
        html += "\n                </div>"
        if !task.stepsSection.isEmpty {
            html += tutorialSteps(task.stepsSection, section: number, references: references, depth: depth)
        }
        html += "\n            </div>"
        return html
    }

    /// Builds the steps area of a section: the step column and the sticky asset column.
    ///
    /// Each step declares a named view timeline; the timeline names are scoped to the
    /// steps area, so the asset column can show the code or media of the step in focus.
    ///
    /// - Parameters:
    ///   - blocks: The steps and the content between them.
    ///   - section: The one-based number of the section, used for unique identifiers.
    ///   - references: The references of the render node.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The `<div class="steps">` element.
    func tutorialSteps(
        _ blocks: [RenderBlockContent],
        section: Int,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        let steps: [(index: Int, step: RenderBlockContent.TutorialStep)] = blocks.enumerated().compactMap { index, block in
            guard case .step(let step) = block else { return nil }
            return (index, step)
        }
        let scope = steps.indices.map { TutorialDocument.stepTimeline($0) }.joined(separator: ", ")
        var content = ""
        var assets = ""
        var stepNumber = 0
        for (index, block) in blocks.enumerated() {
            guard case .step(let step) = block else {
                content += "\n                    <div class=\"interstitial interstitial-\(index + 1)\">\(contentRenderer.renderBlockContent(block, references: references, depth: depth))</div>"
                continue
            }
            let fill = steps.count == 1 ? "both" : stepNumber == 0 ? "backwards" : stepNumber == steps.count - 1 ? "forwards" : "none"
            let timeline = "\(TutorialDocument.stepTimelineProperty): \(TutorialDocument.stepTimeline(stepNumber)); --tutorial-step-fill: \(fill)"
            stepNumber += 1
            let caption = step.caption.isEmpty ? "" : "<div class=\"caption content\">\(renderBlocks(step.caption, references: references, depth: depth))</div>"
            content += """

                                <div class="\(TutorialDocument.stepContainerClass) step-\(stepNumber)">
                                    <div class="\(TutorialDocument.stepClass)" data-index="\(index)" style="\(timeline)"><p class="step-label">\(TutorialDocument.Text.step(stepNumber))</p><div class="content">\(renderBlocks(step.content, references: references, depth: depth))</div>\(caption)</div>
                                    <div class="\(TutorialDocument.stepMediaContainerClass)">\(stepMedia(step, id: "section-\(section)-step-\(stepNumber)", references: references, depth: depth))</div>
                                </div>
            """
            if let code = step.code, let file = references[code.identifier] as? FileReference {
                assets += """

                                <div class="\(TutorialDocument.assetItemClass)" style="\(timeline)"><div class="asset-container-fade"><div class="\(TutorialDocument.codePreviewClass)"><div>\(codeListingHTML(file, references: references))</div>\(runtimePreview(step, references: references, depth: depth))</div></div></div>
                """
            } else if let media = step.media {
                assets += """

                                <div class="\(TutorialDocument.assetItemClass)" style="\(timeline)"><div class="asset-container-fade"><div class="asset-wrapper">\(assetHTML(media, references: references, depth: depth, classes: "step-asset"))</div></div></div>
                """
            }
        }
        return """

                        <div class="\(TutorialDocument.stepsClass)" style="timeline-scope: \(scope)">
                            <div class="content-container">\(content)
                            </div>
                            <div class="\(TutorialDocument.assetContainerClass)">\(assets)
                            </div>
                        </div>
        """
    }

    /// Builds a step's own code or media, shown below the step on narrow screens.
    ///
    /// Code is shown as an excerpt around the lines that changed since the previous
    /// step; the file name opens the complete file in a full screen popover.
    ///
    /// - Parameters:
    ///   - step: The step.
    ///   - id: An identifier unique on the page, used for the popover.
    ///   - references: The references of the render node.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The content of the step's media container.
    func stepMedia(
        _ step: RenderBlockContent.TutorialStep,
        id: String,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        if let code = step.code, let file = references[code.identifier] as? FileReference {
            let modalID = "\(id)-code"
            let preview = TutorialPreviewToggle(hasPreview: step.runtimePreview != nil)
            return """
                <div class="mobile-code-preview">\
                <div class="full-code-listing-modal"><div class="generic-modal modal-fullscreen modal-with-close theme-light" id="\(modalID)" popover role="dialog">\
                <div class="container"><button type="button" class="close" popovertarget="\(modalID)" popovertargetaction="hide" aria-label="\(TutorialDocument.Text.close)">\(TutorialIcon.close.svg())</button>\
                <div class="modal-content"><div class="full-code-listing-modal-content"><div>\(codeListingHTML(file, references: references, classes: "full-code-listing"))</div></div></div></div></div></div>\
                <div><div class="code-listing-preview" data-syntax="\(escapeHTML(file.syntax))">\(codeListingHTML(file, references: references, excerpt: true, fileNameTarget: modalID))</div></div>\
                <div class="preview-toggle-container">\(preview.html)</div></div>
                """
        }
        if let media = step.media {
            return assetHTML(media, references: references, depth: depth)
        }
        return ""
    }

    /// Builds the runtime preview control of a code preview.
    ///
    /// - Parameters:
    ///   - step: The step whose code is previewed.
    ///   - references: The references of the render node.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The `<div class="runtime-preview">` element.
    func runtimePreview(
        _ step: RenderBlockContent.TutorialStep,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        let icon = TutorialIcon.diagonalArrow.svg("icon-inline preview-icon")
        guard let preview = step.runtimePreview else {
            return "<div class=\"runtime-preview collapsed disabled\"><div class=\"runtimve-preview__container\"><button type=\"button\" class=\"header\" disabled title=\"No preview available for this step.\"><span class=\"runtime-preview-label\">\(TutorialDocument.Text.noPreview)</span>\(icon.replacingOccurrences(of: "preview-icon\"", with: "preview-icon preview-show\""))</button></div></div>"
        }
        return "<div class=\"runtime-preview\"><div class=\"runtimve-preview__container\"><span class=\"header\"><span class=\"runtime-preview-label\">\(TutorialDocument.Text.preview)</span>\(icon.replacingOccurrences(of: "preview-icon\"", with: "preview-icon preview-hide\""))</span><div class=\"runtime-preview-asset\">\(assetHTML(preview, references: references, depth: depth))</div></div></div>"
    }

    /// Builds a code listing as swift-docc-render's code listing component does.
    ///
    /// Each line is a `code-line-container` with its line number in a
    /// `data-line-number` attribute; lines that changed since the previous step are
    /// marked `highlighted`.
    ///
    /// - Parameters:
    ///   - file: The file to show.
    ///   - references: The references of the render node, used to find the file type.
    ///   - classes: Further classes of the code listing.
    ///   - excerpt: Whether to show only the lines around the first changed lines, as
    ///     the code preview below a step on narrow screens does.
    ///   - fileNameTarget: The identifier of a popover that the file name opens, if any.
    /// - Returns: The `<div class="code-listing">` element.
    func codeListingHTML(
        _ file: FileReference,
        references: [String: any RenderReference],
        classes: String = "",
        excerpt: Bool = false,
        fileNameTarget: String? = nil
    ) -> String {
        let highlighted = Set(file.highlights.map(\.line))
        var range = 1..<(file.content.count + 1)
        if excerpt, let first = highlighted.min() {
            var end = first
            while highlighted.contains(end + 1) { end += 1 }
            range = max(1, first - 2)..<min(file.content.count + 1, end + 3)
        }
        let highlighter = SwiftSyntaxHighlighter()
        let isSwift = file.syntax.lowercased() == "swift"
        var lines = ""
        for number in range {
            let line = file.content[number - 1]
            let code = line.isEmpty ? "\n" : (isSwift ? highlighter.highlight(line) : escapeHTML(line))
            let highlight = highlighted.contains(number) ? " highlighted" : ""
            lines += "<span class=\"code-line-container\(highlight)\"><span class=\"code-number\" data-line-number=\"\(number)\"></span><span class=\"code-line\">\(code)</span></span>\n"
        }
        let icon = (file.fileType == "swift" ? TutorialIcon.swiftFile : TutorialIcon.genericFile).svg("file-icon")
        let name = "\(icon)\(escapeHTML(file.fileName))"
        let fileName = fileNameTarget.map { "<button type=\"button\" class=\"filename-link\" popovertarget=\"\($0)\">\(name)</button>" } ?? "<span>\(name)</span>"
        var listingClasses = "code-listing"
        if !classes.isEmpty { listingClasses += " \(classes)" }
        if range.count == 1 { listingClasses += " single-line" }
        return "<div class=\"\(listingClasses)\" data-syntax=\"\(escapeHTML(file.syntax))\"><span class=\"filename\">\(fileName)</span><div class=\"container-general\"><pre><code>\(lines)</code></pre></div></div>"
    }
}

/// The runtime preview toggle shown below a step's code on narrow screens.
struct TutorialPreviewToggle {
    /// Whether the step has a runtime preview.
    var hasPreview: Bool

    /// The markup of the toggle.
    var html: String {
        if hasPreview {
            return "<span class=\"toggle-preview\"><span class=\"toggle-text\">\(TutorialDocument.Text.preview)\(TutorialIcon.inlinePlusCircle.svg("toggle-icon icon-inline"))</span></span>"
        }
        return "<span class=\"toggle-preview\"><span class=\"toggle-text\">\(TutorialDocument.Text.noPreview)</span></span>"
    }
}

// MARK: - Assessments and Call to Action

extension HTMLPageBuilder {
    /// Builds the assessments of a tutorial: one multiple choice question at a time.
    ///
    /// The quiz works without JavaScript.  A radio button selects an answer; a hidden
    /// check box inside each answer records that it was submitted, and the Submit
    /// button is a label for the check box of the selected answer.  A hidden check box
    /// per question records that the reader moved on, which hides the question and
    /// shows the next one, and finally the success message.
    ///
    /// - Parameters:
    ///   - section: The assessments section.
    ///   - timeline: The view timeline name that tracks whether the assessments are in view.
    ///   - references: The references of the render node.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The `<div class="assessments-wrapper">` element.
    func tutorialAssessments(
        _ section: TutorialAssessmentsRenderSection,
        timeline: String,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        var html = """

                    <div id="\(escapeHTML(section.anchor))" class="\(TutorialDocument.assessmentsClass)" style="\(TutorialDocument.sectionTimelineProperty): \(timeline)">
                        <div class="row assessments">
                            <div class="col large-10 medium-10 small-12 large-centered">
                                <div class="row banner"><div class="col large-10 large-centered"><h2 class="title">\(TutorialDocument.Text.checkYourUnderstanding)</h2></div></div>
        """
        let total = section.assessments.count
        for (index, assessment) in section.assessments.enumerated() {
            let question = "assessment-\(index + 1)"
            let isLast = index == total - 1
            html += """

                                <div class="assessment">
                                    <div class="row"><p class="title">\(TutorialDocument.Text.question(index + 1, of: total))</p></div>
                                    <div class="\(TutorialDocument.quizClass)">
                                        <div class="title content">\(renderBlocks(assessment.title, references: references, depth: depth))</div>
            """
            if let content = assessment.content {
                html += "\n                            <div class=\"question-content content\">\(renderBlocks(content, references: references, depth: depth))</div>"
            }
            html += "\n                            <fieldset class=\"choices\"><legend class=\"visuallyhidden\">\(TutorialDocument.Text.possibleAnswers)</legend>"
            var submitLabels = ""
            for (choiceIndex, choice) in assessment.choices.enumerated() {
                let submission = "\(question)-choice-\(choiceIndex + 1)"
                let correct = choice.isCorrect ? " \(TutorialDocument.correctChoiceAttribute)" : ""
                var answer = ""
                if let justification = choice.justification {
                    answer += "<div class=\"answer content\">\(renderBlocks(justification, references: references, depth: depth))</div>"
                }
                if let reaction = choice.reaction {
                    answer += "<p class=\"answer\">\(escapeHTML(reaction))</p>"
                }
                html += """

                                <label class="\(TutorialDocument.choiceClass)"\(correct)>\
                \(TutorialIcon.checkCircle.svg("choice-icon"))\(TutorialIcon.resetCircle.svg("choice-icon"))\
                <input type="radio" name="\(question)" value="\(choiceIndex)">\
                <input type="checkbox" class="\(TutorialDocument.choiceSubmissionClass)" id="\(submission)">\
                <div class="question content">\(renderBlocks(choice.content, references: references, depth: depth))</div>\
                \(answer)</label>
                """
                submitLabels += "<label class=\"\(TutorialDocument.buttonClass) check\" for=\"\(submission)\">\(TutorialDocument.Text.submit)</label>"
            }
            let completion = "\(question)-completed"
            let nextClass = isLast ? "results" : "next"
            let nextText = isLast ? TutorialDocument.Text.next : TutorialDocument.Text.nextQuestion
            html += """

                                        </fieldset>
                                        <div class="controls">\
                <span class="\(TutorialDocument.buttonClass) check" aria-disabled="true">\(TutorialDocument.Text.submit)</span>\(submitLabels)\
                <span class="\(TutorialDocument.buttonClass) \(nextClass)" aria-disabled="true">\(nextText)</span>\
                <input type="checkbox" class="\(TutorialDocument.questionCompletionClass)" id="\(completion)">\
                <label class="\(TutorialDocument.buttonClass) \(nextClass)" for="\(completion)">\(nextText)</label></div>
                                    </div>
                                </div>
            """
        }
        html += """

                                <div class="success" role="status"><p>\(TutorialDocument.Text.successMessage)</p></div>
                            </div>
                        </div>
                    </div>
        """
        return html
    }

    /// Builds the call to action at the end of a tutorial, which leads to the next tutorial.
    ///
    /// - Parameters:
    ///   - section: The call to action section.
    ///   - references: The references of the render node.
    ///   - depth: The depth of the page in the output directory.
    /// - Returns: The `<div class="call-to-action">` element.
    func tutorialCallToAction(
        _ section: CallToActionSection,
        references: [String: any RenderReference],
        depth: Int
    ) -> String {
        let abstract = section.abstract.isEmpty ? "" : "<div class=\"description content\"><p>\(contentRenderer.renderInlineContent(section.abstract, references: references, depth: depth).html)</p></div>"
        let button = actionLink(section.action, references: references, depth: depth).map {
            "<a href=\"\(escapeHTML($0.url))\" class=\"\(TutorialDocument.buttonClass)\">\(escapeHTML($0.title))</a>"
        } ?? ""
        let media = section.media.map { assetHTML($0, references: references, depth: depth, classes: "media") } ?? ""
        return """

                    <div class="\(TutorialDocument.callToActionClass)">
                        <div class="row">
                            <div class="col large-5 small-12"><span class="label">\(TutorialDocument.Text.next)</span><h2>\(escapeHTML(section.title))</h2>\(abstract)\(button)</div>
                            <div class="col right-column large-6 small-12">\(media)</div>
                        </div>
                    </div>
        """
    }
}
