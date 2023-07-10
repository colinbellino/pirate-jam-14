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

layout(location = 0) out vec4 o_color;

void main() {
    // vec2 pix = v_texture_coordinates * vec2(56, 168);
    // pix = floor(pix) + min(fract(pix) / fwidth(pix), 1.0) - 0.5;
    // o_color = texture(u_textures[texture_index], pix / vec2(56, 168));

    int texture_index = int(v_texture_index);
    vec2 texture_size = vec2(56, 168);
    float texels_per_pixel = 4; // TODO: calculate this calculate_texels_per_pixel

    vec2 pixel = v_texture_coordinates * texture_size;

    vec2 fat_pixel = floor(pixel) + 0.5;
    fat_pixel += 1 - clamp((1.0 - fract(pixel)) * texels_per_pixel, 0, 1);
    vec2 uv_fat_pixel = fat_pixel / texture_size;

    o_color = texture(u_textures[texture_index], uv_fat_pixel);
}
