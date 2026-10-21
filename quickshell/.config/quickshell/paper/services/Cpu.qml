pragma Singleton

import QtQuick
import Quickshell

// CPU use for the bar (0..1), from Sys's one /proc reader.
Singleton {
    readonly property real usage: Sys.cpu
}
