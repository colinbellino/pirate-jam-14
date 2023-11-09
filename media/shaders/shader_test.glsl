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

in vec4 v_point_color;
in vec4 v_line_color;
uniform float u_time;
uniform vec2[2] u_points;

#define MARKER_RADIUS 30
#define THICCNESS 20.0

float sin01(float x)
{
    return (sin(x) + 1.0) / 2.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    fragColor = vec4(0);

    vec2 p1 = u_points[0];
    vec2 p2 = u_points[1];
    // vec2 p1 = vec2(600, 500);
    // vec2 p2 = vec2(1200, 500);

    /* if (draw_point)  */
    {
        if (length(fragCoord.xy - p1) < MARKER_RADIUS) {
            fragColor = v_point_color;
            return;
        }

        if (length(fragCoord.xy - p2) < MARKER_RADIUS) {
            fragColor = v_point_color;
            return;
        }
    }

    vec2 p3 = fragCoord.xy;
    vec2 p12 = p2 - p1;
    vec2 p13 = p3 - p1;

    float d = dot(p12, p13) / length(p12); // = length(p13) * cos(angle)
    vec2 p4 = p1 + normalize(p12) * d;
    if (length(p4 - p3) < THICCNESS /* * sin01(u_time / 200 + length(p4 - p1) * 0.02) */
            && length(p4 - p1) <= length(p12)
            && length(p4 - p2) <= length(p12)
    ) {
        fragColor += v_line_color;
    }
}

void main() {
    mainImage(gl_FragColor, vec2(gl_FragCoord));
}
