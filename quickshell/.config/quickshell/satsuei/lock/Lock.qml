pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.common
import qs.services

// The lock screen, an episode's title card: an ext-session-lock surface on
// every monitor (LockSurface), one PAM conversation shared between them.
// While it's up the plates' passes stop (Shell.locked; the lock grades its
// own). Today's title comes from ~/.config/rices/satsuei/lock-titles.json,
// one for each date of the year in calendar order (366, 29 February's
// included), so 7 July is always Tanabata's. `rice lock` (and hypridle) call
//   qs -c satsuei ipc call lock lock
Scope {
    id: root

    property string password: ""
    property bool busy: false
    property bool failed: false
    property string message: ""
    property bool leaving: false        // fading out, before unlocking

    signal shake()

    // ── today's episode ────────────────────────────────────────────────────
    property var titles: [["窓辺の光", "The Light by the Window"]]
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/rices/satsuei/lock-titles.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const t = JSON.parse(text()).filter(e => Array.isArray(e) && e.length >= 2);
                if (t.length) root.titles = t;
            } catch (e) {}
        }
    }
    // round, not floor: a day with a clock change is an hour short or long
    function dayOfYear(d) { return Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - new Date(d.getFullYear(), 0, 0)) / 864e5); }
    function episode(d) {
        const n = dayOfYear(d);
        // the title by the date, counted as in a leap year, so a common year skips 29 February's
        const day = dayOfYear(new Date(2000, d.getMonth(), d.getDate()));
        const t = titles[(day - 1) % titles.length];
        return { n, ja: t[0], en: t[1] };
    }

    function lock() {
        if (sessionLock.locked) { Shell.locked = true; return; }
        Shell.closeAll();
        password = "";
        failed = false;
        message = "";
        leaving = false;
        sessionLock.locked = true;
        Shell.locked = true;
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

    // set and cleared right where the lock goes up and comes down (a Binding
    // to sessionLock.locked can be left true after an unlock)
    function released() {
        Shell.locked = false;
        root.password = "";
        root.leaving = false;
        root.busy = false;
    }
    Connections {
        target: sessionLock
        // the compositor can end the lock itself (another locker, a crash)
        function onLockedChanged() { if (!sessionLock.locked) root.released(); }
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

    // the card fades, then the compositor gets the screens back
    Timer {
        id: unlockTimer
        interval: 600
        onTriggered: {
            sessionLock.locked = false;
            root.released();
        }
    }

    WlSessionLock {
        id: sessionLock
        WlSessionLockSurface {
            id: surface
            color: Theme.ink
            LockSurface {
                anchors.fill: parent
                lock: root
                screen: surface.screen
            }
        }
    }
}
