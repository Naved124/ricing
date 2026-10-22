pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Satsuei's chooser card: the generic card, its picture the plate on screen
// now (whatever wallpaper Satsuei last took its look from, read from
// theme.json; the seed before any), with the 撮 seal in the corner and a
// light leak sweeping across it while it's chosen. Its colours are the
// rendered palette's, so they're that plate's too.
Item {
    id: root

    property var rice: ({})
    property bool selected: false
    property bool active: false
    property url base
    property string mode: "dark"

    readonly property var c: rice?.meta?.colors ?? {}
    readonly property string home: Quickshell.env("HOME")
    property string plate: ""

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || root.home + "/.local/state") + "/satsuei/theme.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.plate = JSON.parse(text()).plate ?? ""; } catch (e) { root.plate = ""; }
        }
        onLoadFailed: root.plate = (Quickshell.env("XDG_CONFIG_HOME") || root.home + "/.config") + "/rices/satsuei/seed/wall.webp"
    }

    Loader {
        id: inner
        anchors.fill: parent
        source: root.base
    }
    Binding { target: inner.item; property: "rice"; value: root.rice; when: inner.status === Loader.Ready }
    Binding { target: inner.item; property: "selected"; value: root.selected; when: inner.status === Loader.Ready }
    Binding { target: inner.item; property: "active"; value: root.active; when: inner.status === Loader.Ready }

    // over the picture (GenericCard's 16 px margin, 150 tall)
    Item {
        x: 16
        y: 16
        width: root.width - 32
        height: 150
        clip: true

        Image {
            anchors.fill: parent
            source: root.plate ? "file://" + root.plate : ""
            sourceSize.width: 600
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
        // the light leak: a warm band drifting across while chosen
        Rectangle {
            id: leak
            width: parent.width * 0.6
            height: parent.height * 2.2
            y: -parent.height * 0.6
            rotation: 22
            opacity: root.selected ? 0.55 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: root.c.accent ?? "transparent" }
                GradientStop { position: 1; color: "transparent" }
            }
            NumberAnimation on x {
                running: root.selected && root.visible
                from: -leak.width
                to: leak.parent.width + leak.width * 0.2
                duration: 2600
                loops: Animation.Infinite
                easing.type: Easing.InOutSine
            }
        }
        // the seal
        Rectangle {
            x: 8
            y: 8
            width: 26
            height: 26
            radius: 8
            color: root.c.accent ?? "transparent"
            Text {
                anchors.centerIn: parent
                text: "撮"
                color: root.c.on_accent ?? "transparent"
                font.family: root.rice?.meta?.fonts?.display ?? ""
                font.pixelSize: 15
            }
        }
    }
}
