import FixtureColours

/// A quick drawing in a single ``FixtureColours/Colour``.
///
/// Trace a sketch with ``outline()`` to obtain its ``Outline``.
///
/// ## See Also
///
/// - ``FixtureColours/Tinted``
/// - [Sketching guide](https://example.com/sketching)
public struct Sketch: Tinted, Sendable {
    /// The colour of the sketch.
    public var tint: Colour

    /// How dark the shading is.
    @Clamped public var shading: Double

    /// The colour component the sketch emphasises.
    public var emphasis: Colour.Channel = .red

    /// Returns the sketch lightened with grey.
    ///
    /// The tint is mixed with ``FixtureColours/Colour/mixed(with:)-(Double)``.
    ///
    /// - Parameter brightness: The brightness of the grey.
    /// - Returns: The lightened sketch.
    public func lightened(by brightness: Double) -> Sketch {
        Sketch(tint: tint.mixed(with: brightness))
    }

    /// Creates a sketch.
    ///
    /// - Parameter tint: The colour of the sketch.
    public init(tint: Colour) {
        self.tint = tint
        self.shading = 0.5
    }

    /// Returns the outline of the sketch.
    ///
    /// - Returns: The traced outline.
    public func outline() -> Outline {
        Outline(strokes: 1)
    }
}

/// The outline traced from a ``Sketch``.
public struct Outline: Sendable {
    /// The number of strokes.
    public var strokes: Int
}

/// A charcoal ``FixtureColours/Pigment`` for sketches.
///
/// ## See Also
///
/// - ``FixtureColours/Pigment``
public final class Charcoal: Pigment {
    /// Creates a charcoal pigment.
    public init() {
        super.init(name: "Charcoal")
    }
}
