//
// TemporaryLocationTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import Testing

/// Tests of the temporary locations that tests share within one checkout.
@Suite("Temporary Locations")
struct TemporaryLocationTests {
    @Test("Each checkout gets its own directory, named without its path")
    func perCheckout() {
        let first = TemporaryLocation.directoryName("docc-static-fixture-tests", checkout: "/work/one/swift-docc-static")
        let second = TemporaryLocation.directoryName("docc-static-fixture-tests", checkout: "/work/two/swift-docc-static")
        #expect(first != second)
        #expect(first == TemporaryLocation.directoryName("docc-static-fixture-tests", checkout: "/work/one/swift-docc-static"))
        for name in [first, second] {
            #expect(name.hasPrefix("docc-static-fixture-tests-"))
            #expect(!name.contains("/") && !name.contains("work") && !name.contains("swift-docc-static"))
        }
    }

    @Test("The checkout key is a fixed-length hexadecimal digest")
    func checkoutKey() {
        let key = TemporaryLocation.checkoutKey(for: "/work/one/swift-docc-static")
        #expect(key.count == 16)
        #expect(key.allSatisfy { $0.isHexDigit && !$0.isUppercase })
        #expect(TemporaryLocation.checkoutKey(for: "") == "cbf29ce484222325")
        #expect(key == "45bf4f81804e3e85", "the harness scripts derive the same key")
    }

    @Test("The fixture workspace lives in this checkout's own directory")
    func fixtureWorkspace() {
        let directory = TemporaryLocation.fixtureWorkspace
        #expect(directory.deletingLastPathComponent().standardizedFileURL == FileManager.default.temporaryDirectory.standardizedFileURL)
        #expect(directory.lastPathComponent == TemporaryLocation.directoryName("docc-static-fixture-tests", checkout: TemporaryLocation.checkout))
    }
}
