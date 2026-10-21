#version 440
// One kelp stalk, built here from its segments the way the mock strokes them:
// each segment turns from upright by sin(time + phase + i × .3) × .22 × u and
// the current, u how far up it is, and narrows to 45% at the top, which is
// rounded. The mesh is a strip, x across it and y from the tip (0) to the
// foot (1).
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 foot;         // world px
    float sceneScale;
    float count;       // segments
    float seg;         // a segment's length, world px
    float girth;       // at the foot, world px
    float ph;
    float wt;          // time × 0.5 (× 0.45 with reduced motion)
    float flow;
    vec4 color;        // premultiplied
};
out gl_PerVertex { vec4 gl_Position; };
void main() {
    float side = qt_MultiTexCoord0.x * 2.0 - 1.0;
    float lastHalf = girth * (1.0 - (count - 1.0) / count * 0.55) * 0.5;
    float cap = lastHalf / seg;                       // the round tip, in segments
    float along = (1.0 - qt_MultiTexCoord0.y) * (count + cap);
    vec2 p = foot;
    float ang = -1.5707963, u = 0.0;
    for (int i = 0; i < 32; i++) {
        float fi = float(i);
        if (fi >= count || fi >= along) break;
        u = fi / count;
        ang = -1.5707963 + sin(wt + ph + fi * 0.3) * 0.22 * u + flow * 0.07 * u;
        p += vec2(cos(ang), sin(ang)) * seg * clamp(along - fi, 0.0, 1.0);
    }
    float hw = girth * (1.0 - u * 0.55) * 0.5;
    if (along > count) {
        float k = clamp((along - count) / cap, 0.0, 1.0);
        p += vec2(cos(ang), sin(ang)) * lastHalf * k;
        hw *= sqrt(max(0.0, 1.0 - k * k));
    }
    p += vec2(-sin(ang), cos(ang)) * hw * side;
    qt_TexCoord0 = vec2(side, qt_MultiTexCoord0.y);
    gl_Position = qt_Matrix * vec4(p * sceneScale, 0.0, 1.0);
}
