.pragma library

// SVG path data for the characters' shapes, on the rig's 120 × 160 canvas
// (the mock's viewBox), so every part is one PathSvg.

function ell(cx, cy, rx, ry) {
    return `M ${cx - rx} ${cy} a ${rx} ${ry} 0 1 0 ${2 * rx} 0 a ${rx} ${ry} 0 1 0 ${-2 * rx} 0 Z`;
}

function circ(cx, cy, r) {
    return ell(cx, cy, r, r);
}

function rr(x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    return `M ${x + r} ${y} h ${w - 2 * r} a ${r} ${r} 0 0 1 ${r} ${r} v ${h - 2 * r} a ${r} ${r} 0 0 1 ${-r} ${r}`
         + ` h ${-(w - 2 * r)} a ${r} ${r} 0 0 1 ${-r} ${-r} v ${-(h - 2 * r)} a ${r} ${r} 0 0 1 ${r} ${-r} Z`;
}
