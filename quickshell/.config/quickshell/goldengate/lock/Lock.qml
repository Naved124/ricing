pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.common
import qs.services

// The lock screen, as macOS 27 has it: the wallpaper, the date and the
// large rounded time at the top, the user's picture and name low down and
// a glass password field that shakes on a wrong password. `rice lock`,
// hypridle and gg lock call `lock lock`; one PAM conversation for every screen.
Scope {
    id: root

    property string password: ""
    property bool busy: false
    property bool failed: false
    signal shake()

    function lock() {
        if (sessionLock.locked) return;
        Shell.closeAll();
        password = "";
        failed = false;
        sessionLock.locked = true;
    }
    function submit() {
        if (busy || password === "") return;
        busy = true;
        failed = false;
        if (!pam.start()) { busy = false; failed = true; shake(); }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
        function isLocked(): bool { return sessionLock.locked; }
    }

    PamContext {
        id: pam
        config: "login"
        onPamMessage: if (responseRequired) respond(root.password)
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                sessionLock.locked = false;
                root.password = "";
            } else {
                root.failed = true;
                root.password = "";
                root.shake();
            }
        }
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: surface
            color: Theme.window

            Image {
                anchors.fill: parent
                source: Settings.wallpaper.lock !== "" ? "file://" + Settings.wallpaper.lock
                      : Theme.dark && Walls.night !== "" ? Walls.night : Walls.day
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Column {
                id: clock
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.08
                property date now: new Date()
                Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(clock.now, "dddd d MMMM")
                    color: Theme.onWallpaper
                    font.family: Theme.fontDisplay
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                    style: Text.Raised; styleColor: Theme.onWallpaperShadow
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.now, "h:mm")
                    color: Theme.onWallpaper
                    font.family: Theme.fontRounded
                    font.pixelSize: 132
                    font.weight: Font.Bold
                    style: Text.Raised; styleColor: Theme.onWallpaperShadow
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.72
                spacing: 12

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64; height: 64; radius: 32
                    color: Theme.graphite
                    clip: true
                    Image { anchors.fill: parent; source: Settings.user.avatar ? "file://" + Settings.user.avatar : ""; fillMode: Image.PreserveAspectCrop }
                    Label {
                        anchors.centerIn: parent
                        visible: !Settings.user.avatar
                        text: (Settings.user.name || Quickshell.env("USER") || "?").charAt(0).toUpperCase()
                        color: Theme.onWallpaper; font.pixelSize: 28
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Settings.user.name || Quickshell.env("USER") || ""
                    color: Theme.onWallpaper; strong: true
                    style: Text.Raised; styleColor: Theme.onWallpaperShadow
                }
                GlassPane {
                    id: field
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 220; height: 34
                    radius: 17
                    screen: surface.screen
                    SequentialAnimation on anchors.horizontalCenterOffset {
                        id: shakeAnim
                        running: false
                        NumberAnimation { to: -14; duration: 50 }
                        NumberAnimation { to: 12; duration: 70 }
                        NumberAnimation { to: -8; duration: 70 }
                        NumberAnimation { to: 0; duration: 60 }
                    }
                    Connections { target: root; function onShake() { shakeAnim.restart(); } }
                    TextInput {
                        id: input
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        color: Theme.label
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.textSize
                        enabled: !root.busy
                        focus: true
                        text: root.password
                        onTextChanged: { root.password = text; if (text !== "") root.failed = false; }
                        Keys.onReturnPressed: root.submit()
                        Component.onCompleted: forceActiveFocus()
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: root.failed ? qsTr("Wrong password") : qsTr("Enter Password")
                            color: Theme.label3
                        }
                    }
                }
            }
        }
    }
}
