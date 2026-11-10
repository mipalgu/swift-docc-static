import FixtureCore

/// A text label placed at a point.
public struct Label: Sendable {
    /// How the text is aligned relative to the anchor point.
    public enum Alignment: Sendable {
        /// Aligned to the leading edge.
        case leading
        /// Centred on the anchor.
        case centre
        /// Aligned to the trailing edge.
        case trailing
    }

    /// The text of the label.
    public var text: String

    /// The anchor point of the label.
    public var anchor: Point

    /// The alignment of the text.
    public var alignment: Alignment

    /// Creates a label.
    ///
    /// - Parameters:
    ///   - text: The text to show.
    ///   - anchor: Where to place the text.
    ///   - alignment: How to align the text.
    public init(text: String, anchor: Point, alignment: Alignment = .leading) {
        self.text = text
        self.anchor = anchor
        self.alignment = alignment
    }
}

/// A list of labels.
public typealias LabelList = [Label]

extension Canvas {
    /// Adds the anchor of a label to the canvas.
    ///
    /// - Parameter label: The label to add.
    public func add(_ label: Label) {
        add(label.anchor)
    }
}
