import QtQuick

// Any character, built-in or the user's own, in one place: the media card's
// dancer, the timesheet's little one, the strip's tiles. Loads the cast's
// file (Hana.qml … or Custom.qml for a folder character) and hands it the
// cast, its mode, the energy, whether it runs and how often it ticks.
Item {
    id: root

    property var cast: Characters.dancer
    property string mode: "idle"
    property real energy: 0.6
    property bool running: true
    property int interval: 33

    Loader {
        anchors.fill: parent
        source: Qt.resolvedUrl(root.cast.file)
        onLoaded: {
            item.cast = Qt.binding(() => root.cast);
            item.mode = Qt.binding(() => root.mode);
            item.energy = Qt.binding(() => root.energy);
            item.running = Qt.binding(() => root.running);
            item.interval = Qt.binding(() => root.interval);
        }
    }
}
