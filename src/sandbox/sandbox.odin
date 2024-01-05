package main

import "core:time"
import "core:strings"
import "core:runtime"
import "core:os"
import "core:mem"
import "core:math/rand"
import "core:math/linalg"
import "core:math"
import "core:log"
import "core:fmt"
import "core:intrinsics"
import stb_image "vendor:stb/image"
import e "../engine_v2"
import "../shaders/shader_quad"

MAX_BUNNIES           :: 100_000
MAX_BATCH_ELEMENTS    :: 8192

Bunny :: struct {
    position: linalg.Vector2f32,
    color:    linalg.Vector4f32,
}

App_Memory :: struct {
    allocator:              runtime.Allocator,
    // Platform
    engine_state:           rawptr,
    last_reload:            time.Time,
    // Game
    bindings:               e.Bindings,
    pass_action:            e.Pass_Action,
    pipeline:               e.Pipeline,
    bunnies_count:          int,
    bunnies:                [MAX_BUNNIES]Bunny,
    bunnies_speed:          [MAX_BUNNIES]linalg.Vector2f32,
}

@(private="package") _mem: ^App_Memory

@(export) app_init :: proc() -> rawptr {
    context.allocator = runtime.Allocator { log_allocator_proc, nil }
    _mem = new(App_Memory)
    _mem.allocator = context.allocator
    _mem.engine_state = e.init_and_open_window({ 800, 800 })
    context.logger = e.logger_get_logger()

    e.asset_load(e.asset_add("media/audio/sounds/confirm.mp3", .Audio))
    e.asset_load(e.asset_add("media/audio/sounds/cancel.mp3", .Audio))
    e.asset_load(e.asset_add("media/audio/sounds/hit.mp3", .Audio))
    init_bunnies()

    return _mem
}

@(export) app_update :: proc(app_memory: ^App_Memory) -> (quit: bool, reload: bool) {
    _mem = app_memory
    context.allocator = _mem.allocator
    context.logger = e.logger_get_logger()

    e.frame_begin()
    defer e.frame_end()

    window_size := e.get_window_size()
    mouse_position := e.get_mouse_position()
    frame_stat := e.get_frame_stat()

    if e.mouse_button_is_down(.Left) {
        for i := 0; i < 100; i += 1 {
            if _mem.bunnies_count < MAX_BUNNIES {
                _mem.bunnies[_mem.bunnies_count].position = ({ f32(mouse_position.x), -f32(mouse_position.y) } + { -f32(window_size.x) / 2, f32(window_size.y) / 2 }) * 2.5
                _mem.bunnies_speed[_mem.bunnies_count].x = rand.float32_range(-250, 250) / 30
                _mem.bunnies_speed[_mem.bunnies_count].y = rand.float32_range(-250, 250) / 30
                _mem.bunnies[_mem.bunnies_count].color = {
                    f32(rand.float32_range(50, 240)) / 255,
                    f32(rand.float32_range(80, 240)) / 255,
                    f32(rand.float32_range(100, 240)) / 255,
                    1,
                }
                _mem.bunnies_count += 1
            }
        }
    }
    if e.mouse_button_is_down(.Right) {
        _mem.bunnies_count = 0
    }

    for i := 0; i < _mem.bunnies_count; i += 1 {
        _mem.bunnies[i].position.x += _mem.bunnies_speed[i].x
        _mem.bunnies[i].position.y += _mem.bunnies_speed[i].y

        if (f32(_mem.bunnies[i].position.x) > f32(window_size.x) * 1.25) || (f32(_mem.bunnies[i].position.x) < -f32(window_size.x) * 1.25) {
            _mem.bunnies_speed[i].x *= -1
        }
        if (f32(_mem.bunnies[i].position.y) > f32(window_size.y) * 1.25) || (f32(_mem.bunnies[i].position.y) < -f32(window_size.y) * 1.25) {
            _mem.bunnies_speed[i].y *= -1
        }
    }

    if _mem.bunnies_count > 0 {
        e.update_buffer(_mem.bindings.vertex_buffers[1], {
            ptr = &_mem.bunnies,
            size = u64(_mem.bunnies_count) * size_of(Bunny),
        })
    }

    { // Lines
        e.gl_line({ 0, 0, 0 }, { +1, +1, 0 }, { 1, 0, 0, 1 })
        e.gl_line({ 0, 0, 0 }, { +1, -1, 0 }, { 1, 1, 0, 1 })
        e.gl_line({ 0, 0, 0 }, { -1, -1, 0 }, { 0, 1, 0, 1 })
        e.gl_line({ 0, 0, 0 }, { -1, +1, 0 }, { 0, 1, 1, 1 })
    }

    { // Draw
        e.begin_default_pass(_mem.pass_action, window_size.x, window_size.y)
            e.apply_pipeline(_mem.pipeline)
            e.apply_bindings(_mem.bindings)
            e.draw(0, 6, _mem.bunnies_count)
            e.gl_draw()
        e.end_pass()

        e.commit()
    }

    if e.ui_window("Debug") {
        if e.ui_collapsing_header("Frame", { .DefaultOpen }) {
            e.ui_text("last_reload:     %v", _mem.last_reload)
            e.ui_widget_frame_stat()
            e.ui_widget_mouse()
            e.ui_widget_controllers()
            e.ui_widget_keyboard()
            e.ui_text("target_fps: %v", frame_stat.target_fps)
            if e.ui_button("10") { e.set_target_fps(10) }
            e.ui_same_line()
            if e.ui_button("30") { e.set_target_fps(30) }
            e.ui_same_line()
            if e.ui_button("60") { e.set_target_fps(60) }
            e.ui_same_line()
            if e.ui_button("144") { e.set_target_fps(144) }
        }
        e.ui_widget_audio()
        e.ui_window_assets()
    }

    e.set_window_title("SDL+Sokol (bunnies_count: %v | fps: %v)", _mem.bunnies_count, e.get_frame_stat().fps)

    return e.should_quit(), false
}

@(export) app_reload :: proc(app_memory: ^App_Memory) {
    _mem = app_memory
    context.logger = e.logger_get_logger()

    _mem.last_reload = time.now()
    log.debugf("Sandbox loaded at %v", _mem.last_reload)
    e.reload(_mem.engine_state)
    init_bunnies()
}

@(export) app_quit :: proc(app_memory: ^App_Memory) {
    e.quit()
}

init_bunnies :: proc() {
    _mem.pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.9, 0.9, 0.9, 1.0 } }
    _mem.bindings.fs.samplers[shader_quad.SLOT_smp] = e.make_sampler({
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    })

    // index buffer for static geometry
    indices := [?]u16 {
        0, 1, 2,
        0, 2, 3,
    }
    _mem.bindings.index_buffer = e.make_buffer({
        type = .INDEXBUFFER,
        data = e.Range { &indices, size_of(indices) },
        label = "geometry-indices",
    })

    // vertex buffer for static geometry, goes into vertex-buffer-slot 0
    vertices := [?]f32 {
        -1, +1,
        +1, +1,
        +1, -1,
        -1, -1,
    } * 0.05
    _mem.bindings.vertex_buffers[0] = e.make_buffer({
        data = e.Range { &vertices, size_of(vertices) },
        label = "geometry-vertices",
    })

    // empty, dynamic instance-data vertex buffer, goes into vertex-buffer-slot 1
    _mem.bindings.vertex_buffers[1] = e.make_buffer({
        size = MAX_BUNNIES * size_of(Bunny),
        usage = .STREAM,
        label = "instance-data",
    })

    _mem.pipeline = e.make_pipeline({
        layout = {
            buffers = { 1 = { step_func = .PER_INSTANCE }},
            attrs = {
                shader_quad.ATTR_vs_pos =        { format = .FLOAT2, buffer_index = 0 },
                shader_quad.ATTR_vs_inst_pos =   { format = .FLOAT2, buffer_index = 1 },
                shader_quad.ATTR_vs_inst_color = { format = .FLOAT4, buffer_index = 1 },
            },
        },
        shader = e.make_shader(shader_quad.quad_shader_desc(e.query_backend())),
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

    _mem.bindings.fs.images[shader_quad.SLOT_tex] = e.alloc_image()
    width, height, channels_in_file: i32
    pixels := stb_image.load("../src/bunny_raylib/wabbit.png", &width, &height, &channels_in_file, 0)
    assert(pixels != nil, "couldn't load image")
    // TODO: free pixels?

    e.init_image(_mem.bindings.fs.images[shader_quad.SLOT_tex], {
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
