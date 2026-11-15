//
// PageLinkResolverTests.swift
// DocCStaticTests
//
//  Created by Rene Hexel on 15/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

import Foundation
import SwiftDocC
import Testing

@testable import DocCStatic

/// The base URL of the invented external documentation used by these tests.
private let exampleBase = URL(string: "https://example.com/docs")!

/// Tests of the base URLs of external documentation.
@Suite("External Documentation")
struct ExternalDocumentationTests {
    /// The packages of an invented dependency graph.
    let packages = [
        PackageModules(name: "FixturePalette", identity: "fixture-palette", modules: ["FixtureColours", "FixtureInks"]),
        PackageModules(name: "FixtureCanvas", identity: "fixture-canvas", modules: ["FixtureCanvas"]),
    ]

    @Test("A module key applies to its module, ignoring case and hyphens",
          arguments: ["FixtureColours", "fixturecolours", "FIXTURECOLOURS"])
    func moduleKey(key: String) {
        let external = ExternalDocumentation(mappings: [key: exampleBase], packages: packages)
        #expect(external.baseURL(forModule: "FixtureColours") == exampleBase)
        #expect(external.baseURL(forModule: "fixturecolours") == exampleBase)
        #expect(external.baseURL(forModule: "FixtureInks") == nil)
    }

    @Test("Hyphens and underscores in module names are interchangeable")
    func hyphenatedModule() {
        let external = ExternalDocumentation(mappings: ["fixture-tool": exampleBase])
        #expect(external.baseURL(forModule: "fixture_tool") == exampleBase)
        #expect(ExternalDocumentation.moduleKey(for: "Fixture-Tool") == "fixture_tool")
    }

    @Test("A package name or identity applies to every module of the package",
          arguments: ["FixturePalette", "fixturepalette", "fixture-palette"])
    func packageKey(key: String) {
        let external = ExternalDocumentation(mappings: [key: exampleBase], packages: packages)
        #expect(external.baseURL(forModule: "FixtureColours") == exampleBase)
        #expect(external.baseURL(forModule: "FixtureInks") == exampleBase)
        #expect(external.baseURL(forModule: "FixtureCanvas") == nil)
    }

    @Test("A module key takes precedence over the key of its package")
    func modulePrecedence() {
        let moduleBase = URL(string: "https://example.com/colours")!
        let external = ExternalDocumentation(
            mappings: ["FixturePalette": exampleBase, "FixtureColours": moduleBase], packages: packages
        )
        #expect(external.baseURL(forModule: "FixtureColours") == moduleBase)
        #expect(external.baseURL(forModule: "FixtureInks") == exampleBase)
    }

    @Test("Without packages, keys only name modules")
    func noPackages() {
        let external = ExternalDocumentation(mappings: ["FixturePalette": exampleBase])
        #expect(external.baseURL(forModule: "FixtureColours") == nil)
        #expect(!external.isEmpty)
        #expect(ExternalDocumentation().isEmpty)
    }

    @Test("Page URLs follow DocC's path convention below the base URL",
          arguments: ["https://example.com/docs", "https://example.com/docs/", "https://example.com/docs//"])
    func pageURL(base: String) throws {
        let external = ExternalDocumentation(moduleBaseURLs: ["fixturecolours": try #require(URL(string: base))])
        #expect(external.url(forPagePath: "/documentation/FixtureColours/Colour/init(red:green:blue:)")
            == "https://example.com/docs/documentation/fixturecolours/colour/init(red:green:blue:)/")
        #expect(external.url(forPagePath: "/documentation/fixturecolours") == "https://example.com/docs/documentation/fixturecolours/")
    }

    @Test("Paths outside the documentation root or of other modules have no external URL",
          arguments: ["/tutorials/fixturecolours/drawing", "/documentation", "/documentation/fixtureinks/ink", ""])
    func noPageURL(path: String) {
        let external = ExternalDocumentation(moduleBaseURLs: ["fixturecolours": exampleBase])
        #expect(external.url(forPagePath: path) == nil)
    }
}

/// Tests of reading package information from the Swift Package Manager.
@Suite("Package Information")
struct PackageInformationTests {
    @Test("Dependencies are read from the dependency tree, each once, without the root")
    func dependencies() {
        let json = """
            {"identity": "root", "name": "Root", "path": "/r", "dependencies": [
              {"identity": "fixture-palette", "name": "FixturePalette", "path": "/p", "dependencies": [
                {"identity": "fixture-base", "name": "FixtureBase", "path": "/b", "dependencies": []}]},
              {"identity": "fixture-base", "name": "FixtureBase", "path": "/b", "dependencies": []},
              {"identity": "fixture-bare", "dependencies": []}]}
            """
        #expect(PackageDependency.dependencies(fromShowDependenciesJSON: json) == [
            PackageDependency(name: "FixturePalette", identity: "fixture-palette", path: "/p"),
            PackageDependency(name: "FixtureBase", identity: "fixture-base", path: "/b"),
            PackageDependency(name: "fixture-bare", identity: "fixture-bare", path: ""),
        ])
    }

    @Test("Unreadable listings yield no dependencies", arguments: ["", "[]", "not json"])
    func unreadableDependencies(json: String) {
        #expect(PackageDependency.dependencies(fromShowDependenciesJSON: json).isEmpty)
    }

    @Test("Module names are the targets that are not tests or plugins")
    func moduleNames() {
        let json = """
            {"name": "FixturePalette", "targets": [
              {"name": "FixtureColours", "type": "regular"}, {"name": "fixture-tool", "type": "executable"},
              {"name": "FixtureColoursTests", "type": "test"}, {"name": "FixturePlugin", "type": "plugin"},
              {"type": "regular"}]}
            """
        #expect(PackageModules.moduleNames(fromDumpPackageJSON: json) == ["FixtureColours", "fixture_tool"])
    }

    @Test("Unreadable manifests yield no modules", arguments: ["", "{}", "{\"targets\": 1}"])
    func unreadableManifest(json: String) {
        #expect(PackageModules.moduleNames(fromDumpPackageJSON: json).isEmpty)
    }

    @Test("A package is named by its name or identity, ignoring case")
    func packageNames() {
        let package = PackageModules(name: "FixturePalette", identity: "fixture-palette", modules: [])
        #expect(package.isNamed("fixturepalette"))
        #expect(package.isNamed("Fixture-Palette"))
        #expect(!package.isNamed("FixtureColours"))
    }
}

/// Tests of the destinations of links to documentation pages.
@Suite("Link Resolver")
struct LinkResolverTests {
    /// A resolver for a site with two pages and external documentation of one module.
    let resolver = PageLinkResolver(
        generatedPagePaths: ["documentation/fixtureshapes", "documentation/fixtureshapes/swatch", "documentation/fixtureshapes/'...(_:_:)"],
        externalDocumentation: ExternalDocumentation(moduleBaseURLs: ["fixturecolours": exampleBase])
    )

    @Test("Generated pages are linked relative to the page")
    func generatedPage() {
        #expect(resolver.destination(forPage: "/documentation/fixtureshapes/swatch", depth: 3)
            == "../../../documentation/fixtureshapes/swatch/index.html")
        #expect(resolver.destination(forPage: "/documentation/fixtureshapes", depth: 0)
            == "documentation/fixtureshapes/index.html")
    }

    @Test("Fragments follow the page's file")
    func fragment() {
        #expect(resolver.destination(forPage: "/documentation/fixtureshapes/swatch#Choosing-Pigments", depth: 1)
            == "../documentation/fixtureshapes/swatch/index.html#Choosing-Pigments")
        #expect(resolver.destination(forPage: "/documentation/fixturecolours/colour#Mixing", depth: 1)
            == "https://example.com/docs/documentation/fixturecolours/colour/#Mixing")
    }

    @Test("Components with a leading period are linked to the files they are written to")
    func leadingPeriod() {
        #expect(resolver.destination(forPage: "/documentation/fixtureshapes/...(_:_:)", depth: 0)
            == "documentation/fixtureshapes/'...(_:_:)/index.html")
    }

    @Test("Pages outside the site link to configured external documentation")
    func externalPage() {
        #expect(!resolver.isGenerated("/documentation/fixturecolours/colour"))
        #expect(resolver.destination(forPage: "/documentation/fixturecolours/colour", depth: 2)
            == "https://example.com/docs/documentation/fixturecolours/colour/")
    }

    @Test("Pages outside the site without external documentation have no destination")
    func missingPage() {
        #expect(resolver.destination(forPage: "/documentation/fixtureinks/ink", depth: 2) == nil)
        #expect(resolver.destination(forPage: "/documentation/fixtureshapes/paint", depth: 2) == nil)
    }

    @Test("Web links and fragments of the page are kept",
          arguments: ["https://example.com/pigments", "#overview", "mailto:someone@example.com"])
    func absolute(url: String) {
        #expect(resolver.destination(forPage: url, depth: 2) == url)
    }

    @Test("Without a list of generated pages, every page is linked within the site")
    func unrestricted() {
        #expect(PageLinkResolver.unrestricted.isGenerated("/documentation/anything"))
        #expect(PageLinkResolver.unrestricted.destination(forPage: "/documentation/fixturecolours/colour", depth: 1)
            == "../documentation/fixturecolours/colour/index.html")
    }

    @Test("Symbol paths and qualified names are read from reference identifiers")
    func symbolNames() {
        let identifier = "doc://FixtureSketches/documentation/FixtureColours/Colour/Component-swift.enum/red"
        #expect(PageLinkResolver.symbolPathComponents(ofIdentifier: identifier)
            == ["FixtureColours", "Colour", "Component-swift.enum", "red"])
        #expect(PageLinkResolver.qualifiedSymbolName(ofIdentifier: identifier) == "FixtureColours.Colour.Component.red")
        #expect(PageLinkResolver.qualifiedSymbolName(ofIdentifier: "doc://B/documentation/M/-(_:_:)") == "M.-(_:_:)")
        #expect(PageLinkResolver.symbolPathComponents(ofIdentifier: "doc://B/tutorials/M/T") == nil)
        #expect(PageLinkResolver.qualifiedSymbolName(ofIdentifier: "not a url") == nil)
    }
}

/// Tests that references to pages outside the generated site render like
/// swift-docc-render renders references DocC cannot resolve, and link to external
/// documentation where it is configured.
@Suite("Out-of-Site Reference Rendering")
struct OutOfSiteReferenceRenderingTests {
    /// The identifier of a reference to a symbol of a module outside the site.
    static let colourIdentifier = "doc://FixtureSketches/documentation/FixtureColours/Colour"

    /// The identifier of a reference to a protocol outside the site.
    static let tintedIdentifier = "doc://FixtureSketches/documentation/FixtureColours/Tinted"

    /// The identifier of a reference to a page of the site.
    static let sketchIdentifier = "doc://FixtureSketches/documentation/FixtureSketches/Sketch"

    /// The identifier of a web link.
    static let webIdentifier = "https://example.com/sketching"

    /// The references of an invented page.
    static var references: [String: any RenderReference] {[
        colourIdentifier: TopicRenderReference(
            identifier: RenderReferenceIdentifier(colourIdentifier), title: "Colour", abstract: [],
            url: "/documentation/fixturecolours/colour", kind: .symbol, role: "symbol"
        ),
        tintedIdentifier: TopicRenderReference(
            identifier: RenderReferenceIdentifier(tintedIdentifier), title: "Tinted", abstract: [],
            url: "/documentation/fixturecolours/tinted", kind: .symbol, role: "symbol"
        ),
        sketchIdentifier: TopicRenderReference(
            identifier: RenderReferenceIdentifier(sketchIdentifier), title: "Sketch", abstract: [],
            url: "/documentation/fixturesketches/sketch", kind: .symbol, role: "symbol"
        ),
        webIdentifier: LinkReference(
            identifier: RenderReferenceIdentifier(webIdentifier), title: "Sketching guide",
            titleInlineContent: [.text("Sketching guide")], url: webIdentifier
        ),
    ]}

    /// Returns a resolver for a site that only contains the sketch module.
    static func resolver(external: Bool) -> PageLinkResolver {
        PageLinkResolver(
            generatedPagePaths: ["documentation/fixturesketches", "documentation/fixturesketches/sketch"],
            externalDocumentation: external ? ExternalDocumentation(moduleBaseURLs: ["fixturecolours": exampleBase]) : ExternalDocumentation()
        )
    }

    /// Returns a page builder that uses the given resolver.
    static func builder(external: Bool) -> HTMLPageBuilder {
        HTMLPageBuilder(configuration: Configuration(
            packageDirectory: FileManager.default.temporaryDirectory,
            outputDirectory: FileManager.default.temporaryDirectory
        ), linkResolver: resolver(external: external))
    }

    /// Renders a paragraph with a reference.
    static func paragraph(_ identifier: String, external: Bool, isActive: Bool = true, overridingTitle: String? = nil) -> String {
        let paragraph = RenderBlockContent.paragraph(.init(inlineContent: [
            .reference(identifier: RenderReferenceIdentifier(identifier), isActive: isActive,
                       overridingTitle: overridingTitle, overridingTitleInlineContent: nil)
        ]))
        return RenderContentHTMLRenderer(linkResolver: resolver(external: external))
            .renderBlockContent(paragraph, references: references, depth: 2)
    }

    @Test("A type outside the site is an unlinked type name, like swift-docc-render's unresolved token")
    func declarationTypeWithoutDestination() {
        let html = Self.builder(external: false).declarationTokenMarkup(
            kind: .typeIdentifier, text: "Colour", identifier: Self.colourIdentifier, references: Self.references, depth: 3
        )
        #expect(html == "<span class=\"type-identifier-link\"><span>Colour</span></span>")
    }

    @Test("An attribute outside the site is an unlinked attribute token")
    func declarationAttributeWithoutDestination() {
        let html = Self.builder(external: false).declarationTokenMarkup(
            kind: .attribute, text: "Colour", identifier: Self.colourIdentifier, references: Self.references, depth: 3
        )
        #expect(html == "<span class=\"token-attribute\">Colour</span>")
    }

    @Test("A type with external documentation links to its external page")
    func declarationTypeWithExternalDocumentation() {
        let builder = Self.builder(external: true)
        #expect(builder.declarationTokenMarkup(
            kind: .typeIdentifier, text: "Colour", identifier: Self.colourIdentifier, references: Self.references, depth: 3
        ) == "<a href=\"https://example.com/docs/documentation/fixturecolours/colour/\" class=\"type-identifier-link\"><code><span>Colour</span></code></a>")
        #expect(builder.declarationTokenMarkup(
            kind: .attribute, text: "Colour", identifier: Self.colourIdentifier, references: Self.references, depth: 3
        ) == "<a href=\"https://example.com/docs/documentation/fixturecolours/colour/\" class=\"attribute-link\"><span>Colour</span></a>")
    }

    @Test("A type within the site keeps its relative link")
    func declarationTypeWithinSite() {
        let html = Self.builder(external: false).declarationTokenMarkup(
            kind: .typeIdentifier, text: "Sketch", identifier: Self.sketchIdentifier, references: Self.references, depth: 3
        )
        #expect(html == "<a href=\"../../../documentation/fixturesketches/sketch/index.html\" class=\"type-identifier-link\"><code><span>Sketch</span></code></a>")
    }

    /// A relationships group listing a protocol outside the site and a page of the site.
    static var conformances: RelationshipsRenderSection {
        RelationshipsRenderSection(type: "conformsTo", title: "Conforms To", identifiers: [tintedIdentifier, sketchIdentifier])
    }

    @Test("A related type outside the site is listed by its qualified name, like DocC's unresolved relationships")
    func relationshipWithoutDestination() {
        let html = Self.builder(external: false).buildRelationshipSection(Self.conformances, references: Self.references, depth: 2)
        #expect(html.contains("<li class=\"relationships-item\"><code>Fixture<wbr>Colours<wbr>.Tinted</code></li>"))
        #expect(html.contains("<li class=\"relationships-item\"><a href=\"../../documentation/fixturesketches/sketch/index.html\" class=\"link\"><code>Sketch</code></a></li>"))
        #expect(html.contains("<h3 id=\"conforms-to\" class=\"contenttable-title\">"))
    }

    @Test("A related type with external documentation links to its external page")
    func relationshipWithExternalDocumentation() {
        let html = Self.builder(external: true).buildRelationshipSection(Self.conformances, references: Self.references, depth: 2)
        #expect(html.contains("<li class=\"relationships-item\"><a href=\"https://example.com/docs/documentation/fixturecolours/tinted/\" class=\"link\"><code>Tinted</code></a></li>"))
    }

    @Test("A relationships group without known types is left out")
    func emptyRelationships() {
        let section = RelationshipsRenderSection(type: "conformsTo", title: "Conforms To", identifiers: ["doc://x/missing"])
        #expect(Self.builder(external: false).buildRelationshipSection(section, references: Self.references, depth: 2).isEmpty)
    }

    @Test("A symbol link outside the site shows the symbol's path as code, like DocC's unresolved symbol links")
    func inlineSymbolWithoutDestination() {
        let html = Self.paragraph(Self.colourIdentifier, external: false)
        #expect(html.contains("<p><code class=\"inline-code\">Fixture<wbr>Colours/Colour</code></p>"))
        #expect(!html.contains("href="))
    }

    @Test("An inactive or retitled link outside the site shows its title without a link")
    func inlineInactiveWithoutDestination() {
        #expect(Self.paragraph(Self.colourIdentifier, external: false, isActive: false)
            .contains("<span class=\"inactive-reference\"><code>Colour</code></span>"))
        #expect(Self.paragraph(Self.colourIdentifier, external: false, overridingTitle: "the colour")
            .contains("<span class=\"inactive-reference\">the colour</span>"))
    }

    @Test("A symbol link with external documentation links to its external page")
    func inlineSymbolWithExternalDocumentation() {
        let html = Self.paragraph(Self.colourIdentifier, external: true)
        #expect(html.contains("<a href=\"https://example.com/docs/documentation/fixturecolours/colour/\" class=\"inline-link\"><code>Colour</code></a>"))
    }

    @Test("Web links in prose are kept")
    func inlineWebLink() {
        let html = Self.paragraph(Self.webIdentifier, external: false)
        #expect(html.contains("<a href=\"https://example.com/sketching\" class=\"inline-link\">Sketching guide</a>"))
    }

    @Test("Web links among topics are listed like swift-docc-render's link blocks")
    func webLinkTopic() {
        let group = TaskGroupRenderSection(title: "Related Documentation", abstract: nil, discussion: nil,
                                           identifiers: [Self.webIdentifier, Self.colourIdentifier], generated: false)
        let html = Self.builder(external: false).buildTaskGroup(group, references: Self.references, depth: 2)
        #expect(html.contains("<h3 id=\"Related-Documentation\" class=\"contenttable-title\">"))
        #expect(html.contains("<div class=\"section-content\">\n<div class=\"link-block topic has-inline-element\"><a href=\"https://example.com/sketching\" class=\"link\"><span>Sketching guide</span></a></div></div>"))
        #expect(!html.contains("fixturecolours"))
    }

    @Test("Topics outside the site are listed when external documentation is configured")
    func externalTopic() {
        let group = TaskGroupRenderSection(title: "Colours", abstract: nil, discussion: nil,
                                           identifiers: [Self.colourIdentifier], generated: false)
        #expect(Self.builder(external: false).buildTaskGroup(group, references: Self.references, depth: 2).isEmpty)
        let html = Self.builder(external: true).buildTaskGroup(group, references: Self.references, depth: 2)
        #expect(html.contains("<a href=\"https://example.com/docs/documentation/fixturecolours/colour/\" class=\"link\">"))
    }

    /// Returns a symbol page with the given See Also groups.
    static func page(seeAlso: [TaskGroupRenderSection]) -> RenderNode {
        var node = RenderNode(
            identifier: ResolvedTopicReference(bundleID: "FixtureSketches", path: "/documentation/FixtureSketches/Sketch", sourceLanguage: .swift),
            kind: .symbol
        )
        node.metadata.title = "Sketch"
        node.metadata.symbolKind = "struct"
        node.metadata.role = "symbol"
        node.references = references
        node.seeAlsoSections = seeAlso
        node.relationshipSections = [conformances]
        node.primaryContentSections = [ContentRenderSection(kind: .content, content: [
            .heading(.init(level: 2, text: "Overview", anchor: "overview")),
        ])]
        return node
    }

    @Test("A See Also section without entries has no heading, and the page does not list it")
    func emptySeeAlso() {
        let group = TaskGroupRenderSection(title: "Related Documentation", abstract: nil, discussion: nil,
                                           identifiers: [Self.colourIdentifier], generated: false)
        let node = Self.page(seeAlso: [group])
        let builder = Self.builder(external: false)
        let html = builder.buildMainContent(from: node, references: node.references, depth: 3)
        #expect(!html.contains("see-also"))
        #expect(!html.contains("Related Documentation"))
        #expect(html.contains("id=\"relationships\""))
        #expect(!builder.onThisPageItems(for: node, title: "Sketch").contains { $0.anchor == "see-also" })
        #expect(builder.onThisPageItems(for: node, title: "Sketch").contains { $0.anchor == "relationships" })
    }

    @Test("A See Also section with web links keeps its heading, and the page lists it")
    func seeAlsoWithWebLinks() {
        let group = TaskGroupRenderSection(title: "Related Documentation", abstract: nil, discussion: nil,
                                           identifiers: [Self.webIdentifier], generated: false)
        let node = Self.page(seeAlso: [group])
        let builder = Self.builder(external: false)
        let html = builder.buildMainContent(from: node, references: node.references, depth: 3)
        #expect(html.contains("<section class=\"contenttable alt-light see-also\">"))
        #expect(html.contains("<h2 id=\"see-also\" class=\"title\">"))
        #expect(html.contains("Sketching guide"))
        #expect(builder.onThisPageItems(for: node, title: "Sketch").contains { $0.anchor == "see-also" })
    }

    @Test("Breadcrumbs to pages outside the site are not linked")
    func unlinkedBreadcrumb() throws {
        var node = Self.page(seeAlso: [])
        let json = "{\"paths\": [[\"\(Self.colourIdentifier)\", \"\(Self.sketchIdentifier)\"]]}"
        let hierarchy = try JSONDecoder().decode(RenderReferenceHierarchy.self, from: Data(json.utf8))
        node.hierarchyVariants = .init(defaultValue: .reference(hierarchy))
        let html = Self.builder(external: false).buildBreadcrumbs(for: node, references: Self.references, depth: 3)
        #expect(html.contains("<span class=\"parent item\">Colour</span>"))
        #expect(html.contains("<a href=\"../../../documentation/fixturesketches/sketch/index.html\" class=\"parent item nav-menu-link\">Sketch</a>"))
    }
}

/// Tests that `doc://` links in prose only link to pages that exist.
@Suite("Doc Link Post-Processing of Missing Pages")
struct DocLinkMissingPageTests {
    /// A post-processor for a site with one page of a documented module.
    func processor(external: Bool) -> DocLinkPostProcessor {
        DocLinkPostProcessor(
            documentedModules: ["FixtureShapes": "FixtureShapes"],
            externalURLs: [:],
            pageLinkResolver: PageLinkResolver(
                generatedPagePaths: ["documentation/fixtureshapes/swatch"],
                externalDocumentation: external ? ExternalDocumentation(moduleBaseURLs: ["fixtureshapes": exampleBase]) : ExternalDocumentation()
            )
        )
    }

    @Test("A link to a generated page becomes a relative link")
    func generatedPage() {
        let html = processor(external: false).process("<p>See doc://FixtureShapes/documentation/FixtureShapes/Swatch.</p>", currentDepth: 1)
        #expect(html == "<p>See <a href=\"../documentation/fixtureshapes/swatch/index.html\">Swatch</a>.</p>")
    }

    @Test("A link to a page that is not generated stays text, or links to external documentation")
    func missingPage() {
        let text = "<p>See doc://FixtureShapes/documentation/FixtureShapes/Paint.</p>"
        #expect(processor(external: false).process(text, currentDepth: 1) == text)
        #expect(processor(external: true).process(text, currentDepth: 1)
            == "<p>See <a href=\"https://example.com/docs/documentation/fixtureshapes/paint/\">Paint</a>.</p>")
    }
}
