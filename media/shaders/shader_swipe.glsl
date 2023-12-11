#shader vertex
#version 410 core

layout(location = 0) in vec4 i_position;
layout(location = 1) in vec4 i_color;

uniform mat4 u_view_projection_matrix;

out vec4 v_color;

void main() {
    gl_Position = u_view_projection_matrix * i_position;
    v_color = i_color;
}

#shader fragment
#version 410 core

#define RECT_COLOR  vec4(1, 1, 1, 1)
#define RECT_COUNT  int(11)
#define RECT_OFFSET float(0.05)
#define SAW_COUNT   int(2) // Change this to 1 for flat rect, to 3 or 4 for different patterns

in vec4 v_color;

uniform float u_progress;
uniform vec2 u_window_size;

out vec4 fragColor;

float sin01(float x) {
    return (sin(x) + 1.0) / 2.0;
}

void main() {
    // Inputs
    vec2 uv = gl_FragCoord.xy / u_window_size.xy;

    float t_even = round(float(int(uv.y * float(RECT_COUNT)) % SAW_COUNT));
    float offset_even = mix(0.0, RECT_OFFSET, t_even);
    float color_t = floor(1.0 - uv.x + u_progress + (RECT_OFFSET * uv.x) - offset_even);
    fragColor = mix(vec4(0), RECT_COLOR * v_color, color_t);
}
