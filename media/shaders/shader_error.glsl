#shader vertex
#version 410 core

layout(location = 0) in vec4 i_position;
layout(location = 1) in vec4 i_color;
layout(location = 2) in vec2 i_texture_coordinates;
layout(location = 3) in float i_texture_index;

uniform mat4 u_model_view_projection_matrix;

void main() {
    gl_Position = u_model_view_projection_matrix * i_position;
}

#shader fragment
#version 410 core

layout(location = 0) out vec4 o_color;

void main() {
    o_color = vec4(1, 0, 1, 1);
}
