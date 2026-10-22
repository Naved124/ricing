#version 440
// Into Satsuei: a light leak, the way film flares at the end of a roll. A
// warm glow blooms in from the top right and sweeps across; the old frame
// burns out under it (brightening, then gone) and the new desktop is there
// behind it.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 → 1
    float aspect;       // width / height
};
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 c = texture(source, uv);

    // distance along the sweep: from the top right corner to the bottom left
    vec2 p = vec2((1.0 - uv.x) * aspect, uv.y);
    float along = (p.x + p.y * 0.8) / (aspect + 0.8);
    float e = progress * progress * (3.0 - 2.0 * progress);
    float front = e * 1.35 - 0.15;

    // behind the front the old frame is burnt out; just ahead it flares
    float burnt = smoothstep(front - 0.02, front - 0.22, along);
    float flare = exp(-pow((along - front) / 0.16, 2.0)) * (1.0 - smoothstep(0.8, 1.0, progress));

    // the leak's colours: amber at its heart, rose at its edge
    vec3 amber = vec3(1.0, 0.72, 0.38), rose = vec3(1.0, 0.42, 0.45);
    vec3 leak = mix(rose, amber, smoothstep(0.0, 1.0, flare)) * flare;

    vec3 rgb = c.rgb / max(c.a, 0.001);
    rgb = rgb + leak * 1.2 + rgb * flare * 0.6;
    // a little dust in the flare
    rgb += (hash(floor(uv * vec2(aspect, 1.0) * 420.0)) - 0.5) * 0.08 * flare;

    float a = (1.0 - burnt) * c.a;
    float glow = flare * 0.9 * (1.0 - burnt);
    a = max(a, glow);
    fragColor = vec4(clamp(rgb, 0.0, 1.0) * a, a) * qt_Opacity;
}
