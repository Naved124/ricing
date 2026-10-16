#version 440
// Into Paper: the old desktop is a page peeled from the bottom-right corner.
// The fold sweeps towards the top left; the part already lifted lies folded
// back over the page, showing the sheet's back (paper stock with the print
// faintly showing through), and both the fold and the flap cast a soft warm
// shadow, onto the new desktop and onto the page still lying flat.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 → 1
    float aspect;       // width / height
};
layout(binding = 1) uniform sampler2D source;

const vec3 stock = vec3(0.969, 0.961, 0.937);   // Paper's #f7f5ef
const vec3 umber = vec3(0.235, 0.176, 0.078);   // the shadow colour, #3c2d14

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 size = vec2(aspect, 1.0);
    vec2 p = uv * size;                          // square units, y down

    // the fold sweeps from the bottom-right corner, a little flatter than the diagonal
    vec2 corner = size;
    vec2 dir = normalize(vec2(-1.0, -0.72));
    float span = dot(-corner, dir) + 0.06;       // until the far corner is gone
    float t = progress * progress * (3.0 - 2.0 * progress);
    float fold = t * span;
    float s = dot(p - corner, dir);              // distance from the corner, along dir

    if (s < fold) {
        // the page has gone here: the new desktop, under a soft shadow by the fold
        float a = 0.30 * exp(-(fold - s) * 22.0) * smoothstep(0.0, 0.02, fold);
        fragColor = vec4(umber * a, a) * qt_Opacity;
        return;
    }

    // folding back over the fold line: this pixel shows the flap if its
    // mirror image is still on the page
    float over = s - fold;
    vec2 m = p - 2.0 * over * dir;
    vec2 outside = max(-m, vec2(0.0)) + max(m - size, vec2(0.0));
    bool onFlap = over < fold && max(outside.x, outside.y) <= 0.0;

    if (onFlap) {
        // the back of the sheet: stock, the print showing through mirrored,
        // fibres, darker in the crease and catching the light further out
        vec3 print = texture(source, m / size).rgb;
        float lum = dot(print, vec3(0.299, 0.587, 0.114));
        vec3 back = stock * mix(1.0, lum, 0.07);
        back *= 1.0 - 0.025 * hash(floor(p * 900.0));
        float crease = smoothstep(0.0, 0.12, over);
        float light = mix(0.80, 1.0, crease) - 0.05 * smoothstep(0.0, 0.8, fold - over);
        fragColor = vec4(back * light, 1.0) * qt_Opacity;
        return;
    }

    // the page still lying flat, shaded by the flap above it
    vec4 page = texture(source, uv);
    float gap = over < fold ? length(outside) : (over - fold);
    float shade = 0.28 * exp(-gap * 30.0) * smoothstep(0.0, 0.02, fold);
    fragColor = vec4(mix(page.rgb, umber, shade), 1.0) * page.a * qt_Opacity;
}
