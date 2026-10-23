//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.common
import qs.services

// Golden Gate's login screen: the lock screen's look before anyone has
// logged in. The date and the large rounded time at the top, the user's
// picture, name and a glass password field low down, Sleep, Restart and
// Shut Down under them, as on the Mac. It runs under greetd inside cage,
// as the greeter user, from a copy of this shell in /etc/greetd/goldengate
// that `sudo system/install --greetd` makes: XDG_CONFIG_HOME and
// XDG_STATE_HOME point into that copy (the settings, the wallpaper, the
// mode), and greeter.json says who logs in and what session starts.
ShellRoot {
    id: root

    property string password: ""
    property bool busy: false
    property string message: ""
    property var who: ({ user: "", name: "", avatar: false, session: ["start-hyprland"] })

    readonly property string home: Quickshell.env("XDG_CONFIG_HOME") || ""
    FileView {
        path: root.home + "/greeter.json"
        printErrors: false
        onLoaded: { try { root.who = Object.assign({}, root.who, JSON.parse(text())); } catch (e) {} }
    }
    readonly property string shownName: who.name || Settings.user.name || who.user

    function submit() {
        if (busy || password === "" || !who.user) return;
        busy = true;
        message = "";
        if (Greetd.state === GreetdState.Inactive) Greetd.createSession(who.user);
        else Greetd.respond(password);
    }
    function fail(text) {
        busy = false;
        password = "";
        message = text;
        shake();
        if (Greetd.state !== GreetdState.Inactive) Greetd.cancelSession();
    }
    signal shake()

    Connections {
        target: Greetd
        function onAuthMessage(text, error, responseRequired, echoResponse) {
            if (responseRequired) Greetd.respond(root.password);
            else if (error) root.message = text;
        }
        function onAuthFailure(text) { root.fail(qsTr("Wrong password")); }
        function onError(text) { root.fail(text); }
        function onReadyToLaunch() { Greetd.launch(root.who.session); }
    }

    FloatingWindow {
        id: win
        color: Theme.window
        title: "Golden Gate"
        // cage gives it the whole output anyway
        implicitWidth: screen ? screen.width : 1920
        implicitHeight: screen ? screen.height : 1080

        // the desktop picture, darkened a little while the password is typed
        Image {
            id: wall
            anchors.fill: parent
            source: Walls.at(Theme.dark)
            fillMode: Walls.fillMode
            asynchronous: true
            sourceSize: Qt.size(win.width, win.height)
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
            opacity: root.password !== "" ? 0.5 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
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
            y: parent.height * 0.66
            spacing: 12

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 76; height: 76; radius: 38
                color: Theme.graphite
                clip: true
                Image {
                    id: face
                    anchors.fill: parent
                    source: root.who.avatar ? "file://" + root.home + "/avatar" : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Label {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: (root.shownName || "?").charAt(0).toUpperCase()
                    color: Theme.onWallpaper; font.pixelSize: 32
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.shownName
                color: Theme.onWallpaper; strong: true
                font.pixelSize: Theme.textSize + 2
                style: Text.Raised; styleColor: Theme.onWallpaperShadow
            }
            GlassPane {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 220; height: 34
                radius: 17
                ownFrost: true
                screen: win.screen
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
                    anchors { fill: parent; leftMargin: 14; rightMargin: 34 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: Theme.label
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.textSize
                    enabled: !root.busy
                    focus: true
                    text: root.password
                    onTextChanged: { root.password = text; if (text !== "") root.message = ""; }
                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()
                    Component.onCompleted: forceActiveFocus()
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: root.message || qsTr("Enter Password")
                        color: Theme.label3
                    }
                }
                // the arrow that logs in, once something is typed
                Rectangle {
                    anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
                    width: 24; height: 24; radius: 12
                    visible: root.password !== ""
                    color: go.containsMouse ? Theme.fillPress : Theme.fillHover
                    Label { anchors.centerIn: parent; text: root.busy ? "…" : "→"; strong: true }
                    MouseArea { id: go; anchors.fill: parent; hoverEnabled: true; onClicked: root.submit() }
                }
            }
        }

        // Sleep, Restart, Shut Down
        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 48 }
            spacing: 44
            Repeater {
                model: [
                    { g: "☾", t: qsTr("Sleep"), cmd: ["systemctl", "suspend"] },
                    { g: "↻", t: qsTr("Restart"), cmd: ["systemctl", "reboot"] },
                    { g: "⏻", t: qsTr("Shut Down"), cmd: ["systemctl", "poweroff"] },
                ]
                delegate: Column {
                    id: power
                    required property var modelData
                    spacing: 6
                    GlassPane {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 44; height: 44; radius: 22
                        ownFrost: true
                        screen: win.screen
                        Label { anchors.centerIn: parent; text: power.modelData.g; font.pixelSize: 20 }
                        MouseArea { anchors.fill: parent; onClicked: Quickshell.execDetached(power.modelData.cmd) }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: power.modelData.t
                        color: Theme.onWallpaper
                        font.pixelSize: Theme.smallSize
                        style: Text.Raised; styleColor: Theme.onWallpaperShadow
                    }
                }
            }
        }
    }
}
