//
// StaticHTMLConsumerTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 3/01/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Testing
import Foundation
@testable import DocCStatic

@Suite("Static HTML Consumer Tests")
struct StaticHTMLConsumerTests {
    @Test("Consumer initialises with directories")
    func consumerInit() {
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp/package"),
            outputDirectory: URL(fileURLWithPath: "/tmp/docs")
        )
        let consumer = StaticHTMLConsumer(
            outputDirectory: URL(fileURLWithPath: "/tmp/docs"),
            configuration: config
        )

        #expect(consumer.outputDirectory.path == "/tmp/docs")
    }

    @Test("Consumer provides empty result initially")
    func emptyResult() {
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp"),
            outputDirectory: URL(fileURLWithPath: "/tmp/docs")
        )
        let consumer = StaticHTMLConsumer(
            outputDirectory: URL(fileURLWithPath: "/tmp/docs"),
            configuration: config
        )
        let result = consumer.result()

        #expect(result.generatedPages == 0)
        #expect(result.modulesDocumented == 0)
        #expect(result.symbolsDocumented == 0)
        #expect(result.outputDirectory.path == "/tmp/docs")
    }

    @Test("Consumer provides correct output directory")
    func outputDirectoryInResult() {
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp"),
            outputDirectory: URL(fileURLWithPath: "/custom/path/docs")
        )
        let consumer = StaticHTMLConsumer(
            outputDirectory: URL(fileURLWithPath: "/custom/path/docs"),
            configuration: config
        )

        let result = consumer.result()
        #expect(result.outputDirectory.path == "/custom/path/docs")
    }
}

@Suite("Consumer Output Path Tests")
struct ConsumerOutputPathTests {
    @Test("Consumer respects output directory")
    func outputDirectory() {
        let config = Configuration(
            packageDirectory: URL(fileURLWithPath: "/tmp"),
            outputDirectory: URL(fileURLWithPath: "/custom/output")
        )
        let consumer = StaticHTMLConsumer(
            outputDirectory: URL(fileURLWithPath: "/custom/output"),
            configuration: config
        )

        #expect(consumer.outputDirectory.path == "/custom/output")
    }
}
