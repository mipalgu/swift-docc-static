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
