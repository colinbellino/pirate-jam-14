#shader vertex
#version 410 core

layout(location = 0) in vec4 position;
layout(location = 1) in vec2 texture_coordinates;

out vec2 v_texture_coordinates;

uniform mat4 u_model_view_projection;

void main() {
    gl_Position = u_model_view_projection * position;
    v_texture_coordinates = texture_coordinates;
}

#shader fragment
#version 410 core

in vec2 v_texture_coordinates;

uniform vec4 u_color;
uniform sampler2D u_texture;

layout(location = 0) out vec4 color;

void main() {
    vec4 texture_color = texture(u_texture, v_texture_coordinates);
    color = texture_color;
    color.a = u_color.a;
}
