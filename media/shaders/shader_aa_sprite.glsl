#shader vertex
#version 410 core

layout(location = 0) in vec4 i_position;
layout(location = 1) in vec4 i_color;
layout(location = 2) in vec2 i_texture_coordinates;
layout(location = 3) in float i_texture_index;

uniform mat4 u_model_view_projection;

out vec4 v_color;
out vec2 v_texture_coordinates;
out float v_texture_index;

void main() {
    gl_Position = u_model_view_projection * i_position;
    v_color = i_color;
    v_texture_coordinates = i_texture_coordinates;
    v_texture_index = i_texture_index;
}

#shader fragment
#version 410 core

in vec4 v_color;
in vec2 v_texture_coordinates;
in float v_texture_index;

uniform sampler2D u_textures[16];
uniform float u_texels_per_pixel;

layout(location = 0) out vec4 o_color;

/*
Resources concerning this shader:
- https://hero.handmade.network/episode/chat/chat018/
- https://jorenjoestar.github.io/post/pixel_art_filtering/
- https://www.shadertoy.com/view/MlB3D3
- https://medium.com/@michelotti.matthew/rendering-pixel-art-c07a85d2dc43
- https://colececil.io/blog/2017/scaling-pixel-art-without-destroying-it/
*/
void main() {
    int texture_index = int(v_texture_index);
    vec2 texture_size = vec2(textureSize(u_textures[texture_index], 0));

    vec2 pix = v_texture_coordinates * texture_size;
    vec2 fat_pixel = pix;
    fat_pixel = floor(pix) + smoothstep(0.0, 1.0, fract(pix) / fwidth(pix)) - 0.5;
    vec2 uv_fat_pixel = fat_pixel / texture_size;
    o_color = texture(u_textures[texture_index], uv_fat_pixel) * v_color;
}
