package main

import "core:time"
import "core:strings"
import "core:runtime"
import "core:os"
import "core:mem"
import "core:math/rand"
import "core:math/linalg/glsl"
import "core:math"
import "core:log"
import "core:fmt"
import "core:intrinsics"
import stb_image "vendor:stb/image"
import "../engine"
import "../shaders/shader_sprite"

Vector4f32 :: engine.Vector4f32
Vector2f32 :: engine.Vector2f32

MAX_SPRITES           :: 100_000

Render_Command_Draw_Sprite :: struct {
    pass_action:            engine.Pass_Action,
    pipeline:               engine.Pipeline,
    bindings:               engine.Bindings,
    vs_uniform:             shader_sprite.Vs_Uniform,
    fs_uniform:             shader_sprite.Fs_Uniform,
    count:                  int,
    speed:                  [MAX_SPRITES] Vector2f32,
    data:                   [MAX_SPRITES] struct {
        position:               Vector2f32,
        scale:                  Vector2f32,
        color:                  Vector4f32,
        texture_position:       Vector2f32,
        texture_size:           Vector2f32,
        texture_index:          f32,
        palette:                f32,
    },
}

App_Memory :: struct {
    allocator:              runtime.Allocator,
    // Platform
    engine_state:           rawptr,
    last_reload:            time.Time,
    // Game
    bunnies:                Render_Command_Draw_Sprite,
    palettes:               [engine.PALETTE_MAX]engine.Color_Palette,
    asset_shader_sprite:    engine.Asset_Id,
}

@(private="package") _mem: ^App_Memory

@(export) app_init :: proc() -> rawptr {
    context.allocator = runtime.Allocator { log_allocator_proc, nil }
    _mem = new(App_Memory)
    _mem.allocator = context.allocator
    _mem.engine_state = engine.init_and_open_window({ 800, 800 })
    context.logger = engine.logger_get_logger()

    _mem.palettes[0] = engine.r_make_palette({
        /*  0 */ { 0, 0, 0, 255 },
        /*  1 */ { 34, 32, 52, 255 },
        /*  2 */ { 69, 40, 60, 255 },
        /*  3 */ { 102, 57, 49, 255 },
        /*  4 */ { 143, 86, 59, 255 },
        /*  5 */ { 223, 113, 38, 255 },
        /*  6 */ { 217, 160, 102, 255 },
        /*  7 */ { 238, 195, 154, 255 },
        /*  8 */ { 251, 242, 54, 255 },
        /*  9 */ { 153, 229, 80, 255 },
        /* 10 */ { 106, 190, 48, 255 },
        /* 11 */ { 55, 148, 110, 255 },
        /* 12 */ { 75, 105, 47, 255 },
        /* 13 */ { 82, 75, 36, 255 },
        /* 14 */ { 50, 60, 57, 255 },
        /* 15 */ { 63, 63, 116, 255 },
        /* 16 */ { 48, 96, 130, 255 },
        /* 17 */ { 91, 110, 225, 255 },
        /* 18 */ { 99, 155, 255, 255 },
        /* 19 */ { 95, 205, 228, 255 },
        /* 20 */ { 203, 219, 252, 255 },
        /* 21 */ { 255, 255, 255, 255 },
        /* 22 */ { 155, 173, 183, 255 },
        /* 23 */ { 132, 126, 135, 255 },
        /* 24 */ { 105, 106, 106, 255 },
        /* 25 */ { 89, 86, 82, 255 },
        /* 26 */ { 118, 66, 138, 255 },
        /* 27 */ { 172, 50, 50, 255 },
        /* 28 */ { 217, 87, 99, 255 },
        /* 29 */ { 215, 123, 186, 255 },
        /* 30 */ { 143, 151, 74, 255 },
        /* 31 */ { 138, 111, 48, 255 },
    })

    engine.asset_load(engine.asset_add("media/audio/sounds/confirm.mp3", .Audio))
    engine.asset_load(engine.asset_add("media/audio/sounds/cancel.mp3", .Audio))
    engine.asset_load(engine.asset_add("media/audio/sounds/hit.mp3", .Audio))
    _mem.asset_shader_sprite = engine.asset_add("shader_sprite", .Shader)
    engine.asset_load(_mem.asset_shader_sprite)
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
            if _mem.bunnies.count < MAX_SPRITES {
                // _mem.bunnies.data[_mem.bunnies.count].position = { f32(mouse_position.x), f32(mouse_position.y) }
                _mem.bunnies.data[_mem.bunnies.count].position = { f32(0), f32(0) }
                _mem.bunnies.data[_mem.bunnies.count].scale = { 0.1, -0.1 }
                _mem.bunnies.data[_mem.bunnies.count].texture_position = { 0, 0 }
                _mem.bunnies.data[_mem.bunnies.count].texture_size = { 1, 1 }
                _mem.bunnies.data[_mem.bunnies.count].texture_index = 0
                _mem.bunnies.data[_mem.bunnies.count].palette = 0
                _mem.bunnies.data[_mem.bunnies.count].color = {
                    f32(rand.float32_range(50, 240)) / 255,
                    f32(rand.float32_range(80, 240)) / 255,
                    f32(rand.float32_range(100, 240)) / 255,
                    1,
                }
                _mem.bunnies.speed[_mem.bunnies.count].x = rand.float32_range(-1, 1) / 30
                _mem.bunnies.speed[_mem.bunnies.count].y = rand.float32_range(-1, 1) / 30
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
        engine.sg_update_buffer(_mem.bunnies.bindings.vertex_buffers[1], {
            ptr = &_mem.bunnies.data,
            size = u64(_mem.bunnies.count) * size_of(_mem.bunnies.data[0]),
        })
        _mem.bunnies.vs_uniform.mvp = glsl.identity(glsl.mat4)
    }

    { // Lines
        engine.profiler_zone("lines")
        engine.r_draw_line({ 0, 0, 0, 0 }, { +1, +1, 0, 0 }, { 1, 0, 0, 1 })
        engine.r_draw_line({ 0, 0, 0, 0 }, { +1, -1, 0, 0 }, { 1, 1, 0, 1 })
        engine.r_draw_line({ 0, 0, 0, 0 }, { -1, -1, 0, 0 }, { 0, 1, 0, 1 })
        engine.r_draw_line({ 0, 0, 0, 0 }, { -1, +1, 0, 0 }, { 0, 1, 1, 1 })
    }

    { // Draw
        engine.profiler_zone("draw")
        engine.sg_begin_default_pass(_mem.bunnies.pass_action, window_size.x, window_size.y)
            engine.sg_apply_pipeline(_mem.bunnies.pipeline)
            engine.sg_apply_bindings(_mem.bunnies.bindings)
            engine.sg_apply_uniforms(.VS, 0, { &_mem.bunnies.vs_uniform, size_of(_mem.bunnies.vs_uniform) })
            engine.sg_apply_uniforms(.FS, 0, { &_mem.bunnies.fs_uniform, size_of(_mem.bunnies.fs_uniform) })
            engine.sg_draw(0, 6, _mem.bunnies.count)
            engine.sgl_draw()
        engine.sg_end_pass()

        engine.sg_commit()
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
    command := &_mem.bunnies
    command.pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.1, 0.1, 0.1, 1 } }
    command.bindings.fs.samplers[shader_sprite.SLOT_smp] = engine.sg_make_sampler({
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    })

    // index buffer for static geometry
    indices := [?]u16 {
        0, 1, 2,
        0, 2, 3,
    }
    command.bindings.index_buffer = engine.sg_make_buffer({
        type = .INDEXBUFFER,
        data = { &indices, size_of(indices) },
        label = "geometry-indices",
    })

    // vertex buffer for static geometry, goes into vertex-buffer-slot 0
    vertices := [?]f32 {
        // position     // uv
        +0.5, +0.5,     1, 1,
        -0.5, +0.5,     0, 1,
        -0.5, -0.5,     0, 0,
        +0.5, -0.5,     1, 0,
    }
    command.bindings.vertex_buffers[0] = engine.sg_make_buffer({
        data = { &vertices, size_of(vertices) },
        label = "geometry-vertices",
    })

    // empty, dynamic instance-data vertex buffer, goes into vertex-buffer-slot 1
    command.bindings.vertex_buffers[1] = engine.sg_make_buffer({
        size = len(command.data) * size_of(command.data[0]),
        usage = .STREAM,
        label = "instance-data",
    })

    asset_id := _mem.asset_shader_sprite
    asset_info, asset_info_ok := engine.asset_get_asset_info_shader(asset_id)
    assert(asset_info_ok, fmt.tprintf("shader not loaded: %v", asset_id))

    command.pipeline = engine.sg_make_pipeline({
        layout = {
            buffers = { 1 = { step_func = .PER_INSTANCE }},
            attrs = {
                shader_sprite.ATTR_vs_position =           { format = .FLOAT2, buffer_index = 0 },
                shader_sprite.ATTR_vs_uv =                 { format = .FLOAT2, buffer_index = 0 },
                shader_sprite.ATTR_vs_i_position =         { format = .FLOAT2, buffer_index = 1 },
                shader_sprite.ATTR_vs_i_scale =            { format = .FLOAT2, buffer_index = 1 },
                shader_sprite.ATTR_vs_i_color =            { format = .FLOAT4, buffer_index = 1 },
                shader_sprite.ATTR_vs_i_t_position =       { format = .FLOAT2, buffer_index = 1 },
                shader_sprite.ATTR_vs_i_t_size =           { format = .FLOAT2, buffer_index = 1 },
                shader_sprite.ATTR_vs_i_t_index =          { format = .FLOAT,  buffer_index = 1 },
                shader_sprite.ATTR_vs_i_palette =          { format = .FLOAT,  buffer_index = 1 },
            },
        },
        shader = asset_info,
        index_type = .UINT16,
        cull_mode = .NONE,
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

    command.bindings.fs.images[shader_sprite.SLOT_texture0] = engine.sg_alloc_image()
    command.bindings.fs.images[shader_sprite.SLOT_texture1] = engine.sg_alloc_image()
    command.bindings.fs.images[shader_sprite.SLOT_texture2] = engine.sg_alloc_image()
    command.bindings.fs.images[shader_sprite.SLOT_texture3] = engine.sg_alloc_image()
    width, height, channels_in_file: i32
    path : cstring = "./src/bunny_raylib/wabbit.png"
    when ODIN_DEBUG {
        path = "../src/bunny_raylib/wabbit.png"
    }
    pixels := stb_image.load(path, &width, &height, &channels_in_file, 0)
    assert(pixels != nil, "couldn't load image")
    // TODO: free pixels?

    engine.sg_init_image(command.bindings.fs.images[shader_sprite.SLOT_texture0], {
        width = width,
        height = height,
        data = {
            subimage = { 0 = { 0 = {
                ptr = pixels,
                size = u64(width * height * channels_in_file),
            }, }, },
        },
    })
    engine.sg_init_image(command.bindings.fs.images[shader_sprite.SLOT_texture1], {
        width = width,
        height = height,
        data = {
            subimage = { 0 = { 0 = {
                ptr = pixels,
                size = u64(width * height * channels_in_file),
            }, }, },
        },
    })
    engine.sg_init_image(command.bindings.fs.images[shader_sprite.SLOT_texture2], {
        width = width,
        height = height,
        data = {
            subimage = { 0 = { 0 = {
                ptr = pixels,
                size = u64(width * height * channels_in_file),
            }, }, },
        },
    })
    engine.sg_init_image(command.bindings.fs.images[shader_sprite.SLOT_texture3], {
        width = width,
        height = height,
        data = {
            subimage = { 0 = { 0 = {
                ptr = pixels,
                size = u64(width * height * channels_in_file),
            }, }, },
        },
    })

    command.fs_uniform.palettes = transmute([128][4]f32) _mem.palettes
}

log_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []byte, error: mem.Allocator_Error) {
    data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location)
    log.debugf("[HEAP_ALLOC] %v %v %v byte %v %v %v %v", mode, allocator_data, size, alignment, old_memory, old_size, location)
    return
}
