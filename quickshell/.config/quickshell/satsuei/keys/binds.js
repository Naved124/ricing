.pragma library

// Turns `hyprctl binds -j` into the key sheet's groups.
// base.lua describes every bind as "Group · what it does"; binds that share
// a description (Super+H and Super+←) become one row with both keys.

const MODS = [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]];

const NAMES = {
    Return: "Enter", Escape: "Esc", space: "Space", Space: "Space", TAB: "Tab", Tab: "Tab",
    Print: "PrtSc", slash: "/", question: "?", comma: ",", period: ".", minus: "−", equal: "=",
    left: "←", right: "→", up: "↑", down: "↓",
    mouse_down: "Scroll ↓", mouse_up: "Scroll ↑", "mouse:272": "Left drag", "mouse:273": "Right drag",
    XF86AudioRaiseVolume: "Vol +", XF86AudioLowerVolume: "Vol −", XF86AudioMute: "Mute",
    XF86AudioMicMute: "Mic mute", XF86MonBrightnessUp: "Bright +", XF86MonBrightnessDown: "Bright −",
    XF86AudioPlay: "Play", XF86AudioPause: "Pause", XF86AudioNext: "Next", XF86AudioPrev: "Prev",
};

// the order groups appear in; anything else follows alphabetically
const ORDER = ["Apps", "Shell", "Windows", "Workspaces", "Capture", "Rice", "Media", "Mouse"];

// a bound modifier key on its own (Super_L): shown as that modifier
const MOD_KEY = /^(Super|Alt|Control|Ctrl|Shift)_[LR]$/i;

function keyName(key) {
    if (key in NAMES) return NAMES[key];
    if (key.length === 1) return key.toUpperCase();
    return key.replace(/^XF86/, "");
}

// one bind → its keycaps, e.g. ["Super", "Shift", "T"]
function caps(b) {
    let mods = MODS.filter(([m]) => b.modmask & m).map(([, n]) => n);
    const solo = MOD_KEY.exec(b.key);
    if (solo) {
        const name = solo[1].toLowerCase() === "control" ? "Ctrl"
            : solo[1][0].toUpperCase() + solo[1].slice(1).toLowerCase();
        mods = mods.filter(m => m !== name);
        return [...mods, name];
    }
    return [...mods, keyName(b.key)];
}

// several combos for one row → as few keycaps as reads clearly. Combos
// with the same modifiers share them ("Super" + "1–5", "Super" + "H / ←");
// the rest stay separate alternatives, shown with "or" between them.
function merge(combos) {
    const bySet = new Map();
    for (const c of combos) {
        const prefix = c.slice(0, -1).join("+");
        if (!bySet.has(prefix)) bySet.set(prefix, []);
        bySet.get(prefix).push(c);
    }
    return [...bySet.values()].map(set => {
        if (set.length === 1) return set[0];
        const last = set.map(c => c[c.length - 1]);
        const digits = last.every(k => /^\d$/.test(k))
            && last.map(Number).every((n, i, a) => i === 0 || n === a[i - 1] + 1);
        return [...set[0].slice(0, -1), digits ? `${last[0]}–${last[last.length - 1]}` : last.join(" / ")];
    });
}

// rows with the same text and group merge; the first bind keeps its place
function groups(binds) {
    const byGroup = new Map();
    for (const b of binds) {
        if (!b.has_description || !b.description || b.submap) continue;
        const at = b.description.indexOf(" · ");
        const group = at > 0 ? b.description.slice(0, at) : "Other";
        const text = at > 0 ? b.description.slice(at + 3) : b.description;
        if (!byGroup.has(group)) byGroup.set(group, new Map());
        const rows = byGroup.get(group);
        if (!rows.has(text)) rows.set(text, []);
        rows.get(text).push(caps(b));
    }
    const rank = g => {
        const i = ORDER.indexOf(g);
        return i < 0 ? ORDER.length : i;
    };
    return [...byGroup.keys()]
        .sort((a, b) => rank(a) - rank(b) || a.localeCompare(b))
        .map(name => ({
            name,
            rows: [...byGroup.get(name)].map(([text, combos]) => ({ text, alts: merge(combos) })),
        }));
}

// keep rows whose text or keys mention every word typed
function filter(list, query) {
    const words = query.toLowerCase().split(/\s+/).filter(w => w);
    if (!words.length) return list;
    return list
        .map(g => ({
            name: g.name,
            rows: g.rows.filter(r => {
                const hay = `${g.name} ${r.text} ${r.alts.flat().join(" ")}`.toLowerCase();
                return words.every(w => hay.includes(w));
            }),
        }))
        .filter(g => g.rows.length);
}

// spread groups over n columns, each into the currently shortest one
function columns(list, n) {
    const cols = Array.from({ length: Math.max(1, n) }, () => ({ height: 0, groups: [] }));
    for (const g of list) {
        const col = cols.reduce((a, b) => (b.height < a.height ? b : a));
        col.groups.push(g);
        col.height += g.rows.length + 2;   // a heading weighs about two rows
    }
    return cols.map(c => c.groups);
}
