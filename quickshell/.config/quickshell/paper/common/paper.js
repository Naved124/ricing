.pragma library

// Seeded randomness and hand-drawn shapes for Paper. Everything that wobbles
// takes a seed, so a sheet keeps the same torn edge and a scribble the same
// loop every time it is drawn, while no two instances look alike.

// mulberry32: a small, fast PRNG; returns a function giving 0..1
function rng(seed) {
    let a = (seed >>> 0) || 0x9e3779b9;
    return function () {
        a = (a + 0x6d2b79f5) >>> 0;
        let t = a;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

// a stable number for any string (notification ids, app names)
function hash(text) {
    let h = 2166136261;
    const s = String(text);
    for (let i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i);
        h = Math.imul(h, 16777619);
    }
    return h >>> 0;
}

// a value in [lo, hi] for this seed
function between(seed, lo, hi) {
    return lo + rng(seed)() * (hi - lo);
}

function f(v) {
    return Math.round(v * 100) / 100;
}

// The torn edge of a sheet: the rectangle (0,0)-(w,h) walked with a point
// every ~14 px, each pushed in or out by 0.6–1.2 px. Returns SVG path data.
function deckle(w, h, seed) {
    if (w <= 0 || h <= 0) return "";
    const r = rng(seed);
    const step = 14;
    const pts = [];
    const jit = () => (r() < 0.5 ? -1 : 1) * (0.6 + r() * 0.6);
    const side = (x0, y0, x1, y1, nx, ny) => {
        const len = Math.hypot(x1 - x0, y1 - y0);
        const n = Math.max(1, Math.round(len / step));
        for (let i = 0; i < n; i++) {
            const t = i / n;
            // stay inside the item: the edge only ever moves inwards from its bounds
            const d = Math.abs(jit());
            pts.push([x0 + (x1 - x0) * t + nx * d, y0 + (y1 - y0) * t + ny * d]);
        }
    };
    side(0, 0, w, 0, 0, 1);
    side(w, 0, w, h, -1, 0);
    side(w, h, 0, h, 0, -1);
    side(0, h, 0, 0, 1, 0);
    return "M " + pts.map(p => f(p[0]) + " " + f(p[1])).join(" L ") + " Z";
}

// A hand-drawn loop round a w×h box: a little more than one turn, starting
// at the top, with the radius wavering. { path, length } — length is what
// the dash animation needs.
function scribble(w, h, seed) {
    const r = rng(seed);
    const cx = w / 2, cy = h / 2;
    const rx = w / 2 - 2, ry = h / 2 - 2;
    const start = -Math.PI / 2 + (r() - 0.5) * 0.8;
    const turns = 1.08 + r() * 0.14;
    const n = 48;
    const phase = r() * Math.PI * 2;
    const tilt = (r() - 0.5) * 0.35;
    const pts = [];
    for (let i = 0; i <= n; i++) {
        const t = i / n;
        const a = start + t * turns * Math.PI * 2;
        // the loop opens a little as it comes round, like a pen not lifted
        const k = 1 + Math.sin(a * 3 + phase) * 0.05 + t * 0.07 + (r() - 0.5) * 0.03;
        const x = Math.cos(a) * rx * k, y = Math.sin(a) * ry * k;
        pts.push([cx + x * Math.cos(tilt) - y * Math.sin(tilt), cy + x * Math.sin(tilt) + y * Math.cos(tilt)]);
    }
    let length = 0;
    for (let i = 1; i < pts.length; i++)
        length += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
    return { path: "M " + pts.map(p => f(p[0]) + " " + f(p[1])).join(" L "), length: length };
}

// A crumpled ball of paper: a jagged polygon of radius ~r round (cx, cy),
// plus two crease lines across it. { outline, creases }
function crumple(cx, cy, radius, seed) {
    const r = rng(seed);
    const n = 11 + Math.floor(r() * 4);
    const pts = [];
    for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2 + (r() - 0.5) * 0.3;
        const rr = radius * (0.72 + r() * 0.36);
        pts.push([cx + Math.cos(a) * rr, cy + Math.sin(a) * rr]);
    }
    const outline = "M " + pts.map(p => f(p[0]) + " " + f(p[1])).join(" L ") + " Z";
    const c = () => [cx + (r() - 0.5) * radius, cy + (r() - 0.5) * radius];
    const [a, b, d, e] = [c(), c(), c(), c()];
    const creases = `M ${f(a[0])} ${f(a[1])} L ${f(cx)} ${f(cy)} L ${f(b[0])} ${f(b[1])} M ${f(d[0])} ${f(d[1])} L ${f(e[0])} ${f(e[1])}`;
    return { outline: outline, creases: creases };
}

// A wobbly polyline through points: each segment broken up and nudged, for
// pencil outlines (the battery, the bin, checkboxes). SVG path data.
function pencil(points, seed, wobble, closed) {
    const r = rng(seed);
    const out = [];
    const w = wobble ?? 0.6;
    for (let i = 0; i < points.length - 1; i++) {
        const [x0, y0] = points[i], [x1, y1] = points[i + 1];
        const n = Math.max(1, Math.round(Math.hypot(x1 - x0, y1 - y0) / 6));
        for (let j = 0; j < n; j++) {
            const t = j / n;
            out.push([x0 + (x1 - x0) * t + (r() - 0.5) * w, y0 + (y1 - y0) * t + (r() - 0.5) * w]);
        }
    }
    const last = points[points.length - 1];
    out.push([last[0] + (r() - 0.5) * w, last[1] + (r() - 0.5) * w]);
    return "M " + out.map(p => f(p[0]) + " " + f(p[1])).join(" L ") + (closed ? " Z" : "");
}

// "Firefox — Some very long title" → "Firefox — Some…ng title": cut in the middle
function middle(text, max) {
    const s = String(text ?? "");
    if (s.length <= max) return s;
    const keep = max - 1;
    const head = Math.ceil(keep / 2), tail = Math.floor(keep / 2);
    return s.slice(0, head) + "…" + s.slice(s.length - tail);
}
