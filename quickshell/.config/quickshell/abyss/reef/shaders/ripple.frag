#version 440
// One step of the reef's ripple field, the mock's rule on the GPU:
//   next = ((left + right + up + down) / 2 - before) * 0.982
// The state texture holds the height now in r and the step before in g, one
// texel per cell; the border stays still. Drops ("touches") land on the
// first step of a frame: up to 8 of them, x, y and radius in cells, as
// `h -= amp * exp(-2 d²)` within two radii, d in radii (reef.js drop()).
// `on` 0 passes the state through, so a chain of four passes can take one to
// four steps a frame.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 cells;        // gw, gh
    float on;          // step (1) or pass through (0)
    float nd;          // drops this pass applies
    vec4 d0; vec4 d1; vec4 d2; vec4 d3; vec4 d4; vec4 d5; vec4 d6; vec4 d7;
};
layout(binding = 1) uniform sampler2D src;

float dropOne(vec2 c, vec4 d) {
    float q = dot(c - d.xy, c - d.xy) / (d.w * d.w);
    return q > 4.0 ? 0.0 : d.z * exp(-q * 2.0);
}
float drops(vec2 c) {
    if (nd < 0.5) return 0.0;
    float s = dropOne(c, d0);
    if (nd > 1.5) s += dropOne(c, d1);
    if (nd > 2.5) s += dropOne(c, d2);
    if (nd > 3.5) s += dropOne(c, d3);
    if (nd > 4.5) s += dropOne(c, d4);
    if (nd > 5.5) s += dropOne(c, d5);
    if (nd > 6.5) s += dropOne(c, d6);
    if (nd > 7.5) s += dropOne(c, d7);
    return s;
}
bool edge(vec2 c) { return c.x < 0.5 || c.y < 0.5 || c.x > cells.x - 1.5 || c.y > cells.y - 1.5; }
// the height at a cell, with this pass's drops (none on the border)
float h(vec2 c) {
    if (edge(c)) return 0.0;
    return texture(src, (c + 0.5) / cells).r - drops(c);
}

void main() {
    vec2 c = floor(qt_TexCoord0 * cells);
    if (edge(c)) { fragColor = vec4(0.0, 0.0, 0.0, 1.0); return; }
    vec2 st = texture(src, (c + 0.5) / cells).rg;
    if (on < 0.5) { fragColor = vec4(st, 0.0, 1.0); return; }
    float now = st.r - drops(c);
    float next = ((h(c + vec2(-1.0, 0.0)) + h(c + vec2(1.0, 0.0)) + h(c + vec2(0.0, -1.0)) + h(c + vec2(0.0, 1.0))) * 0.5 - st.g) * 0.982;
    fragColor = vec4(next, now, 0.0, 1.0);
}
