/// A point in a two-dimensional plane.
///
/// Points are value types that can be added together and measured.
public struct Point: Hashable, Sendable {
    /// The horizontal coordinate.
    public var x: Double

    /// The vertical coordinate.
    public var y: Double

    /// The point at the origin of the plane.
    public static let origin = Point(x: 0, y: 0)

    /// Creates a point from its coordinates.
    ///
    /// - Parameters:
    ///   - x: The horizontal coordinate.
    ///   - y: The vertical coordinate.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// Returns the Euclidean distance to another point.
    ///
    /// - Parameter other: The point to measure to.
    /// - Returns: The distance between the two points.
    public func distance(to other: Point) -> Double {
        let dx = other.x - x
        let dy = other.y - y
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Returns the distance to `other` along the horizontal axis; prefer ``distance(to:)``.
    ///
    /// - Parameter other: The point to measure to.
    /// - Returns: The absolute difference of the horizontal coordinates.
    @available(*, deprecated, message: "Use distance(to:) instead.")
    public func horizontalDistance(to other: Point) -> Double {
        abs(other.x - x)
    }

    /// Adds two points component by component.
    ///
    /// - Parameters:
    ///   - lhs: The first point.
    ///   - rhs: The second point.
    /// - Returns: The component-wise sum.
    public static func + (lhs: Point, rhs: Point) -> Point {
        Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    /// The coordinates of a point as a pair.
    public struct Components: Sendable {
        /// The first component.
        public var first: Double

        /// The second component.
        public var second: Double
    }

    /// The coordinates of this point as components.
    public var components: Components {
        Components(first: x, second: y)
    }
}

/// A compass direction.
public enum Direction: CaseIterable, Sendable {
    /// Towards the top.
    case north
    /// Towards the right.
    case east
    /// Towards the bottom.
    case south
    /// Towards the left.
    case west

    /// The direction pointing the other way.
    public var opposite: Direction {
        switch self {
        case .north: .south
        case .east: .west
        case .south: .north
        case .west: .east
        }
    }
}

/// A type that can draw itself on a canvas.
public protocol Drawable {
    /// Draws the receiver.
    ///
    /// - Parameter canvas: The canvas to draw on.
    func draw(on canvas: Canvas)
}

/// A surface that collects points.
public final class Canvas {
    /// The points drawn so far.
    public private(set) var points: [Point] = []

    /// Creates an empty canvas.
    public init() {}

    /// Adds a point to the canvas.
    ///
    /// - Parameter point: The point to add.
    public func add(_ point: Point) {
        points.append(point)
    }
}

extension Point: Drawable {
    /// Draws the point by adding it to the canvas.
    ///
    /// - Parameter canvas: The canvas to draw on.
    public func draw(on canvas: Canvas) {
        canvas.add(self)
    }
}

/// Returns the point halfway between two points.
///
/// - Parameters:
///   - a: The first point.
///   - b: The second point.
/// - Returns: The midpoint.
public func midpoint(_ a: Point, _ b: Point) -> Point {
    Point(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
}

extension Point {
    /// Errors raised when transforming points.
    public enum TransformError: Error, Sendable {
        /// The scale factor is not a finite, positive number.
        case invalidScale(Double)
    }

    /// Returns the point scaled by a factor relative to the origin.
    ///
    /// Use this method to enlarge or shrink a shape point by point.
    ///
    /// - Parameter factor: The positive, finite factor to scale by.
    /// - Returns: A new point whose coordinates are multiplied by `factor`.
    /// - Throws: ``TransformError/invalidScale(_:)`` if `factor` is not positive and finite.
    public func scaled(by factor: Double) throws -> Point {
        guard factor.isFinite, factor > 0 else { throw TransformError.invalidScale(factor) }
        return Point(x: x * factor, y: y * factor)
    }
}

/// A closed figure with an area.
///
/// Conforming types only need to provide ``area``; ``describe()`` has a default
/// implementation.
public protocol Shape {
    /// The area enclosed by the shape.
    var area: Double { get }

    /// Returns a short description of the shape.
    ///
    /// - Returns: A description that includes the area.
    func describe() -> String
}

extension Shape {
    /// Returns a description that mentions the area of the shape.
    ///
    /// - Returns: A description such as `Shape with area 3.0`.
    public func describe() -> String {
        "Shape with area \(area)"
    }
}

/// A circle defined by its centre and radius.
public struct Circle: Shape, Equatable, Sendable {
    /// The centre of the circle.
    public var centre: Point

    /// The radius of the circle.
    public var radius: Double

    /// Creates a circle.
    ///
    /// - Parameters:
    ///   - centre: The centre point.
    ///   - radius: The radius, which must not be negative.
    public init(centre: Point, radius: Double) {
        self.centre = centre
        self.radius = radius
    }

    /// The area enclosed by the circle.
    public var area: Double { Double.pi * radius * radius }
}

extension Canvas {
    /// A layer that groups drawing operations.
    public struct Layer: Sendable {
        /// The name of the layer.
        public var name: String

        /// The visual style of a layer.
        public struct Style: Sendable {
            /// The opacity between zero and one.
            public var opacity: Double

            /// How outlines are drawn.
            public struct Stroke: Sendable {
                /// The width of the outline in points.
                public var width: Double

                /// The dash pattern of the outline.
                public enum Pattern: Sendable {
                    /// A continuous line.
                    case solid
                    /// A dashed line with the given segment length.
                    case dashed(length: Double)
                }

                /// The dash pattern.
                public var pattern: Pattern
            }

            /// The outline style.
            public var stroke: Stroke
        }

        /// The style of the layer.
        public var style: Style
    }
}
