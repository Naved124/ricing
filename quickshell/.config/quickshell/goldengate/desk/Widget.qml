import QtQuick
import qs.common

// a desktop widget: glass, dragged anywhere in `area`, its place (`at`, as
// fractions of the room left around it) reported when dropped
GlassPane {
    id: w
    property var area   // the window it lies in
    property point at
    signal moved(real fx, real fy)
    radius: 22
    x: area ? at.x * (area.width - width) : 0
    y: area ? at.y * (area.height - height) : 0
    DragHandler {
        target: w
        onActiveChanged: if (!active) w.moved(w.x / Math.max(1, w.area.width - w.width), w.y / Math.max(1, w.area.height - w.height))
    }
}
