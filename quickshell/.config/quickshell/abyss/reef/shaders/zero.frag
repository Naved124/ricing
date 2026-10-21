#version 440
// A still sea: the ripple field's state, zeroed.
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf { mat4 qt_Matrix; float qt_Opacity; };
void main() { fragColor = vec4(0.0, 0.0, 0.0, 1.0); }
