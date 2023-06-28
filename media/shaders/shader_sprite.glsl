#shader vertex
#version 410 core

layout(location = 0) in vec4 position;
layout(location = 1) in vec4 color;

out vec4 vertex_color;

uniform mat4 u_model_view_projection;

void main() {
    gl_Position = u_model_view_projection * position;
    vertex_color = color;
}

#shader fragment
#version 410 core

in vec4 vertex_color;

uniform sampler2D u_texture;

layout(location = 0) out vec4 color;

void main() {
    // vec4 texture_color = texture(u_texture, vertex_color);
    // color = texture_color;
    // color.a = u_color.a;
    color = vertex_color;
}
