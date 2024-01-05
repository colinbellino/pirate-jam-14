package game

import "core:log"
import "core:time"
import "core:math/rand"
import stb_image "vendor:stb/image"
import engine "../engine_v2"
import shader_sprite "../shaders/shader_sprite"

Bunny :: struct {
    position: engine.Vector2f32,
    color:    engine.Vector4f32,
}

Bunnies :: struct {
    data:                   [MAX_BUNNIES]Bunny,
    speed:                  [MAX_BUNNIES]engine.Vector2f32,
    count:                  int,
    elements_base:          int,
    elements_num:           int,
    pass_action:            engine.Pass_Action,
    pipeline:               engine.Pipeline,
    bindings:               engine.Bindings,
}

Lines :: struct {
    pass_action:            engine.Pass_Action,
    pipeline:               engine.Pipeline,
    bindings:               engine.Bindings,
}

MAX_BUNNIES           :: 100_000

lines_init :: proc(lines: ^Lines) {
    lines.pass_action.colors[0] = { load_action = .DONTCARE }
}

bunnies_init :: proc(bunnies: ^Bunnies) {
    engine.profiler_zone("bunnies_init")
    bunnies.elements_base = 0
    bunnies.elements_num = 6
    bunnies.pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.2, 0.2, 0.2, 1.0 } }
    bunnies.bindings.fs.samplers[shader_sprite.SLOT_smp] = engine.make_sampler({
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    })

    // index buffer for static geometry
    indices := [?]u16 {
        0, 1, 2,
        0, 2, 3,
    }
    bunnies.bindings.index_buffer = engine.make_buffer({
        type = .INDEXBUFFER,
        data = engine.Range { &indices, size_of(indices) },
        label = "geometry-indices",
    })

    // vertex buffer for static geometry, goes into vertex-buffer-slot 0
    vertices := [?]f32 {
        -1, +1,
        +1, +1,
        +1, -1,
        -1, -1,
    } * 0.05
    bunnies.bindings.vertex_buffers[0] = engine.make_buffer({
        data = engine.Range { &vertices, size_of(vertices) },
        label = "geometry-vertices",
    })

    // empty, dynamic instance-data vertex buffer, goes into vertex-buffer-slot 1
    bunnies.bindings.vertex_buffers[1] = engine.make_buffer({
        size = MAX_BUNNIES * size_of(Bunny),
        usage = .STREAM,
        label = "instance-data",
    })

    bunnies.pipeline = engine.make_pipeline({
        layout = {
            buffers = { 1 = { step_func = .PER_INSTANCE }},
            attrs = {
                shader_sprite.ATTR_vs_pos =        { format = .FLOAT2, buffer_index = 0 },
                shader_sprite.ATTR_vs_inst_pos =   { format = .FLOAT2, buffer_index = 1 },
                shader_sprite.ATTR_vs_inst_color = { format = .FLOAT4, buffer_index = 1 },
            },
        },
        shader = engine.make_shader(shader_sprite.sprite_shader_desc(engine.query_backend())),
        index_type = .UINT16,
        cull_mode = .BACK,
        depth = {
            compare = .LESS_EQUAL,
            write_enabled = true,
        },
        colors = {
            0 = {
                write_mask = .RGBA,
                blend = {
                    enabled = true,
                    src_factor_rgb = .SRC_ALPHA,
                    dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                },
            },
        },
        label = "instancing-pipeline",
    })

    bunnies.bindings.fs.images[shader_sprite.SLOT_tex] = engine.alloc_image()
    width, height, channels_in_file: i32
    pixels := stb_image.load("../src/bunny_raylib/wabbit.png", &width, &height, &channels_in_file, 0)
    assert(pixels != nil, "couldn't load image")
    // TODO: free pixels?

    engine.init_image(bunnies.bindings.fs.images[shader_sprite.SLOT_tex], {
        width = width,
        height = height,
        data = {
            subimage = { 0 = { 0 = {
                ptr = pixels,
                size = u64(width * height * channels_in_file),
            }, }, },
        },
    })
}

bunnies_spawn :: proc(bunnies: ^Bunnies, window_size: Vector2i32, spawn_position: Vector2f32 = { 0, 0 }) {
    engine.profiler_zone("bunnies_spawn")
    for i := 0; i < 100; i += 1 {
        if bunnies.count < MAX_BUNNIES {
            bunnies.data[bunnies.count].position = spawn_position
            bunnies.data[bunnies.count].color = {
                f32(rand.float32_range(50, 240)) / 255,
                f32(rand.float32_range(80, 240)) / 255,
                f32(rand.float32_range(100, 240)) / 255,
                1,
            }
            bunnies.speed[bunnies.count].x = rand.float32_range(-250, 250) / 30
            bunnies.speed[bunnies.count].y = rand.float32_range(-250, 250) / 30
            bunnies.count += 1
        }
    }
}

bunnies_move :: proc(bunnies: ^Bunnies, window_size: Vector2i32) {
    engine.profiler_zone("bunnies_move")
    offset := Vector2i32 { 0, 0 }
    @(static) ratio := Vector2f32 { 1, 1 }
    ratio = { 1_000 / f32(window_size.x), 1_000 / f32(window_size.y) }
    // @(static) ratio := Vector2f32 { 0.58, 0.95 }
    engine.ui_input_float2("ratio", cast(^[2]f32) &ratio)
    for i := 0; i < bunnies.count; i += 1 {
        bunnies.data[i].position.x += bunnies.speed[i].x
        bunnies.data[i].position.y += bunnies.speed[i].y

        if (f32(bunnies.data[i].position.x) > f32(window_size.x) * ratio.x) || (f32(bunnies.data[i].position.x) < -f32(window_size.x) * ratio.x) {
            bunnies.speed[i].x *= -1
        }
        if (f32(bunnies.data[i].position.y) > f32(window_size.y) * ratio.y) || (f32(bunnies.data[i].position.y) < -f32(window_size.y) * ratio.y) {
            bunnies.speed[i].y *= -1
        }
    }
}

bunnies_update :: proc(bunnies: ^Bunnies) {
    if bunnies.count > 0 {
        engine.profiler_zone("bunnies_update")
        engine.update_buffer(bunnies.bindings.vertex_buffers[1], {
            ptr = &bunnies.data,
            size = u64(bunnies.count) * size_of(Bunny),
        })
    }
}

game_mode_debug :: proc() {
    @(static) entered_at: time.Time
    @(static) bunnies: Bunnies
    @(static) lines: Lines

    window_size := engine.get_window_size()
    mouse_position := engine.mouse_get_position()
    engine.ui_text("window_size:    %v", window_size)
    engine.ui_text("mouse_position: %v", mouse_position)

    if game_mode_entering() {
        log.debug("[DEBUG] enter")
        entered_at = time.now()
        // engine.asset_load(_mem.game.asset_image_spritesheet, engine.Image_Load_Options { engine.RENDERER_FILTER_NEAREST, engine.RENDERER_CLAMP_TO_EDGE })

        bunnies_init(&bunnies)
        bunnies_spawn(&bunnies, window_size)
        lines_init(&lines)
    }

    if game_mode_running() {
        when ODIN_DEBUG {
            state := engine.query_pipeline_state(bunnies.pipeline)
            if state == .INVALID {
                bunnies.count = 0
                bunnies_init(&bunnies)
                bunnies_spawn(&bunnies, window_size)
                lines_init(&lines)
            }

            if engine.mouse_button_is_down(.Left) {
                // FIXME: translate mouse position (window space) to render space
                bunnies_spawn(&bunnies, window_size, { f32(mouse_position.x), f32(mouse_position.y) })
            }
            if engine.mouse_button_is_down(.Right) {
                bunnies.count = 0
            }

            if engine.ui_tree_node("bunnies") {
                for i := 0; i < bunnies.count; i += 1 {
                    engine.ui_text("%v pos: %v, color: %v, speed: %v", i, bunnies.data[i].position, bunnies.data[i].color, bunnies.speed[i])
                }
            }
        }

        bunnies_move(&bunnies, window_size)
        bunnies_update(&bunnies)
        { // Lines
            engine.profiler_zone("lines")
            engine.gl_line({ 0, 0, 0 }, { +1, +1, 0 }, { 1, 0, 0, 1 })
            engine.gl_line({ 0, 0, 0 }, { +1, -1, 0 }, { 1, 1, 0, 1 })
            engine.gl_line({ 0, 0, 0 }, { -1, -1, 0 }, { 0, 1, 0, 1 })
            engine.gl_line({ 0, 0, 0 }, { -1, +1, 0 }, { 0, 1, 1, 1 })
        }

        engine.begin_default_pass(bunnies.pass_action, window_size.x, window_size.y)
            engine.apply_pipeline(bunnies.pipeline)
            engine.apply_bindings(bunnies.bindings)
            engine.draw(bunnies.elements_base, bunnies.elements_num, bunnies.count)
            // engine.gl_draw()
        engine.end_pass()

        engine.begin_default_pass(lines.pass_action, window_size.x, window_size.y)
            // engine.apply_pipeline(bunnies.pipeline)
            // engine.apply_bindings(bunnies.bindings)
            engine.gl_draw()
        engine.end_pass()

        engine.commit()

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
