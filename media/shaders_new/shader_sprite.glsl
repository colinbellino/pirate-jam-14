@header package shader_sprite
@header import sg "../../sokol-odin/sokol/gfx"
@header import "../"; @(init) shader_init :: proc() { shaders.shaders["shader_sprite"] = sprite_shader_desc }

@vs vs
uniform vs_uniform {
    mat4 mvp;
};

in vec2 position;
in vec2 uv;

in vec2 i_position;
in vec2 i_scale;
in vec4 i_color;
in vec2 i_t_position;
in vec2 i_t_size;
in float i_t_index;
in float i_palette;

out vec4 f_color;
out vec2 f_uv;
out vec2 f_t_position;
out vec2 f_t_size;
out float f_t_index;
out float f_palette;

void main() {
    vec4 position_v4 = vec4(position * i_scale, 0.0, 1.0);
    vec4 i_position_v4 = vec4(i_position, 0.0, 1.0);
    gl_Position = mvp * (i_position_v4 + position_v4);
    f_color = i_color;
    f_uv = uv;
    f_t_position = i_t_position;
    f_t_size = i_t_size;
    f_t_index = i_t_index;
    f_palette = i_palette;
}
@end

@fs fs
#extension GL_EXT_samplerless_texture_functions: enable

const int PALETTE_SIZE = 32;
const int PALETTE_MAX = 4;

// Imporant: right now, sokol-shdc ignores layout(position) and just use the order in which they are used in the code!
uniform texture2D texture0;
uniform texture2D texture1;
uniform texture2D texture2;
uniform texture2D texture3;
uniform sampler smp;

uniform fs_uniform {
    vec4[PALETTE_MAX * PALETTE_SIZE] palettes;
};

in vec4 f_color;
in vec2 f_uv;
in vec2 f_t_position;
in vec2 f_t_size;
in float f_t_index;
in float f_palette;

out vec4 frag_color;

void main() {
    vec2 uv = f_t_position + f_t_size * f_uv;
    if (int(f_t_index) == 0) {
        frag_color = texture(sampler2D(texture0, smp), uv);
    } else if (int(f_t_index) == 1) {
        frag_color = texture(sampler2D(texture1, smp), uv);
    } else if (int(f_t_index) == 2) {
        frag_color = texture(sampler2D(texture2, smp), uv);
    } else {
        frag_color = texture(sampler2D(texture3, smp), uv);
    }

    int palette_index = int(f_palette);
    float t = clamp(palette_index, 0, 1);
    int index = int(frag_color.r * 255) + int(palette_index - 1) * PALETTE_SIZE;
    frag_color.xyz = mix(frag_color.xyz, palettes[index].xyz, t);

    frag_color *= f_color;
}
@end

@program sprite vs fs
