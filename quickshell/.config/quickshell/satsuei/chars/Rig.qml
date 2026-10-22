import QtQuick
import qs.services

// What every built-in character is: a 120 × 160 canvas (the mock's viewBox)
// scaled to fit the host, feet on its bottom edge, and the pose worked out
// from the mock's pose(). The character itself is the parts it lays on the
// canvas (Part, Blob), bound to the pose:
//   all        bob (up), sway (degrees, about the feet)
//   head       tilt (degrees, about the neck)
//   armL/armR  aL / aR (degrees, about the shoulders)
//   legL/legR  lL / lR (up)
//   extra      ex (degrees: the ahoge, a tail, an antenna)
//   eyes       eyes (1 open, 0 shut; a blink is 130 ms every 2.5–5.5 s)
//   mouth      mouthOpen (dancing, waving)
// Modes: dance (on the beat: `phase` runs at half the tempo, faster when it's
// loud), idle (breathing, a small tilt), wave (the right arm up, at 12 rad/s)
// and sleep (the head down 14°, eyes almost shut, slow breathing).
// `profile` scales each motion ({ bob, tilt, sway, arms, legs, extra, speed },
// and `steps`: snap from pose to pose, 1/steps of a beat each),
// so every character dances its own way; a character can read `beat` (the
// phase in radians: one beat is π) and `t` for moves of its own.
// It ticks at 30 fps only while `running`; between ticks nothing redraws.
Item {
    id: rig

    property string mode: "idle"            // dance | idle | wave | sleep
    property real energy: 0.6               // 0–1: the music's loudness × volume
    property real bpm: Tempo.bpm
    property bool running: true
    property var profile: ({})
    default property alias parts: canvas.data

    property real phase: 0
    property real t: 0
    readonly property real beat: phase * Math.PI * 2

    // the pose
    property real bob: 0
    property real tilt: 0
    property real sway: 0
    property real aL: 8
    property real aR: -8
    property real lL: 0
    property real lR: 0
    property real ex: 0
    property real eyes: 1
    property bool mouthOpen: false

    implicitWidth: 120
    implicitHeight: 160

    Item {
        id: canvas
        width: 120
        height: 160
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        transformOrigin: Item.Bottom
        scale: Math.min(rig.width / 120, rig.height / 160)
    }

    // the profile shapes the dance; waving and sleeping are everyone's
    function k(name) { return rig.mode === "dance" ? rig.profile[name] ?? 1 : 1; }

    property real blinkAt: 2 + Math.random() * 3
    function step(dt) {
        t += dt;
        if (mode === "dance" && !Motion.reduced)
            phase += dt * (bpm / 60) / 2 * (0.75 + energy * 0.6) * k("speed");
        // a stepped dancer (Bit) moves pose to pose, 1/steps of a beat each:
        // it snaps into each one over the first third of the step (eased, so
        // it reads as a robot's pop, not dropped frames) and holds it
        const steps = profile.steps ?? 0;
        let b = beat;
        if (steps > 0 && mode === "dance") {
            const x = beat / Math.PI * steps, f = Math.min(1, (x - Math.floor(x)) / 0.33);
            b = (Math.floor(x) + f * f * (3 - 2 * f)) / steps * Math.PI;
        }
        const e = energy;
        let bo = 0, ti = 0, sw = 0, l = 8, r = -8, ll = 0, lr = 0, x = 0, ey = 1;
        if (Motion.reduced) {
            // still, but alive: open eyes, arms down
        } else if (mode === "dance") {
            bo = -Math.abs(Math.sin(b)) * 7 * e;
            ti = Math.sin(b) * 10 * e;
            sw = Math.sin(b) * 4 * e;
            l = 20 + 80 * (0.5 + 0.5 * Math.sin(b)) * e;
            r = -(20 + 80 * (0.5 + 0.5 * Math.sin(b + Math.PI)) * e);
            ll = Math.max(0, Math.sin(b)) * -5 * e;
            lr = Math.max(0, -Math.sin(b)) * -5 * e;
            x = Math.sin(b * 2) * 18;
        } else if (mode === "wave") {
            bo = Math.sin(t * 3) * 1.5;
            ti = -8 + Math.sin(t * 2) * 3;
            r = -150 + Math.sin(t * 12) * 22;
            l = 10;
            x = Math.sin(t * 6) * 12;
        } else if (mode === "sleep") {
            bo = Math.sin(t * 1.2) * 1.2;
            ti = 14;
            l = 4;
            r = -4;
            ey = 0.08;
            x = -20 + Math.sin(t * 1.2) * 4;
        } else {
            bo = Math.sin(t * 1.6) * 1.2;
            ti = Math.sin(t * 0.7) * 4;
            l = 8 + Math.sin(t * 1.6) * 3;
            r = -l;
            x = Math.sin(t * 1.3) * 8;
        }
        if (mode !== "sleep" && t > blinkAt) {
            ey = 0.1;
            if (t > blinkAt + 0.13) blinkAt = t + 2.5 + Math.random() * 3;
        }
        // the arms' rest (8°) stays; their swing is what the profile scales
        bob = bo * k("bob");
        tilt = ti * k("tilt");
        sway = sw * k("sway");
        aL = 8 + (l - 8) * k("arms");
        aR = -8 + (r + 8) * k("arms");
        lL = ll * k("legs");
        lR = lr * k("legs");
        ex = x * k("extra");
        eyes = ey;
        mouthOpen = mode === "dance" || mode === "wave";
    }

    Timer {
        interval: 33
        repeat: true
        running: rig.running && rig.visible
        property double last: 0
        onRunningChanged: last = 0
        onTriggered: {
            const now = Date.now();
            rig.step(last ? Math.min(0.1, (now - last) / 1000) : 1 / 30);
            last = now;
        }
    }
    Component.onCompleted: step(0)
}
