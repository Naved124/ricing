#version 440
// `rice mode` in Nacre: the pearl turns. A soft iridescent ring, 2–3 px, in
// the target mode's gradient (c0–c4) grows from the bar's orb with the new
// mode inside it; a faint glint (tint) travels round it as it grows. The
// overlay holds the old frame; the new one is underneath.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 → 1, eased on Nacre's bloom curve
    float aspect;       // width / height
    float dark;
    vec2 origin;        // the orb, in the output's 0..1 coordinates
    vec4 tint;          // the glint, alpha included (premultiplied, as Qt passes colours)
    vec4 c0;
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 c4;
};
layout(binding = 1) uniform sampler2D source;

vec3 orient(float t) {
    t = fract(t) * 5.0;
    int i = int(floor(t));
    float f = fract(t);
    vec3 a = i == 0 ? c0.rgb : i == 1 ? c1.rgb : i == 2 ? c2.rgb : i == 3 ? c3.rgb : c4.rgb;
    vec3 b = i == 0 ? c1.rgb : i == 1 ? c2.rgb : i == 2 ? c3.rgb : i == 3 ? c4.rgb : c0.rgb;
    return mix(a, b, f);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 s = vec2(aspect, 1.0);
    vec2 p = (uv - origin) * s;
    float d = length(p);
    float far = max(max(length(origin * s), length((vec2(1.0, 0.0) - origin) * s)),
                    max(length((vec2(0.0, 1.0) - origin) * s), length((vec2(1.0) - origin) * s)));
    float px = 1.0 / 1080.0;
    float e = clamp(progress, 0.0, 1.0);
    float front = e * (far + 12.0 * px);

    // the old frame is gone inside the ring
    float a = smoothstep(front - 1.5 * px, front + 1.5 * px, d);

    // the ring: a sharp 2–3 px core and a faint halo
    float x = d - front;
    float ring = exp(-pow(x / (1.6 * px), 2.0)) + 0.3 * exp(-pow(x / (9.0 * px), 2.0));
    ring *= 1.0 - smoothstep(0.85, 1.0, progress);
    float ang = atan(p.y, p.x) / 6.28318;
    vec3 col = orient(ang * 2.0 + progress * 0.6);
    // the glint, a quarter turn ahead of the colours, sweeping round
    float g = fract(ang - progress * 1.4);
    float glint = exp(-pow(min(g, 1.0 - g) / 0.035, 2.0));
    col = mix(col, tint.a > 0.0 ? tint.rgb / tint.a : col, glint * tint.a);
    float ra = clamp(ring, 0.0, 1.0);

    vec4 c = texture(source, uv);
    // the ring lies over the old frame's soft edge
    vec3 rgb = col * ra + c.rgb * a * (1.0 - ra);
    fragColor = vec4(rgb, ra + a * (1.0 - ra)) * qt_Opacity;
}
