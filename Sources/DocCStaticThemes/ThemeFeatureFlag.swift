//
// ThemeFeatureFlag.swift
// DocCStaticThemes
//
//  Created by Rene Hexel on 11/11/2026.
//  Copyright © 2026 Rene Hexel. All rights reserved.
//

/// A feature switch in the `features` section of a `theme-settings.json` file.
///
/// Feature switches are the swift-docc-render mechanism for turning parts of the
/// page on or off.  Each switch is identified by its key path below `features`,
/// for example `docs.onThisPageNavigator.disable`.  The set of switches is kept
/// deliberately small: a theme should change the look with CSS whenever the
/// information is already present in the page, and use a switch only where the
/// difference cannot be expressed in CSS.
///
/// All switches defined by swift-docc-render are accepted so that theme files can
/// be shared.  Switches that only make sense for the JavaScript renderer are
/// accepted without effect; ``isHonoured`` tells them apart.
public struct ThemeFeatureFlag: Hashable, Sendable, CustomStringConvertible {
    /// The keys below `features` that lead to the switch value, outermost first.
    public let path: [String]

    /// The value the switch has when a theme does not mention it.
    public let defaultValue: Bool

    /// Whether swift-docc-static changes its output according to this switch.
    public let isHonoured: Bool

    /// Creates a feature switch description.
    ///
    /// - Parameters:
    ///   - path: The keys below `features` that lead to the switch value.
    ///   - defaultValue: The value assumed when a theme does not set the switch.
    ///   - isHonoured: Whether swift-docc-static acts on the switch.
    public init(path: [String], defaultValue: Bool, isHonoured: Bool) {
        self.path = path
        self.defaultValue = defaultValue
        self.isHonoured = isHonoured
    }

    /// The dotted key path of the switch, such as `docs.onThisPageNavigator.disable`.
    public var description: String {
        path.joined(separator: ".")
    }

    /// Removes the "On This Page" navigator column from documentation pages.
    ///
    /// This is the swift-docc-render switch `features.docs.onThisPageNavigator.disable`.
    /// It is a switch rather than CSS because the navigator is a separate column
    /// with its own content; leaving it out keeps every page smaller and keeps
    /// the column out of the reading and tab order.
    public static let onThisPageNavigatorDisabled = ThemeFeatureFlag(
        path: ["docs", "onThisPageNavigator", "disable"],
        defaultValue: false,
        isHonoured: true
    )

    /// Enables the quick navigation overlay of swift-docc-render.
    ///
    /// Accepted for compatibility; the static output provides its search through
    /// the sidebar filter instead, which is controlled by the command line.
    public static let quickNavigationEnabled = ThemeFeatureFlag(
        path: ["docs", "quickNavigation", "enable"],
        defaultValue: true,
        isHonoured: false
    )

    /// Enables the language picker of swift-docc-render.
    ///
    /// Accepted for compatibility; the static output does not translate pages.
    public static let internationalisationEnabled = ThemeFeatureFlag(
        path: ["docs", "i18n", "enable"],
        defaultValue: false,
        isHonoured: false
    )

    /// Every feature switch that may appear in a theme file.
    public static let all: [ThemeFeatureFlag] = [
        .onThisPageNavigatorDisabled,
        .quickNavigationEnabled,
        .internationalisationEnabled,
    ]
}
