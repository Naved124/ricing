.pragma library

// The reef's world, a port of docs/abyss/reef-mock.html: the seafloor, kelp,
// corals, sea fans, anemones, the school, the jellies and the plankton, the
// coarse ripple height field the creatures feel, and how all of it moves.
// Constants are the mock's. Time is in 60 Hz frames (dt 2 at 30 fps), as
// there. The GPU keeps its own ripple field for what's drawn (Ripple.qml);
// this one is only for physics, fed the same drops.
//
// Colours come from the palette (opts.pal: CSS strings, opts.hues: the
// creature hues); drawing goes through `ctx`, a Canvas 2D context, with the
// glow sprites gen.py baked (opts.sprite(h, s, l) → an image the context can
// draw).

function mulberry32(a) {
    return function () {
        a |= 0; a = a + 0x6D2B79F5 | 0;
        let t = Math.imul(a ^ a >>> 15, 1 | a);
        t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
        return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
}
function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }

function create(opts) {
    const R = {
        W: 0, H: 0, seed: opts.seed ?? 20261021,
        mot: 1,                       // 0.45 with reduced motion
        plankton: opts.plankton ?? 620, fishCount: opts.fish ?? 24, jellyCount: opts.jellies ?? 5,
        reduced: false,               // half the plankton drawn and moved
        interactive: true,
        // the coarse field: gw × gh cells, wA now, wB before
        gw: 0, gh: 0, wA: null, wB: null,
        calm: 0,                      // steps since the last drop; the field rests after a while
        // drops for the GPU field since it last took them: [x, y, amp, radius] in px
        pending: [],
        flow: 0, sweep: 0, beat: 0, breath: false,
        floorPts: [], ridgePts: [], kelp: [], backCorals: [], corals: [], anemones: [], fans: [],
        fish: [], jellies: [], sparkle: [],
        px: null, py: null, pb: null, pz: null, NP: 0,
        pointer: { x: 0, y: 0, lx: 0, ly: 0, down: false, active: false },
    };
    let rnd = mulberry32(R.seed);
    const hues = opts.hues;           // { creatures: [5], jellies: [5], fans: [2], anemones: [2], sparkle, plankton, back }
    const pal = opts.pal;             // CSS colours (Theme.reefColors)
    const spr = opts.sprite;          // (h, s, l) → a glow sprite the canvas can draw
    const hsla = (h, s, l, a) => `hsla(${h},${s}%,${l}%,${a})`;

    const floorY = x => R.H * .875 + Math.sin(x * .0042 + .6) * R.H * .028 + Math.sin(x * .0113 + 1.7) * R.H * .014;
    const ridgeY = x => R.H * .74 + Math.sin(x * .0026 + 2.1) * R.H * .05 + Math.sin(x * .009) * R.H * .018;
    R.floorY = floorY;

    // ── ripple field (physics) ────────────────────────────────────────────
    function initWave() {
        // whole numbers: QV4 indexes typed arrays far slower with a double
        // (Math.round's result) in the index sum
        R.gw = Math.round(clamp(R.W / 7, 110, 230)) | 0;
        R.gh = Math.max(8, Math.round(R.gw * R.H / R.W)) | 0;
        R.wA = new Float32Array(R.gw * R.gh);
        R.wB = new Float32Array(R.gw * R.gh);
    }
    function drop(x, y, amp, rad) {
        const gw = R.gw, gh = R.gh, wA = R.wA;
        const cx = x / R.W * gw, cy = y / R.H * gh, r = Math.max(1.2, rad / R.W * gw), RR = Math.ceil(r * 2);
        for (let j = -RR; j <= RR; j++) for (let i = -RR; i <= RR; i++) {
            const gx = Math.round(cx) + i, gy = Math.round(cy) + j;
            if (gx < 1 || gy < 1 || gx >= gw - 1 || gy >= gh - 1) continue;
            const dx = gx - cx, dy = gy - cy, d2 = (dx * dx + dy * dy) / (r * r);
            if (d2 > 4) continue;
            wA[gy * gw + gx] -= amp * Math.exp(-d2 * 2);
        }
        R.calm = 0;
        R.pending.push([x, y, amp, rad]);
    }
    R.drop = drop;
    function stepWave() {
        const gw = R.gw | 0, gh = R.gh | 0, wA = R.wA, wB = R.wB;
        for (let y = 1; y < gh - 1; y++) {
            const o = y * gw;
            for (let x = 1; x < gw - 1; x++) {
                const i = o + x;
                wB[i] = ((wA[i - 1] + wA[i + 1] + wA[i - gw] + wA[i + gw]) * .5 - wB[i]) * .982;
            }
        }
        R.wA = wB; R.wB = wA;
    }
    // the slope under a point, as [dx, dy]
    function gradAt(x, y) {
        const gw = R.gw | 0, wA = R.wA;
        const gx = clamp((x / R.W * gw) | 0, 1, gw - 2), gy = clamp((y / R.H * R.gh) | 0, 1, R.gh - 2), i = gy * gw + gx;
        return [wA[i + 1] - wA[i - 1], wA[i + gw] - wA[i - gw]];
    }
    R.gradAt = gradAt;

    // ── the world ─────────────────────────────────────────────────────────
    function branch(d, maxD, len, w) {
        const n = { len: len, w: w, ang: 0, kids: [], ph: rnd() * 6.28, d: d };
        if (d < maxD) {
            const k = d === 0 ? 3 : (rnd() < .72 ? 2 : 1);
            for (let i = 0; i < k; i++) {
                const c = branch(d + 1, maxD, len * (.66 + rnd() * .2), w * .68);
                c.ang = (rnd() - .5) * .7 + (k > 1 ? (i / (k - 1) - .5) * 1.0 : 0);
                n.kids.push(c);
            }
        }
        return n;
    }

    function build(W, H) {
        R.W = W; R.H = H;
        initWave();
        rnd = mulberry32(R.seed);
        const HUES = hues.creatures;
        R.floorPts = []; R.ridgePts = [];
        for (let x = -10; x <= W + 10; x += 12) { R.floorPts.push([x, floorY(x)]); R.ridgePts.push([x, ridgeY(x)]); }
        R.kelp = [];
        const nk = Math.round(W / 120);
        for (let i = 0; i < nk; i++) {
            const x = rnd() * W;
            R.kelp.push({ x: x, y: ridgeY(x) + 30, n: 14 + (rnd() * 6 | 0), seg: H * .026 * (.8 + rnd() * .5), w: 4 + rnd() * 4, ph: rnd() * 6.28 });
        }
        R.backCorals = [];
        const nb = Math.max(3, Math.round(W / 240));
        for (let i = 0; i < nb; i++) {
            const x = (i + .3 + rnd() * .4) / nb * W;
            R.backCorals.push({ x: x, y: floorY(x) + 8, root: branch(0, 4, H * .04 * (.8 + rnd() * .4), 4), hue: HUES[rnd() * 3 | 0] + hues.back, alpha: .32, excite: 0, h: H * .04 * 3.2 });
        }
        R.corals = []; R.anemones = []; R.fans = [];
        const kinds = ['branch', 'anemone', 'fan', 'branch', 'anemone', 'branch', 'fan', 'anemone', 'branch', 'fan'];
        const nf = clamp(Math.round(W / 165), 4, 10);
        for (let i = 0; i < nf; i++) {
            const x = (i + .5 + (rnd() - .5) * .45) / nf * W, y = floorY(x) + 6, k = kinds[i % kinds.length];
            if (k === 'branch') {
                const len = H * .05 * (.8 + rnd() * .45);
                R.corals.push({ x: x, y: y, root: branch(0, 4, len, 5.5), hue: HUES[[0, 1, 3, 4][rnd() * 4 | 0]], alpha: .6, excite: 0, h: len * 3.2 });
            } else if (k === 'fan') {
                R.fans.push({ x: x, y: y, L: H * .19 * (.8 + rnd() * .35), n: 17, hue: rnd() < .5 ? hues.fans[0] : hues.fans[1], ph: rnd() * 6.28, excite: 0 });
            } else {
                R.anemones.push({ x: x, y: y, r: H * .026 * (.85 + rnd() * .35), n: 18, L: H * .065 * (.85 + rnd() * .3), hue: rnd() < .55 ? hues.anemones[0] : hues.anemones[1], retract: 0, hold: 0, ph: rnd() * 6.28 });
            }
        }
        R.sparkle = [];
        for (let i = 0; i < Math.round(W / 22); i++) { const x = rnd() * W; R.sparkle.push({ x: x, y: floorY(x) + 6 + rnd() * H * .1, ph: rnd() * 6.28 }); }
        R.fish = [];
        const nfish = W < 700 ? Math.min(14, R.fishCount) : R.fishCount;
        for (let i = 0; i < nfish; i++)
            R.fish.push({ x: W * (.3 + rnd() * .4), y: H * (.35 + rnd() * .25), vx: (rnd() - .5) * 2, vy: (rnd() - .5), ph: rnd() * 6.28, wa: rnd() * 6.28, s: 5 + rnd() * 4 });
        R.jellies = [];
        const jh = hues.jellies, nj = W < 700 ? Math.min(3, R.jellyCount) : R.jellyCount;
        for (let i = 0; i < nj; i++) {
            const r = (i === nj - 1 ? 14 : 24 + rnd() * 18) * (H / 900 + .25);
            const j = { x: W * (.15 + .7 * (i / (nj - 1 || 1))) + (rnd() - .5) * 80, y: H * (.22 + rnd() * .35), vx: 0, vy: 0, r: r, ph: rnd() * 6.28, rate: .85 + rnd() * .45, hue: jh[i % jh.length], glow: 0, tilt: 0, seed: rnd() * 10, tents: [], arms: [], _w: r, _h: r * .72, _c: 0 };
            const nT = 8, seg = r * .2, len = 11 + (rnd() * 5 | 0);
            for (let k = 0; k < nT; k++) { const pts = []; for (let q = 0; q < len; q++) pts.push({ x: j.x, y: j.y + q * seg, ox: j.x, oy: j.y + q * seg }); j.tents.push({ pts: pts, seg: seg }); }
            for (let k = 0; k < 3; k++) { const pts = []; for (let q = 0; q < 8; q++) pts.push({ x: j.x, y: j.y + q * seg * .9, ox: j.x, oy: j.y + q * seg * .9 }); j.arms.push({ pts: pts, seg: seg * .9 }); }
            R.jellies.push(j);
        }
        for (const c of R.backCorals) restCoral(c);
        for (const c of R.corals) restCoral(c);
        for (const f of R.fans) restFan(f);
        R.NP = Math.round(clamp(W * H / 2600, 180, Math.max(180, R.plankton)));
        R.px = new Float32Array(R.NP); R.py = new Float32Array(R.NP); R.pb = new Float32Array(R.NP); R.pz = new Float32Array(R.NP);
        for (let i = 0; i < R.NP; i++) { R.px[i] = rnd() * W; R.py[i] = rnd() * H * .92; R.pb[i] = .05; R.pz[i] = .7 + rnd() * 1.6; }
        R.pending = [];
    }
    R.build = build;
    // plankton in play: all of them, or half when the reef is cut back
    R.live = () => R.reduced ? R.NP >> 1 : R.NP;

    // ── disturbances ──────────────────────────────────────────────────────
    function excite(x, y, rad, amt) {
        const r2 = rad * rad, n = R.live(), px = R.px, py = R.py, pb = R.pb;
        for (let i = 0; i < n; i++) {
            const dx = px[i] - x, dy = py[i] - y, d2 = dx * dx + dy * dy;
            if (d2 < r2) pb[i] = Math.min(1, pb[i] + amt * (1 - Math.sqrt(d2) / rad));
        }
    }
    R.excite = excite;
    function scatterFish(x, y, rad, f) {
        for (const k of R.fish) {
            const dx = k.x - x, dy = k.y - y, d = Math.hypot(dx, dy) || 1;
            if (d < rad) { k.vx += dx / d * f * (1 - d / rad); k.vy += dy / d * f * (1 - d / rad); }
        }
    }
    // what a press lands on: a jelly flares and jets off, an anemone pulls
    // in, a coral or fan lights its tips
    function hitTest(x, y) {
        for (const j of R.jellies) {
            const cx = j.x + Math.sin(j.tilt) * j.r * .4, cy = j.y - Math.cos(j.tilt) * j.r * .4;
            if (Math.hypot(x - cx, y - cy) < j.r * 1.25) { j.glow = 1; j.ph = Math.PI * .5; j.vx += (j.x - x) * .02; j.vy -= 1.1; excite(j.x, j.y, j.r * 3, .8); return "jelly"; }
        }
        for (const a of R.anemones) if (Math.hypot(x - a.x, y - (a.y - a.L * .5)) < a.L * .9) { a.retract = 1; a.hold = 90; excite(a.x, a.y - a.L * .4, a.L * 1.5, .6); return "anemone"; }
        for (const c of R.corals) if (Math.hypot(x - c.x, y - (c.y - c.h * .5)) < c.h * .65) { c.excite = 1; return "coral"; }
        for (const f of R.fans) if (Math.hypot(x - f.x, y - (f.y - f.L * .55)) < f.L * .6) { f.excite = 1; return "fan"; }
        return "";
    }
    R.hitTest = hitTest;

    R.press = function (x, y) {
        const p = R.pointer;
        p.down = true; p.active = true; p.x = p.lx = x; p.y = p.ly = y;
        drop(x, y, 1.6, 24); excite(x, y, 190, .85); scatterFish(x, y, 240, 3.2);
        return hitTest(x, y);
    };
    R.move = function (x, y) {
        const p = R.pointer, sp = Math.hypot(x - p.lx, y - p.ly);
        p.x = x; p.y = y; p.active = true;
        if (p.down) { if (sp > 3) { drop(x, y, .38, 15); excite(x, y, 80, .45); p.lx = x; p.ly = y; } }
        else if (sp > 5) { drop(x, y, .07, 13); excite(x, y, 60, .22 * Math.min(1, sp / 18)); p.lx = x; p.ly = y; }
    };
    R.release = function () { R.pointer.down = false; };
    R.leave = function () { R.pointer.active = false; R.pointer.down = false; };

    // a workspace switch: a current sweeps across (dir 1 to the right), waves
    // roll in from the edge it leaves, and the plankton lifts
    R.switchWs = function (dir) {
        R.flow = dir * 2.8 * R.mot;
        for (let y = R.H * .15; y < R.H * .95; y += R.H * .12) drop(dir > 0 ? R.W * .02 : R.W * .98, y, .9, 60);
        const n = R.live();
        for (let i = 0; i < n; i++) R.pb[i] = Math.min(1, R.pb[i] + .18);
    };
    // a notification: the jelly nearest where it showed flares and pulses
    R.notify = function (x, y) {
        let best = null, bd = Infinity;
        for (const j of R.jellies) { const d = Math.hypot(j.x - x, j.y - y); if (d < bd) { bd = d; best = j; } }
        if (!best) return;
        best.glow = 1; best.ph = Math.PI * .5; best.vy -= .8; drop(best.x, best.y, 1, 30); excite(best.x, best.y, best.r * 4, .7);
    };
    // the shell touching the water from above (a card landing, the launcher)
    R.disturb = function (x, y, s) {
        drop(x, y, .9 * s, 22 + 14 * s); excite(x, y, 70 + 90 * s, .5 * s);
    };
    // a beat from the music
    R.kick = function () {
        R.beat = 1;
        const n = R.live();
        for (let i = 0; i < n; i++) R.pb[i] = Math.min(1, R.pb[i] + .07);
    };

    // ── a step of the world ───────────────────────────────────────────────
    R.update = function (dt, t) {
        const MOT = R.mot, W = R.W, H = R.H;
        // 60 steps a second whatever the frame rate. 0.982 a step leaves a
        // drop under a thousandth of itself after 400 (about 7 s), so past
        // that the field is still and stops costing anything
        const steps = Math.max(1, Math.round(dt));
        if (R.calm < 420) {
            for (let i = 0; i < steps; i++) stepWave();
            R.calm += steps;
            if (R.calm >= 420) { R.wA.fill(0); R.wB.fill(0); }
        }
        R.flow *= Math.pow(.975, dt); R.sweep += R.flow * dt * .004;
        if (R.breath) R.beat = .3 * (.5 - .5 * Math.cos(t * Math.PI));    // 0.5 Hz
        else R.beat *= Math.pow(.9, dt);
        const flow = R.flow;

        // plankton
        const n = R.live(), px = R.px, py = R.py, pb = R.pb;
        for (let i = 0; i < n; i++) {
            const x = px[i], y = py[i], g = gradAt(x, y), gm = Math.abs(g[0]) + Math.abs(g[1]);
            px[i] += (Math.sin(y * .006 + t * .25) * .12 + flow * .55 + g[0] * 5) * dt * MOT;
            py[i] += (Math.cos(x * .005 + t * .2) * .08 - .02 + g[1] * 5) * dt * MOT;
            if (px[i] < 0) px[i] += W; else if (px[i] > W) px[i] -= W;
            if (py[i] < 0) py[i] += H * .92; else if (py[i] > H * .92) py[i] -= H * .92;
            pb[i] = Math.min(1, .05 + (pb[i] - .05) * Math.pow(.962, dt) + gm * .35);
        }
        // the school: separation, alignment, cohesion, a wander, walls, the
        // pointer, the ripples and the current
        const pAct = R.pointer.active && R.interactive, ptr = R.pointer;
        for (const f of R.fish) {
            let ax = 0, ay = 0, sxp = 0, syp = 0, alx = 0, aly = 0, cx = 0, cy = 0, na = 0, nc = 0;
            for (const o of R.fish) {
                if (o === f) continue;
                const dx = o.x - f.x, dy = o.y - f.y, d2 = dx * dx + dy * dy;
                if (d2 < 484) { const d = Math.sqrt(d2) || 1; sxp -= dx / d; syp -= dy / d; }
                if (d2 < 4900) { alx += o.vx; aly += o.vy; na++; }
                if (d2 < 8100) { cx += o.x; cy += o.y; nc++; }
            }
            ax += sxp * .06; ay += syp * .06;
            if (na) { ax += (alx / na - f.vx) * .035; ay += (aly / na - f.vy) * .035; }
            if (nc) { ax += (cx / nc - f.x) * .0007; ay += (cy / nc - f.y) * .0007; }
            f.wa += (Math.random() - .5) * .3; ax += Math.cos(f.wa) * .02; ay += Math.sin(f.wa) * .012;
            if (f.x < 70) ax += .07; if (f.x > W - 70) ax -= .07; if (f.y < H * .17) ay += .06; if (f.y > floorY(f.x) - H * .08) ay -= .09;
            if (pAct) { const dx = f.x - ptr.x, dy = f.y - ptr.y, d = Math.hypot(dx, dy) || 1; if (d < 150) { ax += dx / d * .4 * (1 - d / 150); ay += dy / d * .4 * (1 - d / 150); } }
            const g = gradAt(f.x, f.y); ax += g[0] * 1.6; ay += g[1] * 1.6; ax += flow * .025;
            f.vx += ax * dt; f.vy += ay * dt;
            const sp = Math.hypot(f.vx, f.vy) || 1, ns = clamp(sp, .55, 2.8);
            f.vx = f.vx / sp * ns; f.vy = f.vy / sp * ns;
            f.x += f.vx * dt * MOT; f.y += f.vy * dt * MOT; f.ph += dt * (.22 + ns * .13);
        }
        // jellies: the bell's pulse thrusts along the tilt; tentacles and
        // oral arms are verlet chains hanging from the rim
        for (const j of R.jellies) {
            j.ph += dt * .045 * j.rate * (1 + j.glow * 1.4) * MOT;
            const c = Math.max(0, Math.sin(j.ph));
            const floorNear = j.y > floorY(j.x) - j.r * 4, high = j.y < H * .13;
            const th = high ? 0 : c * .032 * j.rate * (floorNear ? 2 : 1) * dt;
            j.vx += Math.sin(j.tilt) * th; j.vy -= Math.cos(j.tilt) * th;
            j.vy += .0055 * dt; j.vx += flow * .006 * dt;
            if (j.x < j.r * 2) j.vx += .012 * dt; if (j.x > W - j.r * 2) j.vx -= .012 * dt;
            if (pAct) { const dx = j.x - ptr.x, dy = j.y - ptr.y, d = Math.hypot(dx, dy) || 1; if (d < 120) { j.vx += dx / d * .012 * dt; j.vy += dy / d * .006 * dt; } }
            const g = gradAt(j.x, j.y); j.vx += g[0] * .35; j.vy += g[1] * .35;
            const dr = Math.pow(.984, dt); j.vx *= dr; j.vy *= dr;
            j.x += j.vx * dt * MOT; j.y += j.vy * dt * MOT;
            const tt = Math.sin(t * .07 + j.seed) * .32 + (j.x < W * .15 ? .3 : 0) + (j.x > W * .85 ? -.3 : 0) + j.vx * .15;
            j.tilt += (clamp(tt, -.55, .55) - j.tilt) * .012 * dt;
            j.glow *= Math.pow(.972, dt);
            const w = j.r * (1 - .16 * c), h = j.r * (.72 + .14 * c), ct = Math.cos(j.tilt), st = Math.sin(j.tilt);
            const sim = (ch, ax0, ay0, grav) => {
                const p = ch.pts; p[0].x = ax0; p[0].y = ay0;
                for (let q = 1; q < p.length; q++) {
                    const nd = p[q]; const vx = (nd.x - nd.ox) * .93, vy = (nd.y - nd.oy) * .93; nd.ox = nd.x; nd.oy = nd.y;
                    const gg = gradAt(nd.x, nd.y); nd.x += vx + (flow * .12 + gg[0] * 1.2) * dt; nd.y += vy + (grav + gg[1] * 1.2) * dt;
                }
                for (let it = 0; it < 2; it++) for (let q = 1; q < p.length; q++) {
                    const a = p[q - 1], b = p[q]; const dx = b.x - a.x, dy = b.y - a.y, d = Math.hypot(dx, dy) || 1, k = (d - ch.seg) / d; b.x -= dx * k; b.y -= dy * k;
                }
            };
            const nt = j.tents.length;
            for (let k = 0; k < nt; k++) { const lx = -w * .88 + 1.76 * w * (k / (nt - 1)), ly = -h * .02; sim(j.tents[k], j.x + lx * ct - ly * st, j.y + lx * st + ly * ct, .05); }
            for (let k = 0; k < j.arms.length; k++) { const lx = (k - 1) * w * .2, ly = -h * .1; sim(j.arms[k], j.x + lx * ct - ly * st, j.y + lx * st + ly * ct, .035); }
            j._w = w; j._h = h; j._c = c;
        }
        for (const a of R.anemones) { if (a.hold > 0) { a.hold -= dt; a.retract += (1 - a.retract) * .3; } else a.retract *= Math.pow(.982, dt); }
        for (const c of R.corals) c.excite *= Math.pow(.965, dt);
        for (const f of R.fans) f.excite *= Math.pow(.965, dt);
    };

    // ── what the GPU moves (Scene.qml) ────────────────────────────────────
    // Corals and fans are drawn once at rest (bakeCoral, bakeFan) and swayed
    // by their vertex shaders (shaders/coral.vert, fan.vert); kelp is drawn
    // whole by kelp.vert. The tips' glows stay on the canvas and move by the
    // same rules, coralSway() and fanBend(), so they stay on their branches.
    //
    // A coral's rest shape: its segments and tips with no sway, its bounds
    // and how far its top moves. In the mock each branch turns on its own
    // phase by .05 × (depth + 1), and so carries everything above it; summed
    // up a tip's sideways travel is Σ .05 (d + 1) × (joint height − tip
    // height) over the joints under it. `lean` adds those up (the current
    // pushes every branch the same way), `swing` takes their root sum of
    // squares (each on its own phase); both are averaged over the tips and
    // scaled so the tips travel as far as the mock's do (rms 9.8 px against
    // its 9.7 on a 1920×1080 reef; the lean within 7%).
    function restCoral(c) {
        const segs = [], tips = [];
        let swing = 0, lean = 0, x0 = c.x, x1 = c.x, y0 = c.y, y1 = c.y;
        const walk = (n, x, y, a, joints, sib) => {
            const aa = a + n.ang, x2 = x + Math.cos(aa) * n.len, y2 = y + Math.sin(aa) * n.len;
            segs.push({ x: x, y: y, x2: x2, y2: y2, d: n.d, w: n.w, sib: sib });
            const pad = n.w / 2 + 1;
            x0 = Math.min(x0, x - pad, x2 - pad); x1 = Math.max(x1, x + pad, x2 + pad);
            y0 = Math.min(y0, y - pad, y2 - pad); y1 = Math.max(y1, y + pad, y2 + pad);
            const here = joints.concat([[y, n.d]]);
            if (n.kids.length) for (let i = 0; i < n.kids.length; i++) walk(n.kids[i], x2, y2, aa, here, i);
            else {
                let s2 = 0, l = 0;
                for (const [jy, d] of here) { const k = .05 * (d + 1) * (jy - y2); s2 += k * k; l += k; }
                swing += Math.sqrt(s2); lean += l;
                tips.push(x2, y2);
            }
        };
        walk(c.root, c.x, c.y, -Math.PI / 2, [], 0);
        const nt = tips.length / 2;
        // the texture only holds the shape at rest; the vertex shader moves it
        const reach = 2;
        c.rest = { segs: segs, tips: tips, height: Math.max(1, c.y - y0), swing: swing / nt * 1.6, lean: lean / nt * .94,
                   x0: x0 - reach, y0: y0 - reach, x1: x1 + reach, y1: y1 + reach };
        c.ph = c.root.ph;
    }
    // where a point of a coral (at rest x, y) has moved to now, [dx, dy]:
    // the coral turns about its foot, more the higher up (so the top travels
    // with the square of its height, the foot not at all), and its side
    // branches bob twice what that turn alone gives them, as the mock's
    // separately turning branches do. The same as coral.vert.
    function coralSway(c, x, y, t) {
        const r = c.rest, hn = clamp((c.y - y) / r.height, 0, 1), w = t * .85 * R.mot;
        const s = .75 * Math.sin(w + c.ph + x * .004) + .25 * Math.sin(w * 1.37 + c.ph * 1.9 + hn * 2.4);
        const th = (r.swing * s + r.lean * R.flow) / r.height * hn;
        return [th * (c.y - y), 2 * th * (x - c.x)];
    }
    R.coralSway = coralSway;
    // a sea fan: rays from its foot, joined by rungs, bending more toward
    // their ends (bend × u², u along the ray), as fan.vert bends them
    function fanRay(f, i, u, bend) {
        const base = -Math.PI / 2 + (i / (f.n - 1) - .5) * 1.7;
        const L = f.L * (.78 + .22 * Math.cos((i / (f.n - 1) - .5) * 2.4));
        const a = base + bend * u * u;
        return [f.x + Math.cos(a) * L * u, f.y + Math.sin(a) * L * u];
    }
    function restFan(f) {
        const pad = 3;
        f.rest = { x0: f.x - f.L - pad, x1: f.x + f.L + pad, y0: f.y - f.L - pad, y1: f.y + pad };
    }
    R.fanBend = (f, t) => Math.sin(t * .7 * R.mot + f.ph) * .14 + R.flow * .06;
    R.kelpTime = t => t * .5 * R.mot;

    // A coral at rest, into a canvas whose (0, 0) is at its rest bounds'
    // corner (in world px; the caller scales). Segments in groups that never
    // touch within themselves (one per depth and place among siblings), so
    // where branches meet their round caps overlap and brighten the knot, as
    // the mock's stroke-per-segment does.
    R.bakeCoral = function (ctx, c) {
        const r = c.rest, groups = [];
        for (const g of r.segs) {
            const key = g.d * 4 + g.sib;
            (groups[key] || (groups[key] = { d: g.d, w: g.w, s: [] })).s.push(g);
        }
        ctx.save(); ctx.translate(-r.x0, -r.y0);
        ctx.globalCompositeOperation = 'lighter'; ctx.lineCap = 'round';
        for (const g of groups) {
            if (!g) continue;
            ctx.strokeStyle = hsla(c.hue, 85, 32 + g.d * 8, c.alpha); ctx.lineWidth = g.w;
            ctx.beginPath();
            for (const sg of g.s) { ctx.moveTo(sg.x, sg.y); ctx.lineTo(sg.x2, sg.y2); }
            ctx.stroke();
        }
        ctx.restore();
    };
    R.bakeFan = function (ctx, f) {
        const rows = 6, r = f.rest;
        ctx.save(); ctx.translate(-r.x0, -r.y0);
        ctx.globalCompositeOperation = 'lighter';
        ctx.strokeStyle = hsla(f.hue, 75, 50, .3); ctx.lineWidth = 1.3; ctx.beginPath();
        for (let i = 0; i < f.n; i++) {
            const p0 = fanRay(f, i, 0, 0); ctx.moveTo(p0[0], p0[1]);
            for (let k = 1; k <= rows; k++) { const p = fanRay(f, i, k / rows, 0); ctx.lineTo(p[0], p[1]); }
        }
        for (let k = 2; k <= rows; k++) for (let i = 0; i < f.n - 1; i++) {
            const a = fanRay(f, i, k / rows, 0), b = fanRay(f, i + 1, k / rows, 0);
            ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]);
        }
        ctx.stroke();
        ctx.restore();
    };
    // the distant ridge (a translucent silhouette), drawn once
    R.drawRidge = function (ctx) {
        ctx.globalCompositeOperation = 'source-over';
        ctx.fillStyle = pal.ridge; ctx.beginPath(); ctx.moveTo(-10, R.H);
        for (const p of R.ridgePts) ctx.lineTo(p[0], p[1]);
        ctx.lineTo(R.W + 10, R.H); ctx.fill();
    };
    // the seafloor and its faint lit edge, drawn once
    R.drawFloor = function (ctx) {
        const W = R.W, H = R.H;
        ctx.globalCompositeOperation = 'source-over';
        const fg = ctx.createLinearGradient(0, H * .82, 0, H); fg.addColorStop(0, pal.floorTop); fg.addColorStop(1, pal.floorBottom);
        ctx.fillStyle = fg; ctx.beginPath(); ctx.moveTo(-10, H); for (const p of R.floorPts) ctx.lineTo(p[0], p[1]); ctx.lineTo(W + 10, H); ctx.fill();
        ctx.globalCompositeOperation = 'lighter';
        ctx.strokeStyle = pal.floorLine; ctx.lineWidth = 2; ctx.beginPath();
        R.floorPts.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])); ctx.stroke();
        ctx.globalCompositeOperation = 'source-over';
    };
    // the anemones' bodies (they never move), drawn once
    R.drawBases = function (ctx) {
        for (const a of R.anemones) {
            const by = a.y - a.r * .55;
            ctx.globalCompositeOperation = 'source-over';
            ctx.fillStyle = pal.anemoneBase; ctx.beginPath(); ellipsePath(ctx, a.x, by, a.r * 1.1, a.r * .75, 0, 0, Math.PI * 2); ctx.fill();
            ctx.globalCompositeOperation = 'lighter';
            ctx.strokeStyle = hsla(a.hue, 80, 45, .35); ctx.lineWidth = 1.2; ctx.beginPath(); ellipsePath(ctx, a.x, by, a.r * 1.1, a.r * .75, 0, Math.PI * 1.05, Math.PI * 1.95); ctx.stroke();
        }
        ctx.globalCompositeOperation = 'source-over';
    };

    // ── drawing (Canvas 2D, in world px; the caller scales) ──────────────
    // an ellipse turned by `rot`, as a path (the QML context's ellipse() has neither)
    function ellipsePath(ctx, x, y, rx, ry, rot, a0, a1) {
        ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.scale(rx, ry);
        ctx.moveTo(Math.cos(a0), Math.sin(a0)); ctx.arc(0, 0, 1, a0, a1, false);
        ctx.restore();
    }
    function blit(ctx, img, x, y, r, a) {
        if (a <= 0.003) return;
        ctx.globalAlpha = a > 1 ? 1 : a;
        ctx.drawImage(img, x - r, y - r, r * 2, r * 2);
    }

    // the mock's coral, a stroke per branch segment (the reference only)
    function drawBranch(ctx, n, x, y, a, t, c, tips) {
        const sway = Math.sin(t * .85 * R.mot + n.ph + x * .004) * .05 * (n.d + 1) + R.flow * .05 * (n.d + 1);
        const aa = a + n.ang + sway, x2 = x + Math.cos(aa) * n.len, y2 = y + Math.sin(aa) * n.len;
        ctx.strokeStyle = hsla(c.hue, 85, 32 + n.d * 8 + c.excite * 12, c.alpha); ctx.lineWidth = n.w;
        ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x2, y2); ctx.stroke();
        if (n.kids.length) for (const k of n.kids) drawBranch(ctx, k, x2, y2, aa, t, c, tips); else tips.push(x2, y2);
    }
    function drawCoral(ctx, c, t, tipScale) {
        const tips = []; ctx.lineCap = 'round';
        drawBranch(ctx, c.root, c.x, c.y, -Math.PI / 2, t, c, tips);
        const s = spr(c.hue, 95, 62);
        for (let i = 0; i < tips.length; i += 2) {
            const a = clamp((.32 + R.beat * .35 + c.excite * .7 + .12 * Math.sin(t * 2 + i)) * c.alpha * 1.6, 0, 1);
            blit(ctx, s, tips[i], tips[i + 1], (3.5 + c.excite * 5 + R.beat * 2) * tipScale, a);
        }
        ctx.globalAlpha = 1;
    }
    function drawFan(ctx, f, t) {
        const rows = 6, rays = [];
        for (let i = 0; i < f.n; i++) {
            const base = -Math.PI / 2 + (i / (f.n - 1) - .5) * 1.7, pts = [];
            for (let k = 0; k <= rows; k++) {
                const u = k / rows, bend = (Math.sin(t * .7 * R.mot + f.ph) * .14 + R.flow * .06) * u * u;
                const L = f.L * (.78 + .22 * Math.cos((i / (f.n - 1) - .5) * 2.4));
                pts.push([f.x + Math.cos(base + bend) * L * u, f.y + Math.sin(base + bend) * L * u]);
            }
            rays.push(pts);
        }
        ctx.strokeStyle = hsla(f.hue, 75, 50 + f.excite * 15, .3 + f.excite * .4); ctx.lineWidth = 1.3; ctx.beginPath();
        for (const r of rays) { ctx.moveTo(r[0][0], r[0][1]); for (const p of r) ctx.lineTo(p[0], p[1]); }
        for (let k = 2; k <= rows; k++) for (let i = 0; i < rays.length - 1; i++) { ctx.moveTo(rays[i][k][0], rays[i][k][1]); ctx.lineTo(rays[i + 1][k][0], rays[i + 1][k][1]); }
        ctx.stroke();
        const s = spr(f.hue, 95, 65);
        for (let i = 0; i < rays.length; i++) {
            const p = rays[i][rows];
            blit(ctx, s, p[0], p[1], 3 + f.excite * 4, clamp(.35 + f.excite * .6 + R.beat * .3 + .15 * Math.sin(t * 1.6 + i * .7), 0, 1));
        }
        ctx.globalAlpha = 1;
    }
    function drawAnemone(ctx, a, t) {
        const by = a.y - a.r * .55;
        ctx.globalCompositeOperation = 'source-over';
        ctx.fillStyle = pal.anemoneBase; ctx.beginPath(); ellipsePath(ctx, a.x, by, a.r * 1.1, a.r * .75, 0, 0, Math.PI * 2); ctx.fill();
        ctx.globalCompositeOperation = 'lighter';
        ctx.strokeStyle = hsla(a.hue, 80, 45, .35); ctx.lineWidth = 1.2; ctx.beginPath(); ellipsePath(ctx, a.x, by, a.r * 1.1, a.r * .75, 0, Math.PI * 1.05, Math.PI * 1.95); ctx.stroke();
        anemoneTentacles(ctx, a, t);
    }
    // tentacles: curves out of the body that sway, pull in when touched
    // (retract) and relax again, with a glow at each tip
    function anemoneTentacles(ctx, a, t) {
        const k = a.retract, by = a.y - a.r * .55;
        ctx.globalCompositeOperation = 'lighter';
        ctx.lineCap = 'round'; ctx.lineWidth = 2.1; ctx.strokeStyle = hsla(a.hue, 90, 62, .42 + k * .2);
        const s = spr(a.hue, 100, 70), tips = [];
        ctx.beginPath();
        for (let i = 0; i < a.n; i++) {
            const u = i / (a.n - 1) - .5, ang = -Math.PI / 2 + u * 2.3 * (1 - .5 * k);
            const L = a.L * (1 - .72 * k) * (.82 + .18 * Math.sin(i * 1.7 + a.ph));
            const s0x = a.x + Math.sin(u * Math.PI) * a.r * .9, s0y = by - a.r * .55 + Math.abs(u) * a.r * .5;
            const dx = Math.cos(ang), dy = Math.sin(ang), wv = (1 - k) * R.mot;
            const w1 = Math.sin(t * 1.3 + i * .6 + a.ph) * .28 * wv, w2 = Math.sin(t * 1.3 + i * .6 + a.ph + .9) * .4 * wv;
            const cxp = s0x + dx * L * .5 - dy * L * w1 + R.flow * 3, cyp = s0y + dy * L * .5 + dx * L * w1;
            const ex = s0x + dx * L - dy * L * w2 + R.flow * 6, ey = s0y + dy * L + dx * L * w2;
            ctx.moveTo(s0x, s0y); ctx.quadraticCurveTo(cxp, cyp, ex, ey); tips.push(ex, ey);
        }
        ctx.stroke();
        for (let i = 0; i < tips.length; i += 2) blit(ctx, s, tips[i], tips[i + 1], 3 + k * 3 + R.beat * 2, clamp(.45 + k * .4 + R.beat * .3, 0, 1));
        ctx.globalAlpha = 1;
    }
    function smoothChain(ctx, p) {
        ctx.beginPath(); ctx.moveTo(p[0].x, p[0].y);
        for (let q = 1; q < p.length - 1; q++) ctx.quadraticCurveTo(p[q].x, p[q].y, (p[q].x + p[q + 1].x) / 2, (p[q].y + p[q + 1].y) / 2);
        const l = p[p.length - 1]; ctx.lineTo(l.x, l.y); ctx.stroke();
    }
    function drawJelly(ctx, j, t) {
        const w = j._w, h = j._h, g = j.glow, hue = j.hue;
        const cx = j.x + Math.sin(j.tilt) * h * .45, cy = j.y - Math.cos(j.tilt) * h * .45;
        blit(ctx, spr(hue, 90, 55), cx, cy, j.r * (3.2 + g * 1.5), .16 + g * .4);
        ctx.globalAlpha = 1;
        ctx.lineCap = 'round';
        ctx.lineWidth = .9; ctx.strokeStyle = hsla(hue, 90, 72, .26 + g * .45); for (const ch of j.tents) smoothChain(ctx, ch.pts);
        ctx.lineWidth = 2.6; ctx.strokeStyle = hsla(hue, 80, 60, .16 + g * .3); for (const ch of j.arms) smoothChain(ctx, ch.pts);
        ctx.save(); ctx.translate(j.x, j.y); ctx.rotate(j.tilt);
        const gr = ctx.createRadialGradient(0, -h * .55, 0, 0, -h * .4, w * 1.1);
        gr.addColorStop(0, hsla(hue, 100, 82, .30 + g * .35)); gr.addColorStop(.6, hsla(hue, 95, 60, .12 + g * .15)); gr.addColorStop(1, hsla(hue, 90, 50, .04));
        ctx.beginPath(); ctx.moveTo(-w, 0); ctx.bezierCurveTo(-w * 1.02, -h * 1.3, w * 1.02, -h * 1.3, w, 0);
        const sc8 = 8;
        for (let k = sc8; k > 0; k--) { const x0 = -w + 2 * w * (k / sc8), x1 = -w + 2 * w * ((k - 1) / sc8); ctx.quadraticCurveTo((x0 + x1) / 2, -h * .16, x1, 0); }
        ctx.closePath(); ctx.fillStyle = gr; ctx.fill();
        ctx.lineWidth = 1.1; ctx.strokeStyle = hsla(hue, 100, 82, .5 + g * .45); ctx.stroke();
        // the gonads: four loops turning slowly inside the bell
        ctx.lineWidth = 1; ctx.strokeStyle = hsla(hue, 100, 85, .22 + g * .3);
        for (let k = 0; k < 4; k++) { const a = k / 4 * Math.PI * 2 + t * .2; ctx.beginPath(); ellipsePath(ctx, Math.cos(a) * w * .28, -h * .5 + Math.sin(a) * h * .12, w * .15, h * .1, a, 0, Math.PI * 2); ctx.stroke(); }
        ctx.restore();
        // rim lights: a pulse running round the bell's edge
        const s = spr(hue, 100, 75), ct = Math.cos(j.tilt), st = Math.sin(j.tilt);
        for (let k = 0; k < 9; k++) {
            const lx = -w + 2 * w * (k / 8), ly = -h * .04;
            blit(ctx, s, j.x + lx * ct - ly * st, j.y + lx * st + ly * ct, 2.4 + g * 3, clamp(.25 + .75 * Math.max(0, Math.sin(j.ph * 2 - k * .7)) * (.5 + g) + g * .3, 0, 1));
        }
        ctx.globalAlpha = 1;
    }
    function drawFish(ctx, f) {
        const a = Math.atan2(f.vy, f.vx), s = f.s, tail = Math.sin(f.ph) * .55;
        ctx.save(); ctx.translate(f.x, f.y); ctx.rotate(a);
        ctx.fillStyle = pal.fish;
        ctx.beginPath(); ctx.moveTo(s * 1.3, 0); ctx.quadraticCurveTo(s * .2, -s * .55, -s, 0); ctx.quadraticCurveTo(s * .2, s * .55, s * 1.3, 0); ctx.fill();
        ctx.beginPath(); ctx.moveTo(-s * .9, 0); ctx.lineTo(-s * 1.75, -s * .5 + tail * s * .5); ctx.lineTo(-s * 1.6, tail * s * .3); ctx.lineTo(-s * 1.75, s * .5 + tail * s * .5); ctx.closePath(); ctx.fill();
        ctx.fillStyle = pal.photophore;
        for (let k = 0; k < 3; k++) ctx.fillRect(s * .6 - k * s * .55, s * .2, 1.1, 1.1);
        ctx.restore();
    }

    // what moves on the canvas, all of it light (added): the floor's
    // sparkle, the corals' and fans' tips, the anemones' tentacles, the
    // school, the jellies and the plankton. Scene.qml draws the rest.
    R.drawLive = function (ctx, t) {
        ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = 1;
        const ss = spr(hues.sparkle, 90, 65);
        for (const s of R.sparkle) { const a = Math.max(0, Math.sin(t * .9 + s.ph)) * .5; if (a < .05) continue; blit(ctx, ss, s.x, s.y, 3, a); }
        for (const c of R.backCorals) coralTips(ctx, c, t, .7);
        for (const f of R.fans) fanTips(ctx, f, t);
        for (const c of R.corals) coralTips(ctx, c, t, 1);
        for (const a of R.anemones) anemoneTentacles(ctx, a, t);
        ctx.globalCompositeOperation = 'lighter';
        for (const f of R.fish) drawFish(ctx, f);
        for (const j of R.jellies) drawJelly(ctx, j, t);
        drawPlankton(ctx);
        ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
    };
    function coralTips(ctx, c, t, tipScale) {
        const s = spr(c.hue, 95, 62), tips = c.rest.tips;
        for (let i = 0; i < tips.length; i += 2) {
            const a = clamp((.32 + R.beat * .35 + c.excite * .7 + .12 * Math.sin(t * 2 + i)) * c.alpha * 1.6, 0, 1);
            const d = coralSway(c, tips[i], tips[i + 1], t);
            blit(ctx, s, tips[i] + d[0], tips[i + 1] + d[1], (3.5 + c.excite * 5 + R.beat * 2) * tipScale, a);
        }
        ctx.globalAlpha = 1;
    }
    function fanTips(ctx, f, t) {
        const s = spr(f.hue, 95, 65), bend = R.fanBend(f, t);
        for (let i = 0; i < f.n; i++) {
            const p = fanRay(f, i, 1, bend);
            blit(ctx, s, p[0], p[1], 3 + f.excite * 4, clamp(.35 + f.excite * .6 + R.beat * .3 + .15 * Math.sin(t * 1.6 + i * .7), 0, 1));
        }
        ctx.globalAlpha = 1;
    }
    function drawPlankton(ctx) {
        const ps = spr(hues.plankton, 100, 70), n = R.live();
        ctx.fillStyle = pal.plankton;
        for (let i = 0; i < n; i++) {
            const b = R.pb[i], a = b * (.45 + R.pz[i] * .3);
            if (a < .03) continue;
            const s = R.pz[i];
            ctx.globalAlpha = Math.min(1, a); ctx.fillRect(R.px[i] - s / 2, R.py[i] - s / 2, s, s);
            if (b > .3) blit(ctx, ps, R.px[i], R.py[i], 4 + b * 9, b * .5);
        }
        ctx.globalAlpha = 1;
    }

    // The whole scene on one canvas, the mock's drawScene() as it is: the
    // reference the GPU split is checked against (tools/still.py --reference).
    R.draw = function (ctx, t, withPlankton) {
        const W = R.W, H = R.H;
        ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
        // the distant ridge, a translucent silhouette, and the kelp
        ctx.fillStyle = pal.ridge; ctx.beginPath(); ctx.moveTo(-10, H);
        for (const p of R.ridgePts) ctx.lineTo(p[0], p[1]);
        ctx.lineTo(W + 10, H); ctx.fill();
        ctx.lineCap = 'round'; ctx.strokeStyle = pal.kelp;
        for (const k of R.kelp) {
            let x = k.x, y = k.y;
            for (let i = 0; i < k.n; i++) {
                const u = i / k.n, ang = -Math.PI / 2 + Math.sin(t * .5 * R.mot + k.ph + i * .3) * .22 * u + R.flow * .07 * u;
                const nx = x + Math.cos(ang) * k.seg, ny = y + Math.sin(ang) * k.seg;
                ctx.lineWidth = k.w * (1 - u * .55); ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(nx, ny); ctx.stroke(); x = nx; y = ny;
            }
        }
        ctx.globalCompositeOperation = 'lighter';
        for (const c of R.backCorals) drawCoral(ctx, c, t, .7);
        // the seafloor
        ctx.globalCompositeOperation = 'source-over';
        const fg = ctx.createLinearGradient(0, H * .82, 0, H); fg.addColorStop(0, pal.floorTop); fg.addColorStop(1, pal.floorBottom);
        ctx.fillStyle = fg; ctx.beginPath(); ctx.moveTo(-10, H); for (const p of R.floorPts) ctx.lineTo(p[0], p[1]); ctx.lineTo(W + 10, H); ctx.fill();
        ctx.globalCompositeOperation = 'lighter';
        ctx.strokeStyle = pal.floorLine; ctx.lineWidth = 2; ctx.beginPath();
        R.floorPts.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1])); ctx.stroke();
        const ss = spr(hues.sparkle, 90, 65);
        for (const s of R.sparkle) { const a = Math.max(0, Math.sin(t * .9 + s.ph)) * .5; if (a < .05) continue; blit(ctx, ss, s.x, s.y, 3, a); }
        ctx.globalAlpha = 1;
        for (const f of R.fans) drawFan(ctx, f, t);
        for (const c of R.corals) drawCoral(ctx, c, t, 1);
        for (const a of R.anemones) drawAnemone(ctx, a, t);
        ctx.globalCompositeOperation = 'lighter';
        for (const f of R.fish) drawFish(ctx, f);
        for (const j of R.jellies) drawJelly(ctx, j, t);
        if (withPlankton) drawPlankton(ctx);
        ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
    };

    // every glow the reef draws, as [h, s, l]; gen.py bakes the same list
    R.spriteKeys = function () {
        const k = [], c = hues.creatures;
        for (const h of [c[0], c[1], c[3], c[4]]) k.push([h, 95, 62]);
        for (const h of c.slice(0, 3)) k.push([h + hues.back, 95, 62]);
        for (const h of hues.fans) k.push([h, 95, 65]);
        for (const h of hues.anemones) k.push([h, 100, 70]);
        for (const h of hues.jellies) { k.push([h, 90, 55]); k.push([h, 100, 75]); }
        k.push([hues.sparkle, 90, 65]); k.push([hues.plankton, 100, 70]);
        return k;
    };

    R.counts = () => ({ plankton: R.live(), fish: R.fish.length, jellies: R.jellies.length,
                        corals: R.corals.length + R.backCorals.length, fans: R.fans.length,
                        anemones: R.anemones.length, kelp: R.kelp.length });
    return R;
}
