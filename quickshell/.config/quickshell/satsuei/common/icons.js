.pragma library
// Satsuei's icons: Nacre's set (24×24, rounded strokes, no icon theme needed)
// and a few of the studio's own. Icon.qml colours them at runtime.

var paths = {
    "sliders":     '<path d="M4 7h10M18 7h2M4 17h2M10 17h10"/><circle cx="16" cy="7" r="2"/><circle cx="8" cy="17" r="2"/>',
    "sparkle":     '<path d="M12 3l2.2 5.8L20 11l-5.8 2.2L12 19l-2.2-5.8L4 11l5.8-2.2z"/>',
    "person":      '<circle cx="12" cy="10" r="6"/><path d="M6 21c1-3 3.5-4.5 6-4.5s5 1.5 6 4.5"/>',
    "image":       '<rect x="3.5" y="4.5" width="17" height="15" rx="3"/><circle cx="9" cy="10" r="1.8"/><path d="M4 17l5-4.5 4 3.5 3-2.5 4 3.5"/>',
    "shuffle":     '<path d="M4 7h3.5c4 0 5 10 9 10H20"/><path d="M4 17h3.5c1.6 0 2.7-1.6 3.6-3.6M13 9.6C13.9 8.1 15 7 16.5 7H20"/><path d="M17.5 4.5L20 7l-2.5 2.5M17.5 14.5L20 17l-2.5 2.5"/>',
    "plus":        '<path d="M12 5v14M5 12h14"/>',
    "crosshair":   '<circle cx="12" cy="12" r="7.5"/><path d="M12 2.5v5M12 16.5v5M2.5 12h5M16.5 12h5"/>',
    "eye":         '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>',
    "film":        '<rect x="3.5" y="4.5" width="17" height="15" rx="2.5"/><path d="M7.5 4.5v15M16.5 4.5v15M3.5 9h4M3.5 15h4M16.5 9h4M16.5 15h4"/>',
    "wifi":        '<path d="M2.5 9a14 14 0 0 1 19 0"/><path d="M5.5 12.3a9.5 9.5 0 0 1 13 0"/><path d="M8.6 15.5a5 5 0 0 1 6.8 0"/><circle cx="12" cy="19" r="1.1" fill="C"/>',
    "wifi-low":    '<path d="M8.6 15.5a5 5 0 0 1 6.8 0"/><circle cx="12" cy="19" r="1.1" fill="C"/><path opacity=".3" d="M2.5 9a14 14 0 0 1 19 0"/><path opacity=".3" d="M5.5 12.3a9.5 9.5 0 0 1 13 0"/>',
    "wifi-off":    '<path d="M2.5 9a14 14 0 0 1 5-3.2"/><path d="M12 5a14 14 0 0 1 9.5 4"/><path d="M8.6 15.5a5 5 0 0 1 6.8 0"/><path d="M3 3l18 18"/>',
    "ethernet":    '<rect x="4" y="4" width="16" height="12" rx="2.5"/><path d="M8 16v4h8v-4"/><path d="M8.5 8v3M12 8v3M15.5 8v3"/>',
    "volume":      '<path d="M4 9.5v5h3.5l4.5 4V5.5l-4.5 4z"/><path d="M15.5 9a4 4 0 0 1 0 6"/><path d="M18.3 6.3a8 8 0 0 1 0 11.4"/>',
    "volume-low":  '<path d="M4 9.5v5h3.5l4.5 4V5.5l-4.5 4z"/><path d="M15.5 9a4 4 0 0 1 0 6"/>',
    "volume-mute": '<path d="M4 9.5v5h3.5l4.5 4V5.5l-4.5 4z"/><path d="M16 9.5l5 5M21 9.5l-5 5"/>',
    "mic":         '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0"/><path d="M12 17.5V21"/>',
    "mic-off":     '<path d="M15 9.5V6a3 3 0 0 0-5.8-1"/><path d="M9 9v2a3 3 0 0 0 4.6 2.5"/><path d="M5.5 11a6.5 6.5 0 0 0 10.7 5"/><path d="M18.5 11a6.4 6.4 0 0 1-.5 2.4"/><path d="M12 17.5V21"/><path d="M3 3l18 18"/>',
    "battery":     '<rect x="2.5" y="7" width="17" height="10" rx="3"/><path d="M21.5 10.5v3"/>',
    "bolt":        '<path d="M13 2.5L5.5 13.5H11l-1 8 7.5-11H12z"/>',
    "bluetooth":   '<path d="M7 7.5l10 9-5 4.5V3l5 4.5-10 9"/>',
    "bluetooth-off": '<path d="M12 12v9l5-4.5-3.2-2.9"/><path d="M12 3v5.5"/><path d="M12 3l5 4.5-2.3 2"/><path d="M7 7.5l4 3.6"/><path d="M3 3l18 18"/>',
    "coffee":      '<path d="M4.5 9h11v4.5a5 5 0 0 1-5 5h-1a5 5 0 0 1-5-5z"/><path d="M15.5 10.5h1.5a2.5 2.5 0 0 1 0 5h-1.6"/><path d="M8 3.5c-.8.9.8 1.6 0 2.5M11.5 3.5c-.8.9.8 1.6 0 2.5"/><path d="M4 21h13"/>',
    "camera":      '<path d="M4 8.5A2.5 2.5 0 0 1 6.5 6H8l1.5-2h5L16 6h1.5A2.5 2.5 0 0 1 20 8.5v8a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 16.5z"/><circle cx="12" cy="12.5" r="3.5"/>',
    "arrow-down":  '<path d="M12 4v15"/><path d="M6.5 13.5L12 19l5.5-5.5"/>',
    "arrow-up":    '<path d="M12 20V5"/><path d="M6.5 10.5L12 5l5.5 5.5"/>',
    "moon":        '<path d="M20 14.5A8.5 8.5 0 1 1 9.5 4a6.8 6.8 0 0 0 10.5 10.5z"/>',
    "sun":         '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>',
    "sunset":      '<path d="M7 16a5 5 0 0 1 10 0"/><path d="M3 20h18"/><path d="M12 4v4M4.9 8.9l1.4 1.4M19.1 8.9l-1.4 1.4"/>',
    "bell":        '<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2.2 2.2 0 0 0 4 0"/>',
    "bell-off":    '<path d="M8.5 5.6A6 6 0 0 1 18 11v4"/><path d="M6 11v5l-1.5 2H16"/><path d="M10 20.5a2.2 2.2 0 0 0 4 0"/><path d="M3 3l18 18"/>',
    "power":       '<path d="M12 3v8"/><path d="M6.4 6.5a8 8 0 1 0 11.2 0"/>',
    "lock":        '<rect x="5" y="10.5" width="14" height="10" rx="3"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
    "logout":      '<path d="M14 4h3.5A2.5 2.5 0 0 1 20 6.5v11a2.5 2.5 0 0 1-2.5 2.5H14"/><path d="M4 12h11"/><path d="M8 8l-4 4 4 4"/>',
    "reboot":      '<path d="M20 12a8 8 0 1 1-2.6-5.9"/><path d="M20 4v4.5h-4.5"/>',
    "search":      '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5L21 21"/>',
    "calculator":  '<rect x="5" y="3" width="14" height="18" rx="3"/><path d="M8.5 7.5h7"/><path d="M9 12h.01M12 12h.01M15 12h.01M9 16h.01M12 16h.01M15 16h.01" stroke-width="2.4"/>',
    "folder":      '<path d="M3.5 7.5A2.5 2.5 0 0 1 6 5h3.5l2 2.5H18a2.5 2.5 0 0 1 2.5 2.5v7A2.5 2.5 0 0 1 18 19.5H6A2.5 2.5 0 0 1 3.5 17z"/>',
    "emoji":       '<circle cx="12" cy="12" r="8.5"/><path d="M8.5 14a4 4 0 0 0 7 0"/><path d="M9 9.5h.01M15 9.5h.01" stroke-width="2.4"/>',
    "terminal":    '<rect x="3" y="4.5" width="18" height="15" rx="3"/><path d="M7 9.5l3 2.5-3 2.5"/><path d="M12.5 15h4"/>',
    "globe":       '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17"/><path d="M12 3.5a13 13 0 0 1 0 17a13 13 0 0 1 0-17z"/>',
    "clipboard":   '<rect x="5" y="4.5" width="14" height="16" rx="2.5"/><rect x="9" y="3" width="6" height="3.5" rx="1.2"/><path d="M8.5 11h7M8.5 15h5"/>',
    "play":        '<path d="M8 5.5v13l10.5-6.5z"/>',
    "pause":       '<path d="M8.5 5.5v13M15.5 5.5v13"/>',
    "next":        '<path d="M6 6v12l9-6z"/><path d="M18 6v12"/>',
    "prev":        '<path d="M18 6v12l-9-6z"/><path d="M6 6v12"/>',
    "close":       '<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>',
    "chevron-down": '<path d="M6.5 9.5l5.5 5.5 5.5-5.5"/>',
    "chevron-right": '<path d="M9.5 6.5l5.5 5.5-5.5 5.5"/>',
    "check":       '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    "gauge":       '<path d="M4.5 17a8 8 0 1 1 15 0"/><path d="M12 13l3.5-4"/>',
    "leaf":        '<path d="M5 19c0-8 5-13 14-14-1 9-6 14-14 14z"/><path d="M5 19l7-7"/>',
    "rocket":      '<path d="M12 15l-3-3a13 13 0 0 1 9.5-8.5 13 13 0 0 1-8.5 9.5"/><path d="M9 12l-3.5.5L4 10l4.5-2"/><path d="M12 15l-.5 3.5L14 20l2-4.5"/><path d="M5.5 18.5c1-2 2.5-2.5 3.5-1.5"/>',
    "record":      '<circle cx="12" cy="12" r="5" fill="C"/>',
    "send":        '<path d="M4 12l16-7-6 16-3-7z"/><path d="M11 13l9-8"/>',
    "file":        '<path d="M7 3.5h6.5l4.5 4.5v10A2.5 2.5 0 0 1 15.5 20.5h-8.5A2.5 2.5 0 0 1 4.5 18V6A2.5 2.5 0 0 1 7 3.5z"/><path d="M13 3.5V8h5"/>',
    "app":         '<rect x="4" y="4" width="16" height="16" rx="4.5"/>',
    "keyboard":    '<rect x="2.5" y="6" width="19" height="12" rx="3"/><path d="M6 10h.01M9 10h.01M12 10h.01M15 10h.01M18 10h.01M8 14h8" stroke-width="2"/>',
    "brightness":  '<circle cx="12" cy="12" r="3.5"/><path d="M12 3v2.5M12 18.5V21M3 12h2.5M18.5 12H21M5.6 5.6l1.8 1.8M16.6 16.6l1.8 1.8M5.6 18.4l1.8-1.8M16.6 7.4l1.8-1.8"/>',
    "tray":        '<circle cx="6" cy="12" r="1.4" fill="C"/><circle cx="12" cy="12" r="1.4" fill="C"/><circle cx="18" cy="12" r="1.4" fill="C"/>',
    "touch":       '<path d="M9 11V5.5a1.5 1.5 0 0 1 3 0V11"/><path d="M12 10V8.5a1.5 1.5 0 0 1 3 0V11"/><path d="M15 10.5a1.5 1.5 0 0 1 3 0V15a6 6 0 0 1-6 6h-1a6 6 0 0 1-5.2-3l-2-3.5a1.5 1.5 0 0 1 2.6-1.5L9 15"/>',
    "touch-off":   '<path d="M9 9V5.5a1.5 1.5 0 0 1 3 0V8"/><path d="M15 10.5a1.5 1.5 0 0 1 3 0V15a6 6 0 0 1-.6 2.6"/><path d="M15.4 20A6 6 0 0 1 12 21h-1a6 6 0 0 1-5.2-3l-2-3.5a1.5 1.5 0 0 1 2.6-1.5L9 15v-3"/><path d="M3 3l18 18"/>',
    "jelly":       '<path d="M4.5 12a7.5 7.5 0 0 1 15 0l-1.9 1.2-1.9-1.2-1.9 1.2L12 12l-1.9 1.2L8.2 12l-1.9 1.2z"/><path d="M8 14.5c0 2 1 3 0 5.5M12 14c0 2.5 1 3.5 0 6.5M16 14.5c0 2-1 3 0 5.5"/>',
    "suspend":     '<path d="M20 14.5A8.5 8.5 0 1 1 9.5 4a6.8 6.8 0 0 0 10.5 10.5z"/><path d="M15 4h4l-4 4.5h4" stroke-width="1.5"/>',
    "drop":        '<path d="M12 3.5c3 4 6 7 6 10.5a6 6 0 0 1-12 0c0-3.5 3-6.5 6-10.5z"/>',
    "dark":        '<path d="M20 14.5A8.5 8.5 0 1 1 9.5 4a6.8 6.8 0 0 0 10.5 10.5z"/>',
    "light":       '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>',
    "calendar":    '<rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
    "notion":      '<rect x="4" y="3.5" width="16" height="17" rx="3"/><path d="M9 16.5V7.5l6 9V7.5"/>'
};

// color: a QML color; SVG gets rgb() plus opacity (it can't read #aarrggbb)
function svg(name, color, stroke) {
    var rgb = "rgb(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + ","
        + Math.round(color.b * 255) + ")";
    var body = (paths[name] || paths["app"]).replace(/fill="C"/g, 'fill="' + rgb + '"');
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="'
        + rgb + '" stroke-width="' + (stroke || 1.7) + '" opacity="' + color.a
        + '" stroke-linecap="round" stroke-linejoin="round">' + body + '</svg>';
}
