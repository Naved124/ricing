import QtQuick
import qs.common
import qs.plate

// The plate and its pass on their own, for tools/grab.py: the seed plate (or
// --plate), at a fixed hour, every effect on unless told otherwise.
Item {
    id: root
    required property var opts
    Grade {
        id: hour
        follow: false
        manualHour: root.opts.hour
        nightLight: root.opts.night
        bright: Qt.vector3d(...root.opts.bright)
    }
    Pass {
        objectName: "pass"
        anchors.fill: parent
        grading: hour
        source: root.opts.plate
        bloomSource: root.opts.bloom
        softSource: root.opts.soft
        animated: root.opts.animated
        light: Qt.point(root.opts.light[0], root.opts.light[1])
        time: root.opts.time
        bloom: root.opts.fx.bloom
        rays: root.opts.fx.rays
        motes: root.opts.fx.motes
        grain: root.opts.fx.grain
        grade: root.opts.fx.grade
        pass: root.opts.fx.pass
        expo: root.opts.expo
    }
}
