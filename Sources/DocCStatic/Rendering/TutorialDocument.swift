//
// TutorialDocument.swift
// DocCStatic
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// The names shared by the generated tutorial pages, their stylesheets and tests.
///
/// Tutorial pages and the tutorials overview page reproduce the markup of
/// swift-docc-render's tutorial components, so that the same class names select the
/// same parts in both renderers.  The interactive parts of a tutorial (the step that
/// is in focus, the code or media shown next to the steps, the quiz and the menus)
/// work without JavaScript: they are driven by form controls, popovers and scroll
/// driven animations that the stylesheet refers to by the names defined here.
///
/// This type is the single authoritative home of the names that the Swift code and
/// the tests must agree on.  The stylesheets in `Stylesheets/7x-*.css` use the same
/// literal names.
public enum TutorialDocument {}

// MARK: - Page Classes

public extension TutorialDocument {
    /// The class of the `<body>` element of a tutorial page.
    static let pageClass = "tutorial-page"

    /// The class of the `<body>` element of a tutorials overview page.
    static let overviewPageClass = "tutorial-overview-page"

    /// The class of the element that wraps a tutorial page below the `<body>`.
    static let tutorialClass = "tutorial"

    /// The class of the element that wraps a tutorials overview page below the `<body>`.
    static let overviewClass = "tutorials-overview"

    /// The class of the navigation bar of tutorial and tutorials overview pages.
    static let navigationClass = "nav"

    /// The class of a navigation bar's title link, whose first child holds the technology name.
    static let navigationTitleClass = "nav-title-content"
}

// MARK: - Tutorial Parts

public extension TutorialDocument {
    /// The class of the hero section that introduces a tutorial.
    static let heroClass = "tutorial-hero"

    /// The class of the element that holds a tutorial's introduction text in the hero.
    static let heroIntroClass = "intro"

    /// The class of the container of a tutorial's sections.
    static let sectionsClass = "sections"

    /// The class of one tutorial section.
    static let sectionClass = "section"

    /// The class of the steps area of a section, which holds the step column and the asset column.
    static let stepsClass = "steps"

    /// The class of the element that wraps one step and its own asset.
    static let stepContainerClass = "step-container"

    /// The class of the card that describes one step.
    static let stepClass = "step"

    /// The class of the per-step container of a step's code or media.
    ///
    /// Every step carries its own asset in document order inside this container.
    static let stepMediaContainerClass = "media-container"

    /// The class of the sticky column that shows the asset of the step in focus.
    static let assetContainerClass = "asset-container"

    /// The class of an item of the asset column: the code or media of one step.
    ///
    /// The item is shown while its step is in focus.
    static let assetItemClass = "asset-container-item"

    /// The class of the code preview shown in the asset column.
    static let codePreviewClass = "code-preview"

    /// The class of the assessments section.
    static let assessmentsClass = "assessments-wrapper"

    /// The class of one multiple choice question.
    static let quizClass = "quiz"

    /// The class of one answer of a multiple choice question.
    static let choiceClass = "choice"

    /// The class of the call to action that leads to the next tutorial.
    static let callToActionClass = "call-to-action"

    /// The class of buttons and links styled as a call to action button.
    static let buttonClass = "button-cta"
}

// MARK: - Tutorials Overview Parts

public extension TutorialDocument {
    /// The class of the hero section of a tutorials overview page.
    static let overviewHeroClass = "hero"

    /// The class of the section below the hero that lists the volumes and chapters.
    static let learningPathClass = "learning-path"

    /// The class of one chapter tile of a tutorials overview page.
    static let chapterClass = "chapter"

    /// The class of the list of tutorials and articles of a chapter.
    static let topicListClass = "topic-list"

    /// The class of the hidden abstract of a tutorial or article in a chapter's list,
    /// for themes that show it.
    static let topicAbstractClass = "topic-abstract"
}

// MARK: - State Without JavaScript

public extension TutorialDocument {
    /// The custom property that holds the name of the view timeline of a step.
    ///
    /// Each step and each asset of the asset column declare this property inline, so
    /// that the asset of a step is shown while the step is in focus.
    static let stepTimelineProperty = "--tutorial-step-timeline"

    /// The prefix of the view timeline names of the steps of a section.
    static let stepTimelinePrefix = "--tutorial-step-"

    /// The custom property that holds the name of the view timeline of a page section.
    static let sectionTimelineProperty = "--tutorial-section-timeline"

    /// The prefix of the view timeline names of the sections of a tutorial page or the
    /// chapters of a tutorials overview page.
    static let sectionTimelinePrefix = "--tutorial-section-"

    /// The class of the hidden check box that records that a choice was submitted.
    static let choiceSubmissionClass = "choice-submitted"

    /// The class of the hidden check box that records that a question was completed.
    static let questionCompletionClass = "question-completed"

    /// The attribute that marks a correct choice of a question.
    static let correctChoiceAttribute = "data-correct"

    /// The class of the hidden check box that opens the navigation menu on narrow screens.
    static let menuToggleClass = "nav-menu-toggle"

    /// Returns the view timeline name of a step.
    ///
    /// - Parameter index: The zero-based index of the step within its section.
    /// - Returns: A dashed identifier unique within the section.
    static func stepTimeline(_ index: Int) -> String { "\(stepTimelinePrefix)\(index + 1)" }

    /// Returns the view timeline name of a page section or chapter.
    ///
    /// - Parameter index: The zero-based index of the section on its page.
    /// - Returns: A dashed identifier unique within the page.
    static func sectionTimeline(_ index: Int) -> String { "\(sectionTimelinePrefix)\(index + 1)" }

    /// Returns the anchor of a chapter or section title, as swift-docc-render forms it.
    ///
    /// White space and the characters `` ` ``, `"`, `<` and `>` become dashes, leading
    /// dashes are removed and the result is lowercased.
    ///
    /// - Parameter title: The title to form an anchor for.
    /// - Returns: The anchor, without a leading `#`.
    static func anchor(for title: String) -> String {
        var anchor = ""
        var previousWasSpace = false
        for character in title.trimmingCharacters(in: .whitespacesAndNewlines) {
            if character.isWhitespace {
                if !previousWasSpace { anchor.append("-") }
                previousWasSpace = true
                continue
            }
            previousWasSpace = false
            anchor.append("`\"<>".contains(character) ? "-" : character)
        }
        return String(anchor.drop(while: { $0 == "-" })).lowercased()
    }
}

// MARK: - Icons

/// The icons of tutorial pages, drawn as swift-docc-render draws them.
///
/// Each icon is an inline SVG element that is hidden from assistive technologies,
/// with the classes swift-docc-render gives it.
public enum TutorialIcon: String, CaseIterable, Sendable {
    /// A clock, shown next to estimated times.
    case timer
    /// A tutorial, shown in the chapter lists of the tutorials overview.
    case tutorial
    /// An article, shown in the chapter lists of the tutorials overview.
    case article
    /// A chevron pointing right, shown between the menus of the navigation bar.
    case chevron
    /// A small chevron pointing down, shown in menus.
    case inlineChevronDown
    /// A small chevron pointing right, shown after the Xcode requirement.
    case inlineChevronRight
    /// The Xcode icon, shown with the Xcode requirement.
    case xcode
    /// A download icon, shown with the project files.
    case download
    /// The Swift file icon, shown in front of the name of a Swift file.
    case swiftFile
    /// A generic file icon, shown in front of the name of other files.
    case genericFile
    /// A diagonal arrow, shown in the runtime preview toggle.
    case diagonalArrow
    /// A circle with a check mark, shown on a correct answer.
    case checkCircle
    /// A circle with a cross, shown on an incorrect answer.
    case resetCircle
    /// A circle with a plus sign, shown in the mobile preview toggle.
    case inlinePlusCircle
    /// A cross, shown in the button that closes a full screen view.
    case close

    /// The class swift-docc-render gives the icon, in addition to `svg-icon`.
    public var className: String {
        switch self {
        case .timer: "timer-icon"
        case .tutorial: "tutorial-icon"
        case .article: "article-icon"
        case .chevron: "chevron-icon"
        case .inlineChevronDown: "inline-chevron-down-icon"
        case .inlineChevronRight: "inline-chevron-right-icon"
        case .xcode: "xcode-icon"
        case .download: "download-icon"
        case .swiftFile: "swift-file-icon"
        case .genericFile: "generic-file-icon"
        case .diagonalArrow: "diagonal-arrow"
        case .checkCircle: "check-circle-icon"
        case .resetCircle: "reset-circle-icon"
        case .inlinePlusCircle: "inline-plus-circle-icon"
        case .close: "close-icon"
        }
    }

    /// The `viewBox` of the icon.
    var viewBox: String { self == .swiftFile ? "0 0 15 14" : "0 0 14 14" }

    /// The path data of the icon.
    var paths: [String] {
        let circle = "M7 0.5c3.59 0 6.5 2.91 6.5 6.5s-2.91 6.5-6.5 6.5c-3.59 0-6.5-2.91-6.5-6.5v0c0-3.59 2.91-6.5 6.5-6.5v0zM7 1.5c-3.038 0-5.5 2.462-5.5 5.5s2.462 5.5 5.5 5.5c3.038 0 5.5-2.462 5.5-5.5v0c0-3.038-2.462-5.5-5.5-5.5v0z"
        let page = [
            "M8.033 1l3.967 4.015v7.985h-10v-12zM7.615 2h-4.615v10h8v-6.574z",
            "M7 1h1v4h-1z",
            "M7 5h5v1h-5z",
        ]
        switch self {
        case .timer:
            return [
                "M7 0.5c3.59 0 6.5 2.91 6.5 6.5s-2.91 6.5-6.5 6.5c-3.59 0-6.5-2.91-6.5-6.5v0c0-3.59 2.91-6.5 6.5-6.5v0zM7 2c-2.761 0-5 2.239-5 5s2.239 5 5 5c2.761 0 5-2.239 5-5v0c0-2.761-2.239-5-5-5v0z",
                "M6.51 3.51h1.5v3.5h-1.5v-3.5z",
                "M6.51 7.010h4v1.5h-4v-1.5z",
            ]
        case .tutorial:
            return [
                "M0.933 6.067h3.733v1.867h-3.733v-1.867z",
                "M0.933 1.867h3.733v1.867h-3.733v-1.867z",
                "M13.067 1.867v10.267h-7.467v-10.267zM12.133 2.8h-5.6v8.4h5.6z",
                "M0.933 10.267h3.733v1.867h-3.733v-1.867z",
            ]
        case .article, .genericFile:
            return page
        case .chevron:
            return ["M3.22 1.184l0.325-0.38 7.235 6.201-7.235 6.19-0.325-0.38 6.792-5.811-6.792-5.82z"]
        case .inlineChevronDown:
            return ["M12.634 2.964l0.76 0.649-6.343 7.426-6.445-7.423 0.755-0.655 5.683 6.545 5.59-6.542z"]
        case .inlineChevronRight:
            return ["M2.964 1.366l0.649-0.76 7.426 6.343-7.423 6.445-0.655-0.755 6.545-5.683-6.542-5.59z"]
        case .xcode:
            return [
                "M2.668 4.452l-1.338-2.229 0.891-0.891 2.229 1.338 1.338 2.228 3.667 3.666 0.194-0.194 2.933 2.933c0.13 0.155 0.209 0.356 0.209 0.576 0 0.497-0.403 0.9-0.9 0.9-0.22 0-0.421-0.079-0.577-0.209l0.001 0.001-2.934-2.933 0.181-0.181-3.666-3.666z",
                "M11.824 1.277l-0.908 0.908c-0.091 0.091-0.147 0.216-0.147 0.354 0 0.106 0.033 0.205 0.090 0.286l-0.001-0.002 0.058 0.069 0.185 0.185c0.090 0.090 0.215 0.146 0.353 0.146 0.107 0 0.205-0.033 0.286-0.090l-0.002 0.001 0.069-0.057 0.909-0.908c0.118 0.24 0.187 0.522 0.187 0.82 0 1.045-0.848 1.893-1.893 1.893-0.296 0-0.577-0.068-0.826-0.189l0.011 0.005-5.5 5.5c0.116 0.238 0.184 0.518 0.184 0.813 0 1.045-0.848 1.893-1.893 1.893-0.296 0-0.576-0.068-0.826-0.189l0.011 0.005 0.908-0.909c0.090-0.090 0.146-0.215 0.146-0.353 0-0.107-0.033-0.205-0.090-0.286l0.001 0.002-0.057-0.069-0.185-0.185c-0.091-0.091-0.216-0.147-0.354-0.147-0.106 0-0.205 0.033-0.286 0.090l0.002-0.001-0.069 0.058-0.908 0.908c-0.116-0.238-0.184-0.518-0.184-0.813 0-1.045 0.847-1.892 1.892-1.892 0.293 0 0.571 0.067 0.819 0.186l-0.011-0.005 5.5-5.5c-0.116-0.238-0.184-0.519-0.184-0.815 0-1.045 0.847-1.892 1.892-1.892 0.296 0 0.577 0.068 0.827 0.19l-0.011-0.005z",
            ]
        case .download:
            return [
                "M7 0.5c3.59 0 6.5 2.91 6.5 6.5s-2.91 6.5-6.5 6.5c-3.59 0-6.5-2.91-6.5-6.5s2.91-6.5 6.5-6.5zM7 1.5c-3.038 0-5.5 2.462-5.5 5.5s2.462 5.5 5.5 5.5c3.038 0 5.5-2.462 5.5-5.5s-2.462-5.5-5.5-5.5z",
                "M7.51 2.964l-0.001 5.431 1.308-2.041 0.842 0.539-2.664 4.162-2.633-4.164 0.845-0.534 1.303 2.059 0.001-5.452z",
            ]
        case .swiftFile:
            return ["M14.93,13.56A2.15,2.15,0,0,0,15,13a5.37,5.37,0,0,0-1.27-3.24A6.08,6.08,0,0,0,14,7.91,9.32,9.32,0,0,0,9.21.31a8.51,8.51,0,0,1,1.78,5,6.4,6.4,0,0,1-.41,2.18A45.06,45.06,0,0,1,3.25,1.54,44.57,44.57,0,0,0,7.54,6.9,45.32,45.32,0,0,1,1.47,2.32,35.69,35.69,0,0,0,8.56,9.94a6.06,6.06,0,0,1-3.26.85A9.48,9.48,0,0,1,0,8.91a10,10,0,0,0,8.1,4.72c2.55,0,3.25-1.2,4.72-1.2a2.09,2.09,0,0,1,1.91,1.15C14.79,13.69,14.88,13.75,14.93,13.56Z"]
        case .diagonalArrow:
            return ["M0.010 12.881l10.429-10.477-3.764 0.824-0.339-1.549 7.653-1.679-1.717 7.622-1.546-0.349 0.847-3.759-10.442 10.487z"]
        case .checkCircle:
            return [circle, "M9.626 3.719l0.866 0.5-3.5 6.062-3.464-2 0.5-0.866 2.6 1.5z"]
        case .resetCircle:
            return [circle, "M3.828 4.539l0.707-0.707 5.657 5.657-0.707 0.707-5.657-5.657z", "M3.828 9.489l5.657-5.657 0.707 0.707-5.657 5.657-0.707-0.707z"]
        case .inlinePlusCircle:
            return [circle, "M4 6.52h6v1h-6v-1z", "M6.5 4.010h1v6h-1v-6z"]
        case .close:
            return ["M12.73,0l1.27,1.27-5.74,5.73,5.72,5.72-1.27,1.27-5.72-5.72L1.28,13.99,.01,12.72,5.72,7.01,0,1.28,1.27,.01,6.99,5.73,12.73,0Z"]
        }
    }

    /// Returns the icon as an inline SVG element.
    ///
    /// - Parameter classes: Further classes of the icon, such as `icon-inline`.
    /// - Returns: The `<svg>` element, hidden from assistive technologies.
    public func svg(_ classes: String = "") -> String {
        let extra = classes.isEmpty ? "" : " \(classes)"
        let body = paths.map { "<path d=\"\($0)\"></path>" }.joined()
        return "<svg aria-hidden=\"true\" class=\"svg-icon \(className)\(extra)\" xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"\(viewBox)\">\(body)</svg>"
    }
}
