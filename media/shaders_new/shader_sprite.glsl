@header package shader_sprite
@header import sg "../../sokol-odin/sokol/gfx"

@vs vs
uniform vs_uniform {
    mat4 projection_view;
    // TODO: flip x & y
};

in vec2 position;
in vec2 uv;

in vec2 i_position;
in vec2 i_scale;
in vec4 i_color;
in vec2 i_t_position;
in vec2 i_t_size;

out vec4 f_color;
out vec2 f_uv;
out vec2 f_t_position;
out vec2 f_t_size;

void main() {
    vec4 position_v4 = vec4(position * i_scale, 0.0, 1.0);
    vec4 i_position_v4 = vec4(i_position, 0.0, 1.0);
    gl_Position = projection_view * (i_position_v4 + position_v4);
    f_color = i_color;
    f_uv = uv;
    f_t_position = i_t_position;
    f_t_size = i_t_size;
}
@end

@fs fs
#extension GL_EXT_samplerless_texture_functions: enable

uniform texture2D textures[4];
uniform sampler smp;

in vec4 f_color;
in vec2 f_uv;
in vec2 f_t_position;
in vec2 f_t_size;

out vec4 frag_color;

void main() {
    int texture_index = 0;
    ivec2 texture_size = textureSize(textures[texture_index], 0);
    vec2 uv = f_t_position + f_t_size * f_uv /* / texture_size */;
    frag_color = texture(sampler2D(textures[texture_index], smp), uv) * f_color;
}
@end

@program sprite vs fs
