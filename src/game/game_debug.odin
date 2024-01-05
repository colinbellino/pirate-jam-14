package game

import "core:log"
import "core:time"
import engine "../engine_v2"

Bunny :: struct {
    position: engine.Vector2f32,
    color:    engine.Vector4f32,
}

Bunnies :: struct {
    data:                   [MAX_BUNNIES]Bunny,
    speed:                  [MAX_BUNNIES]engine.Vector2f32,
    count:                  int,
    bindings:               engine.Bindings,
    pass_action:            engine.Pass_Action,
    pipeline:               engine.Pipeline,
}

MAX_BUNNIES           :: 100_000
bunnies: Bunnies

init_bunnies :: proc() {
    // bunnies.pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.9, 0.9, 0.9, 1.0 } }
    // bunnies.bindings.fs.samplers[shader_quad.SLOT_smp] = engine.make_sampler({
    //     min_filter = .NEAREST,
    //     mag_filter = .NEAREST,
    // })

    // // index buffer for static geometry
    // indices := [?]u16 {
    //     0, 1, 2,
    //     0, 2, 3,
    // }
    // bunnies.bindings.index_buffer = engine.make_buffer({
    //     type = .INDEXBUFFER,
    //     data = engine.Range { &indices, size_of(indices) },
    //     label = "geometry-indices",
    // })

    // // vertex buffer for static geometry, goes into vertex-buffer-slot 0
    // vertices := [?]f32 {
    //     -1, +1,
    //     +1, +1,
    //     +1, -1,
    //     -1, -1,
    // } * 0.05
    // bunnies.bindings.vertex_buffers[0] = engine.make_buffer({
    //     data = engine.Range { &vertices, size_of(vertices) },
    //     label = "geometry-vertices",
    // })

    // // empty, dynamic instance-data vertex buffer, goes into vertex-buffer-slot 1
    // bunnies.bindings.vertex_buffers[1] = engine.make_buffer({
    //     size = MAX_BUNNIES * size_of(Bunny),
    //     usage = .STREAM,
    //     label = "instance-data",
    // })

    // bunnies.pipeline = engine.make_pipeline({
    //     layout = {
    //         buffers = { 1 = { step_func = .PER_INSTANCE }},
    //         attrs = {
    //             shader_quad.ATTR_vs_pos =        { format = .FLOAT2, buffer_index = 0 },
    //             shader_quad.ATTR_vs_inst_pos =   { format = .FLOAT2, buffer_index = 1 },
    //             shader_quad.ATTR_vs_inst_color = { format = .FLOAT4, buffer_index = 1 },
    //         },
    //     },
    //     shader = engine.make_shader(shader_quad.quad_shader_desc(engine.query_backend())),
    //     index_type = .UINT16,
    //     cull_mode = .BACK,
    //     depth = {
    //         compare = .LESS_EQUAL,
    //         write_enabled = true,
    //     },
    //     colors = {
    //         0 = {
    //             write_mask = .RGBA,
    //             blend = {
    //                 enabled = true,
    //                 src_factor_rgb = .SRC_ALPHA,
    //                 dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
    //             },
    //         },
    //     },
    //     label = "instancing-pipeline",
    // })

    // bunnies.bindings.fs.images[shader_quad.SLOT_tex] = engine.alloc_image()
    // width, height, channels_in_file: i32
    // pixels := stb_image.load("../src/bunny_raylib/wabbit.png", &width, &height, &channels_in_file, 0)
    // assert(pixels != nil, "couldn't load image")
    // // TODO: free pixels?

    // engine.init_image(bunnies.bindings.fs.images[shader_quad.SLOT_tex], {
    //     width = width,
    //     height = height,
    //     data = {
    //         subimage = { 0 = { 0 = {
    //             ptr = pixels,
    //             size = u64(width * height * channels_in_file),
    //         }, }, },
    //     },
    // })
}

game_mode_debug :: proc() {
    @(static) entered_at: time.Time

    if game_mode_entering() {
        log.debug("[DEBUG] enter")
        entered_at = time.now()
        // engine.asset_load(_mem.game.asset_image_spritesheet, engine.Image_Load_Options { engine.RENDERER_FILTER_NEAREST, engine.RENDERER_CLAMP_TO_EDGE })
    }

    if game_mode_running() {
        engine.renderer_clear({ 0.2, 0.2, 0.2, 1 })

        start_battle := false
        time_scale := engine.get_time_scale()
        if time_scale > 99 && time.diff(time.time_add(entered_at, time.Duration(f32(time.Second) / time_scale)), time.now()) > 0 {
            start_battle = true
        }

        if start_battle {
            log.debugf("DEBUG -> BATTLE")
            game_mode_transition(.Battle)
        }
    }

    if game_mode_exiting() {
        log.debug("[DEBUG] exit")
    }
}
