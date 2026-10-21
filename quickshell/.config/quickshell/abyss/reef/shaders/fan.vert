#version 440
// A sea fan, drawn once at rest, bent here as the mock bends it: every point
// turns about the fan's foot by bend × u², u how far along its ray it is
// (the rays' lengths vary across the fan), so the rim sways and the foot
// holds (reef.js fanRay() puts the tips' glows on the same rim).
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 origin;       // the texture's corner, world px
    float sceneScale;
    vec2 foot;         // world px
    float len;         // the longest ray, world px
    float bend;        // reef.js fanBend(): its sway and the current
    float excite;      // 1 when touched, fading
};
out gl_PerVertex { vec4 gl_Position; };
void main() {
    vec2 w = origin + qt_Vertex.xy / sceneScale;
    vec2 rel = w - foot;
    float rho = length(rel);
    float phi = atan(rel.y, rel.x);
    float rayLen = len * (0.78 + 0.22 * cos((phi + 1.5707963) / 1.7 * 2.4));
    float u = min(rho / max(rayLen, 1.0), 1.3);
    float a = phi + bend * u * u;
    vec2 moved = foot + rho * vec2(cos(a), sin(a));
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = qt_Matrix * vec4((moved - origin) * sceneScale, 0.0, 1.0);
}
