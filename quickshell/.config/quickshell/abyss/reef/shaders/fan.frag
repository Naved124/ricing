#version 440
// A sea fan's lattice, added to the scene; touched, it brightens and pales
// (the mock's lightness 50 → 65% and alpha .3 → .7).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 origin;
    float sceneScale;
    vec2 foot;
    float len;
    float bend;
    float excite;
};
layout(binding = 1) uniform sampler2D src;
void main() {
    vec4 c = texture(src, qt_TexCoord0);
    vec3 rgb = (c.rgb + (vec3(c.a) - c.rgb) * 0.3 * excite) * (1.0 + 1.33 * excite);
    fragColor = vec4(rgb, 0.0) * qt_Opacity;
}
