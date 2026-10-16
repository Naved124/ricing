#version 440
// A small pearl: lit from the top-left, matte or glossy, with an optional
// iridescent rim. Used for workspace dots, the tray pearl and power buttons.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 base;      // body colour
    vec4 shade;     // edge colour
    vec4 c0;
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 c4;
    float gloss;    // 0 matte .. 1 glossy highlight
    float iri;      // 0 none .. 1 full iridescent rim
    float angle;
};

vec3 conic(float t) {
    t = fract(t) * 5.0;
    if (t < 1.0) return mix(c0.rgb, c1.rgb, t);
    if (t < 2.0) return mix(c1.rgb, c2.rgb, t - 1.0);
    if (t < 3.0) return mix(c2.rgb, c3.rgb, t - 2.0);
    if (t < 4.0) return mix(c3.rgb, c4.rgb, t - 3.0);
    return mix(c4.rgb, c0.rgb, t - 4.0);
}

void main() {
    vec2 p = qt_TexCoord0 * 2.0 - 1.0;
    float d = length(p);
    float aa = fwidth(d) * 1.5;
    float alpha = 1.0 - smoothstep(1.0 - aa, 1.0, d);

    float lit = clamp(1.0 - length(p + vec2(0.35, 0.4)) / 1.4, 0.0, 1.0);
    vec3 col = mix(shade.rgb, base.rgb, mix(0.55, 1.0, lit));

    float rim = pow(clamp((d - 0.3) / 0.7, 0.0, 1.0), 1.5);
    vec3 irid = conic((atan(p.y, p.x) + angle) / 6.2831853 + d * 0.2);
    col = mix(col, irid, rim * iri * 0.9);

    float spec = pow(clamp(1.0 - length(p + vec2(0.38, 0.42)) / 0.34, 0.0, 1.0), 2.0);
    col = mix(col, vec3(1.0), spec * gloss * 0.85);

    fragColor = vec4(col, 1.0) * alpha * qt_Opacity;
}
