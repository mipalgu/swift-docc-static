# Getting Started

Create points and draw them on a canvas.

## Overview

This article shows the main types of the module together with the
`Point` and `Canvas` types. The [`swift build`](https://www.swift.org/documentation/)
command builds the module, and ``Point/distance(to:)`` measures distances.

### Creating Points

Create a point with ``Point/init(x:y:)`` and measure distances:

```swift
let a = Point(x: 0, y: 0)
let b = Point(x: 3, y: 4)
print(a.distance(to: b)) // 5.0
let description = "The distance between \(a) and \(b) is \(a.distance(to: b)), which is a fairly long line of Swift code."
```

Points can also be described as JSON:

```json
{
  "x": 3,
  "y": 4,
  "comment": "A JSON listing with a long line that does not fit into the content column at desktop widths"
}
```

### Comparing Directions

| Direction | Opposite |
| --------- | -------- |
| north     | south    |
| east      | west     |

Things to remember:

- Points are values.
- A canvas is a reference type.
  1. Create a canvas.
  2. Add points.

![A blue rectangle standing in for a canvas.](canvas-diagram.png)

## Drawing

Drawing is covered in the tutorial.

### Asides

> Note: Coordinates are stored as `Double` values.

> Warning: A canvas is not thread-safe.

> Important: Always draw on the canvas you created.

> Tip: Use ``midpoint(_:_:)`` to find the centre between two points.

> Experiment: Try scaling a point with ``Point/scaled(by:)``.
