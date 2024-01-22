@header package shader_sprite
@header import sg "../../sokol-odin/sokol/gfx"
@header import "../"; @(init) shader_init :: proc() { shaders.shaders["shader_sprite"] = sprite_shader_desc }
@header import "core:math/linalg"
@ctype mat4 linalg.Matrix4x4f32

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
uniform texture2D texture4;
uniform texture2D texture5;
uniform texture2D texture6;
uniform texture2D texture7;
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

/*
Resources concerning this shader:
- https://hero.handmade.network/episode/chat/chat018/
- https://jorenjoestar.github.io/post/pixel_art_filtering/
- https://www.shadertoy.com/view/MlB3D3
- https://medium.com/@michelotti.matthew/rendering-pixel-art-c07a85d2dc43
- https://colececil.io/blog/2017/scaling-pixel-art-without-destroying-it/
*/
void main() {
    vec2 uv = f_t_position + f_t_size * f_uv;

    vec2 texture_size;
    if (int(f_t_index) == 0) {
        texture_size = vec2(textureSize(texture0, 0));
    } else if (int(f_t_index) == 1) {
        texture_size = vec2(textureSize(texture1, 0));
    } else if (int(f_t_index) == 2) {
        texture_size = vec2(textureSize(texture2, 0));
    } else if (int(f_t_index) == 3) {
        texture_size = vec2(textureSize(texture3, 0));
    } else if (int(f_t_index) == 4) {
        texture_size = vec2(textureSize(texture4, 0));
    } else if (int(f_t_index) == 5) {
        texture_size = vec2(textureSize(texture5, 0));
    } else if (int(f_t_index) == 6) {
        texture_size = vec2(textureSize(texture6, 0));
    } else {
        texture_size = vec2(textureSize(texture7, 0));
    }

    { // Pixel AA
        vec2 pix = uv * texture_size;
        vec2 fat_pixel = pix;
        fat_pixel.x = floor(pix.x) + smoothstep(0.0, 1.0, fract(pix.x) / fwidth(pix.x)) - 0.5;
        fat_pixel.y = floor(pix.y) + smoothstep(0.0, 1.0, fract(pix.y) / fwidth(pix.y)) - 0.5;
        uv = fat_pixel / texture_size;
    }

    if (int(f_t_index) == 0) {
        frag_color = texture(sampler2D(texture0, smp), uv);
    } else if (int(f_t_index) == 1) {
        frag_color = texture(sampler2D(texture1, smp), uv);
    } else if (int(f_t_index) == 2) {
        frag_color = texture(sampler2D(texture2, smp), uv);
    } else if (int(f_t_index) == 3) {
        frag_color = texture(sampler2D(texture3, smp), uv);
    } else if (int(f_t_index) == 4) {
        frag_color = texture(sampler2D(texture4, smp), uv);
    } else if (int(f_t_index) == 5) {
        frag_color = texture(sampler2D(texture5, smp), uv);
    } else if (int(f_t_index) == 6) {
        frag_color = texture(sampler2D(texture6, smp), uv);
    } else {
        frag_color = texture(sampler2D(texture7, smp), uv);
    }

    int palette_index = int(f_palette);
    float t = clamp(palette_index, 0, 1);
    int index = int(frag_color.r * 255) + int(palette_index - 1) * PALETTE_SIZE;
    frag_color.xyz = mix(frag_color.xyz, palettes[index].xyz, t);

    frag_color *= f_color;
}
@end

@program sprite vs fs
