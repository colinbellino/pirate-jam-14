#shader vertex
#version 410 core

layout(location = 0) in vec4 position;
layout(location = 1) in vec4 color;
layout(location = 2) in vec2 uv;

uniform mat4 u_model_view_projection;

out vec4 vertex_color;
out vec2 vertex_uv;

void main() {
    gl_Position = u_model_view_projection * position;
    vertex_color = color;
    vertex_uv = uv;
}

#shader fragment
#version 410 core

in vec4 vertex_color;
in vec2 vertex_uv;

uniform sampler2D u_texture;

layout(location = 0) out vec4 color;

void main() {
    vec4 texture_color = texture(u_texture, vertex_uv);
    color = texture_color * vertex_color;
    // color.a = u_color.a;
    // color = vertex_color;
}
