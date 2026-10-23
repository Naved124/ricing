import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common

// An app's icon by its desktop id, class or icon name, MacTahoe's when it
// has one (its light set by day, its dark one at night: the shell's icon
// theme is fixed when it starts, so the path is swapped here); without one,
// a rounded tile with the app's initial
Item {
    id: root
    property string app: ""
    property real implicitSize: 48
    readonly property var entry: app ? (DesktopEntries.byId(app) || DesktopEntries.heuristicLookup(app)) : null
    // the entry's icon, else the name itself, its last part (com.anthropic.Claude → claude),
    // or the name without a -full (an icon theme may have only some sizes of one)
    readonly property string path: {
        if (!app) return "";
        const tries = [entry && entry.icon, app, app.toLowerCase(), app.split(".").pop().toLowerCase(), app.replace(/-full$/, "")];
        for (const t of tries) {
            const p = t ? Quickshell.iconPath(t, true) : "";
            if (p) return p.replace(/\/icons\/MacTahoe[^\/]*\//, Theme.dark ? "/icons/MacTahoe-dark/" : "/icons/MacTahoe-light/");
        }
        return "";
    }
    implicitWidth: implicitSize
    implicitHeight: implicitSize

    IconImage {
        anchors.fill: parent
        implicitSize: root.implicitSize
        visible: root.path !== ""
        source: root.path
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: parent.width * 0.08
        visible: root.path === ""
        radius: width * 0.22
        color: Theme.graphite
        Label {
            anchors.centerIn: parent
            text: ((root.entry && root.entry.name) || root.app.split(".").pop() || "?").charAt(0).toUpperCase()
            color: Theme.onAccent
            font.pixelSize: parent.height * 0.5
            strong: true
        }
    }
}
