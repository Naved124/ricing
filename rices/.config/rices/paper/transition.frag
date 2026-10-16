#version 440
// Into Paper: the old desktop is peeled from the bottom-right corner like a
// page, its curled back showing warm paper stock, a soft shadow beneath.
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
    vec2 p = vec2(uv.x * aspect, uv.y);

    // the fold line runs perpendicular to this direction, sweeping from the
    // bottom-right corner to past the top-left
    vec2 dir = normalize(vec2(-aspect, -1.0) * vec2(1.0, 1.0));
    vec2 corner = vec2(aspect, 1.0);
    float span = dot(vec2(0.0) - corner, dir) + 0.4;
    float t = progress * progress * (3.0 - 2.0 * progress);
    float fold = t * span;                    // fold distance from the corner
    float s = dot(p - corner, dir);           // this pixel's distance from the corner along dir

    float radius = 0.08;
    vec4 stock = vec4(0.973, 0.957, 0.918, 1.0);

    if (s > fold + radius) {
        // untouched page; a shadow from the curl just ahead of the fold
        vec4 c = texture(source, uv);
        float sh = exp(-(s - fold - radius) * 18.0) * 0.35 * step(0.001, t);
        fragColor = vec4(c.rgb * (1.0 - sh), 1.0) * qt_Opacity;
        return;
    }
    if (s > fold) {
        // on the curl: the page bends over the cylinder; show its back
        float k = (s - fold) / radius;        // 0..1 over the curl
        float light = 0.8 + 0.2 * sin(k * 3.14159);
        fragColor = vec4(stock.rgb * light, 1.0) * qt_Opacity;
        return;
    }
    // behind the fold the page has gone: the new desktop shows
    fragColor = vec4(0.0);
}
