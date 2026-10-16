#version 440
// Fades the right edge of a texture to transparent (long titles, marquees).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float fadeStart;    // 0..1, where the fade begins
    float fadeLeft;     // 0..1, width of a fade on the left edge (0 = none)
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    float a = 1.0 - smoothstep(fadeStart, 1.0, qt_TexCoord0.x);
    if (fadeLeft > 0.0) a *= smoothstep(0.0, fadeLeft, qt_TexCoord0.x);
    fragColor = c * a * qt_Opacity;
}
