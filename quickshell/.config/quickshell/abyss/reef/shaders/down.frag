#version 440
// The bloom's source: the scene (both layers) at a quarter of its size, each
// texel the average of a 4×4 block (four bilinear taps).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf { mat4 qt_Matrix; float qt_Opacity; vec2 texel; };
layout(binding = 1) uniform sampler2D src;   // the scene's layers; texel is their texel size
layout(binding = 2) uniform sampler2D live;
vec4 both(vec2 uv) { return texture(src, uv) + texture(live, uv); }
void main() {
    vec2 uv = qt_TexCoord0;
    fragColor = (both(uv + texel * vec2(-1.0, -1.0)) + both(uv + texel * vec2(1.0, -1.0))
               + both(uv + texel * vec2(-1.0, 1.0)) + both(uv + texel * vec2(1.0, 1.0))) * 0.25;
}
