#shader vertex
#version 410 core

layout(location = 0) in vec4 i_position;
layout(location = 1) in vec4 i_point_color;
layout(location = 2) in vec4 i_line_color;
uniform mat4 u_model_view_projection;
out vec4 v_point_color;
out vec4 v_line_color;

void main() {
    gl_Position = u_model_view_projection * i_position;
    v_point_color = i_point_color;
    v_line_color = i_line_color;
}

#shader fragment
#version 410 core

#define MARKER_RADIUS 30
#define THICCNESS 20.0
#define MAX_POINTS 128

in vec4 v_point_color;
in vec4 v_line_color;
uniform float u_time;
uniform int u_points_count;
uniform vec2[MAX_POINTS] u_points;

float sin01(float x) {
    return (sin(x) + 1.0) / 2.0;
}

void main() {
    gl_FragColor = vec4(0);

    for (int i = 1; i < u_points_count; i += 1) {
        vec2 p1 = u_points[i-1];
        vec2 p2 = u_points[i];

        { // Points
            if (length(gl_FragCoord.xy - p1) < MARKER_RADIUS) {
                gl_FragColor = v_point_color;
                return;
            }

            if (length(gl_FragCoord.xy - p2) < MARKER_RADIUS) {
                gl_FragColor = v_point_color;
                return;
            }
        }

        { // Lines
            vec2 p3 = gl_FragCoord.xy;
            vec2 p12 = p2 - p1;
            vec2 p13 = p3 - p1;

            float d = dot(p12, p13) / length(p12); // = length(p13) * cos(angle)
            vec2 p4 = p1 + normalize(p12) * d;
            if (length(p4 - p3) < THICCNESS /* * sin01(u_time / 200 + length(p4 - p1) * 0.02) */
                    && length(p4 - p1) <= length(p12)
                    && length(p4 - p2) <= length(p12)
            ) {
                gl_FragColor += v_line_color;
            }
        }
    }
}
