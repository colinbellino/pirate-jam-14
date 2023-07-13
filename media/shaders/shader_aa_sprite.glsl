#shader vertex
#version 410 core

layout(location = 0) in vec4 i_position;
layout(location = 1) in vec4 i_color;
layout(location = 2) in vec2 i_texture_coordinates;
layout(location = 3) in float i_texture_index;

uniform mat4 u_model_view_projection;

out vec4 v_color;
out vec2 v_texture_coordinates;
out float v_texture_index;

void main() {
    gl_Position = u_model_view_projection * i_position;
    v_color = i_color;
    v_texture_coordinates = i_texture_coordinates;
    v_texture_index = i_texture_index;
}

#shader fragment
#version 410 core

in vec4 v_color;
in vec2 v_texture_coordinates;
in float v_texture_index;

uniform sampler2D u_textures[16];
uniform float u_texels_per_pixel;

layout(location = 0) out vec4 o_color;

void main() {
    int texture_index = int(v_texture_index);
    vec2 texture_size = vec2(textureSize(u_textures[texture_index], 0));

    vec2 pixel = v_texture_coordinates * texture_size;
    vec2 fat_pixel;
    // casey
    // fat_pixel = (floor(pixel) + 0.5) + 1 - clamp((1.0 - fract(pixel)) * u_texels_per_pixel, 0, 1);
    // shader toy
    // fat_pixel = floor(pixel) + min(fract(pixel) / fwidth(pixel), 1.0) - 0.5;
    fat_pixel = floor(pixel) + smoothstep(0.0, 1.0, fract(pixel) / fwidth(pixel)) - 0.5;
    vec2 uv_fat_pixel = fat_pixel / texture_size;
    o_color = texture(u_textures[texture_index], uv_fat_pixel) * v_color;
}
