@header package shader_sprite
@header import sg "../../sokol-odin/sokol/gfx"

@vs vs
uniform vs_uniform {
    mat4 projection_view;
};

in vec2 position;
in vec2 uv;

// in mat4 inst_model;
// in vec4 inst_model0;
// in vec4 inst_model1;
// in vec4 inst_model2;
// in vec4 inst_model3;
in vec2 inst_position;
in vec4 inst_color;

out vec4 f_color;
out vec2 f_uv;

void main() {
    // mat4 inst_model = mat4(
    //     inst_model0.x, inst_model1.x, inst_model2.x, inst_model3.x,
    //     inst_model0.y, inst_model1.y, inst_model2.y, inst_model3.y,
    //     inst_model0.z, inst_model1.z, inst_model2.z, inst_model3.z,
    //     inst_model0.w, inst_model1.w, inst_model2.w, inst_model3.w
    // );
    mat4 scale = mat4(
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    );
    gl_Position = projection_view * vec4(inst_position + position, 0.0, 1.0);
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
    frag_color = f_color;
    frag_color = vec4(1, 1, 0, 1);
}
@end

@program sprite vs fs
