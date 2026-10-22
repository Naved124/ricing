#version 440
// A soft round glow, the reef's sprite() falloff: full at the centre, .55 at
// 18% out, .12 at half, nothing at the edge, in one colour. `add` 1 adds
// its light (alpha 0) instead of laying it over.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;         // premultiplied
    float add;
};
void main() {
    float d = length(qt_TexCoord0 - 0.5) * 2.0;
    float a = d < 0.18 ? mix(1.0, 0.55, d / 0.18)
            : d < 0.5 ? mix(0.55, 0.12, (d - 0.18) / 0.32)
            : d < 1.0 ? mix(0.12, 0.0, (d - 0.5) / 0.5) : 0.0;
    vec4 c = tint * a * qt_Opacity;
    fragColor = vec4(c.rgb, c.a * (1.0 - add));
}
