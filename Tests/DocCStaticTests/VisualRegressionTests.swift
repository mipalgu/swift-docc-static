//
// VisualRegressionTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing

@testable import DocCStatic

/// The mismatches written by `run.mjs --json`.
private struct MismatchReport: Decodable {
    /// One computed value that differs from the golden data.
    struct Mismatch: Decodable {
        let role: String
        let property: String
        let expected: String
        let actual: String
        let page: String
        let viewport: String
        let scheme: String

        /// The known-issue key: the role and property.
        var key: String { "\(role).\(property)" }

        /// A one-line description with the place and both values.
        var summary: String {
            "\(role) / \(property): expected \(expected), actual \(actual) on \(page) at \(viewport) \(scheme)"
        }
    }

    /// The mismatches that are neither covered by an accepted deviation nor expected.
    let mismatches: [Mismatch]

    /// The accepted deviations that covered no mismatch, described in one line each.
    let unusedDeviations: [String]
}

/// The results written by `nojs.mjs --json`.
private struct NoJavaScriptReport: Decodable {
    let page: String
    let checks: [String: Bool]
    /// Whether answering a quiz question needed a Submit button, on pages with a quiz.
    let quizSubmit: Bool?
}

/// The results written by `onthispage.mjs --json`.
private struct OnThisPageReport: Decodable {
    let page: String
    let checks: [String: Bool]
    let failures: [String]
}

/// The results written by `navigator.mjs --json`.
private struct NavigatorReport: Decodable {
    let page: String
    let checks: [String: Bool]
}

/// The results written by `loading.mjs --json`.
private struct LoadingReport: Decodable {
    /// A transition or animation that started while a page loaded.
    struct Animation: Decodable {
        let name: String
        let count: Int
        let conditions: [String]
    }

    let page: String
    let loads: Int
    let animations: [Animation]
}

/// Checks the accepted deviations of every built-in theme without a browser.
@Suite("Accepted Deviations")
struct AcceptedDeviationTests {
    @Test("Every accepted deviation names a known role, property and condition, and a reason",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func deviationsAreWellFormed(theme: ThemeSettings.BuiltInTheme) throws {
        let roles = try #require(VisualRegressionHarness.json("roles.json") as? [String: Any])
        let harness = try #require(VisualRegressionHarness.json("harness.json") as? [String: Any])
        let measured = try #require(harness["properties"] as? [String])
        let variants = try #require(harness["variants"] as? [String])
        let pages = Set(FixturePage.all.map(\.id))
        let properties = Set(measured + ["*", "presence", "box.x", "box.width", "box.height", "text"])
        let viewports = Set(variants.compactMap { $0.split(separator: "/").first.map(String.init) })
        let schemes = Set(variants.compactMap { $0.split(separator: "/").last.map(String.init) })
        for deviation in try VisualRegressionHarness.acceptedDeviations(for: theme.rawValue) {
            let name = "\(deviation.role).\(deviation.property) for \(theme.rawValue)"
            #expect(deviation.role == "*" || roles[deviation.role] != nil, "\(name) names an unknown role")
            #expect(deviation.roles == nil || deviation.role == "*", "\(name) lists roles but names a role")
            for role in deviation.roles ?? [] {
                #expect(roles[role] != nil, "\(name) lists the unknown role \(role)")
            }
            #expect(properties.contains(deviation.property), "\(name) names an unmeasured property")
            #expect(Set(deviation.pages ?? []).isSubset(of: pages), "\(name) names an unknown page")
            #expect(Set(deviation.viewports ?? []).isSubset(of: viewports), "\(name) names an unknown viewport")
            #expect(Set(deviation.schemes ?? []).isSubset(of: schemes), "\(name) names an unknown scheme")
            #expect(deviation.reason.count > 20 && deviation.reason.hasSuffix("."), "\(name) gives no reason")
        }
    }

    @Test("The default theme accepts the clipped overflow of the tutorials overview volume")
    func defaultDeviations() throws {
        let deviations = try VisualRegressionHarness.acceptedDeviations(for: ThemeSettings.BuiltInTheme.default.rawValue)
        #expect(Set(deviations.map { "\($0.role).\($0.property)" }) == ["overviewVolume.overflowX", "overviewVolume.overflowY"])
        #expect(try VisualRegressionHarness.knownIssues(for: ThemeSettings.BuiltInTheme.default.rawValue).mismatches.isEmpty)
    }
}

/// Browser-based checks of the rendered fixture against golden reference data.
///
/// These tests run only when Node, playwright-core and a browser are available (see
/// ``VisualRegressionHarness/isAvailable``); otherwise they are skipped.  The golden data
/// of the `default` theme comes from swift-docc-render and that of
/// `docc-static-classic` from the main branch generator; see
/// `Tests/VisualRegression/README.md`.
@Suite(
    "Visual Regression",
    .serialized,
    .enabled(if: VisualRegressionHarness.isAvailable, "Needs Node, playwright-core and a browser")
)
struct VisualRegressionTests {
    @Test("Rendered roles match the golden data except for known issues",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func matchesGoldenData(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let results = try VisualRegressionHarness.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: results) }
        let reportFile = results.appendingPathComponent("mismatches.json")
        _ = try VisualRegressionHarness.runNode(
            script: "run.mjs",
            arguments: ["--theme", theme.rawValue, "--site", fixture.outputDirectory.path, "--json", reportFile.path]
        )
        let report = try JSONDecoder().decode(MismatchReport.self, from: Data(contentsOf: reportFile))
        var occurring: [String: String] = [:]
        for mismatch in report.mismatches where occurring[mismatch.key] == nil {
            let count = report.mismatches.filter { $0.key == mismatch.key }.count
            occurring[mismatch.key] = "\(count)x, first: \(mismatch.summary)"
        }
        VisualRegressionHarness.reconcile(
            occurring: occurring,
            known: try VisualRegressionHarness.knownIssues(for: theme.rawValue).mismatches,
            kind: "visual mismatches",
            listName: "mismatches",
            theme: theme.rawValue
        )
        for deviation in report.unusedDeviations {
            Issue.record("Accepted deviation \(deviation) covers no mismatch for \(theme.rawValue); remove it from accepted-deviations/\(theme.rawValue).json")
        }
    }

    @Test("Every page type works without JavaScript", arguments: ThemeSettings.BuiltInTheme.allCases)
    func worksWithoutJavaScript(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let results = try VisualRegressionHarness.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: results) }
        let reportFile = results.appendingPathComponent("nojs.json")
        _ = try VisualRegressionHarness.runNode(
            script: "nojs.mjs",
            arguments: ["--site", fixture.outputDirectory.path, "--json", reportFile.path]
        )
        let report = try JSONDecoder().decode([NoJavaScriptReport].self, from: Data(contentsOf: reportFile))
        #expect(report.count == FixturePage.all.count)
        for page in report {
            #expect(page.checks["content"] == true, "\(page.page) renders no content without JavaScript")
            for (check, passed) in page.checks.sorted(by: { $0.key < $1.key }) {
                #expect(passed, "\(check) fails on \(page.page) without JavaScript for \(theme.rawValue)")
            }
        }
        for page in report {
            for scheme in [ColourSchemeToggle.Scheme.light, .dark] {
                #expect(
                    page.checks["\(scheme.rawValue)Choice"] == true,
                    "\(page.page) does not show the \(scheme.label) colours when chosen without JavaScript"
                )
            }
        }
        // Like the main branch, classic reveals an answer's justification as soon as it
        // is chosen; like swift-docc-render, the default theme asks to submit it first
        let quizzes = report.filter { $0.quizSubmit != nil }
        #expect(!quizzes.isEmpty, "no page with a quiz was checked")
        for page in quizzes {
            #expect(page.quizSubmit == (theme == .default), "\(page.page) of \(theme.rawValue) has an unexpected Submit button")
        }
        // Like the main branch, classic lets the reader collapse nested groups; like
        // swift-docc-render, the default theme shows no group chevrons
        #expect(report.contains { $0.checks["groupCollapse"] != nil } == (theme == .classic),
                "group headings of \(theme.rawValue) do not collapse as expected")
        let documentation = Set(FixturePage.all.filter { $0.kind == "documentation" }.map(\.id))
        for page in report where documentation.contains(page.page) {
            #expect(page.checks["sidebar"] == true, "\(page.page) has no working sidebar")
            #expect(page.checks["expandCollapse"] == true, "\(page.page) cannot expand and collapse rows")
            #expect(page.checks["moduleTitle"] == true, "\(page.page) hides its row or the module title")
        }
    }

    @Test("A single module's pages match swift-docc-render like those of several modules")
    func singleModuleMatchesGoldenData() async throws {
        let theme = ThemeSettings.BuiltInTheme.default
        let fixture = try await FixtureDocumentation.shared.singleModuleOutput(theme: theme)
        let results = try VisualRegressionHarness.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: results) }
        let reportFile = results.appendingPathComponent("mismatches.json")
        _ = try VisualRegressionHarness.runNode(
            script: "run.mjs",
            arguments: ["--theme", theme.rawValue, "--site", fixture.outputDirectory.path, "--json", reportFile.path]
        )
        let report = try JSONDecoder().decode(MismatchReport.self, from: Data(contentsOf: reportFile))
        // The golden data compares a module's chevron with swift-docc-render's row
        // chevrons; like swift-docc-render, a single module's title has none
        let noModuleChevron = { (mismatch: MismatchReport.Mismatch) in
            mismatch.role == "sidebarModuleChevron" && mismatch.property == "presence" && mismatch.actual == "absent"
        }
        #expect(report.mismatches.contains(where: noModuleChevron), "the single module's title has a chevron")
        for mismatch in report.mismatches where !noModuleChevron(mismatch) {
            Issue.record("Single module: \(mismatch.summary)")
        }
        #expect(report.unusedDeviations.isEmpty)
    }

    @Test("The navigator scrolls to the current row only when it is not visible at the top",
          arguments: ThemeSettings.BuiltInTheme.allCases, [false, true])
    func navigatorScrollsLikeTheReference(theme: ThemeSettings.BuiltInTheme, singleModule: Bool) async throws {
        let fixture = singleModule
            ? try await FixtureDocumentation.shared.singleModuleOutput(theme: theme)
            : try await FixtureDocumentation.shared.output(theme: theme)
        let results = try VisualRegressionHarness.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: results) }
        let reportFile = results.appendingPathComponent("navigator.json")
        _ = try VisualRegressionHarness.runNode(
            script: "navigator.mjs",
            arguments: ["--site", fixture.outputDirectory.path, "--json", reportFile.path]
        )
        let report = try JSONDecoder().decode([NavigatorReport].self, from: Data(contentsOf: reportFile))
        let documentation = FixturePage.all.filter { $0.kind == "documentation" }
        #expect(report.count == documentation.count)
        #expect(report.contains { $0.checks["firstScreen"] != nil }, "no row fitted in the first screenful")
        #expect(report.contains { $0.checks["top"] != nil }, "no row needed scrolling")
        for page in report {
            for (check, passed) in page.checks.sorted(by: { $0.key < $1.key }) {
                #expect(passed, "\(check) fails on \(page.page) for \(theme.rawValue)")
            }
        }
    }

    @Test("Pages do not animate while they load, even when their stylesheets arrive late",
          arguments: ThemeSettings.BuiltInTheme.allCases, [false, true])
    func doesNotAnimateWhileLoading(theme: ThemeSettings.BuiltInTheme, singleModule: Bool) async throws {
        let fixture = singleModule
            ? try await FixtureDocumentation.shared.singleModuleOutput(theme: theme)
            : try await FixtureDocumentation.shared.output(theme: theme)
        let results = try VisualRegressionHarness.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: results) }
        let reportFile = results.appendingPathComponent("loading.json")
        _ = try VisualRegressionHarness.runNode(
            script: "loading.mjs",
            arguments: ["--site", fixture.outputDirectory.path, "--json", reportFile.path]
        )
        let report = try JSONDecoder().decode([LoadingReport].self, from: Data(contentsOf: reportFile))
        #expect(report.count == FixturePage.all.count)
        for page in report {
            #expect(page.loads > 0, "\(page.page) was not loaded")
            for animation in page.animations {
                Issue.record("\(animation.name) runs while \(page.page) loads for \(theme.rawValue) (\(animation.count) of \(page.loads) loads, first: \(animation.conditions.first ?? "unknown"))")
            }
        }
    }

    @Test("The \"On This Page\" column follows the section in view without JavaScript",
          arguments: ThemeSettings.BuiltInTheme.allCases)
    func onThisPageFollowsScrolling(theme: ThemeSettings.BuiltInTheme) async throws {
        let fixture = try await FixtureDocumentation.shared.output(theme: theme)
        let results = try VisualRegressionHarness.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: results) }
        let reportFile = results.appendingPathComponent("onthispage.json")
        _ = try VisualRegressionHarness.runNode(
            script: "onthispage.mjs",
            arguments: ["--site", fixture.outputDirectory.path, "--json", reportFile.path]
        )
        let report = try JSONDecoder().decode([OnThisPageReport].self, from: Data(contentsOf: reportFile))
        let hasColumn = !ThemeConfiguration(builtInTheme: theme).isEnabled(.onThisPageNavigatorDisabled)
        #expect(report.contains { $0.page == "article" } == hasColumn, "the article's column was not checked")
        for page in report {
            for (check, passed) in page.checks.sorted(by: { $0.key < $1.key }) {
                #expect(passed, "\(check) fails on \(page.page) for \(theme.rawValue): \(page.failures.joined(separator: "; "))")
            }
        }
    }
}
