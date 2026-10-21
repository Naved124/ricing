#version 440
// A coral's light, added to the scene (alpha 0: it brightens what's behind,
// like the mock's 'lighter'), brighter while touched.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 origin;
    float sceneScale;
    vec2 foot;
    float tall;
    float swing;
    float lean;
    float ph;
    float wt;
    float flow;
    float gain;
};
layout(binding = 1) uniform sampler2D src;
void main() {
    vec4 c = texture(src, qt_TexCoord0);
    fragColor = vec4(c.rgb * gain, 0.0) * qt_Opacity;
}
