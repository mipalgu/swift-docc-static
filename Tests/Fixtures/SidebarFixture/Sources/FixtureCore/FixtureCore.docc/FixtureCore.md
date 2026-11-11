# ``FixtureCore``

Core geometry types used to exercise the static documentation renderer.

## Overview

FixtureCore provides a small set of geometric types such as ``Point`` and
``Canvas``. Read <doc:GettingStarted> for a tour and <doc:WorkingWithShapes>
for shapes.

Strokes of a layer's style follow a pattern: a canvas always draws all of its points and its lines
with the pattern of ``Canvas/Layer/Style/Stroke/Pattern-swift.enum``, and
``Canvas/Layer/Style/Stroke/Pattern-swift.enum`` decides whether they are solid.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:WorkingWithShapes>
- ``Point``
- ``Canvas``

### Shapes

- ``Shape``
- ``Circle``

### Directions and Drawing

- ``Direction``
- ``Drawable``

### Functions

- ``midpoint(_:_:)``
