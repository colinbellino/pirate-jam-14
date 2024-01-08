@header package shader_sprite
@header import sg "../../sokol-odin/sokol/gfx"

@vs vs
uniform vs_uniform {
    mat4 projection_view;
};

in vec2 position;
in vec2 uv;

in vec2 inst_position;
in vec2 inst_scale;
in vec4 inst_color;

out vec4 f_color;
out vec2 f_uv;

void main() {
    vec4 position_v4 = vec4(position * inst_scale, 0.0, 1.0);
    vec4 inst_position_v4 = vec4(inst_position, 0.0, 1.0);
    gl_Position = projection_view * (inst_position_v4 + position_v4);
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
