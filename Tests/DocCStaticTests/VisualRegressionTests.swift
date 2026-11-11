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

    let mismatches: [Mismatch]
}

/// The results written by `nojs.mjs --json`.
private struct NoJavaScriptReport: Decodable {
    let page: String
    let checks: [String: Bool]
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
        let documentation = Set(FixturePage.all.filter { $0.kind == "documentation" }.map(\.id))
        for page in report where documentation.contains(page.page) {
            #expect(page.checks["sidebar"] == true, "\(page.page) has no working sidebar")
            #expect(page.checks["expandCollapse"] == true, "\(page.page) cannot expand and collapse rows")
        }
    }
}
