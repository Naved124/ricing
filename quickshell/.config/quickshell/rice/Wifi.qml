pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wi-Fi for the network widget (Network.qml), through NetworkManager's nmcli,
// so it works whichever backend NetworkManager drives (iwd here; see
// system/install --network). Nothing runs until the widget opens: then one
// read of the state, and one `nmcli monitor` that re-reads it on every
// change until the widget closes.
//
// Passwords go to nmcli on its standard input (a `read` in sh), not through
// this shell's own command lines; NetworkManager stores them with the
// connection, so a saved network reconnects by itself.
Singleton {
    id: root

    property bool watching: false
    property bool radio: true                 // Wi-Fi on
    property string device: ""                // wlan0
    property string wired: ""                 // the connected cable's connection, if any
    property var networks: []                 // [{ ssid, signal, security, freq, inUse, saved }]
    property var saved: []                    // [{ name, uuid, autoconnect, active }]
    property var active: null                 // { name, uuid, ip, gateway, dns: [], dnsAuto, manualDns }
    property bool scanning: false
    property string busy: ""                  // what's under way ("Connecting to …")
    property string error: ""

    function isWifi(type) { return type === "802-11-wireless" || type === "wifi"; }

    // nmcli -t: fields split on ':', with '\:' and '\\' escaped
    function fields(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) cur += line[++i];
            else if (ch === ":") { out.push(cur); cur = ""; }
            else cur += ch;
        }
        out.push(cur);
        return out;
    }

    // ── reading ────────────────────────────────────────────────────────────
    function refresh() {
        if (reader.running) { again = true; return; }
        reader.running = true;
    }
    property bool again: false
    Process {
        id: reader
        command: ["sh", "-c", `
            echo @radio; nmcli -t -f WIFI general
            echo @dev; nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device
            echo @scan; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY,FREQ device wifi list --rescan no
            echo @saved; nmcli -t -f NAME,UUID,TYPE,AUTOCONNECT,DEVICE connection show
            dev=$(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }')
            echo @active
            [ -n "$dev" ] && nmcli -t -f GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show "$dev"
            echo @end`]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
        onExited: if (root.again) { root.again = false; root.refresh(); }
    }
    function parse(text) {
        let part = "", dev = "", wired = "", radio = true;
        const nets = {}, saved = [], act = { dns: [] };
        let activeName = "";
        for (const line of text.split("\n")) {
            if (line.startsWith("@")) { part = line.slice(1); continue; }
            if (!line) continue;
            const f = fields(line);
            if (part === "radio") radio = f[0] === "enabled";
            else if (part === "dev") {
                if (f[1] === "wifi" && !dev) dev = f[0];
                if (f[1] === "ethernet" && f[2] === "connected") wired = f[3];
            } else if (part === "scan") {
                const ssid = f[1];
                if (!ssid) continue;                       // hidden ones show under "Hidden network…"
                const n = { ssid, inUse: f[0] === "*", signal: Number(f[2]) || 0, security: f[3] && f[3] !== "--" ? f[3] : "",
                            freq: f[4] ?? "" };
                // one row per name: the strongest, or the one in use
                const was = nets[ssid];
                if (!was || n.inUse || (!was.inUse && n.signal > was.signal)) nets[ssid] = n;
            } else if (part === "saved") {
                if (!isWifi(f[2])) continue;
                saved.push({ name: f[0], uuid: f[1], autoconnect: f[3] === "yes", active: !!f[4] && f[4] !== "--" });
            } else if (part === "active") {
                const key = f[0], val = f.slice(1).join(":");
                if (key === "GENERAL.CONNECTION") activeName = val;
                else if (key.startsWith("IP4.ADDRESS")) act.ip = val;
                else if (key === "IP4.GATEWAY") act.gateway = val;
                else if (key.startsWith("IP4.DNS")) act.dns.push(val);
            }
        }
        const names = new Set(saved.map(s => s.name));
        root.radio = radio;
        root.device = dev;
        root.wired = wired;
        root.saved = saved;
        root.networks = Object.values(nets).map(n => Object.assign(n, { saved: names.has(n.ssid) }))
            .sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal));
        const conn = saved.find(s => s.name === activeName);
        if (activeName && conn) {
            root.active = Object.assign({ name: activeName, uuid: conn.uuid, ip: "", gateway: "", dnsAuto: true, manualDns: "" },
                                        act, { name: activeName, uuid: conn.uuid });
            dnsReader.command = ["nmcli", "-t", "-f", "ipv4.dns,ipv4.ignore-auto-dns", "connection", "show", conn.uuid];
            dnsReader.running = true;
        } else {
            root.active = null;
        }
    }
    // the connection's own DNS setting (what it asks for, not what it got)
    Process {
        id: dnsReader
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active) return;
                let manual = "", ignore = false;
                for (const line of text.split("\n")) {
                    const f = root.fields(line);
                    if (f[0] === "ipv4.dns") manual = f.slice(1).join(":").split(",").join(" ").trim();
                    if (f[0] === "ipv4.ignore-auto-dns") ignore = f[1] === "yes";
                }
                root.active = Object.assign({}, root.active, { manualDns: manual, dnsAuto: !ignore || !manual });
            }
        }
    }

    // while the widget is open: every change re-reads (a quarter second later,
    // as one change comes as several lines)
    Process {
        running: root.watching
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: settle.restart() }
    }
    Timer { id: settle; interval: 250; onTriggered: root.refresh() }
    onWatchingChanged: if (watching) { error = ""; refresh(); rescan(); }

    // ── doing ──────────────────────────────────────────────────────────────
    // one nmcli at a time; its complaint, if it has one, is shown
    property var queue: []
    function run(what, argv, input) {
        queue = queue.concat([{ what, argv, input: input ?? null }]);
        if (!doer.running) next();
    }
    function next() {
        if (!queue.length) { busy = ""; return; }
        const job = queue[0];
        queue = queue.slice(1);
        busy = job.what;
        doer.input = job.input;
        doer.command = job.argv;
        doer.running = true;
    }
    Process {
        id: doer
        property var input: null
        stdinEnabled: input !== null
        onStarted: if (input !== null) { write(input + "\n"); }
        stderr: StdioCollector { id: complaint }
        onExited: code => {
            if (code !== 0) root.error = complaint.text.trim().replace(/^Error: /, "") || `nmcli failed (${code})`;
            root.next();
            root.refresh();
        }
    }

    function rescan() {
        if (!radio) return;
        scanning = true;
        Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
        scanDone.restart();
    }
    Timer { id: scanDone; interval: 3500; onTriggered: { root.scanning = false; root.refresh(); } }

    function setRadio(on) {
        error = "";
        run(on ? "Turning Wi-Fi on" : "Turning Wi-Fi off", ["nmcli", "radio", "wifi", on ? "on" : "off"]);
    }
    // a network in the list: a saved one comes up as it is; a new one with
    // its password (none for an open one), which NetworkManager then keeps
    function connect(ssid, password, hidden) {
        error = "";
        const known = saved.find(s => s.name === ssid);
        if (known && !password) { up(known.uuid, ssid); return; }
        const extra = hidden ? " hidden yes" : "";
        if (password)
            run(`Connecting to ${ssid}`, ["sh", "-c",
                `IFS= read -r p; exec nmcli --wait 30 device wifi connect "$1" password "$p"${extra}`, "sh", ssid], password);
        else
            run(`Connecting to ${ssid}`, ["sh", "-c", `exec nmcli --wait 30 device wifi connect "$1"${extra}`, "sh", ssid]);
    }
    function up(uuid, name) { error = ""; run(`Connecting to ${name ?? "it"}`, ["nmcli", "--wait", "30", "connection", "up", "uuid", uuid]); }
    function down(uuid) { error = ""; run("Disconnecting", ["nmcli", "connection", "down", "uuid", uuid]); }
    function forget(uuid) { error = ""; run("Forgetting it", ["nmcli", "connection", "delete", "uuid", uuid]); }
    function autoconnect(uuid, on) {
        run("Saving", ["nmcli", "connection", "modify", "uuid", uuid, "connection.autoconnect", on ? "yes" : "no"]);
    }
    // DNS for a connection: a list of servers, or "" for the network's own;
    // the connection comes up again to take it
    function setDns(uuid, servers) {
        error = "";
        const list = servers.split(/[\s,]+/).filter(s => s).join(" ");
        run("Setting DNS", ["nmcli", "connection", "modify", "uuid", uuid,
                            "ipv4.dns", list, "ipv4.ignore-auto-dns", list ? "yes" : "no",
                            "ipv6.ignore-auto-dns", list ? "yes" : "no"]);
        run("Reconnecting", ["nmcli", "--wait", "30", "connection", "up", "uuid", uuid]);
    }

    // a saved network's password, asked for when shown (NetworkManager may ask
    // polkit first)
    property var secrets: ({})
    function reveal(uuid) {
        secret.uuid = uuid;
        secret.command = ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", "uuid", uuid];
        secret.running = true;
    }
    function hide(uuid) {
        const s = Object.assign({}, secrets);
        delete s[uuid];
        secrets = s;
    }
    Process {
        id: secret
        property string uuid: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const s = Object.assign({}, root.secrets);
                s[secret.uuid] = text.trim() || "(none stored)";
                root.secrets = s;
            }
        }
    }
}
