//
// TemporaryLocation.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation

/// Temporary directories that tests keep between runs of one checkout.
///
/// Some tests keep expensive intermediate results, such as the build cache of the
/// fixture package, in the system temporary directory so that repeated runs stay fast.
/// Those directories are named after the checkout the tests run from, so that test
/// runs of different checkouts of the package on the same machine never share (and
/// corrupt) them.  The name contains a digest of the checkout's location rather than
/// the location itself.
enum TemporaryLocation {
    /// The root directory of the checkout the tests were compiled from.
    static let checkout = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Support
        .deletingLastPathComponent()  // DocCStaticTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // package root
        .standardizedFileURL
        .path

    /// The directory that holds the copied fixture package, its build cache and the
    /// documentation generated from it.
    static var fixtureWorkspace: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(directoryName("docc-static-fixture-tests", checkout: checkout))
    }

    /// Returns the name of a temporary directory that belongs to one checkout.
    ///
    /// - Parameters:
    ///   - prefix: The name that describes the directory's purpose.
    ///   - checkout: The location of the checkout.
    /// - Returns: The prefix, a hyphen and the checkout key of the location.
    static func directoryName(_ prefix: String, checkout: String) -> String {
        "\(prefix)-\(checkoutKey(for: checkout))"
    }

    /// Returns a short key that identifies a checkout without revealing its location.
    ///
    /// The key is the 64-bit FNV-1a hash of the UTF-8 encoded location, written as 16
    /// lowercase hexadecimal digits.  The visual regression harness scripts derive their
    /// temporary directory names the same way.
    ///
    /// - Parameter checkout: The location of the checkout.
    /// - Returns: The hexadecimal key.
    static func checkoutKey(for checkout: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in checkout.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let digits = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - digits.count) + digits
    }
}
