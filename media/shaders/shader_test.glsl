#shader vertex
#version 410 core

layout(location = 0) in vec4 i_position;
layout(location = 1) in vec4 i_color;
layout(location = 2) in vec2 i_texture_coordinates;
layout(location = 3) in float i_texture_index;
layout(location = 4) in float i_palette_index;
uniform mat4 u_model_view_projection;
out vec4 v_color;
out vec2 v_texture_coordinates;
out float v_texture_index;
out float v_palette_index;

void main() {
    gl_Position = u_model_view_projection * i_position;
    v_color = i_color;
    v_texture_coordinates = i_texture_coordinates;
    v_texture_index = i_texture_index;
    v_palette_index = i_palette_index;
}

#shader fragment
#version 410 core

#define MARKER_RADIUS 100

in vec4 v_color;
uniform float u_time;
layout(location = 0) out vec4 o_color;

void main() {
    o_color = vec4(0.0);

    vec2 position = vec2(500, 500);
    float zero_to_one = (sin(u_time / 1000) + 1.0) / 2.0;

    if (length(gl_FragCoord.xy - position) < (MARKER_RADIUS + MARKER_RADIUS * zero_to_one)) {
        o_color = v_color;
    } else {
        // o_color = vec4(1);
    }
}
