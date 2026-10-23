import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.common
import qs.services

// a tray icon, drawn as a symbol in the bar's ink (as the Mac's are),
// or as the app drew it when Settings turns that off. Apps whose icon is a
// full-colour badge (Spotify, qBittorrent) would come out a solid blot, so
// Papirus's one-colour panel icon for the app is used first when it has one.
Item {
    id: ti
    property string source
    property string appId: ""
    property color ink: Theme.label
    implicitWidth: 16; implicitHeight: 16
    // one-colour icons on disk (MenuBar lists them once): Colloid's symbolic
    // app icons ("c:name") and Papirus's panel set ("p:name")
    property var panel: []
    // tray ids whose app is known by another name in those sets
    readonly property var aliases: ({ "spotify-client": "com.spotify.Client", "spotify": "com.spotify.Client" })
    readonly property string mono: {
        if (!Settings.menubar.monoTray) return "";
        const names = [];
        const m = /^image:\/\/icon\/([^?]+)/.exec(source);
        const i = appId.toLowerCase();
        if (aliases[i]) names.push(aliases[i]);
        if (m) names.push(m[1]);
        if (i) names.push(appId, i);
        for (const n of names)
            if (panel.includes("c:" + n + "-symbolic")) return "file:///usr/share/icons/Colloid-Grey-Dark/apps/symbolic/" + n + "-symbolic.svg";
        for (const n of names.concat(i ? [i + "-tray", i + "-indicator", i + "-panel"] : []))
            if (panel.includes("p:" + n)) return "file:///usr/share/icons/Papirus/22x22/panel/" + n + ".svg";
        return "";
    }
    IconImage {
        id: timg
        anchors.fill: parent
        implicitSize: 16
        source: ti.mono || ti.source
        visible: !Settings.menubar.monoTray
        layer.enabled: Settings.menubar.monoTray
    }
    Rectangle {
        id: fill
        anchors.fill: parent
        visible: false
        color: ti.ink
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: Settings.menubar.monoTray
        source: fill
        maskEnabled: true
        maskSource: timg
        maskThresholdMin: 0.3
        maskSpreadAtMin: 0.3
    }
}
