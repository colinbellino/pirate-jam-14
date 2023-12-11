#shader vertex
#version 410 core

layout(location = 0) in vec4 i_position;
layout(location = 1) in vec4 i_color;
layout(location = 2) in vec2 i_texture_coordinates;
layout(location = 3) in float i_texture_index;
layout(location = 4) in float i_palette_index;

uniform mat4 u_view_projection_matrix;

out vec4 v_color;
out vec2 v_texture_coordinates;
out float v_texture_index;
out float v_palette_index;

void main() {
    gl_Position = u_view_projection_matrix * i_position;
    v_color = i_color;
    v_texture_coordinates = i_texture_coordinates;
    v_texture_index = i_texture_index;
    v_palette_index = i_palette_index;
}

#shader fragment
#version 410 core

in vec4 v_color;
in vec2 v_texture_coordinates;
in float v_texture_index;
in float v_palette_index;

const int PALETTE_SIZE = 32;
const int PALETTE_MAX = 4;
uniform vec4[PALETTE_MAX * PALETTE_SIZE] u_palettes;
uniform sampler2D u_textures[16];

layout(location = 0) out vec4 o_color;

void main() {
    int texture_index = int(v_texture_index);
    vec4 color = texture(u_textures[texture_index], v_texture_coordinates) * v_color;

    if (v_palette_index > 0) {
        int index = int(color.r * 255) + int(v_palette_index - 1) * PALETTE_SIZE;
        color.xyz = u_palettes[index].xyz;
    }

    o_color = color;
}
