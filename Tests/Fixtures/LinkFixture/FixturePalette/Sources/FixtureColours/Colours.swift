/// A colour described by its red, green and blue components.
public struct Colour: Hashable, Sendable {
    /// The red component, between zero and one.
    public var red: Double

    /// The green component, between zero and one.
    public var green: Double

    /// The blue component, between zero and one.
    public var blue: Double

    /// The colour without any light.
    public static let black = Colour(red: 0, green: 0, blue: 0)

    /// A component of a colour.
    public enum Channel: Sendable {
        /// The red component.
        case red

        /// The green component.
        case green

        /// The blue component.
        case blue
    }

    /// Returns the colour mixed with another colour in equal parts.
    ///
    /// - Parameter other: The colour to mix with.
    /// - Returns: The mixed colour.
    public func mixed(with other: Colour) -> Colour {
        Colour(red: (red + other.red) / 2, green: (green + other.green) / 2, blue: (blue + other.blue) / 2)
    }

    /// Returns the colour mixed with grey of the given brightness.
    ///
    /// - Parameter brightness: The brightness of the grey, between zero and one.
    /// - Returns: The mixed colour.
    public func mixed(with brightness: Double) -> Colour {
        mixed(with: Colour(red: brightness, green: brightness, blue: brightness))
    }

    /// Creates a colour from its components.
    ///
    /// - Parameters:
    ///   - red: The red component.
    ///   - green: The green component.
    ///   - blue: The blue component.
    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// A type that has a tint.
public protocol Tinted {
    /// The colour of the tint.
    var tint: Colour { get }
}

/// A named pigment that paints are mixed from.
open class Pigment {
    /// The name of the pigment.
    public let name: String

    /// Creates a pigment.
    ///
    /// - Parameter name: The name of the pigment.
    public init(name: String) {
        self.name = name
    }
}

/// A property wrapper that keeps a value between zero and one.
@propertyWrapper
public struct Clamped: Sendable {
    /// The clamped value.
    private var value: Double

    /// The value, kept between zero and one.
    public var wrappedValue: Double {
        get { value }
        set { value = min(max(newValue, 0), 1) }
    }

    /// Creates a clamped value.
    ///
    /// - Parameter wrappedValue: The initial value.
    public init(wrappedValue: Double) {
        self.value = min(max(wrappedValue, 0), 1)
    }
}
