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

uniform float u_time;

#define MARKER_RADIUS 30
#define THICCNESS 20.0

float sin01(float x)
{
    return (sin(x) + 1.0) / 2.0;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    fragColor = vec4(1.0);

    vec2 p1 = vec2(600, 500);
    vec2 p2 = vec2(1200, 500);

    bool draw_point = true;
    if (draw_point) {
        if (length(fragCoord.xy - p1) < MARKER_RADIUS) {
            fragColor += vec4(1.0, 0.0, 0.0, 1.0);
        }

        if (length(fragCoord.xy - p2) < MARKER_RADIUS) {
            fragColor += vec4(1.0, 0.0, 0.0, 1.0);
        }
    }

    vec2 p3 = fragCoord.xy;
    vec2 p12 = p2 - p1;
    vec2 p13 = p3 - p1;

    float d = dot(p12, p13) / length(p12); // = length(p13) * cos(angle)
    vec2 p4 = p1 + normalize(p12) * d;
    if (length(p4 - p3) < THICCNESS * sin01(u_time / 200 + length(p4 - p1) * 0.02)
          && length(p4 - p1) <= length(p12)
          && length(p4 - p2) <= length(p12)) {
        fragColor += vec4(0.0, 1.0, 0.0, 1.0);
    }
}

void main() {
    mainImage(gl_FragColor, vec2(gl_FragCoord));
}
