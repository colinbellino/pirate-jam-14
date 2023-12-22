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

#define SIZE                float(1)
#define MAX_INDEX           int(512)
uniform float               u_indexes_count;
uniform float[MAX_INDEX]    u_indexes;
uniform vec2                u_window_size;
uniform float               u_grid_width;
in vec4                     v_position;
in vec4                     v_color;
out vec4                    fragColor;

void main() {
    vec2 position = floor(v_position.xy * SIZE / 8);
    ivec2 grid_position = ivec2(position);
    int cell_index = grid_position.y * int(u_grid_width) + grid_position.x;

    float value = 0.0;
    for (int i = 0; i < u_indexes_count; i += 1) {
        if (u_indexes[i] == cell_index) {
            value = 1.0;
            break;
        }
    }

    fragColor = v_color;
    fragColor.a = mix(0.0, 1.0, value);
    // fragColor.r = position.x / float(grid_size.x);
    // fragColor.g = position.y / float(grid_size.y);
}
