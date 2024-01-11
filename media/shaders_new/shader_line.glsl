@header package shader_line
@header import sg "../../sokol-odin/sokol/gfx"
@header import "../"; @(init) shader_init :: proc() { shaders.shaders["shader_line"] = line_shader_desc }
@header import "core:math/linalg"
@ctype mat4 linalg.Matrix4x4f32
@ctype vec2 linalg.Vector2f32
@ctype vec4 linalg.Vector4f32

@vs vs
in vec2 position;

void main() {
    gl_Position = vec4(position, 0.0, 1.0);
}
@end

@fs fs
// 5000 = 1 grid cell in game
#define MARKER_RADIUS 5000
#define THICCNESS 5000
#define MAX_POINTS 128

uniform fs_uniform {
    mat4  view_matrix;
    mat4  projection_matrix;
    mat4  mvp;
    vec4  points_color;
    vec4  lines_color;
    vec4[MAX_POINTS] points;
    int   points_count;
    float lines_thickness;
    float time;
    float points_radius;
    vec2  window_size;
};

out vec4 frag_color;

float sin01(float x) {
    return (sin(x) + 1.0) / 2.0;
}

vec2 world_to_clip_position(vec4 point) {
    vec4 clip_space_position = mvp * point;
    return ((clip_space_position.xy + 1.0) / 2.0) * window_size;
}

float manhattan_distance(vec2 a, vec2 b) {
    return abs(a.x - b.x) + abs(a.y - b.y);
}

void main() {
    frag_color = vec4(0, 0, 0, 0);

    vec4 position = gl_FragCoord;
    float zoom = projection_matrix[0][0];

    for (int i = 1; i < points_count; i += 1) {
        vec2 p1 = world_to_clip_position(points[i-1]);
        vec2 p2 = world_to_clip_position(points[i]);

        { // Points
            float radius = MARKER_RADIUS * points_radius * zoom;
            if (manhattan_distance(position.xy, p1) < radius) {
                frag_color = points_color;
                frag_color.a = 1;
                return;
            }

            // if (length(position.xy - p2) < radius) {
            if (manhattan_distance(position.xy, p2) < radius) {
                frag_color = points_color;
                frag_color.a = 1;
                return;
            }
        }

        { // Lines
            vec2 p3 = position.xy;
            vec2 p12 = p2 - p1;
            vec2 p13 = p3 - p1;

            float d = dot(p12, p13) / length(p12); // = length(p13) * cos(angle)
            vec2 p4 = p1 + normalize(p12) * d;
            float radius = (THICCNESS * lines_thickness * zoom) /* * sin01(time / 200 + length(p4 - p1) * 0.50) */;
            if (length(p4 - p3) < radius
                && length(p4 - p1) <= length(p12)
                && length(p4 - p2) <= length(p12)
            ) {
                frag_color = lines_color;
                // float delta = 0.5;
                // frag_color.a = smoothstep(1 - delta, 1 + delta, radius);
            }
        }
    }
}
@end

@program line vs fs
