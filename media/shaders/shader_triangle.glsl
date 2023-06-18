#shader vertex
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

#shader fragment
#version 410 core

in vec4 fragment_position;
in vec4 fragment_color;
flat in int fragment_instance;

uniform float time;

out vec4 color;

void main() {
    float R = fragment_color.x - 0.5 * cos(fragment_position.x * time);
    float G = fragment_color.y - 0.5 * cos(fragment_position.y * time);
    float B = fragment_color.z - 0.5 * cos(fragment_position.z * time);
    color = vec4(R, G, B, fragment_color.w);
    // color = fragment_color;
}
