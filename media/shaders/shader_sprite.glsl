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

uniform sampler2D u_textures[2];

layout(location = 0) out vec4 o_color;

void main() {
    int index = int(v_texture_index);
    o_color = texture(u_textures[index], v_texture_coordinates) * v_color;
}
