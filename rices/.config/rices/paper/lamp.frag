#version 440
// `rice mode` in Paper: the lamp clicks. Going dark, the night closes in
// from the screen's edges to the lamp and ends as its pool; going light, the
// pool grows from the lamp until the room is lit. The edge is a soft warm
// band (tint) that warms the old frame just inside it, like a room light
// dimming. The overlay holds the old frame; the new one is underneath.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 → 1, eased (Paper's drop overshoots a little)
    float aspect;       // width / height
    float dark;         // 1 going dark, 0 going light
    vec2 origin;        // the lamp, in the output's 0..1 coordinates
    vec4 tint;          // the warm edge, alpha included (premultiplied, as Qt passes colours)
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 s = vec2(aspect, 1.0);
    float d = length((uv - origin) * s);
    // the farthest corner from the lamp
    float far = max(max(length(origin * s), length((vec2(1.0, 0.0) - origin) * s)),
                    max(length((vec2(0.0, 1.0) - origin) * s), length((vec2(1.0) - origin) * s)));
    float pool = 0.45 * aspect;          // the dark wallpaper's lamp pool
    float feather = 0.037;               // about 40 px at 1080
    float e = clamp(progress, 0.0, 1.1);

    float r, a;
    if (dark > 0.5) {
        // the lit room shrinks to the pool, then the pool's old light goes
        r = mix(far + feather, pool, min(e, 1.0));
        a = 1.0 - smoothstep(r - feather, r + feather, d);
        a *= 1.0 - smoothstep(0.72, 1.0, progress);
    } else {
        // the pool grows from the lamp until nothing of the night is left
        r = mix(pool * 0.25, far + 2.0 * feather, e);
        a = smoothstep(r - feather, r + feather, d);
    }

    vec3 amber = tint.a > 0.0 ? tint.rgb / tint.a : vec3(0.0);
    vec4 c = texture(source, uv);
    // warmth just inside the edge, on whichever side the old frame is
    float inside = dark > 0.5 ? smoothstep(r - 5.0 * feather, r, d) * step(d, r)
                              : smoothstep(r + 5.0 * feather, r, d) * step(r, d);
    c.rgb = mix(c.rgb, amber, inside * tint.a * 0.6);

    // the band itself, laid over the soft edge (where the old frame is half
    // gone) so it reads warm rather than grey; it fades as the transition settles
    float band = exp(-pow((d - r) / feather, 2.0)) * min(1.0, tint.a * 1.6)
               * (1.0 - smoothstep(0.85, 1.0, progress));
    vec3 rgb = amber * band + c.rgb * a * (1.0 - band);
    fragColor = vec4(rgb, band + a * (1.0 - band)) * qt_Opacity;
}
