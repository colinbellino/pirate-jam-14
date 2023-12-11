#shader vertex
#version 410 core

layout(location = 0) in vec4 i_position;
layout(location = 1) in vec4 i_color;

uniform mat4 u_view_projection_matrix;

out vec4 v_position;
out vec4 v_color;

void main() {
    gl_Position = u_view_projection_matrix * i_position;
    v_position = i_position;
    v_color = i_color;
}

#shader fragment
#version 410 core

#define SIZE       float(1)
#define COLOR_ODD  vec4(0.0, 0.0, 0.0, 0.0)
#define COLOR_EVEN vec4(1.0, 1.0, 1.0, 1.0)
#define PATTERN    vec2(2.0, 2.0)
// Other patterns that might be useful
// #define PATTERN    vec2(4.0, 4.0)
// #define PATTERN    vec2(2.0, 3.0)

in vec4 v_position;
in vec4 v_color;

uniform vec2 u_window_size;

out vec4 fragColor;

void main() {
    vec2 position = floor(v_position.xy * SIZE / 8);
    float t = mod(position.x + mod(position.y, PATTERN.y), PATTERN.x);
    fragColor = mix(COLOR_EVEN, COLOR_ODD, t) * v_color;
}
