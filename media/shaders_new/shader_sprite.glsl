@header package shader_quad
@header import sg "../../sokol-odin/sokol/gfx"

@vs vs
uniform vs_uniform {
    mat4 mvp;
};
in vec2 pos;
in vec2 uv;
in vec2 inst_pos;
in vec4 inst_color;
out vec4 f_color;
out vec2 f_uv;

void main() {
    gl_Position = mvp * vec4(inst_pos + pos, 0.0, 1.0);
    f_color = inst_color;
    f_uv = uv;
}
@end

@fs fs
in vec4 f_color;
in vec2 f_uv;
uniform texture2D tex;
uniform sampler smp;
out vec4 frag_color;

void main() {
    frag_color = texture(sampler2D(tex, smp), f_uv) * f_color;
}
@end

@program sprite vs fs
