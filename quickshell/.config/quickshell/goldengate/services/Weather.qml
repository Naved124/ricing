pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The weather for the desktop widget, from Open-Meteo (free, no key), every
// half hour while the widget is shown. Where: Settings' location, or, the
// first time, a guess from the IP address (ipinfo.io), kept in Settings.
Singleton {
    id: root

    property bool wanted: false
    // where, as Settings has it or as the IP lookup just found it
    property var found: null
    readonly property real lat: found ? found.lat : Settings.location.lat
    readonly property real lon: found ? found.lon : Settings.location.lon
    readonly property bool located: lat !== 0 && lon !== 0
    readonly property string city: found ? found.city : Settings.location.city
    property bool ready: false
    property real temp: 0
    property real high: 0
    property real low: 0
    property int code: 0
    property bool day: true
    property var hours: []      // [{ label, temp, code, day }]

    function text(c) {
        return c === 0 ? qsTr("Clear") : c === 1 ? qsTr("Mostly Clear") : c === 2 ? qsTr("Partly Cloudy")
             : c === 3 ? qsTr("Cloudy") : c <= 48 ? qsTr("Foggy") : c <= 57 ? qsTr("Drizzle")
             : c <= 67 ? qsTr("Rain") : c <= 77 ? qsTr("Snow") : c <= 82 ? qsTr("Showers")
             : c <= 86 ? qsTr("Snow Showers") : qsTr("Thunderstorms");
    }
    function symbol(c, isDay) {
        const n = isDay ? "" : "-night";
        return c <= 1 ? "weather-clear" + n + "-symbolic" : c === 2 ? "weather-few-clouds" + n + "-symbolic"
             : c === 3 ? "weather-overcast-symbolic" : c <= 48 ? "weather-fog-symbolic"
             : c <= 57 ? "weather-showers-scattered-symbolic" : c <= 67 || (c >= 80 && c <= 82) ? "weather-showers-symbolic"
             : c <= 77 || c === 85 || c === 86 ? "weather-snow-symbolic" : "weather-storm-symbolic";
    }

    function refresh() {
        if (!located) { if (!where.running) where.running = true; return; }
        get.command = ["curl", "-sfm", "10", "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,weather_code,is_day&hourly=temperature_2m,weather_code,is_day"
            + "&daily=temperature_2m_max,temperature_2m_min&forecast_days=2&timezone=auto"];
        get.running = true;
    }

    Timer { running: root.wanted; interval: 30 * 60 * 1000; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

    Process {
        id: where
        command: ["curl", "-sfm", "8", "https://ipinfo.io/json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    const [lat, lon] = j.loc.split(",").map(parseFloat);
                    root.found = { city: j.city || "", lat: Math.round(lat * 100) / 100, lon: Math.round(lon * 100) / 100 };
                    // one write: several in a row race the file's reload
                    Shell.gg(["set", "location", JSON.stringify(root.found)]);
                    Qt.callLater(root.refresh);
                } catch (e) { /* offline: the next half hour tries again */ }
            }
        }
    }
    Process {
        id: get
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    root.temp = j.current.temperature_2m;
                    root.code = j.current.weather_code;
                    root.day = j.current.is_day === 1;
                    root.high = j.daily.temperature_2m_max[0];
                    root.low = j.daily.temperature_2m_min[0];
                    const now = j.current.time.slice(0, 13);
                    const h = j.hourly, start = Math.max(0, h.time.findIndex(t => t.slice(0, 13) === now));
                    const out = [];
                    for (let i = start; i < Math.min(h.time.length, start + 6); ++i)
                        out.push({ label: i === start ? qsTr("Now") : Qt.formatTime(new Date(h.time[i]), "h AP").replace(":00", ""),
                                   temp: h.temperature_2m[i], code: h.weather_code[i], day: h.is_day[i] === 1 });
                    root.hours = out;
                    root.ready = true;
                } catch (e) { /* keep what was shown */ }
            }
        }
    }
}
