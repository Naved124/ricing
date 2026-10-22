import QtQuick

// A part of a character (its head, an arm, the tail) that the rig moves:
// rotated by `angle` about (ox, oy), moved by (dx, dy), squashed by `sy`
// (and `sx`) about the same point. The canvas's 120 × 160, so the parts'
// shapes keep the mock's coordinates.
Item {
    id: part

    property real angle: 0
    property real ox: 60
    property real oy: 80
    property real dx: 0
    property real dy: 0
    property real sx: 1
    property real sy: 1

    width: 120
    height: 160
    transform: [
        Scale { origin.x: part.ox; origin.y: part.oy; xScale: part.sx; yScale: part.sy },
        Rotation { origin.x: part.ox; origin.y: part.oy; angle: part.angle },
        Translate { x: part.dx; y: part.dy }
    ]
}
