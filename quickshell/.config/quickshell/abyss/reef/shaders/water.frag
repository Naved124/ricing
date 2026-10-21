#version 440
// The reef's water, the mock's composite (docs/abyss/reef-mock.html): the
// depth gradient, light rays from above the surface (swept by a workspace
// switch, brighter on the beat), caustics near the top and two layers of
// marine snow; then the scene seen through the ripples (refracted by the
// field's slope), its bloom, the ripples' glint and height tint, a vignette,
// a soft tone map and dither. Constants are the mock's.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;          // output size in px (only its aspect matters)
    vec2 cells;        // the ripple grid
    float time;
    float sweep;
    float beat;
    float bloom;       // 1.05; 0 when the reef is cut back
    float dim;         // 1 normally; the lock screen's reef is darker
    vec3 surface;      // the water's colour at the surface,
    vec3 middle;       // half way,
    vec3 deepest;      // and at the floor
};
layout(binding = 1) uniform sampler2D scene;   // the dark and swaying part, premultiplied
layout(binding = 4) uniform sampler2D live;    // what glows and moves, all added light
layout(binding = 2) uniform sampler2D blur;    // the scene, quarter size, blurred
layout(binding = 3) uniform sampler2D field;   // height now in r (Ripple.qml)

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + 1.), f.x), f.y);
}
float snow(vec2 uv, float sc, float sp, float t, float asp) {
    vec2 p = uv * vec2(asp, 1.) * sc; p.y -= t * sp; p.x += sin(p.y * .35 + t * .3) * .25;
    vec2 id = floor(p), f = fract(p) - .5; float r = hash(id); vec2 of = vec2(hash(id + 3.1), hash(id + 7.7)) - .5;
    float d = length(f - of * .7); return step(.82, r) * smoothstep(.07, 0., d) * (.4 + .6 * hash(id + 1.3));
}
float height(vec2 uv) { return texture(field, uv).r; }

void main() {
    vec2 uv = qt_TexCoord0;
    // the slope and height as the mock packs them (×95 and ×70 of 127.5)
    vec2 px = 1.0 / cells;
    vec2 g = clamp(vec2(height(uv + vec2(px.x, 0.)) - height(uv - vec2(px.x, 0.)),
                        height(uv + vec2(0., px.y)) - height(uv - vec2(0., px.y))) * (95.0 / 127.5), -1.0, 1.0);
    float h = clamp(height(uv) * (70.0 / 127.5), -1.0, 1.0);
    vec2 off = g * .016; vec2 suv = uv + off; float t = time; float asp = res.x / res.y;
    vec3 bg = mix(surface, middle, smoothstep(0., .55, suv.y)); bg = mix(bg, deepest, smoothstep(.45, 1., suv.y));
    bg += vec3(.025, .10, .12) * smoothstep(.28, 0., suv.y);
    vec2 rp = suv - vec2(.38, -.38); float ang = atan(rp.x * asp, rp.y);
    float r1 = pow(.5 + .5 * sin(ang * 36. + t * .12 + sweep * 6. + noise(vec2(ang * 6., t * .07)) * 3.), 5.);
    float r2 = pow(.5 + .5 * sin(ang * 59. - t * .09 + sweep * 4.), 9.);
    float rays = (r1 * .6 + r2 * .4) * smoothstep(.9, .05, suv.y) * (.45 + .55 * noise(vec2(ang * 9., suv.y * 1.5 - t * .15)));
    bg += vec3(.035, .14, .17) * rays * (.6 + beat * .35);
    float c = noise(suv * vec2(9. * asp, 6.) + vec2(t * .08 + sweep * 2., t * .05)); c = pow(1. - abs(c * 2. - 1.), 9.);
    bg += vec3(.06, .18, .2) * c * smoothstep(.3, 0., suv.y) * .4;
    float sn = snow(suv, 22., .35, t, asp) * .5 + snow(suv + .37, 38., .22, t, asp) * .3;
    bg += vec3(.35, .6, .65) * sn * .22 * (1. - suv.y * .5);
    // the mock's one scene canvas is two layers here; light adds, as there
    vec4 s1 = texture(scene, suv), s2 = texture(live, suv);
    vec4 sc = vec4(s1.rgb + s2.rgb, min(1.0, s1.a + s2.a));
    vec3 col = bg * (1. - sc.a) + sc.rgb;
    vec3 bl = texture(blur, uv + off * 1.4).rgb;
    col += bl * bloom;
    float spec = clamp(dot(g, normalize(vec2(-.55, -.85))), 0., 1.);
    col += vec3(.2, .62, .7) * spec * .32 * (1. - uv.y * .55);
    col += vec3(.03, .13, .16) * abs(h) * .35;
    vec2 q = uv - .5; col *= 1. - dot(q * vec2(asp * .7, 1.), q * vec2(asp * .7, 1.)) * .75;
    col *= dim;
    col = col / (1. + col * .25);
    col += (hash(gl_FragCoord.xy + fract(t)) - .5) / 255.;
    fragColor = vec4(col, 1.) * qt_Opacity;
}
