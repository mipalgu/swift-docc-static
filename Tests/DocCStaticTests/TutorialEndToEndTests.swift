//
// TutorialEndToEndTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing
@testable import DocCStatic

/// End-to-end tests that run the real generator on the fixture package and check
/// the markup of the tutorial pages and the tutorials overview page.
///
/// The markup follows swift-docc-render's tutorial components, and every interactive
/// part (menus, the step in focus, the quiz) is driven by HTML and CSS alone.
@Suite("Tutorial End-to-End Tests", .serialized)
struct TutorialEndToEndTests {
    /// The path of the first fixture tutorial in the generated output.
    static let tutorialPath = "tutorials/fixturecore/drawingpoints/index.html"

    /// The path of the second fixture tutorial in the generated output.
    static let secondTutorialPath = "tutorials/fixturecore/connectingpoints/index.html"

    /// The path of the tutorials overview page in the generated output.
    static let overviewPath = "tutorials/tutorials/index.html"

    /// Returns the number of occurrences of a string in the text.
    func count(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    @Test("Tutorial pages contain no scripts other than the shared appearance script",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func noTutorialScripts(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let html = try fixture.text(at: Self.tutorialPath)
        #expect(!html.contains("tutorial-dropdown-menu"))
        #expect(!html.contains("addEventListener('click', closeAllDropdowns)"))
    }

    @Test("The navigation bar has popover menus for tutorials and sections",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func navigationMenus(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let html = try fixture.text(at: Self.tutorialPath)
        #expect(html.contains("<nav id=\"nav\" class=\"\(TutorialDocument.navigationClass) nav--solid-background\""))
        #expect(html.contains("popovertarget=\"tutorial-menu\""))
        #expect(html.contains("id=\"tutorial-menu\" popover"))
        #expect(html.contains("popovertarget=\"section-menu\""))
        #expect(html.contains("id=\"section-menu\" popover"))
        #expect(html.contains("<li class=\"option option-active\"><a href=\"../../../tutorials/fixturecore/drawingpoints/index.html\" aria-current=\"page\">Drawing Points</a></li>"))
        #expect(html.contains("<a href=\"#Create-a-Canvas\">Create a Canvas</a>"))
        #expect(html.contains("<a href=\"#Check-Your-Understanding\">\(TutorialDocument.Text.checkYourUnderstanding)</a>"))
        #expect(html.contains("class=\"\(TutorialDocument.menuToggleClass)\" id=\"\(TutorialDocument.menuToggleClass)\""))
        #expect(html.contains("<label class=\"nav-menucta\" for=\"\(TutorialDocument.menuToggleClass)\""))
        #expect(html.contains(TutorialDocument.Text.sectionTracker(2, of: 3)))
        #expect(html.contains(TutorialDocument.Text.sectionTracker(3, of: 3)))
    }

    @Test("The hero shows the chapter, title, introduction, time and Xcode requirement",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func hero(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let html = try fixture.text(at: Self.tutorialPath)
        #expect(html.contains("id=\"introduction\" class=\"\(TutorialDocument.heroClass)\""))
        #expect(html.contains("<div class=\"hero dark\">"))
        #expect(html.contains("<div class=\"bg\" style=\"background-image: url("))
        #expect(html.contains("<span class=\"eyebrow\">Basics</span><h1 class=\"heading\">Drawing Points</h1>"))
        #expect(html.contains("<div class=\"duration\">5<div class=\"minutes\">mins</div></div>"))
        #expect(html.contains("aria-label=\"5 minutes Estimated Time\""))
        #expect(html.contains("href=\"https://developer.apple.com/download/\" class=\"content-link\">Xcode 16"))
    }

    @Test("Each step carries its own asset and has an item in the asset column",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func stepsAndAssets(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let html = try fixture.text(at: Self.tutorialPath)
        #expect(count(of: "<div class=\"\(TutorialDocument.stepContainerClass) step-", in: html) == 5)
        #expect(count(of: "<div class=\"\(TutorialDocument.stepMediaContainerClass)\">", in: html) == 5)
        #expect(count(of: "<div class=\"\(TutorialDocument.assetItemClass)\"", in: html) == 5)
        #expect(html.contains("timeline-scope: \(TutorialDocument.stepTimeline(0)), \(TutorialDocument.stepTimeline(1)), \(TutorialDocument.stepTimeline(2))"))
        #expect(html.contains("\(TutorialDocument.stepTimelineProperty): \(TutorialDocument.stepTimeline(0)); --tutorial-step-fill: backwards"))
        #expect(html.contains("\(TutorialDocument.stepTimelineProperty): \(TutorialDocument.stepTimeline(2)); --tutorial-step-fill: forwards"))
        #expect(html.contains("<div class=\"caption content\">"))
        #expect(html.contains("class=\"asset step-asset\""))
    }

    @Test("Code listings show file names, line numbers and the lines that changed",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func codeListings(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let html = try fixture.text(at: Self.tutorialPath)
        #expect(html.contains("<div class=\"\(TutorialDocument.codePreviewClass)\">"))
        #expect(html.contains("class=\"svg-icon swift-file-icon file-icon\""))
        #expect(html.contains("main.swift</span></span>"))
        #expect(html.contains("<span class=\"code-number\" data-line-number=\"1\"></span>"))
        #expect(html.contains("<span class=\"code-line-container highlighted\"><span class=\"code-number\" data-line-number=\"5\"></span>"))
        #expect(html.contains("popovertarget=\"section-1-step-2-code\""))
        #expect(html.contains("id=\"section-1-step-2-code\" popover"))
        #expect(html.contains("class=\"runtime-preview collapsed disabled\""))
    }

    @Test("The quiz keeps its state in form controls",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func quiz(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let html = try fixture.text(at: Self.tutorialPath)
        #expect(html.contains("class=\"\(TutorialDocument.assessmentsClass)\""))
        #expect(count(of: "<div class=\"assessment\">", in: html) == 2)
        #expect(html.contains(TutorialDocument.Text.question(1, of: 2)))
        #expect(count(of: "<label class=\"\(TutorialDocument.choiceClass)\"", in: html) == 5)
        #expect(count(of: "<label class=\"\(TutorialDocument.choiceClass)\" \(TutorialDocument.correctChoiceAttribute)>", in: html) == 2)
        #expect(html.contains("<input type=\"radio\" name=\"assessment-1\" value=\"0\">"))
        #expect(html.contains("<input type=\"checkbox\" class=\"\(TutorialDocument.choiceSubmissionClass)\" id=\"assessment-1-choice-1\">"))
        #expect(html.contains("<label class=\"\(TutorialDocument.buttonClass) check\" for=\"assessment-1-choice-1\">\(TutorialDocument.Text.submit)</label>"))
        #expect(html.contains("<input type=\"checkbox\" class=\"\(TutorialDocument.questionCompletionClass)\" id=\"assessment-2-completed\">"))
        #expect(html.contains("<label class=\"\(TutorialDocument.buttonClass) results\" for=\"assessment-2-completed\">\(TutorialDocument.Text.next)</label>"))
        #expect(html.contains("<div class=\"answer content\">\n        <p>A canvas collects the points added to it.</p></div>"))
        #expect(html.contains(TutorialDocument.Text.successMessage))
    }

    @Test("The call to action leads to the next tutorial",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func callToAction(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let html = try fixture.text(at: Self.tutorialPath)
        #expect(html.contains("<div class=\"\(TutorialDocument.callToActionClass)\">"))
        #expect(html.contains("<span class=\"label\">\(TutorialDocument.Text.next)</span><h2>Connecting Points</h2>"))
        #expect(html.contains("class=\"\(TutorialDocument.buttonClass)\">Get started</a>"))
        let second = try fixture.text(at: Self.secondTutorialPath)
        #expect(!second.contains("<div class=\"\(TutorialDocument.callToActionClass)\">"))
    }

    @Test("The tutorials overview is rendered from the table of contents",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func overview(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let html = try fixture.text(at: Self.overviewPath)
        #expect(html.contains("<body class=\"\(TutorialDocument.overviewPageClass)\""))
        #expect(html.contains("<nav id=\"nav\" class=\"\(TutorialDocument.navigationClass) theme-dark\""))
        #expect(html.contains("<h1 class=\"title\">Drawing with FixtureCore</h1>"))
        #expect(html.contains("<strong class=\"time\">15min</strong>"))
        #expect(html.contains("class=\"\(TutorialDocument.buttonClass) is-dark\">Get started</a>"))
        #expect(html.contains("<section class=\"\(TutorialDocument.chapterClass) tile\" id=\"basics\""))
        #expect(html.contains("<span class=\"eyebrow\" aria-hidden=\"true\">\(TutorialDocument.Text.chapter(1))</span>"))
        #expect(count(of: "<li class=\"topic tutorial\">", in: html) == 2)
        #expect(html.contains("<span class=\"time-label\">10min</span>"))
        #expect(html.contains("<a href=\"#basics\" class=\"tutorials-navigation-link\">Basics</a>"))
        #expect(!html.contains("Learn through hands-on tutorials"))
    }

    @Test("Tutorial pages share the footer and colour scheme toggle of documentation pages",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func sharedFooter(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let footer = ColourSchemeToggle.footerMarkup(content: Configuration.defaultFooter)
        for path in [Self.tutorialPath, Self.overviewPath] {
            let html = try fixture.text(at: path)
            #expect(html.contains(footer), "\(path) lacks the shared footer")
            #expect(count(of: "<footer", in: html) == 1, "\(path) has more than one footer")
            let body = html.components(separatedBy: "<body").dropFirst().first?.prefix { $0 != ">" } ?? ""
            #expect(body.contains(ColourSchemeToggle.bodyAttribute), "\(path) does not record the default scheme")
        }
        let css = try fixture.text(at: "css/main.css")
        for retired in [".documentation-footer", ".appearance-selector", ".appearance-btn"] {
            #expect(!css.contains(retired), "the stylesheet still styles \(retired)")
        }
    }
}

/// Tests of the names and texts shared by tutorial pages.
@Suite("Tutorial Document Names")
struct TutorialDocumentTests {
    @Test("Anchors are formed as swift-docc-render forms them",
          arguments: [
            ("Basics", "basics"),
            ("Ecore Metamodeling", "ecore-metamodeling"),
            ("  Two  Spaces ", "two-spaces"),
            ("Use `Canvas`", "use--canvas-"),
            ("<Generic>", "generic-"),
          ])
    func anchors(title: String, anchor: String) {
        #expect(TutorialDocument.anchor(for: title) == anchor)
    }

    @Test("Timeline names are unique dashed identifiers")
    func timelines() {
        #expect(TutorialDocument.stepTimeline(0) == "--tutorial-step-1")
        #expect(TutorialDocument.sectionTimeline(2) == "--tutorial-section-3")
    }

    @Test("Times are spelt out for assistive technologies")
    func spokenTimes() {
        #expect(TutorialDocument.Text.spokenTime("20min") == "20 minutes")
        #expect(TutorialDocument.Text.spokenTime("2hrs") == "2 hours")
        #expect(TutorialDocument.Text.fullMinutes(1) == "1 minute")
        #expect(TutorialDocument.Text.shortMinutes(5) == "mins")
    }

    @Test("Every icon is an SVG element hidden from assistive technologies",
          arguments: TutorialIcon.allCases)
    func icons(icon: TutorialIcon) {
        let svg = icon.svg("extra")
        #expect(svg.hasPrefix("<svg aria-hidden=\"true\" class=\"svg-icon \(icon.className) extra\""))
        #expect(svg.contains("<path d=\""))
        #expect(svg.hasSuffix("</svg>"))
    }
}
