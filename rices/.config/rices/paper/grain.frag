#version 300 es
// Paper grain: Hyprland's decoration:screen_shader while Paper is active.
//
// Static paper fibres laid over the whole screen, at most ±2.5% of the
// light, as a multiply. The pattern hangs off the pixel grid, never off
// time: there is no `time` uniform, so Hyprland keeps damage tracking and
// only redraws what changed. A screen shader does stop direct scanout,
// which fullscreen games and video use to skip compositing, so
// `rice grain off` (Super+Shift+G) turns it off.
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// noise stretched along one direction: long thin fibres lying that way
float fibres(vec2 px, vec2 dir, float along, float across) {
    vec2 n = vec2(-dir.y, dir.x);
    return noise(vec2(dot(px, dir) * along, dot(px, n) * across));
}

void main() {
    vec4 c = texture(tex, v_texcoord);
    vec2 px = gl_FragCoord.xy;

    // two crossing layers of fibres, a little cloud, and a fine tooth
    float g = fibres(px, vec2(0.94, 0.34), 0.06, 0.85) * 0.38
            + fibres(px, vec2(0.17, -0.98), 0.05, 0.75) * 0.30
            + noise(px * 0.012) * 0.17
            + hash(floor(px)) * 0.15;

    // multiply by 0.975 … 1.025
    float k = 1.0 + (g - 0.5) * 0.05;
    fragColor = vec4(min(c.rgb * k, vec3(1.0)), c.a);
}
