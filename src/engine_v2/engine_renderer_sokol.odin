package engine_v2

import "core:fmt"
import gl "vendor:OpenGL"
import sg "../sokol-odin/sokol/gfx"
import sgl "../sokol-odin/sokol/gl"
import slog "../sokol-odin/sokol/log"

Bindings :: sg.Bindings
Pass_Action :: sg.Pass_Action
Pipeline :: sg.Pipeline
Range :: sg.Range

begin_default_pass :: sg.begin_default_pass
make_pipeline :: sg.make_pipeline
apply_pipeline :: sg.apply_pipeline
apply_bindings :: sg.apply_bindings
make_sampler :: sg.make_sampler
make_shader :: sg.make_shader
make_buffer :: sg.make_buffer
update_buffer :: sg.update_buffer
draw :: sg.draw
end_pass :: sg.end_pass
query_backend :: sg.query_backend
commit :: sg.commit
init_image :: sg.init_image
alloc_image :: sg.alloc_image
gl_draw :: sgl.draw

sokol_init :: proc() {
    sg.setup({
        logger = { func = slog.func },
        allocator = { alloc_fn = sokol_alloc_fn, free_fn = sokol_free_fn },
    })
    if sg.isvalid() == false {
        fmt.panicf("sg.setup error: %v.\n", "no clue how to get errors from sokol_gfx")
    }
    assert(sg.query_backend() == .GLCORE33)

    sgl.setup({
        logger = { func = slog.func },
    })
}


sokol_quit :: proc() {
    sgl.shutdown()
    sg.shutdown()
}

gl_line :: proc(start, end: Vector3f32, color: Vector4f32) {
    sgl.defaults()
    sgl.begin_lines()
        sgl.c4f(color.r, color.g, color.b, color.a)
        sgl.v3f(start.x, start.y, start.z)
        sgl.v3f(end.x,   end.y,   end.z)
    sgl.end()
}
