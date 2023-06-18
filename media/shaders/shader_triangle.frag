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
