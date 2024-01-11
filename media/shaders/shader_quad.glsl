@header package shader_quad
@header import sg "../../sokol-odin/sokol/gfx"
@header import "../"; @(init) shader_init :: proc() { shaders.shaders["shader_quad"] = quad_shader_desc }
@header import "core:math/linalg"
@ctype mat4 linalg.Matrix4x4f32
@ctype vec2 linalg.Vector2f32
@ctype vec4 linalg.Vector4f32

@vs vs
in vec2 position;
in vec4 color;

out vec4 v_color;

void main() {
    gl_Position = vec4(position, 0.0, 1.0);
    v_color = color;
}
@end

@fs fs
in vec4 v_color;

out vec4 frag_color;

void main() {
    frag_color = vec4(1, 0, 0, 0);
}
@end

@program quad vs fs
