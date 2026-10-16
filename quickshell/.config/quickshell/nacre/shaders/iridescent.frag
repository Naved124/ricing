#version 440
// Rotating conic gradient through the five iridescent stops (closed loop),
// clipped to a rounded rectangle. ring > 0 draws only a border of that width.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 c0;
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 c4;
    vec2 size;      // item size in px
    float radius;   // corner radius in px
    float ring;     // 0 = filled, otherwise border width in px
    float angle;    // rotation in radians
    float sheen;    // 0..1 extra white highlight toward the top
};

vec3 conic(float t) {
    t = fract(t) * 5.0;
    if (t < 1.0) return mix(c0.rgb, c1.rgb, t);
    if (t < 2.0) return mix(c1.rgb, c2.rgb, t - 1.0);
    if (t < 3.0) return mix(c2.rgb, c3.rgb, t - 2.0);
    if (t < 4.0) return mix(c3.rgb, c4.rgb, t - 3.0);
    return mix(c4.rgb, c0.rgb, t - 4.0);
}

float roundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * size;
    float a = atan(p.y, p.x) + angle;
    vec3 col = conic(a / 6.2831853);
    col = mix(col, vec3(1.0), sheen * clamp(0.5 - qt_TexCoord0.y, 0.0, 0.5));

    float d = roundedBox(p, size * 0.5, min(radius, min(size.x, size.y) * 0.5));
    float alpha = clamp(0.5 - d, 0.0, 1.0);
    if (ring > 0.0) alpha *= clamp(d + ring + 0.5, 0.0, 1.0);
    fragColor = vec4(col, 1.0) * alpha * qt_Opacity;
}
