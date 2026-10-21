import QtQuick
import qs
import "icons.js" as Icons

// One of Abyss's icons, drawn in any colour at any size.
Image {
    id: root

    property string name: "app"
    property color color: Theme.ink
    property real size: 18
    property real stroke: 1.7

    width: size
    height: size
    sourceSize: Qt.size(size * 2, size * 2)
    smooth: true
    asynchronous: false
    source: "data:image/svg+xml;utf8," + encodeURIComponent(Icons.svg(name, color, stroke))
}
