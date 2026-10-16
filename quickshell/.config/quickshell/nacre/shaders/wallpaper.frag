#version 440
// Nacre wallpaper: slow iridescent blooms drifting over a pearl gradient,
// faint shell growth-lines in the lower-right corner, and a soft ripple where
// the desktop was clicked.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 pearl;
    vec4 shell;
    vec4 lilac;
    vec4 c0;
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 c4;
    vec2 resolution;
    float time;         // seconds, frozen while paused
    vec2 ripplePos;     // 0..1 uv of the last click
    float rippleAge;    // seconds since the click, < 0 when none
};

vec3 stop(int i) {
    if (i == 0) return c0.rgb;
    if (i == 1) return c1.rgb;
    if (i == 2) return c2.rgb;
    if (i == 3) return c3.rgb;
    return c4.rgb;
}

float blob(vec2 uv, vec2 c, float r) {
    float d = length(uv - c) / r;
    return exp(-d * d * 2.2);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = resolution.x / max(resolution.y, 1.0);
    vec2 p = vec2(uv.x * aspect, uv.y);

    // the pearl ground: light at the top-left, a breath of shell lower down
    vec3 col = mix(pearl.rgb, shell.rgb, smoothstep(0.0, 1.4, uv.y * 0.8 + uv.x * 0.35));

    // a ripple bends the blooms outward for a moment
    vec2 rp = vec2(ripplePos.x * aspect, ripplePos.y);
    float ring = 0.0;
    if (rippleAge >= 0.0) {
        float radius = rippleAge * 0.45;
        float dist = length(p - rp);
        float fade = exp(-rippleAge * 1.6);
        ring = exp(-pow((dist - radius) * 28.0, 2.0)) * fade;
        p += normalize(p - rp + 1e-4) * ring * 0.015;
    }

    // five blooms on slow Lissajous paths, one per gradient stop
    float t = time * 0.035;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        vec2 c = vec2(
            (0.5 + 0.42 * sin(t * (0.9 + fi * 0.17) + fi * 1.9)) * aspect,
            0.5 + 0.38 * cos(t * (0.7 + fi * 0.13) + fi * 2.7));
        float w = blob(p, c, 0.32 + 0.05 * sin(t * 1.3 + fi));
        col = mix(col, stop(i), w * 0.42);
    }

    // growth lines: concentric arcs from the lower-right corner, very faint
    vec2 corner = vec2(aspect + 0.08, 1.12);
    float r = length(p - corner);
    float a = atan(p.y - corner.y, p.x - corner.x);
    float lines = abs(fract(r * 26.0 + 0.04 * sin(a * 9.0 + r * 4.0)) - 0.5);
    float lineMask = (1.0 - smoothstep(0.0, 0.06, lines)) * smoothstep(0.75, 0.15, r);
    col = mix(col, lilac.rgb, lineMask * 0.16);

    // the ripple ring itself catches a little iridescence
    vec3 irid = stop(int(mod(floor(atan(p.y - rp.y, p.x - rp.x) * 0.8 + 5.0), 5.0)));
    col = mix(col, mix(irid, vec3(1.0), 0.4), ring * 0.35);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
