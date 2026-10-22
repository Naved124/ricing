import QtQuick
import Quickshell

// The hour's light: one keyframe table, read by the plate's pass and by every
// character standing in it (SceneMatch), so they're graded alike. Theme holds
// the one instance (Theme.grade).
//
// Each keyframe is multiply, then lift, then saturation, with the rays'
// strength and colour; between keyframes they're smoothstepped. The rays'
// colour leans 30% toward the plate's brightest colour. Night light (the
// control centre's) takes green to 0.88 and blue to 0.7; expo is the
// brightness slider.
QtObject {
    id: grade

    // follow the clock, or hold the hour the Satsuei panel's slider set
    property bool follow: true
    property real manualHour: 7.2
    property real clockHour: 12
    readonly property real hour: follow ? clockHour : manualHour
    property bool nightLight: false
    property real expo: 1.0
    property vector3d bright: Qt.vector3d(1, 0.9, 0.85)

    readonly property var keys: [
        // hour  multiply              lift              sat   rays  ray colour
        [0,    [0.56, 0.63, 0.98], [0.00, 0.01, 0.05], 0.78, 0.12, [0.55, 0.62, 1.00]],
        [5,    [0.60, 0.64, 0.95], [0.01, 0.01, 0.05], 0.80, 0.15, [0.60, 0.65, 1.00]],
        [6.5,  [1.06, 0.93, 0.93], [0.04, 0.02, 0.03], 1.00, 0.85, [1.00, 0.74, 0.66]],
        [9,    [1.01, 1.00, 0.98], [0.01, 0.01, 0.00], 1.05, 0.60, [1.00, 0.92, 0.80]],
        [13,   [1.04, 1.04, 1.03], [0.00, 0.00, 0.00], 1.10, 0.45, [1.00, 0.97, 0.90]],
        [17.4, [1.13, 0.95, 0.80], [0.03, 0.01, 0.00], 1.16, 1.05, [1.00, 0.70, 0.42]],
        [19,   [1.00, 0.80, 0.95], [0.04, 0.00, 0.05], 1.10, 0.70, [1.00, 0.50, 0.62]],
        [21,   [0.64, 0.68, 0.96], [0.01, 0.01, 0.05], 0.84, 0.14, [0.60, 0.65, 1.00]],
        [24,   [0.56, 0.63, 0.98], [0.00, 0.01, 0.05], 0.78, 0.12, [0.55, 0.62, 1.00]]
    ]
    readonly property var names: [[0, "Night"], [5, "Before dawn"], [6, "Dawn"], [8, "Morning"], [11, "Noon"],
                                  [15, "Afternoon"], [17, "Golden hour"], [18.6, "Dusk"], [20.3, "Night"]]

    readonly property var at: sample(hour)
    readonly property vector3d mul: {
        const m = at.mul;
        return nightLight ? Qt.vector3d(m[0], m[1] * 0.88, m[2] * 0.7) : Qt.vector3d(m[0], m[1], m[2]);
    }
    readonly property vector3d lift: Qt.vector3d(at.lift[0], at.lift[1], at.lift[2])
    readonly property real sat: at.sat
    readonly property real rays: at.rays
    readonly property vector3d rayCol: Qt.vector3d(
        at.rayCol[0] + (bright.x - at.rayCol[0]) * 0.3,
        at.rayCol[1] + (bright.y - at.rayCol[1]) * 0.3,
        at.rayCol[2] + (bright.z - at.rayCol[2]) * 0.3)
    readonly property string phase: nameAt(hour)

    function sample(h) {
        h = ((h % 24) + 24) % 24;
        let i = 0;
        while (i < keys.length - 2 && keys[i + 1][0] <= h) i++;
        const A = keys[i], B = keys[i + 1];
        let k = (h - A[0]) / (B[0] - A[0]);
        k = k * k * (3 - 2 * k);
        const l = (a, b) => a + (b - a) * k;
        const lv = (a, b) => a.map((v, j) => l(v, b[j]));
        return { mul: lv(A[1], B[1]), lift: lv(A[2], B[2]), sat: l(A[3], B[3]), rays: l(A[4], B[4]),
                 rayCol: lv(A[5], B[5]) };
    }
    function nameAt(h) {
        let n = "Night";
        for (const [t, s] of names) if (h >= t) n = s;
        return n;
    }
    function fmt(h) {
        const m = Math.round(h * 60) % 1440;
        return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
    }

    // the hour, a minute at a time (the grade drifts too slowly to need more)
    property SystemClock clock: SystemClock {
        precision: SystemClock.Minutes
        onDateChanged: grade.clockHour = date.getHours() + date.getMinutes() / 60
    }
    Component.onCompleted: {
        const d = new Date();
        clockHour = d.getHours() + d.getMinutes() / 60;
    }
}
