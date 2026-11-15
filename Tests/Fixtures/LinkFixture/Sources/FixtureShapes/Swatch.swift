import FixtureColours

/// A patch of a single colour.
///
/// A swatch shows one ``FixtureColours/Colour`` and has a ``Swatch/opacity``.
public struct Swatch: Tinted, Sendable {
    /// The colour of the swatch.
    public var tint: Colour

    /// How opaque the swatch is.
    @Clamped public var opacity: Double

    /// Creates a swatch.
    ///
    /// - Parameters:
    ///   - tint: The colour of the swatch.
    ///   - opacity: How opaque the swatch is.
    public init(tint: Colour, opacity: Double = 1) {
        self.tint = tint
        self.opacity = opacity
    }

    /// Returns the colour of this swatch laid over a background.
    ///
    /// - Parameter background: The ``FixtureColours/Colour`` underneath.
    /// - Returns: The blended colour.
    public func blended(over background: Colour) -> Colour {
        Colour(
            red: tint.red * opacity + background.red * (1 - opacity),
            green: tint.green * opacity + background.green * (1 - opacity),
            blue: tint.blue * opacity + background.blue * (1 - opacity)
        )
    }
}

/// A paint mixed from a ``FixtureColours/Pigment``.
public final class Paint: Pigment {
    /// The swatch that shows the paint.
    public let swatch: Swatch

    /// Creates a paint.
    ///
    /// - Parameters:
    ///   - name: The name of the pigment.
    ///   - swatch: The swatch that shows the paint.
    public init(name: String, swatch: Swatch) {
        self.swatch = swatch
        super.init(name: name)
    }
}
