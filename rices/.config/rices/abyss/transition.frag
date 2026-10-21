#version 440
// Into Abyss: the flood. Dark water rises from the bottom edge over the old
// frame; its surface is a bright, slightly turbulent line strung with
// plankton sparks, and just above it the old frame wavers, seen through
// the water's lens. Under the surface the reef shows through.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 → 1 (on the drift curve)
    float aspect;       // width / height
};
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + 1.), f.x), f.y);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float p = progress;
    float x = uv.x * aspect;
    // the surface: from just under the bottom edge to just over the top
    float level = mix(1.06, -0.1, p);
    float line = level + 0.010 * sin(x * 8.0 + p * 13.0) + 0.006 * sin(x * 21.0 - p * 19.0)
               + 0.006 * (noise(vec2(x * 30.0, p * 24.0)) - 0.5);
    float d = uv.y - line;                      // > 0 under water

    // above the surface the old frame, wavering close over it
    float near = (1.0 - smoothstep(0.0, 0.07, -d)) * step(d, 0.0);
    vec2 suv = uv + near * vec2(0.010 * sin(uv.y * 90.0 + p * 24.0), 0.014 * near);
    vec4 old = texture(source, clamp(suv, 0.0, 1.0));
    float above = 1.0 - smoothstep(-0.003, 0.003, d);
    vec4 col = old * above;

    // the water: abyss-dark under the surface, thinning as it deepens so the
    // reef below shows through
    vec3 abyss = vec3(0.004, 0.024, 0.043);
    float body = (1.0 - above) * (1.0 - smoothstep(0.0, 0.3, d)) * 0.9;
    col += vec4(abyss * body, body);

    // the surface's light, and plankton sparks strung along it
    vec3 teal = vec3(0.384, 0.949, 0.886);
    float glow = exp(-abs(d) * 260.0) * 0.95 + exp(-abs(d) * 45.0) * 0.22;
    // one spark at most in every 26th of the width, re-strung nine times on the way up
    vec2 cell = vec2(floor(x * 26.0 / aspect), floor(p * 9.0));
    float r = hash(cell);
    float sx = (cell.x + 0.5 + (hash(cell + 3.1) - 0.5) * 0.8) / 26.0 * aspect;
    float sy = line + (hash(cell + 7.7) - 0.6) * 0.025;
    // (in the screen's proportions: x across it, y down it)
    float spark = step(0.55, r) * exp(-length(vec2(x - sx, uv.y - sy)) * 420.0);
    float light = (glow + spark * 1.6) * (1.0 - smoothstep(0.9, 1.0, p));
    col.rgb += teal * light;
    col.a = max(col.a, clamp(light, 0.0, 1.0));
    fragColor = col * qt_Opacity;
}
