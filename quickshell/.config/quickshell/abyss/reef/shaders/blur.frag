#version 440
// One direction of the bloom's Gaussian (the mock's blur(3px) at a quarter of
// the scene's size): sigma 3 texels, out to 8 texels (normalised), nine bilinear taps.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf { mat4 qt_Matrix; float qt_Opacity; vec2 dir; };
layout(binding = 1) uniform sampler2D src;
void main() {
    // weights of sigma 3 at 0..8, folded in pairs onto linear taps
    const float w0 = 0.13357;
    const float w[4] = float[4](0.23331, 0.13593, 0.05138, 0.01259);
    const float o[4] = float[4](1.45843, 3.40398, 5.35181, 7.30294);
    vec4 s = texture(src, qt_TexCoord0) * w0;
    for (int i = 0; i < 4; i++) {
        s += texture(src, qt_TexCoord0 + dir * o[i]) * w[i];
        s += texture(src, qt_TexCoord0 - dir * o[i]) * w[i];
    }
    fragColor = s;
}
