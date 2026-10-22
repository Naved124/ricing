#version 440
// Satsuei's compositing pass, the mock's (docs/satsuei/mock.html): the plate
// gets its light without being repainted. In order:
//   diffusion   the soft map screen-blended over it (0.22)
//   bloom       the bloom and soft maps where they're bright (smoothstep
//               0.5 → 0.96 on luminance), added (0.36)
//   rays        shafts from the light source; rays.frag works them out at an
//               eighth of the size, this adds them in the ray colour
//   motes       three layers of specks on a hashed grid in screen space,
//               drifting up, swaying, twinkling; shown where the bloom map is
//               bright and in a cone around the light
//   grade       the hour's multiply, then lift, then saturation (Grade.qml)
//   then the brightness slider (expo), a soft vignette and film grain.
// Inside the windows (frostMap) the plate itself is the soft map: frosted
// glass behind every see-through window, with the pass on or off.
// `pass` mixes the whole of it over the raw plate (Compositing off, hold to
// compare); every effect has its own 0–1 that the shell eases.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;          // the output, px
    vec2 img;          // the plate, px
    vec2 light;        // the light source on the plate, 0–1
    vec2 par;          // parallax, a fraction of the plate (at most 0.006)
    float time;
    float bloom;
    float rays;
    float motes;
    float grain;
    float grade;
    float pass;
    float expo;
    float sat;
    float rayAmt;
    float mapLod;      // 0 with the blur maps; a preview samples the plate's mips
    float seed;        // the grain's seed, shared with the characters
    float frost;       // 0–1: the plate blurred inside the windows
    vec3 mul;
    vec3 lift;
    vec3 rayCol;
};
layout(binding = 1) uniform sampler2D plate;
layout(binding = 2) uniform sampler2D bloomMap;   // 1/4 size, heavy blur
layout(binding = 3) uniform sampler2D softMap;    // 1/8 size, heavier
layout(binding = 4) uniform sampler2D rayMap;     // rays.frag's, an eighth of the screen
layout(binding = 5) uniform sampler2D frostMap;   // the windows' shapes, a quarter of the screen

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
// four at once for a mote's cell: is there one, where, how big
vec4 h42(vec2 p) {
    vec4 q = fract(p.xyxy * vec4(0.1031, 0.1030, 0.0973, 0.1099) + vec4(0.0, 0.0, 0.37, 0.71));
    q += dot(q, q.wzxy + 33.33);
    return fract((q.xxyz + q.yzzw) * q.zywx);
}

void main() {
    vec2 f = qt_TexCoord0 * res;
    float s = max(res.x / img.x, res.y / img.y) * 1.04;      // cover, 4% over for the parallax
    vec2 uv = ((f - res * 0.5) / s + img * 0.5) / img + par;

    vec3 raw = texture(plate, uv).rgb;
    vec3 d = textureLod(softMap, uv, mapLod * 1.2).rgb;
    vec3 q = textureLod(bloomMap, uv, mapLod).rgb;
    if (frost > 0.001)
        raw = mix(raw, mix(q, d, 0.6), texture(frostMap, qt_TexCoord0).a * frost);
    vec3 c = raw;
    if (bloom > 0.001) {
        c = mix(c, 1.0 - (1.0 - c) * (1.0 - d), 0.22 * bloom);
        // the mock sums three mip levels (weights .45, .75, 1.05); the two maps stand in
        vec3 b = q * smoothstep(0.5, 0.96, luma(q)) * 1.2 + d * smoothstep(0.5, 0.96, luma(d)) * 1.05;
        b *= 1.6;
        c += b * 0.36 * bloom;
    }
    if (rays > 0.001)
        c += rayCol * texture(rayMap, qt_TexCoord0).r * 4.0 * rays * rayAmt;
    if (motes > 0.001) {
        float m = 0.0;
        for (int k = 0; k < 3; k++) {
            float fk = float(k), sz = 46.0 + fk * 36.0;
            vec2 g = f / sz;
            g.y += time * (0.04 + 0.025 * fk);                      // up the screen
            g.x += sin(time * 0.17 + fk * 2.0) * 0.35;
            vec2 id = floor(g), fr = fract(g);
            vec4 r = h42(id + fk * 7.13);
            if (r.x > 0.5) {
                vec2 pp = 0.2 + 0.6 * r.yz;
                pp += 0.12 * vec2(sin(time * 0.6 + r.x * 20.0), cos(time * 0.45 + r.x * 13.0));
                float dd = length((fr - pp) * sz);
                float rad = 0.8 + 1.8 * r.w + fk * 0.7;
                float tw = 0.55 + 0.45 * sin(time * (0.8 + r.x * 1.6) + r.x * 40.0);
                m += smoothstep(rad, 0.0, dd) * tw * (1.0 - fk * 0.18);
            }
        }
        float beam = smoothstep(0.32, 0.85, luma(d));
        vec2 v = (uv - light) * img;
        float cone = exp(-length(v) / img.y * 1.6);
        c += mix(vec3(1.0), rayCol, 0.6) * m * (beam * 0.75 + cone * 0.6 + 0.08) * motes;
    }
    vec3 g = c * mul + lift;
    g = mix(vec3(luma(g)), g, sat);
    c = mix(c, g, grade);
    vec2 cc = f / res - 0.5;
    c *= 1.0 - 0.42 * dot(cc, cc);
    if (grain > 0.001)
        c += (h21(f * 0.731 + fract(time * 7.3 + seed) * 91.0) - 0.5) * 0.07 * grain;
    c = mix(raw, c, pass) * expo;
    fragColor = vec4(c, 1.0) * qt_Opacity;
}
