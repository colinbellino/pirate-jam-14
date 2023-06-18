#version 410 core

layout(location = 0) in vec3 vertex_position;
layout(location = 1) in vec4 vertex_color;

uniform float time;

out vec3 fragment_position;
out vec4 fragment_color;
flat out int instance;

void main() {
    instance = gl_InstanceID;
    fragment_position = vertex_position;
    fragment_color = vertex_color;

    gl_Position = vec4(vertex_position, 1.0);
}
