#version 440
// `rice mode` in Golden Gate: the frozen frame (the old mode) fades out over
// the new one in 450 ms, so nothing on screen repaints in stages.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 → 1
    float aspect;
    float dark;
    vec2 origin;
    vec4 tint;
    vec4 c0;
    vec4 c1;
    vec4 c2;
    vec4 c3;
    vec4 c4;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    fragColor = c * (1.0 - progress) * qt_Opacity;
}
