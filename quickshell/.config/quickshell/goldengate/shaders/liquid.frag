#version 440
// Golden Gate's own Liquid Glass, for when no compositor plugin can draw it
// (gg glass backend shader). A pane of thick glass over what's behind it:
// clear in the middle (blurred more as the clarity tints it), a rim that
// bends the picture inwards like a lens with a little dispersion, the light
// along the top edge, and a bright edge where the glass turns away.
//
// `sharp` and `soft` are what's behind the pane (the wallpaper, or the screen
// in Accurate mode), `pad` px past each side; `soft` is the same at an eighth
// of the size, so linear filtering blurs it. GlassPane lays its tint on top.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;       // the pane, px
    float radius;    // its corners, px
    float rim;       // how far in the bend reaches, px
    float pad;       // the sources' margin past the pane, px
    float clarity;   // 0 Ultraclear … 1 Tinted
    float dark;      // 0 day … 1 night (Theme.k)
};
layout(binding = 1) uniform sampler2D sharp;
layout(binding = 2) uniform sampler2D soft;

// signed distance to the pane's rounded box (negative inside)
float box(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec2 toSource(vec2 px) { return (px + pad) / (size + 2.0 * pad); }

vec3 behind(vec2 px, float blur) {
    vec2 uv = toSource(px);
    vec2 t = 1.5 / (size + 2.0 * pad) * 8.0;
    // five soft taps smooth the eighth-size texture into a round blur
    vec3 s = texture(soft, uv).rgb * 0.4
           + (texture(soft, uv + vec2(t.x, 0.0)).rgb + texture(soft, uv - vec2(t.x, 0.0)).rgb
           +  texture(soft, uv + vec2(0.0, t.y)).rgb + texture(soft, uv - vec2(0.0, t.y)).rgb) * 0.15;
    return mix(texture(sharp, uv).rgb, s, blur);
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec2 c = px - size * 0.5;
    float d = box(c, size * 0.5, radius);

    // the normal of the edge, from the distance field's gradient
    vec2 e = vec2(0.5, 0.0);
    vec2 n = normalize(vec2(box(c + e.xy, size * 0.5, radius) - box(c - e.xy, size * 0.5, radius),
                            box(c + e.yx, size * 0.5, radius) - box(c - e.yx, size * 0.5, radius)) + 1e-5);
    // 0 in the flat middle, 1 at the edge, curving like a lens
    float edge = clamp(1.0 + d / rim, 0.0, 1.0);
    float bend = edge * edge * edge;

    // the rim pulls in what's just outside the pane; blue bends most
    vec2 pull = -n * bend * rim * 0.85;
    float blur = mix(0.3, 1.0, clarity);
    vec3 col;
    col.r = behind(px + pull * 0.94, blur).r;
    col.g = behind(px + pull, blur).g;
    col.b = behind(px + pull * 1.08, blur).b;

    // frost by day (brighter, a touch less saturated), smoke at night
    float l = dot(col, vec3(0.299, 0.587, 0.114));
    vec3 day = mix(vec3(l), col, 0.9) * 1.06 + 0.035;
    vec3 night = mix(vec3(l), col, 0.85) * 0.78;
    col = mix(day, night, dark);

    // the light from above: a highlight along the top of the rim
    float top = max(0.0, dot(-n, normalize(vec2(-0.35, -1.0))));
    col += vec3(1.0) * pow(edge, 4.0) * top * mix(0.55, 0.3, dark);
    // where the glass turns away it catches the room: a thin bright edge
    col += vec3(1.0) * smoothstep(-1.6, 0.0, d) * mix(0.18, 0.1, dark);

    float a = smoothstep(0.75, -0.75, d) * qt_Opacity;
    fragColor = vec4(clamp(col, 0.0, 1.0) * a, a);
}
