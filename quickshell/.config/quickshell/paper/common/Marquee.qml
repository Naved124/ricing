pragma ComponentBehavior: Bound

import QtQuick

// A line too long for its place, slid along like a strip of ticker tape:
// it waits at its start, slides left until its end has shown and a second
// copy has come round behind it, and starts over. A line that fits stays
// still. Offsets are whole pixels, so the letters stay sharp.
//   delegate  the text (drawn twice while it scrolls)
Item {
    id: root

    property Component delegate
    property real gap: 56
    property real speed: 40                 // px a second
    property int pause: 1800                // ms at rest before each pass
    property real offset: 0

    readonly property real contentWidth: first.item ? first.item.implicitWidth : 0
    readonly property bool scrolling: contentWidth > width + 1

    implicitWidth: contentWidth
    implicitHeight: first.item ? first.item.implicitHeight : 0
    clip: true

    function restart() {
        pass.stop();
        offset = 0;
        if (scrolling && visible) pass.start();
    }
    onContentWidthChanged: Qt.callLater(restart)
    onScrollingChanged: Qt.callLater(restart)
    onVisibleChanged: Qt.callLater(restart)

    Item {
        x: -Math.round(root.offset)
        width: root.contentWidth * 2 + root.gap
        height: root.height

        Loader {
            id: first
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: root.delegate
        }
        Loader {
            x: root.contentWidth + root.gap
            anchors.verticalCenter: parent.verticalCenter
            active: root.scrolling
            sourceComponent: root.delegate
        }
    }

    SequentialAnimation {
        id: pass
        loops: Animation.Infinite
        PauseAnimation { duration: root.pause }
        NumberAnimation {
            target: root
            property: "offset"
            from: 0
            to: root.contentWidth + root.gap
            duration: (root.contentWidth + root.gap) / root.speed * 1000
        }
    }
}
