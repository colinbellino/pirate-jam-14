@header package shader_quad
@header import sg "../../sokol-odin/sokol/gfx"

@vs vs
uniform vs_uniform {
    mat4 mvp;
};
in vec2 pos;
in vec2 inst_pos;
in vec4 inst_color;

out vec4 color;
out vec2 uv;

void main() {
    // gl_Position = mvp * vec4(inst_pos, 0.0, 1.0);
    vec2 size = vec2(32, -32);
    gl_Position = (mvp * vec4(pos * size, 0, 1)) + vec4((inst_pos * 0.001), 0.0, 1.0);
    // if (mvp[0][0] == 0.001) {
    //     gl_Position = vec4(pos, 0, 1) + vec4((inst_pos * 0.001), 0.0, 1.0);
    // }
    color = inst_color;
    uv = pos;
}
@end

@fs fs
in vec4 color;
in vec2 uv;
uniform texture2D tex;
uniform sampler smp;
out vec4 frag_color;

void main() {
    frag_color = texture(sampler2D(tex, smp), uv) * color;
}
@end

@program sprite vs fs
