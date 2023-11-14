#shader vertex
#version 410 core

layout(location = 0) in vec4 i_position;
layout(location = 1) in vec4 i_point_color;
layout(location = 2) in vec4 i_line_color;
uniform mat4 u_model_view_projection_matrix;
out vec4 v_point_color;
out vec4 v_line_color;
out vec4 v_position;

void main() {
    gl_Position = u_model_view_projection_matrix * i_position;
    v_position = gl_Position;
    v_point_color = i_point_color;
    v_line_color = i_line_color;
}

#shader fragment
#version 410 core

// 5000 = 1 grid cell in game
#define MARKER_RADIUS 5000
#define THICCNESS 5000
#define MAX_POINTS 128

in vec4 v_point_color;
in vec4 v_line_color;
in vec4 v_position;

uniform ivec2 u_window_size;
uniform mat4 u_view_matrix;
uniform mat4 u_projection_matrix;
uniform mat4 u_model_view_projection_matrix;

uniform float u_time;
uniform int u_points_count;
uniform vec2[MAX_POINTS] u_points;

float sin01(float x) {
    return (sin(x) + 1.0) / 2.0;
}

vec2 world_to_window_position(vec2 point) {
    vec2 view_offset = vec2(0, 0);
    vec4 clip_space_position = u_projection_matrix * (u_view_matrix * vec4(point, 0, 1));
    vec3 normalized_device_position = clip_space_position.xyz / clip_space_position.w;
    vec2 window_space_position = ((normalized_device_position.xy + 1.0) / 2.0) * u_window_size + view_offset;
    return window_space_position;
}

void main() {
    gl_FragColor = vec4(0, 0, 0, 0);

    vec4 line_color = vec4(1, 0, 1, 1);
    vec4 position = gl_FragCoord;

    for (int i = 1; i < u_points_count; i += 1) {
        vec2 p1 = world_to_window_position(u_points[i-1]);
        vec2 p2 = world_to_window_position(u_points[i]);

        { // Points
            if (length(position.xy - p1) < MARKER_RADIUS * u_projection_matrix[0][0]) {
                gl_FragColor = v_point_color;
                return;
            }

            if (length(position.xy - p2) < MARKER_RADIUS * u_projection_matrix[0][0]) {
                gl_FragColor = v_point_color;
                return;
            }
        }

        { // Lines
            vec2 p3 = position.xy;
            vec2 p12 = p2 - p1;
            vec2 p13 = p3 - p1;

            float d = dot(p12, p13) / length(p12); // = length(p13) * cos(angle)
            vec2 p4 = p1 + normalize(p12) * d;
            float r = THICCNESS * u_projection_matrix[0][0] * sin01(u_time / 200 + length(p4 - p1) * 0.02);
            if (length(p4 - p3) < r
                && length(p4 - p1) <= length(p12)
                && length(p4 - p2) <= length(p12)
            ) {
                gl_FragColor = line_color;
                float delta = 0.5;
                gl_FragColor.a = smoothstep(1 - delta, 1 + delta, r);
            }
        }
    }
}
