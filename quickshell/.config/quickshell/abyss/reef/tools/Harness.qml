import QtQuick
import ".."

// The reef on its own, for tools/still.py and the side-by-side check: the
// palette's look comes in as `look` (tools/still.py reads palette.toml).
Item {
    id: root
    required property var look
    property alias reef: reef
    Reef {
        id: reef
        objectName: "reef"
        anchors.fill: parent
        colors: root.look.colors
        kelpColor: root.look.kelpColor
        hues: root.look.hues
        waterTop: Qt.vector3d(...root.look.top)
        waterMid: Qt.vector3d(...root.look.mid)
        waterBottom: Qt.vector3d(...root.look.bottom)
    }
}
