#version 440
// Nacre wallpaper: a cold steel-to-lilac ground with vivid iridescent blooms
// and deeper ice/orchid accents drifting slowly over it, faint diagonal frost
// streaks, a fine crystalline grain, shell growth-lines in the lower-right
// corner, and a soft ripple where the desktop was clicked. The colour and the
// shapes are there so Hyprland's blur has something to frost.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 ground0;       // top-left
    vec4 ground1;       // bottom-right
    vec4 lilac;         // growth lines
    vec4 c0;            // blooms: the gradient stops, made vivid
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 c4;
    vec4 a0;            // accents: deeper ice and orchid
    vec4 a1;
    vec4 a2;
    vec2 resolution;
    float time;         // seconds, frozen while paused
    vec2 ripplePos;     // 0..1 uv of the last click
    float rippleAge;    // seconds since the click, < 0 when none
    float dark;         // Theme.k: 0 light, 1 dark (the colours above are already mixed)
};

vec3 bloomColor(int i) {
    if (i == 0) return c0.rgb;
    if (i == 1) return c1.rgb;
    if (i == 2) return c2.rgb;
    if (i == 3) return c3.rgb;
    return c4.rgb;
}

vec3 accentColor(int i) {
    if (i == 0) return a0.rgb;
    if (i == 1) return a1.rgb;
    return a2.rgb;
}

float blob(vec2 uv, vec2 c, float r) {
    float d = length(uv - c) / r;
    return exp(-d * d * 2.2);
}

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec2 hash2(vec2 p) {
    return vec2(hash(p), hash(p + 17.17));
}

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

// crystalline grain: distance to the nearest cell edge in a fine Voronoi
// pattern, so the grain has facets rather than looking like film noise
float crystal(vec2 px) {
    vec2 cell = floor(px), f = fract(px);
    float d1 = 8.0, d2 = 8.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 o = vec2(x, y);
            vec2 r = o + hash2(cell + o) - f;
            float d = dot(r, r);
            if (d < d1) { d2 = d1; d1 = d; }
            else if (d < d2) { d2 = d; }
        }
    }
    return sqrt(d2) - sqrt(d1);   // 0 on an edge
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = resolution.x / max(resolution.y, 1.0);
    vec2 p = vec2(uv.x * aspect, uv.y);

    // the ground: icy steel at the top-left, lilac towards the bottom-right
    float g = clamp(uv.y * 0.65 + uv.x * 0.35, 0.0, 1.0);
    vec3 col = mix(ground0.rgb, ground1.rgb, smoothstep(0.0, 1.0, g));

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

    // five vivid blooms on slow Lissajous paths, one per gradient stop
    float t = time * 0.03;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        vec2 c = vec2(
            (0.5 + 0.42 * sin(t * (0.9 + fi * 0.17) + fi * 1.9)) * aspect,
            0.5 + 0.38 * cos(t * (0.7 + fi * 0.13) + fi * 2.7));
        float w = blob(p, c, 0.30 + 0.05 * sin(t * 1.3 + fi));
        col = mix(col, bloomColor(i), w * 0.7);
    }

    // three deeper accents, smaller and slower, laid on like tinted glass
    // (multiplied), so their cores sit darker than the ground: depth
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        vec2 c = vec2(
            (0.5 + 0.40 * sin(t * (0.55 + fi * 0.11) + fi * 2.4 + 0.8)) * aspect,
            0.5 + 0.36 * cos(t * (0.45 + fi * 0.09) + fi * 1.7 + 2.1));
        float w = blob(p, c, 0.24 + 0.03 * sin(t * 0.9 + fi * 2.0));
        vec3 tint = accentColor(i) / max(ground0.rgb, vec3(0.2));
        vec3 tinted = col * pow(tint, vec3(1.8));
        col = mix(col, tinted, w);
    }

    // a cold sheen in the top-left corner, as if light falls on the ice there
    col = mix(col, vec3(0.97, 0.98, 1.0), 0.32 * smoothstep(0.75, 0.0, length(uv - vec2(0.0, 0.0))));

    // frost streaks: faint diagonal scratches, patchy, drifting with the blooms
    vec2 dir = normalize(vec2(1.0, -0.62));
    float along = dot(p, vec2(-dir.y, dir.x));
    float across = dot(p, dir);
    float streak = abs(fract(along * 38.0 + noise(vec2(across * 3.0, along * 6.0)) * 1.6) - 0.5);
    streak = (1.0 - smoothstep(0.0, 0.035, streak));
    float patchy = smoothstep(0.55, 0.85, noise(p * 2.2 + vec2(t * 0.2, 0.0)));
    col = mix(col, vec3(1.0), streak * patchy * 0.10);

    // crystalline grain, 2–3%: brighter facet edges, slightly darker cells
    float e = crystal(uv * resolution / 5.0);
    col += (1.0 - smoothstep(0.0, 0.12, e)) * 0.025 - 0.006;

    // growth lines: concentric arcs from the lower-right corner, very faint
    vec2 corner = vec2(aspect + 0.08, 1.12);
    float r = length(p - corner);
    float a = atan(p.y - corner.y, p.x - corner.x);
    float lines = abs(fract(r * 26.0 + 0.04 * sin(a * 9.0 + r * 4.0)) - 0.5);
    float lineMask = (1.0 - smoothstep(0.0, 0.06, lines)) * smoothstep(0.75, 0.15, r);
    col = mix(col, lilac.rgb, lineMask * 0.16);

    // the ripple ring itself catches a little iridescence
    vec3 irid = bloomColor(int(mod(floor(atan(p.y - rp.y, p.x - rp.x) * 0.8 + 5.0), 5.0)));
    col = mix(col, mix(irid, vec3(1.0), 0.4), ring * 0.35);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
