@header package shader_sprite
@header import sg "../../sokol-odin/sokol/gfx"

@vs vs
in vec2 pos;
in vec2 inst_pos;

out vec2 uv;

void main() {
    gl_Position = vec4(pos + (inst_pos * 0.001), 0.0, 1.0);
    vec2 scale = vec2(10, 10);
    uv = (pos - vec2(0.5, 0.5) / scale) * -scale;
}
@end

@fs fs
in vec2 uv;
uniform texture2D tex;
uniform sampler smp;
out vec4 frag_color;

void main() {
    frag_color = texture(sampler2D(tex, smp), uv);
}
@end

@program sprite vs fs
