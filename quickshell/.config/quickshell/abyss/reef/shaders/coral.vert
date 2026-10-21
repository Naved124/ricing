#version 440
// A coral, drawn once at rest into a texture, swayed here: it turns about its
// foot, more the higher up, by its own two phases and the current (the same
// as reef.js coralSway(), which moves the tips' glows to match).
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 origin;       // the texture's corner, world px
    float sceneScale;  // scene px per world px
    vec2 foot;         // where it grows from, world px
    float tall;        // foot to top, world px
    float swing;       // how far the top sways, px
    float lean;        // how far the current pushes it, px per unit of flow
    float ph;          // its phase
    float wt;          // time × 0.85 (× 0.45 with reduced motion)
    float flow;        // the current (a workspace switch)
    float gain;        // brighter when touched
};
out gl_PerVertex { vec4 gl_Position; };
void main() {
    vec2 w = origin + qt_Vertex.xy / sceneScale;
    float hn = clamp((foot.y - w.y) / tall, 0.0, 1.0);
    float s = 0.75 * sin(wt + ph + w.x * 0.004) + 0.25 * sin(wt * 1.37 + ph * 1.9 + hn * 2.4);
    float th = (swing * s + lean * flow) / tall * hn;
    vec2 d = vec2(th * (foot.y - w.y), 2.0 * th * (w.x - foot.x));
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * vec4(qt_Vertex.xy + d * sceneScale, 0.0, 1.0);
}
