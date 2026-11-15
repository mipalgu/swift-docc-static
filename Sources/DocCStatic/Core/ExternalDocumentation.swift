//
// ExternalDocumentation.swift
// DocCStatic
//
//  Created by Rene Hexel on 15/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//
import Foundation

/// The hosted documentation of modules that are not part of the generated site.
///
/// Pages of the generated site often refer to symbols of modules that the site does
/// not document, such as the types of a dependency in a declaration, the protocols a
/// type conforms to, or a symbol link in a documentation comment.  When the
/// documentation of such a module is hosted elsewhere, its base URL can be given in
/// ``Configuration/externalDocumentationURLs``, keyed by the name of the module or
/// by the name of the package that provides it.  Links to the module's symbols then
/// point to their pages below that base URL, following DocC's path convention:
/// `<base>/documentation/<module>/<path>/`, with the module and path in lower case.
///
/// A key is matched, ignoring case, against
///
/// 1. the name of a module, such as `FixtureColours`, where hyphens and
///    underscores are interchangeable, as Swift turns the hyphens of a target name
///    into underscores; and
/// 2. the name of a package (the `name` in its manifest) or its identity (the
///    last component of its location, such as `fixture-palette`), which applies
///    the URL to every module of that package.
///
/// A key that names a module takes precedence over a key that names the package
/// providing that module.
public struct ExternalDocumentation: Sendable, Equatable {
    /// The documentation base URLs, keyed by module key (see ``moduleKey(for:)``).
    public let moduleBaseURLs: [String: URL]

    /// The name of the first path component of DocC documentation pages.
    public static let documentationRoot = "documentation"

    /// Creates external documentation from base URLs keyed by module.
    ///
    /// - Parameter moduleBaseURLs: The base URLs, keyed by module key (see
    ///   ``moduleKey(for:)``).
    public init(moduleBaseURLs: [String: URL] = [:]) {
        self.moduleBaseURLs = moduleBaseURLs
    }

    /// Creates external documentation from configured base URLs.
    ///
    /// Every key is used as a module name; a key that also matches the name or
    /// identity of one of `packages` applies to all modules of that package unless a
    /// key names the module itself.
    ///
    /// - Parameters:
    ///   - mappings: The base URLs keyed by module or package name, as in
    ///     ``Configuration/externalDocumentationURLs``.
    ///   - packages: The packages whose modules package keys apply to.
    public init(mappings: [String: URL], packages: [PackageModules] = []) {
        var urls: [String: URL] = [:]
        // Keys sorted so that the result does not depend on dictionary order
        let keys = mappings.keys.sorted()
        for key in keys {
            guard let url = mappings[key] else { continue }
            for package in packages where package.isNamed(key) {
                for module in package.modules {
                    let moduleKey = Self.moduleKey(for: module)
                    if urls[moduleKey] == nil { urls[moduleKey] = url }
                }
            }
        }
        for key in keys {
            urls[Self.moduleKey(for: key)] = mappings[key]
        }
        self.moduleBaseURLs = urls
    }

    /// Returns the key under which the base URL of a module is stored.
    ///
    /// - Parameter name: The name of a module, as written in source code, in a
    ///   target name or in a documentation path.
    /// - Returns: The name in lower case, with hyphens replaced by underscores.
    public static func moduleKey(for name: String) -> String {
        name.lowercased().replacingOccurrences(of: "-", with: "_")
    }

    /// Whether no external documentation is configured.
    public var isEmpty: Bool { moduleBaseURLs.isEmpty }

    /// Returns the documentation base URL of a module.
    ///
    /// - Parameter module: The name of the module.
    /// - Returns: The base URL, or `nil` if none is configured for the module.
    public func baseURL(forModule module: String) -> URL? {
        moduleBaseURLs[Self.moduleKey(for: module)]
    }

    /// Returns the external URL of a documentation page.
    ///
    /// - Parameter path: The DocC path of the page, such as
    ///   `/documentation/fixturecolours/colour`, without a fragment.
    /// - Returns: The absolute URL of the page below the base URL of its module,
    ///   ending in `/`, or `nil` if the path is not a documentation path or no base
    ///   URL is configured for its module.
    public func url(forPagePath path: String) -> String? {
        let components = path.split(separator: "/").map(String.init)
        guard components.count >= 2,
              components[0].lowercased() == Self.documentationRoot,
              let baseURL = baseURL(forModule: components[1])
        else { return nil }
        var base = baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        return base + "/" + components.joined(separator: "/").lowercased() + "/"
    }
}

// MARK: - Packages

/// A package and the names of the modules it provides.
///
/// ``ExternalDocumentation`` uses this to apply a base URL keyed by package name to
/// the modules of that package.
public struct PackageModules: Sendable, Equatable {
    /// The name of the package, as declared in its manifest.
    public var name: String

    /// The identity of the package, such as the last component of its location.
    public var identity: String

    /// The names of the modules of the package.
    public var modules: [String]

    /// Creates a description of a package.
    ///
    /// - Parameters:
    ///   - name: The name of the package, as declared in its manifest.
    ///   - identity: The identity of the package.
    ///   - modules: The names of the modules of the package.
    public init(name: String, identity: String, modules: [String]) {
        self.name = name
        self.identity = identity
        self.modules = modules
    }

    /// Returns whether a key names this package.
    ///
    /// - Parameter key: A key of ``Configuration/externalDocumentationURLs``.
    /// - Returns: `true` if the key is the package's name or identity, ignoring case.
    public func isNamed(_ key: String) -> Bool {
        let key = key.lowercased()
        return key == name.lowercased() || key == identity.lowercased()
    }
}

/// A package dependency as listed by the Swift Package Manager.
public struct PackageDependency: Sendable, Equatable {
    /// The name of the package, as declared in its manifest.
    public var name: String

    /// The identity of the package.
    public var identity: String

    /// The local directory that holds the package.
    public var path: String

    /// Creates a description of a package dependency.
    ///
    /// - Parameters:
    ///   - name: The name of the package.
    ///   - identity: The identity of the package.
    ///   - path: The local directory that holds the package.
    public init(name: String, identity: String, path: String) {
        self.name = name
        self.identity = identity
        self.path = path
    }

    /// Returns the dependencies listed by `swift package show-dependencies --format json`.
    ///
    /// The listing is a tree whose root is the package itself; the root is left out,
    /// and a package that several packages depend on is listed once.
    ///
    /// - Parameter json: The JSON output of the command.
    /// - Returns: The dependencies in the order of a depth-first walk, or an empty
    ///   array if the output cannot be read.
    public static func dependencies(fromShowDependenciesJSON json: String) -> [PackageDependency] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        var result: [PackageDependency] = []
        var seen = Set<String>()
        func visit(_ node: [String: Any]) {
            for child in node["dependencies"] as? [[String: Any]] ?? [] {
                if let identity = child["identity"] as? String, !seen.contains(identity) {
                    seen.insert(identity)
                    result.append(PackageDependency(
                        name: child["name"] as? String ?? identity,
                        identity: identity,
                        path: child["path"] as? String ?? ""
                    ))
                }
                visit(child)
            }
        }
        visit(root)
        return result
    }
}

public extension PackageModules {
    /// The kinds of targets that do not become documented modules.
    static let undocumentedTargetTypes: Set<String> = ["test", "plugin"]

    /// Returns the module names declared by a package manifest.
    ///
    /// - Parameter json: The JSON output of `swift package dump-package`.
    /// - Returns: The names of the targets that are not tests or plugins, with
    ///   hyphens replaced by underscores like Swift module names, or an empty array
    ///   if the output cannot be read.
    static func moduleNames(fromDumpPackageJSON json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let targets = manifest["targets"] as? [[String: Any]]
        else { return [] }
        return targets.compactMap { target in
            guard let name = target["name"] as? String,
                  !undocumentedTargetTypes.contains(target["type"] as? String ?? "")
            else { return nil }
            return name.replacingOccurrences(of: "-", with: "_")
        }
    }
}
