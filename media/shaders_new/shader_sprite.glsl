@header package shader_quad
@header import sg "../../sokol-odin/sokol/gfx"

@vs vs
uniform vs_uniform {
    mat4 projection;
    mat4 view;
    mat4 model;
};
in vec2 pos;
in vec2 inst_pos;
in vec4 inst_color;
out vec4 color;

void main() {
    gl_Position = projection * view * model * vec4(inst_pos + pos, 0.0, 1.0);
    color = inst_color;
}
@end

@fs fs
in vec4 color;
out vec4 frag_color;

void main() {
    frag_color = color;
}
@end

@program sprite vs fs
