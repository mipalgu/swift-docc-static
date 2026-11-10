# Getting Started

Create points and draw them on a canvas.

## Overview

This article shows the main types of the module together with the
`Point` and `Canvas` types.

### Creating Points

Create a point with ``Point/init(x:y:)`` and measure distances:

```swift
let a = Point(x: 0, y: 0)
let b = Point(x: 3, y: 4)
print(a.distance(to: b)) // 5.0
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

> Note: Coordinates are stored as `Double` values.

> Warning: A canvas is not thread-safe.

> Important: Always draw on the canvas you created.

> Tip: Use ``midpoint(_:_:)`` to find the centre between two points.
