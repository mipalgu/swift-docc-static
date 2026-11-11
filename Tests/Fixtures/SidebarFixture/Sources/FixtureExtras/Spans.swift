/// A span between two numbers.
///
/// Its operators have names that are awkward in paths: names starting with a period,
/// names containing a slash or a less-than sign, and the equality operator.
public struct Span: Equatable, Sendable {
    /// The lower bound.
    public var lower: Double

    /// The upper bound.
    public var upper: Double

    /// Creates a span.
    ///
    /// - Parameters:
    ///   - lower: The lower bound.
    ///   - upper: The upper bound.
    public init(lower: Double, upper: Double) {
        self.lower = lower
        self.upper = upper
    }

    /// Returns the smallest span covering two spans.
    public static func ... (lhs: Span, rhs: Span) -> Span {
        Span(lower: min(lhs.lower, rhs.lower), upper: max(lhs.upper, rhs.upper))
    }

    /// Returns the span from negative infinity to the upper bound of a span.
    public static prefix func ... (span: Span) -> Span {
        Span(lower: -.infinity, upper: span.upper)
    }

    /// Returns the span from the lower bound of a span to infinity.
    public static postfix func ... (span: Span) -> Span {
        Span(lower: span.lower, upper: .infinity)
    }

    /// Returns the span from negative infinity to just below the lower bound of a span.
    public static prefix func ..< (span: Span) -> Span {
        Span(lower: -.infinity, upper: span.lower.nextDown)
    }

    /// Returns the span from the lower bound of one span to just below that of another.
    public static func ..< (lhs: Span, rhs: Span) -> Span {
        Span(lower: lhs.lower, upper: rhs.lower.nextDown)
    }

    /// Divides both bounds of a span.
    public static func / (lhs: Span, rhs: Double) -> Span {
        Span(lower: lhs.lower / rhs, upper: lhs.upper / rhs)
    }

    /// Returns whether two spans have the same bounds.
    public static func == (lhs: Span, rhs: Span) -> Bool {
        lhs.lower == rhs.lower && lhs.upper == rhs.upper
    }
}

/// A marker, whose name differs from that of ``marker`` only in case.
public struct Marker: Sendable {
    /// Creates a marker.
    public init() {}
}

/// The default marker number, whose name differs from that of ``Marker`` only in case.
public let marker = 0

/// A size with a name that is not ASCII.
public struct Größe: Sendable {
    /// The value, also with a name that is not ASCII.
    public var wert: Double

    /// Creates a size.
    ///
    /// - Parameter wert: The value.
    public init(wert: Double) {
        self.wert = wert
    }
}
