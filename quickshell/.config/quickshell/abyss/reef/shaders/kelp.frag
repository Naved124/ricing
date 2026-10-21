#version 440
// Kelp: a dark silhouette over the ridge, its edges smoothed across a pixel.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 foot;
    float sceneScale;
    float count;
    float seg;
    float girth;
    float ph;
    float wt;
    float flow;
    vec4 color;
};
void main() {
    float side = abs(qt_TexCoord0.x);
    float aa = max(fwidth(qt_TexCoord0.x) * 1.2, 1e-3);
    fragColor = color * (1.0 - smoothstep(1.0 - aa, 1.0, side)) * qt_Opacity;
}
