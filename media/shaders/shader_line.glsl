#shader vertex
#version 410 core

layout(location = 0) in vec4 i_position;

uniform mat4 u_view_projection_matrix;

void main() {
    gl_Position = u_view_projection_matrix * i_position;
}

#shader fragment
#version 410 core

// 5000 = 1 grid cell in game
#define MARKER_RADIUS 5000
#define THICCNESS 5000
#define MAX_POINTS 128

uniform float u_time;
uniform vec2 u_window_size;
uniform mat4 u_view_matrix;
uniform mat4 u_projection_matrix;
uniform int u_points_count;
uniform vec2[MAX_POINTS] u_points;
uniform vec4 u_points_color;
uniform float u_points_radius;
uniform vec4 u_lines_color;
uniform float u_lines_thickness;

out vec4 fragColor;

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

float manhattan_distance(vec2 a, vec2 b) {
    return abs(a.x - b.x) + abs(a.y - b.y);
}

void main() {
    fragColor = vec4(0, 0, 0, 0);

    vec4 position = gl_FragCoord;

    for (int i = 1; i < u_points_count; i += 1) {
        vec2 p1 = world_to_window_position(u_points[i-1]);
        vec2 p2 = world_to_window_position(u_points[i]);

        { // Points
            float radius = MARKER_RADIUS * u_points_radius * u_projection_matrix[0][0];
            if (manhattan_distance(position.xy, p1) < radius) {
                fragColor = u_points_color;
                fragColor.a = 1;
                return;
            }

            // if (length(position.xy - p2) < radius) {
            if (manhattan_distance(position.xy, p2) < radius) {
                fragColor = u_points_color;
                fragColor.a = 1;
                return;
            }
        }

        { // Lines
            vec2 p3 = position.xy;
            vec2 p12 = p2 - p1;
            vec2 p13 = p3 - p1;

            float d = dot(p12, p13) / length(p12); // = length(p13) * cos(angle)
            vec2 p4 = p1 + normalize(p12) * d;
            float r = (THICCNESS * u_lines_thickness * u_projection_matrix[0][0]) /* * sin01(u_time / 200 + length(p4 - p1) * 0.50) */;
            if (length(p4 - p3) < r
                && length(p4 - p1) <= length(p12)
                && length(p4 - p2) <= length(p12)
            ) {
                fragColor = u_lines_color;
                // float delta = 0.5;
                // fragColor.a = smoothstep(1 - delta, 1 + delta, r);
            }
        }
    }
}
