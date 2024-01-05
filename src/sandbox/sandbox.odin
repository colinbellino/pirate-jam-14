package main

import "core:time"
import "core:strings"
import "core:runtime"
import "core:os"
import "core:mem"
import "core:math/rand"
import "core:math"
import "core:log"
import "core:fmt"
import "core:intrinsics"
import stb_image "vendor:stb/image"
import engine "../engine_v2"
import "../shaders/shader_quad"

MAX_BUNNIES           :: 100_000

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

App_Memory :: struct {
    allocator:              runtime.Allocator,
    // Platform
    engine_state:           rawptr,
    last_reload:            time.Time,
    // Game
    bunnies:                Bunnies,
}

@(private="package") _mem: ^App_Memory

@(export) app_init :: proc() -> rawptr {
    context.allocator = runtime.Allocator { log_allocator_proc, nil }
    _mem = new(App_Memory)
    _mem.allocator = context.allocator
    _mem.engine_state = engine.init_and_open_window({ 800, 800 })
    context.logger = engine.logger_get_logger()

    engine.asset_load(engine.asset_add("media/audio/sounds/confirm.mp3", .Audio))
    engine.asset_load(engine.asset_add("media/audio/sounds/cancel.mp3", .Audio))
    engine.asset_load(engine.asset_add("media/audio/sounds/hit.mp3", .Audio))
    init_bunnies()

    return _mem
}

@(export) app_update :: proc(app_memory: ^App_Memory) -> (quit: bool, reload: bool) {
    _mem = app_memory
    context.allocator = _mem.allocator
    context.logger = engine.logger_get_logger()

    engine.profiler_zone("app_update")

    engine.set_window_title("SDL+Sokol (bunnies_count: %v | fps: %v)", _mem.bunnies.count, engine.get_frame_stat().fps)
    engine.frame_begin()
    defer engine.frame_end()

    window_size := engine.get_window_size()
    mouse_position := engine.mouse_get_position()
    frame_stat := engine.get_frame_stat()

    if engine.mouse_button_is_down(.Left) {
        engine.profiler_zone("bunnies_spawn")
        for i := 0; i < 100; i += 1 {
            if _mem.bunnies.count < MAX_BUNNIES {
                _mem.bunnies.data[_mem.bunnies.count].position = ({ f32(mouse_position.x), -f32(mouse_position.y) } + { -f32(window_size.x) / 2, f32(window_size.y) / 2 }) * 2.5
                _mem.bunnies.data[_mem.bunnies.count].color = {
                    f32(rand.float32_range(50, 240)) / 255,
                    f32(rand.float32_range(80, 240)) / 255,
                    f32(rand.float32_range(100, 240)) / 255,
                    1,
                }
                _mem.bunnies.speed[_mem.bunnies.count].x = rand.float32_range(-250, 250) / 30
                _mem.bunnies.speed[_mem.bunnies.count].y = rand.float32_range(-250, 250) / 30
                _mem.bunnies.count += 1
            }
        }
    }
    if engine.mouse_button_is_down(.Right) {
        _mem.bunnies.count = 0
    }

    {
        engine.profiler_zone("bunnies_move")
        for i := 0; i < _mem.bunnies.count; i += 1 {
            _mem.bunnies.data[i].position.x += _mem.bunnies.speed[i].x
            _mem.bunnies.data[i].position.y += _mem.bunnies.speed[i].y

            if (f32(_mem.bunnies.data[i].position.x) > f32(window_size.x) * 1.25) || (f32(_mem.bunnies.data[i].position.x) < -f32(window_size.x) * 1.25) {
                _mem.bunnies.speed[i].x *= -1
            }
            if (f32(_mem.bunnies.data[i].position.y) > f32(window_size.y) * 1.25) || (f32(_mem.bunnies.data[i].position.y) < -f32(window_size.y) * 1.25) {
                _mem.bunnies.speed[i].y *= -1
            }
        }
    }

    if _mem.bunnies.count > 0 {
        engine.profiler_zone("bunnies_update")
        engine.update_buffer(_mem.bunnies.bindings.vertex_buffers[1], {
            ptr = &_mem.bunnies.data,
            size = u64(_mem.bunnies.count) * size_of(Bunny),
        })
    }

    { // Lines
        engine.profiler_zone("lines")
        engine.gl_line({ 0, 0, 0 }, { +1, +1, 0 }, { 1, 0, 0, 1 })
        engine.gl_line({ 0, 0, 0 }, { +1, -1, 0 }, { 1, 1, 0, 1 })
        engine.gl_line({ 0, 0, 0 }, { -1, -1, 0 }, { 0, 1, 0, 1 })
        engine.gl_line({ 0, 0, 0 }, { -1, +1, 0 }, { 0, 1, 1, 1 })
    }

    { // Draw
        engine.profiler_zone("draw")
        engine.begin_default_pass(_mem.bunnies.pass_action, window_size.x, window_size.y)
            engine.apply_pipeline(_mem.bunnies.pipeline)
            engine.apply_bindings(_mem.bunnies.bindings)
            engine.draw(0, 6, _mem.bunnies.count)
            engine.gl_draw()
        engine.end_pass()

        engine.commit()
    }

    if engine.ui_window("Debug") {
        engine.profiler_zone("ui_debug")
        if engine.ui_collapsing_header("Frame", { .DefaultOpen }) {
            engine.ui_text("last_reload:     %v", _mem.last_reload)
            engine.ui_widget_frame_stat()
            engine.ui_widget_mouse()
            engine.ui_widget_controllers()
            engine.ui_widget_keyboard()
            engine.ui_text("target_fps: %v", frame_stat.target_fps)
            if engine.ui_button("10") { engine.set_target_fps(10) }
            engine.ui_same_line()
            if engine.ui_button("30") { engine.set_target_fps(30) }
            engine.ui_same_line()
            if engine.ui_button("60") { engine.set_target_fps(60) }
            engine.ui_same_line()
            if engine.ui_button("144") { engine.set_target_fps(144) }
            engine.ui_same_line()
            if engine.ui_button("240") { engine.set_target_fps(240) }
            engine.ui_same_line()
            if engine.ui_button("999") { engine.set_target_fps(999) }
        }
        engine.ui_widget_audio()
        window_assets := false
        engine.ui_window_assets(&window_assets)
    }

    return engine.should_quit(), false
}

@(export) app_reload :: proc(app_memory: ^App_Memory) {
    _mem = app_memory
    context.logger = engine.logger_get_logger()

    _mem.last_reload = time.now()
    log.debugf("Sandbox loaded at %v", _mem.last_reload)
    engine.reload(_mem.engine_state)
    init_bunnies()
}

@(export) app_quit :: proc(app_memory: ^App_Memory) {
    engine.quit()
}

init_bunnies :: proc() {
    _mem.bunnies.pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.9, 0.9, 0.9, 1.0 } }
    _mem.bunnies.bindings.fs.samplers[shader_quad.SLOT_smp] = engine.make_sampler({
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    })

    // index buffer for static geometry
    indices := [?]u16 {
        0, 1, 2,
        0, 2, 3,
    }
    _mem.bunnies.bindings.index_buffer = engine.make_buffer({
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
    _mem.bunnies.bindings.vertex_buffers[0] = engine.make_buffer({
        data = engine.Range { &vertices, size_of(vertices) },
        label = "geometry-vertices",
    })

    // empty, dynamic instance-data vertex buffer, goes into vertex-buffer-slot 1
    _mem.bunnies.bindings.vertex_buffers[1] = engine.make_buffer({
        size = MAX_BUNNIES * size_of(Bunny),
        usage = .STREAM,
        label = "instance-data",
    })

    _mem.bunnies.pipeline = engine.make_pipeline({
        layout = {
            buffers = { 1 = { step_func = .PER_INSTANCE }},
            attrs = {
                shader_quad.ATTR_vs_pos =        { format = .FLOAT2, buffer_index = 0 },
                shader_quad.ATTR_vs_inst_pos =   { format = .FLOAT2, buffer_index = 1 },
                shader_quad.ATTR_vs_inst_color = { format = .FLOAT4, buffer_index = 1 },
            },
        },
        shader = engine.make_shader(shader_quad.quad_shader_desc(engine.query_backend())),
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

    _mem.bunnies.bindings.fs.images[shader_quad.SLOT_tex] = engine.alloc_image()
    width, height, channels_in_file: i32
    path : cstring = "./src/bunny_raylib/wabbit.png"
    when ODIN_DEBUG {
        path = "../src/bunny_raylib/wabbit.png"
    }
    pixels := stb_image.load(path, &width, &height, &channels_in_file, 0)
    assert(pixels != nil, "couldn't load image")
    // TODO: free pixels?

    engine.init_image(_mem.bunnies.bindings.fs.images[shader_quad.SLOT_tex], {
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

log_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []byte, error: mem.Allocator_Error) {
    data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location)
    log.debugf("[HEAP_ALLOC] %v %v %v byte %v %v %v %v", mode, allocator_data, size, alignment, old_memory, old_size, location)
    return
}
