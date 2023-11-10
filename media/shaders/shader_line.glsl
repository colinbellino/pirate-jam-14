#shader vertex
#version 410 core

layout(location = 0) in vec4 i_position;
layout(location = 1) in vec4 i_point_color;
layout(location = 2) in vec4 i_line_color;
uniform mat4 u_model_view_projection;
out vec4 v_point_color;
out vec4 v_line_color;
out vec4 v_position;

void main() {
    gl_Position = u_model_view_projection * i_position;
    v_position = gl_Position;
    v_point_color = i_point_color;
    v_line_color = i_line_color;
}

#shader fragment
#version 410 core

// #define MARKER_RADIUS 30.0
#define MARKER_RADIUS 0.3
// #define THICCNESS 20.0
#define THICCNESS 0.3
#define MAX_POINTS 128

in vec4 v_point_color;
in vec4 v_line_color;
in vec4 v_position;
uniform mat4 u_model_view_projection;
uniform float u_time;
uniform int u_points_count;
uniform vec2[MAX_POINTS] u_points;

float sin01(float x) {
    return (sin(x) + 1.0) / 2.0;
}

void main() {
    gl_FragColor = vec4(0, 0, 0, 0);
    // vec4 position = u_model_view_projection * gl_FragCoord;
    // vec4 position = v_position;
    vec4 position = gl_FragCoord;
    vec4 line_color = vec4(1, 0, 1, 1);

    for (int i = 1; i < u_points_count; i += 1) {
        vec2 p1 = u_points[i-1];
        vec2 p2 = u_points[i];

        { // Points
            if (length(position.xy - p1) < MARKER_RADIUS) {
                gl_FragColor = v_point_color;
                return;
            }

            if (length(position.xy - p2) < MARKER_RADIUS) {
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
            if (length(p4 - p3) < THICCNESS /* * sin01(u_time / 200 + length(p4 - p1) * 0.02) */
                    && length(p4 - p1) <= length(p12)
                    && length(p4 - p2) <= length(p12)
            ) {
                gl_FragColor = line_color;
            }
        }
    }
}
