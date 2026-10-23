pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services

// System Settings: a real window (it gets the traffic lights and the
// window glass), a sidebar of panes and the pane on the right. Every
// change goes through gg, so the terminal and this agree.
FloatingWindow {
    id: root

    property string pane: "appearance"
    readonly property var panes: [
        { id: "appearance", t: qsTr("Appearance"), g: "◐" },
        { id: "glass", t: qsTr("Liquid Glass"), g: "◇" },
        { id: "desktop", t: qsTr("Desktop & Dock"), g: "▭" },
        { id: "menubar", t: qsTr("Menu Bar"), g: "▔" },
        { id: "accessibility", t: qsTr("Accessibility"), g: "♿" },
        { id: "wallpaper", t: qsTr("Wallpaper"), g: "▣" },
        { id: "about", t: qsTr("About"), g: "ⓘ" },
    ]
    // a window the red light closed is gone though `visible` stayed true, so
    // opening always hides it first and shows it again on the next tick
    function open(p) {
        if (p) pane = p;
        visible = false;
        Qt.callLater(() => root.visible = true);
    }

    title: qsTr("System Settings")
    implicitWidth: 820
    implicitHeight: 600
    visible: false
    color: Theme.window

    component Row_: RowLayout {
        property string label
        default property alias controls: box.data
        Layout.fillWidth: true
        Label { text: parent.label; Layout.fillWidth: true }
        RowLayout { id: box; spacing: 6 }
    }
    component Choice: Rectangle {
        property string text
        property bool on
        signal picked()
        implicitWidth: t.implicitWidth + 22; implicitHeight: 26; radius: 13
        color: on ? Theme.accent : Theme.fill
        Label { id: t; anchors.centerIn: parent; text: parent.text; color: parent.on ? Theme.onAccent : Theme.label; font.pixelSize: Theme.smallSize + 1 }
        MouseArea { anchors.fill: parent; onClicked: parent.picked() }
    }
    component Switch_: Rectangle {
        property bool on
        signal flipped()
        implicitWidth: 38; implicitHeight: 22; radius: 11
        color: on ? Theme.accent : Theme.fillPress
        Rectangle { x: parent.on ? 18 : 2; y: 2; width: 18; height: 18; radius: 9; color: Theme.onAccent; Behavior on x { SpringAnimation { spring: Theme.spring; damping: Theme.damping } } }
        MouseArea { anchors.fill: parent; onClicked: parent.flipped() }
    }
    function set(key, v) { Shell.gg(["set", key, JSON.stringify(v)]); }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 220
            color: Theme.grouped
            Column {
                anchors { fill: parent; margins: 10; topMargin: 44 }
                spacing: 2
                Repeater {
                    model: root.panes
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 30; radius: 7
                        color: root.pane === modelData.id ? Theme.accent : "transparent"
                        Label { x: 10; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.g + "   " + parent.modelData.t; color: root.pane === parent.modelData.id ? Theme.onAccent : Theme.label }
                        MouseArea { anchors.fill: parent; onClicked: root.pane = parent.modelData.id }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 24
            spacing: 14

            Label { text: root.panes.find(p => p.id === root.pane).t; font.family: Theme.fontDisplay; font.pixelSize: Theme.titleSize + 3; strong: true }

            // Appearance
            ColumnLayout {
                visible: root.pane === "appearance"
                Layout.fillWidth: true
                spacing: 14
                Row_ {
                    label: qsTr("Appearance")
                    Choice { text: qsTr("Light"); on: !Theme.dark; onPicked: Shell.gg(["appearance", "light"]) }
                    Choice { text: qsTr("Dark"); on: Theme.dark; onPicked: Shell.gg(["appearance", "dark"]) }
                    Choice { text: qsTr("Auto"); onPicked: Shell.gg(["appearance", "auto"]) }
                }
                Row_ {
                    label: qsTr("Accent colour")
                    Repeater {
                        model: Theme.accentNames
                        delegate: Rectangle {
                            required property string modelData
                            width: 20; height: 20; radius: 10
                            color: Theme.accentOf(modelData, Theme.blue)
                            border.width: Theme.accentName === modelData ? 3 : 0
                            border.color: Theme.label3
                            MouseArea { anchors.fill: parent; onClicked: Shell.gg(["accent", parent.modelData]) }
                        }
                    }
                }
                Row_ { label: qsTr("Accent from the wallpaper"); Choice { text: qsTr("Use"); onPicked: Shell.gg(["accent", "wallpaper"]) } }
            }
            // Liquid Glass
            ColumnLayout {
                visible: root.pane === "glass"
                Layout.fillWidth: true
                spacing: 14
                Row_ {
                    label: qsTr("Glass")
                    Choice { text: qsTr("Liquid"); on: Theme.glassMode === "liquid"; onPicked: Shell.gg(["glass", "liquid"]) }
                    Choice { text: qsTr("Frosted"); on: Theme.glassMode === "frosted"; onPicked: Shell.gg(["glass", "frosted"]) }
                    Choice { text: qsTr("Solid"); on: Theme.glassMode === "solid"; onPicked: Shell.gg(["glass", "solid"]) }
                }
                Row_ {
                    label: qsTr("Clarity: Ultraclear … Tinted")
                    Slider {
                        implicitWidth: 240
                        value: Theme.clarity
                        onMoved: v => clarityLater.v = v
                    }
                }
                Row_ {
                    label: qsTr("Drawn by")
                    Repeater {
                        model: ["auto", "hyprglass", "hyprliquid", "shader"]
                        Choice { required property string modelData; text: modelData; on: Settings.glass.backend === modelData; onPicked: Shell.gg(["glass", "backend", modelData]) }
                    }
                }
                Row_ { label: qsTr("Accurate (the shell's shader sees windows)"); Switch_ { on: Settings.glass.accurate; onFlipped: root.set("glass.accurate", !on) } }
                Label { text: Glass.reason ? qsTr("Now: Frosted, because %1").arg(Glass.reason) : qsTr("Now: %1 (%2)").arg(Glass.mode).arg(Glass.backend); secondary: true; wrapMode: Text.Wrap; Layout.fillWidth: true }
                Timer {
                    id: clarityLater
                    property real v: -1
                    interval: 250
                    onVChanged: restart()
                    onTriggered: Shell.gg(["glass", "clarity", v.toFixed(2)])
                }
            }
            // Desktop & Dock
            ColumnLayout {
                visible: root.pane === "desktop"
                Layout.fillWidth: true
                spacing: 14
                Row_ { label: qsTr("Dock size"); Slider { implicitWidth: 240; value: (Settings.dock.size - 32) / 64; onMoved: v => root.set("dock.size", Math.round(32 + v * 64)) } }
                Row_ { label: qsTr("Magnification"); Switch_ { on: Settings.dock.magnify; onFlipped: root.set("dock.magnify", !on) } }
                Row_ { label: qsTr("Hide the Dock automatically"); Switch_ { on: Settings.dock.autohide; onFlipped: root.set("dock.autohide", !on) } }
                Row_ {
                    label: qsTr("Windows")
                    Choice { text: qsTr("Floating"); on: Settings.windows.layout !== "tiled"; onPicked: root.set("windows.layout", "floating") }
                    Choice { text: qsTr("Tiled"); on: Settings.windows.layout === "tiled"; onPicked: root.set("windows.layout", "tiled") }
                }
                Repeater {
                    model: [["tl", qsTr("Top left corner")], ["tr", qsTr("Top right corner")], ["bl", qsTr("Bottom left corner")], ["br", qsTr("Bottom right corner")]]
                    delegate: Row_ {
                        id: hc
                        required property var modelData
                        label: modelData[1]
                        readonly property string cur: (Settings.desktop.hotCorners || {})[modelData[0]] || "none"
                        Repeater {
                            model: ["none", "missioncontrol", "desktop", "notifications", "apps", "lock"]
                            Choice {
                                required property string modelData
                                text: modelData
                                on: hc.cur === modelData
                                onPicked: {
                                    const c = Object.assign({}, Settings.desktop.hotCorners);
                                    c[hc.modelData[0]] = modelData;
                                    root.set("desktop.hotCorners", c);
                                }
                            }
                        }
                    }
                }
            }
            // Menu Bar
            ColumnLayout {
                visible: root.pane === "menubar"
                Layout.fillWidth: true
                spacing: 14
                Row_ { label: qsTr("Show the menu bar background"); Switch_ { on: Settings.appearance.menuBarBackground; onFlipped: root.set("appearance.menuBarBackground", !on) } }
                Row_ { label: qsTr("Battery percentage"); Switch_ { on: Settings.menubar.batteryPercent; onFlipped: root.set("menubar.batteryPercent", !on) } }
                Row_ { label: qsTr("Now playing"); Switch_ { on: Settings.menubar.nowPlaying; onFlipped: root.set("menubar.nowPlaying", !on) } }
                Row_ {
                    label: qsTr("Dynamic Island")
                    Repeater {
                        model: ["always", "activities", "off"]
                        Choice { required property string modelData; text: modelData; on: Settings.island.show === modelData; onPicked: root.set("island.show", modelData) }
                    }
                }
            }
            // Accessibility
            ColumnLayout {
                visible: root.pane === "accessibility"
                Layout.fillWidth: true
                spacing: 14
                Row_ { label: qsTr("Reduce motion"); Switch_ { on: Settings.accessibility.reduceMotion; onFlipped: root.set("accessibility.reduceMotion", !on) } }
                Row_ { label: qsTr("Reduce transparency"); Switch_ { on: Settings.accessibility.reduceTransparency; onFlipped: root.set("accessibility.reduceTransparency", !on) } }
                Row_ { label: qsTr("Increase contrast"); Switch_ { on: Settings.accessibility.increaseContrast; onFlipped: root.set("accessibility.increaseContrast", !on) } }
            }
            // Wallpaper
            ColumnLayout {
                visible: root.pane === "wallpaper"
                Layout.fillWidth: true
                spacing: 14
                Row_ {
                    label: qsTr("Desktop picture")
                    Choice { text: qsTr("Previous"); onPicked: Shell.gg(["wall", "prev"]) }
                    Choice { text: qsTr("Next"); onPicked: Shell.gg(["wall", "next"]) }
                }
                Label { text: Settings.wallpaper.dir; secondary: true }
            }
            // About
            ColumnLayout {
                visible: root.pane === "about"
                Layout.fillWidth: true
                spacing: 8
                Label { text: "Golden Gate"; font.family: Theme.fontDisplay; font.pixelSize: 30; strong: true }
                Label { text: qsTr("macOS 27 on Hyprland and Quickshell"); secondary: true }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
