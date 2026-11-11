#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 0) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float rightScale;
} ubuf;

void main()
{
    vec2 uv = qt_TexCoord0;
    float scale = mix(1.0, ubuf.rightScale, uv.x);
    float inset = (1.0 - scale) * 0.5;
    float y = (uv.y - inset) / scale;
    if (y < 0.0 || y > 1.0) {
        fragColor = vec4(0.0);
        return;
    }
    vec4 color = texture(source, vec2(uv.x, y));
    fragColor = color * ubuf.qt_Opacity;
}
