pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs
import qs.services

// The lock screen: an ext-session-lock surface on every monitor, each with
// its own reef, one PAM conversation shared between them. While it's up the
// wallpaper's reefs stop (Shell.locked). `rice lock` (and hypridle) call
//   qs -c abyss ipc call lock lock
Scope {
    id: root

    property string password: ""
    property bool busy: false
    property bool failed: false
    property string message: ""
    property bool leaving: false        // the water clearing, before unlocking

    signal shake()

    function lock() {
        if (sessionLock.locked) return;
        Shell.closeAll();
        password = "";
        failed = false;
        message = "";
        leaving = false;
        sessionLock.locked = true;
    }

    function submit() {
        if (busy || password === "") return;
        busy = true;
        failed = false;
        message = "";
        if (!pam.start()) {
            busy = false;
            failed = true;
            message = "Couldn't start authentication";
            shake();
        }
    }

    Binding { target: Shell; property: "locked"; value: sessionLock.locked }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
        function isLocked(): bool { return sessionLock.locked; }
    }

    PamContext {
        id: pam
        // /etc/pam.d/login: the password you log in with
        config: "login"
        onPamMessage: {
            if (responseRequired) respond(root.password);
            else if (messageIsError) root.message = message;
        }
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.leaving = true;
                unlockTimer.start();
            } else {
                root.password = "";
                root.failed = true;
                if (root.message === "") root.message = result === PamResult.MaxTries ? "Too many tries — wait a moment" : "Not that one";
                root.shake();
            }
        }
    }

    // let the water clear, then give the compositor the screens back
    Timer {
        id: unlockTimer
        interval: 900
        onTriggered: {
            sessionLock.locked = false;
            root.password = "";
            root.leaving = false;
        }
    }

    WlSessionLock {
        id: sessionLock
        WlSessionLockSurface {
            id: surface
            color: Theme.abyss
            LockSurface {
                anchors.fill: parent
                lock: root
                screen: surface.screen
            }
        }
    }
}
