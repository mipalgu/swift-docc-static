//
// ConfigurationTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Testing
import Foundation
@testable import DocCStatic

@Suite("Configuration Tests")
struct ConfigurationTests {
    @Test("Default configuration has expected values")
    func defaultConfiguration() {
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp/package"),
            outputDirectory: URL(fileURLWithPath: "/tmp/output")
        )

        #expect(config.targets.isEmpty)
        #expect(config.dependencyPolicy == .all)
        #expect(config.externalDocumentationURLs.isEmpty)
        #expect(config.includeSearch == false)
        #expect(config.isVerbose == false)
    }

    @Test("Custom configuration preserves values")
    func customConfiguration() {
        let externalURL = URL(string: "https://example.com/docs")!
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp/package"),
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            targets: ["MyLib", "MyOtherLib"],
            dependencyPolicy: .exclude(["SomePackage"]),
            externalDocumentationURLs: ["OtherPackage": externalURL],
            includeSearch: true,
            isVerbose: true
        )

        #expect(config.targets == ["MyLib", "MyOtherLib"])
        #expect(config.dependencyPolicy == .exclude(["SomePackage"]))
        #expect(config.externalDocumentationURLs["OtherPackage"] == externalURL)
        #expect(config.includeSearch == true)
        #expect(config.isVerbose == true)
    }

    @Test("Theme configuration defaults to DocC style")
    func defaultTheme() {
        let theme = ThemeConfiguration.default

        #expect(theme.accentColour == "#0066cc")
        #expect(theme.includeDarkMode == true)
        #expect(theme.customCSS == nil)
    }

    @Test("Custom theme configuration")
    func customTheme() {
        let theme = ThemeConfiguration(
            accentColour: "#ff0000",
            includeDarkMode: false,
            customCSS: ".custom { color: red; }"
        )

        #expect(theme.accentColour == "#ff0000")
        #expect(theme.includeDarkMode == false)
        #expect(theme.customCSS == ".custom { color: red; }")
    }
}

@Suite("Dependency Policy Tests")
struct DependencyPolicyTests {
    @Test("All policy includes everything")
    func allPolicy() {
        let policy = DependencyInclusionPolicy.all
        #expect(policy == .all)
    }

    @Test("Exclude policy specifies packages")
    func excludePolicy() {
        let policy = DependencyInclusionPolicy.exclude(["PackageA", "PackageB"])
        if case .exclude(let packages) = policy {
            #expect(packages == ["PackageA", "PackageB"])
        } else {
            Issue.record("Expected exclude policy")
        }
    }

    @Test("Include only policy specifies packages")
    func includeOnlyPolicy() {
        let policy = DependencyInclusionPolicy.includeOnly(["PackageA"])
        if case .includeOnly(let packages) = policy {
            #expect(packages == ["PackageA"])
        } else {
            Issue.record("Expected includeOnly policy")
        }
    }

    @Test("None policy excludes all dependencies")
    func nonePolicy() {
        let policy = DependencyInclusionPolicy.none
        #expect(policy == .none)
    }
}
