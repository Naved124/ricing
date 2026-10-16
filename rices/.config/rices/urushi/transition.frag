#version 440
// Into Urushi: the old desktop darkens like a lacquer lid closing, then the
// lid lifts away upward, its lower edge catching a line of gold.
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
    vec2 uv = qt_TexCoord0;

    // 0 → 0.35: darken to lacquer black
    float dark = smoothstep(0.0, 0.35, progress);
    // 0.3 → 1: lift (ease-in-out)
    float t = clamp((progress - 0.3) / 0.7, 0.0, 1.0);
    float lift = t * t * (3.0 - 2.0 * t) * 1.05;

    vec2 suv = vec2(uv.x, uv.y + lift);
    if (suv.y > 1.0) { fragColor = vec4(0.0); return; }   // already lifted past

    vec4 c = texture(source, suv);
    vec3 lacquer = vec3(0.043, 0.039, 0.035);
    c.rgb = mix(c.rgb, lacquer, dark * 0.96);

    // a lacquer sheen sweeping across the lid
    float sheen = exp(-pow((uv.x + uv.y * 0.4) - (0.2 + progress * 1.2), 2.0) * 40.0);
    c.rgb += vec3(0.25, 0.2, 0.12) * sheen * dark * (1.0 - t);

    // the gold rim on the lid's lower edge
    float edge = 1.0 - suv.y;                 // distance from the lid's bottom
    float gold = exp(-edge * edge * 9000.0) * step(0.001, lift);
    c.rgb = mix(c.rgb, vec3(0.788, 0.635, 0.29), gold);

    fragColor = vec4(c.rgb, 1.0) * qt_Opacity;
}
