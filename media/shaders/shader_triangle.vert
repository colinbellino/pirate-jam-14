#version 410 core

layout(location = 0) in vec4 vertex_position;
layout(location = 1) in vec4 vertex_color;

uniform float time;

out vec4 fragment_position;
out vec4 fragment_color;
flat out int fragment_instance;

void main() {
    fragment_instance = gl_InstanceID;
    fragment_position = vertex_position;
    fragment_color = vertex_color;

    gl_Position = vertex_position;
}
