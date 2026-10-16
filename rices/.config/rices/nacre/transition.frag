#version 440
// Into Nacre: a ripple opens from the centre of the screen. The old frame
// is refracted at the wavefront and edged in the iridescent gradient, and
// the new desktop shows through the widening ring.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;     // 0 → 1
    float aspect;       // width / height
};
layout(binding = 1) uniform sampler2D source;

vec3 iridescent(float t) {
    // rose → sky → mint → sun → orchid → rose
    vec3 c[6] = vec3[](vec3(0.949, 0.765, 0.839), vec3(0.765, 0.875, 0.953),
                       vec3(0.804, 0.933, 0.859), vec3(0.953, 0.886, 0.690),
                       vec3(0.863, 0.776, 0.949), vec3(0.949, 0.765, 0.839));
    t = fract(t) * 5.0;
    int i = int(floor(t));
    return mix(c[i], c[i + 1], fract(t));
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
    float d = length(p);
    float maxD = length(vec2(aspect, 1.0)) * 0.5 + 0.15;

    // ease-out wavefront
    float e = 1.0 - pow(1.0 - progress, 2.2);
    float front = e * maxD;
    float band = 0.12;

    // inside the front the old frame is gone
    float x = (d - front) / band;               // < 0 inside, 0..1 in the band
    float alpha = smoothstep(0.0, 1.0, x);

    // refraction: push samples outward near the front
    float bend = exp(-x * x * 3.0) * 0.025 * (1.0 - progress);
    vec2 dir = d > 0.0001 ? p / d : vec2(0.0);
    vec2 suv = uv + dir * bend / vec2(aspect, 1.0);
    vec4 c = texture(source, clamp(suv, 0.0, 1.0));

    // an iridescent rim riding the wavefront
    float rim = exp(-pow((d - front) / (band * 0.35), 2.0)) * (1.0 - smoothstep(0.75, 1.0, progress));
    vec3 tint = iridescent(atan(p.y, p.x) / 6.2831 + progress * 0.5);
    c.rgb = mix(c.rgb, tint, rim * 0.6);

    float a = max(alpha, rim * 0.85);
    fragColor = vec4(c.rgb * a, a) * qt_Opacity;
}
