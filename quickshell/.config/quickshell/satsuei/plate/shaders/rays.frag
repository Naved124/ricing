#version 440
// The pass's light shafts, worked out at an eighth of the screen's size (the
// soft map's; finer would cost 4× for nothing) and added by satsuei.frag: a radial blur toward the light source over the soft
// map (44 steps, each 0.962 of the last, only what's brighter than 0.58),
// times a slowly turning pattern of shafts, plus a faint glow near the light.
// Written a quarter strength so it fits in the texture; satsuei.frag takes
// it back up.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;
    vec2 img;
    vec2 light;
    vec2 par;
    float time;
    float mapLod;
};
layout(binding = 1) uniform sampler2D softMap;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
    vec2 f = qt_TexCoord0 * res;
    float s = max(res.x / img.x, res.y / img.y) * 1.04;
    vec2 uv = ((f - res * 0.5) / s + img * 0.5) / img + par;
    vec2 dir = (uv - light) / 44.0;
    vec2 q = uv;
    float il = 1.0, acc = 0.0;
    for (int i = 0; i < 44; i++) {
        q -= dir;
        acc += smoothstep(0.58, 0.98, luma(textureLod(softMap, q, mapLod * 1.3).rgb)) * il;
        il *= 0.962;
    }
    acc /= 44.0;
    vec2 v = (uv - light) * img;
    float a = atan(v.y, v.x);
    float sh = 0.5 + 0.5 * (0.6 * sin(a * 19.0 + time * 0.13) + 0.4 * sin(a * 7.0 - time * 0.09));
    float near = exp(-length(v) / img.y * 1.2);
    fragColor = vec4(vec3((acc * (0.45 + 0.9 * sh) * 1.9 + near * 0.06) * 0.25), 1.0);
}
