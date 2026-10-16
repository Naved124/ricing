#version 440
// The fallback dissolve: the old frame simply fades, with a slight lift.
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
    vec4 c = texture(source, qt_TexCoord0);
    float a = 1.0 - smoothstep(0.0, 1.0, progress);
    fragColor = c * a * qt_Opacity;
}
