@header package shader_swipe
@header import sg "../../sokol-odin/sokol/gfx"
@header import "../"; @(init) shader_init :: proc() { shaders.shaders["shader_swipe"] = swipe_shader_desc }

@vs vs
uniform vs_uniform {
    mat4 mvp;
    vec2 window_size;
};

in vec2 position;

in vec2 i_position;
in vec4 i_color;

out vec4 f_color;

void main() {
    gl_Position = mvp * vec4((position * window_size) + i_position, 0.0, 1.0);
    f_color = i_color;
}
@end

@fs fs
uniform fs_uniform {
    vec2  window_size;
    float progress;
};

#define RECT_COLOR  vec4(1, 1, 1, 1)
#define RECT_COUNT  int(11)
#define RECT_OFFSET float(0.05)
#define SAW_COUNT   int(2) // Change this to 1 for flat rect, to 3 or 4 for different patterns

in vec4 f_color;

out vec4 frag_color;

float sin01(float x) {
    return (sin(x) + 1.0) / 2.0;
}

void main() {
    vec2 uv = gl_FragCoord.xy / window_size;

    float t_even = round(float(int(uv.y * float(RECT_COUNT)) % SAW_COUNT));
    float offset_even = mix(0.0, RECT_OFFSET, t_even);
    float color_t = floor(1.0 - uv.x + progress + (RECT_OFFSET * uv.x) - offset_even);
    frag_color = mix(vec4(0), RECT_COLOR * f_color, color_t);
}
@end

@program swipe vs fs
