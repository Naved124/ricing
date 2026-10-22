#version 440
// SceneMatch: a custom character drawn into the plate's light, so a GIF
// doesn't sit on the desktop like a sticker (chars/SceneMatch.qml).
//   · recolour: up to four rules; a pixel whose hue and chroma (OKLab's a, b)
//     lie within `tol` of a rule's `from` takes the target's hue and chroma,
//     its lightness kept relative to the source's, with a smooth falloff;
//     pixels near a `protect` colour never move
//   · ambient: the plate's grade (multiply, lift, saturation, exposure)
//   · rim: where the character is opaque but a step toward the light is
//     not, the light's colour
//   · outline: a 1.5 px edge dilated from the alpha, in the glass tint
//   · grain: the plate's film grain, when it's on
// Colours come in premultiplied; the work is done on straight colour.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 from0; vec4 from1; vec4 from2; vec4 from3;     // rgb, a = in use
    vec4 to0; vec4 to1; vec4 to2; vec4 to3;
    vec4 tol;                                           // per rule
    vec4 strength;
    vec4 prot0; vec4 prot1; vec4 prot2; vec4 prot3;     // rgb, a = in use
    vec4 mul;                                           // the grade
    vec4 lift;
    float sat;
    float expo;
    float ambient;
    float rim;
    vec4 rimCol;
    vec2 lightDir;                                      // toward the light, y down
    vec2 texel;                                         // one px in uv
    float outline;
    vec4 outlineCol;
    float grain;
    float seed;
};
layout(binding = 1) uniform sampler2D source;

vec3 toLinear(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 toSrgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(max(c, 0.0), vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

vec3 oklab(vec3 srgb) {
    vec3 c = toLinear(clamp(srgb, 0.0, 1.0));
    vec3 lms = vec3(0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b,
                    0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b,
                    0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b);
    lms = sign(lms) * pow(abs(lms), vec3(1.0 / 3.0));
    return vec3(0.2104542553 * lms.x + 0.7936177850 * lms.y - 0.0040720468 * lms.z,
                1.9779984951 * lms.x - 2.4285922050 * lms.y + 0.4505937099 * lms.z,
                0.0259040371 * lms.x + 0.7827717662 * lms.y - 0.8086757660 * lms.z);
}
vec3 srgbOf(vec3 lab) {
    vec3 lms = vec3(lab.x + 0.3963377774 * lab.y + 0.2158037573 * lab.z,
                    lab.x - 0.1055613458 * lab.y - 0.0638541728 * lab.z,
                    lab.x - 0.0894841775 * lab.y - 1.2914855480 * lab.z);
    lms = lms * lms * lms;
    vec3 c = vec3( 4.0767416621 * lms.x - 3.3077115913 * lms.y + 0.2309699292 * lms.z,
                  -1.2684380046 * lms.x + 2.6097574011 * lms.y - 0.3413193965 * lms.z,
                  -0.0041960863 * lms.x - 0.7034186147 * lms.y + 1.7076147010 * lms.z);
    return toSrgb(clamp(c, 0.0, 1.0));
}

// how far a rule reaches this pixel (0–1), and what it turns it into
float reach(vec3 lab, vec4 from, float t, float s) {
    if (from.a < 0.5) return 0.0;
    float d = length(lab.yz - oklab(from.rgb).yz);
    return (1.0 - smoothstep(t * 0.5, t, d)) * s;
}
vec3 turned(vec3 lab, vec4 from, vec4 to) {
    vec3 f = oklab(from.rgb), t = oklab(to.rgb);
    float l = clamp(lab.x * t.x / max(f.x, 0.05), 0.0, 1.0);
    return vec3(mix(lab.x, l, 0.75), t.yz + (lab.yz - f.yz));
}
float near(vec3 lab, vec4 p) { return p.a < 0.5 ? 1.0 : smoothstep(0.035, 0.08, length(lab - oklab(p.rgb))); }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 s = texture(source, uv);
    float a = s.a;
    vec3 c = a > 0.001 ? s.rgb / a : vec3(0.0);

    if (a > 0.001) {
        // ── recolour ──────────────────────────────────────────────────────
        vec3 lab = oklab(c);
        float keep = near(lab, prot0) * near(lab, prot1) * near(lab, prot2) * near(lab, prot3);
        float w0 = reach(lab, from0, tol.x, strength.x), w1 = reach(lab, from1, tol.y, strength.y);
        float w2 = reach(lab, from2, tol.z, strength.z), w3 = reach(lab, from3, tol.w, strength.w);
        float w = max(max(w0, w1), max(w2, w3)) * keep;
        if (w > 0.001) {
            vec3 t = w == w0 * keep ? turned(lab, from0, to0) : w == w1 * keep ? turned(lab, from1, to1)
                   : w == w2 * keep ? turned(lab, from2, to2) : turned(lab, from3, to3);
            c = mix(c, srgbOf(t), w);
        }
        // ── the plate's light ────────────────────────────────────────────
        vec3 g = c * mul.rgb + lift.rgb;
        float y = dot(g, vec3(0.2126, 0.7152, 0.0722));
        g = mix(vec3(y), g, sat) * expo;
        c = mix(c, g, ambient);
        // ── rim: the edge that faces the light ───────────────────────────
        float toward = texture(source, uv + lightDir * texel * 2.5).a;
        c += rimCol.rgb * rim * (1.0 - toward) * 0.8;
        // ── grain ────────────────────────────────────────────────────────
        c += (hash(floor(uv / texel) + seed) - 0.5) * 0.08 * grain;
    }

    // ── outline: the alpha dilated 1.5 px, under the character ───────────
    float o = 0.0;
    if (outline > 0.001 && a < 0.99) {
        vec2 d = texel * 1.5;
        o = max(max(max(texture(source, uv + vec2(d.x, 0.0)).a, texture(source, uv - vec2(d.x, 0.0)).a),
                    max(texture(source, uv + vec2(0.0, d.y)).a, texture(source, uv - vec2(0.0, d.y)).a)),
                max(max(texture(source, uv + d).a, texture(source, uv - d).a),
                    max(texture(source, uv + vec2(d.x, -d.y)).a, texture(source, uv + vec2(-d.x, d.y)).a)));
        o *= outline * (1.0 - a) * outlineCol.a;
    }
    vec3 oc = outlineCol.a > 0.001 ? outlineCol.rgb / outlineCol.a : vec3(0.0);
    vec3 rgb = clamp(c, 0.0, 1.0) * a + oc * o;
    fragColor = vec4(rgb, a + o) * qt_Opacity;
}
