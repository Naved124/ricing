pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.common
import qs.services

// The lock screen: an ext-session-lock surface on every monitor and one PAM
// conversation shared between them. `rice lock` (and hypridle) call
//   qs -c paper ipc call lock lock
Scope {
    id: root

    property string password: ""
    property bool busy: false
    property bool failed: false
    property string message: ""
    property bool opening: false        // the envelope opens before unlocking

    signal shake()

    function lock() {
        if (sessionLock.locked) return;
        Shell.closeAll();
        password = "";
        failed = false;
        message = "";
        opening = false;
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
            message = "couldn't start authentication";
            shake();
        }
    }

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
                root.opening = true;
                unlockTimer.start();
            } else {
                // the dots stay, struck through, until the next key
                root.failed = true;
                if (root.message === "") root.message = result === PamResult.MaxTries ? "too many tries, wait a moment" : "that's not it";
                root.shake();
            }
        }
    }

    // the flap opens, the letter slides up, everything fades: then unlock
    Timer {
        id: unlockTimer
        interval: 600 + 450
        onTriggered: {
            sessionLock.locked = false;
            root.password = "";
            root.opening = false;
        }
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: surface
            color: Theme.kraft

            Envelope {
                anchors.fill: parent
                lock: root
                screen: surface.screen
            }
        }
    }
}
