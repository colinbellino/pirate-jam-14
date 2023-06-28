#shader vertex
#version 410 core

layout(location = 0) in vec4 position;
layout(location = 1) in vec4 color;
layout(location = 2) in vec2 uv;
layout(location = 3) in float texture_index;

uniform mat4 u_model_view_projection;

out vec4 vertex_color;
out vec2 vertex_uv;
out float vertex_texture_index;

void main() {
    gl_Position = u_model_view_projection * position;
    vertex_color = color;
    vertex_uv = uv;
    vertex_texture_index = texture_index;
}

#shader fragment
#version 410 core

in vec4 vertex_color;
in vec2 vertex_uv;
in float vertex_texture_index;

uniform sampler2D u_textures[2];

layout(location = 0) out vec4 color;

void main() {
    int index = int(vertex_texture_index);
    vec4 texture_color = texture(u_textures[index], vertex_uv);
    color = texture_color * vertex_color;
}
