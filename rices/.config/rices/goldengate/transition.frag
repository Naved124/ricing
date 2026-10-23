#version 440
// Into Golden Gate: a lens of glass opens from the centre of the screen. The
// old frame bends at its rim (refraction with a slight chromatic split, a
// bright specular edge) and the new desktop shows through the clear middle.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 → 1
    float aspect;       // width / height
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
    float d = length(p);
    float maxD = length(vec2(aspect, 1.0)) * 0.5 + 0.2;
    // a spring: quick, then easing into place
    float t = 1.0 - pow(1.0 - progress, 3.0);
    float r = t * maxD;
    float rim = 0.12;
    // 0 inside the lens (the new desktop), 1 outside (the old frame)
    float outside = smoothstep(r - 0.01, r + 0.01, d);
    // the old frame bends toward the rim as it's pushed outward
    float band = clamp(1.0 - abs(d - r) / rim, 0.0, 1.0);
    vec2 dir = d > 0.0 ? p / d : vec2(0.0);
    vec2 bend = dir * band * band * 0.05 / vec2(aspect, 1.0);
    vec4 col;
    col.r = texture(source, uv - bend * 1.15).r;
    col.g = texture(source, uv - bend).g;
    col.b = texture(source, uv - bend * 0.85).b;
    col.a = texture(source, uv - bend).a;
    // the specular edge of the glass
    float edge = exp(-pow((d - r) / 0.006, 2.0)) * (1.0 - progress);
    col.rgb += edge * 0.6;
    float a = outside * (1.0 - smoothstep(0.85, 1.0, progress));
    fragColor = vec4(col.rgb, 1.0) * col.a * a * qt_Opacity;
}
