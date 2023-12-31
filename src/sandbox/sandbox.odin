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
import "core:c/libc"
import "vendor:sdl2"
import rl "vendor:raylib"
import gl "vendor:OpenGL"
import stb_image "vendor:stb/image"
import imgui "../odin-imgui"
import "../engine"
import er "../engine_renderer"
import "../shaders/shader_quad"

MAX_BUNNIES           :: 100_000
MAX_BATCH_ELEMENTS    :: 8192
DESIRED_MAJOR_VERSION :: 3
DESIRED_MINOR_VERSION :: 3

Bunny :: struct {
    position: linalg.Vector2f32,
    color:    linalg.Vector4f32,
}

Frame_Stat :: struct {
    fps:            f32,
    sleep_time:     f32,
    target_fps:     f32,
    delta_time:     f32,
}

App_Memory :: struct {
    logger:             runtime.Logger,
    allocator:          runtime.Allocator,
    // Platform
    platform_frame:     Frame_Stat,
    screen_width:       i32,
    screen_height:      i32,
    frame_start:        u64,
    mouse_position:     [2]i32,
    mouse_left_down:    bool,
    mouse_right_down:   bool,
    should_quit:        bool,
    window:             ^sdl2.Window,
    gl_context:         sdl2.GLContext,
    last_reload:        time.Time,
    // Renderer
    bindings:           er.Bindings,
    pass_action:        er.Pass_Action,
    pipeline:           er.Pipeline,
    // Game
    bunnies_count:      int,
    bunnies:            [MAX_BUNNIES]Bunny,
    bunnies_speed:      [MAX_BUNNIES]linalg.Vector2f32,
}

@(private="package") _mem: ^App_Memory
@(private="package") track: mem.Tracking_Allocator

@(export) app_init :: proc() -> rawptr {
    context.allocator = runtime.default_allocator()
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })
    context.allocator = runtime.Allocator { log_allocator_proc, nil }
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)

    _mem = new(App_Memory)
    _mem.allocator = context.allocator
    _mem.logger = context.logger
    _mem.screen_width = 800
    _mem.screen_height = 800
    _mem.window = init_window(_mem.screen_width, _mem.screen_height)
    _mem.platform_frame.target_fps = f32(engine.platform_get_refresh_rate(_mem.window))

    app_reload(_mem)

    return _mem
}

@(export) app_update :: proc(app_memory: ^App_Memory) -> (quit: bool, reload: bool) {
    _mem = app_memory
    context.allocator = _mem.allocator
    context.logger = _mem.logger

    _mem.frame_start = sdl2.GetPerformanceCounter()

    process_inputs()

    if _mem.mouse_left_down {
        for i := 0; i < 100; i += 1 {
            if _mem.bunnies_count < MAX_BUNNIES {
                _mem.bunnies[_mem.bunnies_count].position = ({ f32(_mem.mouse_position.x), -f32(_mem.mouse_position.y) } + { -f32(_mem.screen_width) / 2, f32(_mem.screen_height) / 2 }) * 2.5
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
    if _mem.mouse_right_down {
        _mem.bunnies_count = 0
    }

    for i := 0; i < _mem.bunnies_count; i += 1 {
        _mem.bunnies[i].position.x += _mem.bunnies_speed[i].x
        _mem.bunnies[i].position.y += _mem.bunnies_speed[i].y

        if (f32(_mem.bunnies[i].position.x) > f32(_mem.screen_width) * 1.25) || (f32(_mem.bunnies[i].position.x) < -f32(_mem.screen_width) * 1.25) {
            _mem.bunnies_speed[i].x *= -1
        }
        if (f32(_mem.bunnies[i].position.y) > f32(_mem.screen_height) * 1.25) || (f32(_mem.bunnies[i].position.y) < -f32(_mem.screen_height) * 1.25) {
            _mem.bunnies_speed[i].y *= -1
        }
    }

    if _mem.bunnies_count > 0 {
        er.update_buffer(_mem.bindings.vertex_buffers[1], {
            ptr = &_mem.bunnies,
            size = u64(_mem.bunnies_count) * size_of(Bunny),
        })
    }

    { // Lines
        er.gl_line({ 0, 0, 0 }, { +1, +1, 0 }, { 1, 0, 0, 1 })
        er.gl_line({ 0, 0, 0 }, { +1, -1, 0 }, { 1, 1, 0, 1 })
        er.gl_line({ 0, 0, 0 }, { -1, -1, 0 }, { 0, 1, 0, 1 })
        er.gl_line({ 0, 0, 0 }, { -1, +1, 0 }, { 0, 1, 1, 1 })
    }

    { // Draw
        er.begin_default_pass(_mem.pass_action, _mem.screen_width, _mem.screen_height)
            er.apply_pipeline(_mem.pipeline)
            er.apply_bindings(_mem.bindings)
            er.draw(0, 6, _mem.bunnies_count)
            er.gl_draw()
        er.end_pass()

        er.commit()
    }

    when true { // GUI
        er.ui_frame_begin()

        // imgui.ShowDemoWindow(nil)
        imgui.Begin("Stats", nil, .AlwaysAutoResize)
            engine.ui_text("mouse_left_down: %v", _mem.mouse_left_down)
            engine.ui_text("mouse_right_down:%v", _mem.mouse_right_down)
            engine.ui_text("bunnies_count:   %v", _mem.bunnies_count)
            engine.ui_text("last_reload:     %v", _mem.last_reload)
            if engine.ui_tree_node("platform", { .DefaultOpen }) {
                frame := &_mem.platform_frame
                imgui.Text("target_fps:    "); imgui.SameLine(); engine.ui_slider_float("", &frame.target_fps, 1, 240)
                engine.ui_text("fps:           %3.0f", frame.fps)
                engine.ui_text("sleep_time:    %3.0f", frame.sleep_time)
                engine.ui_text("delta_time:    %3.0f", frame.delta_time)
                @(static) fps_plot := engine.Statistic_Plot {}; imgui.SetNextItemWidth(400); engine.ui_statistic_plots(&fps_plot, frame.fps, "fps", min = 0, max = 5_000)
                // @(static) delta_time_plot := engine.Statistic_Plot {}; imgui.SetNextItemWidth(400); engine.ui_statistic_plots(&delta_time_plot, frame.delta_time, "delta_time", min = 0, max = 100)
            }
        imgui.End()

        er.ui_frame_end()
    }

    sdl2.GL_SwapWindow(_mem.window)

    sdl2.SetWindowTitle(_mem.window, strings.clone_to_cstring(fmt.tprintf("SDL+Sokol (bunnies_count: %v | fps: %v)", _mem.bunnies_count, _mem.platform_frame.fps), context.temp_allocator))

    update_frame_stat(&_mem.platform_frame)
    if _mem.platform_frame.sleep_time > 0 {
        sdl2.Delay(u32(_mem.platform_frame.sleep_time))
    }

    return _mem.should_quit, false
}

@(export) app_reload :: proc(app_memory: ^App_Memory) {
    _mem = app_memory
    context.allocator = _mem.allocator
    context.logger = _mem.logger

    er.init()
    er.ui_init(_mem.window, &_mem.gl_context)
    game_init()
    log.debugf("Sandbox loaded at %v", _mem.last_reload)
}

@(export) app_quit :: proc(app_memory: ^App_Memory) {
    context.allocator = _mem.allocator
    context.logger = _mem.logger

    er.ui_quit()
    er.quit()
    free(_mem)

    if len(track.allocation_map) > 0 {
        log.errorf("=== %v allocations not freed: ===", len(track.allocation_map))
        for _, entry in track.allocation_map {
            log.errorf("- %v bytes @ %v", entry.size, entry.location)
        }
    }
    if len(track.bad_free_array) > 0 {
        log.errorf("=== %v incorrect frees: ===", len(track.bad_free_array))
        for entry in track.bad_free_array {
            log.errorf("- %p @ %v", entry.memory, entry.location)
        }
    }
    mem.tracking_allocator_destroy(&track)
}

init_window :: proc(screen_width, screen_height: i32) -> ^sdl2.Window {
    if sdl_res := sdl2.Init(sdl2.INIT_EVERYTHING); sdl_res < 0 {
        fmt.panicf("sdl2.init returned %v.", sdl_res)
    }

    _mem.window = sdl2.CreateWindow("SDL+Sokol", screen_width / 2, screen_height / 4, screen_width, screen_height, { .SHOWN, .OPENGL })
    if _mem.window == nil {
        fmt.panicf("sdl2.CreateWindow failed.\n")
    }

    sdl2.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))

    gl.load_up_to(int(DESIRED_MAJOR_VERSION), int(DESIRED_MINOR_VERSION), proc(ptr: rawptr, name: cstring) {
        (cast(^rawptr)ptr)^ = sdl2.GL_GetProcAddress(name)
    })

    _mem.gl_context = sdl2.GL_CreateContext(_mem.window)
    if _mem.gl_context == nil {
        fmt.panicf("sdl2.GL_CreateContext error: %v.\n", sdl2.GetError())
    }
    log.debugf("GL version: %s", gl.GetString(gl.VERSION))

    sdl2.GL_SetSwapInterval(0)

    return _mem.window
}

game_init :: proc() {
    _mem.pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.9, 0.9, 0.9, 1.0 } }
    _mem.bindings.fs.samplers[shader_quad.SLOT_smp] = er.make_sampler({
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    })

    // index buffer for static geometry
    indices := [?]u16 {
        0, 1, 2,
        0, 2, 3,
    }
    _mem.bindings.index_buffer = er.make_buffer({
        type = .INDEXBUFFER,
        data = er.Range { &indices, size_of(indices) },
        label = "geometry-indices",
    })

    // vertex buffer for static geometry, goes into vertex-buffer-slot 0
    vertices := [?]f32 {
        -1, +1,
        +1, +1,
        +1, -1,
        -1, -1,
    } * 0.05
    _mem.bindings.vertex_buffers[0] = er.make_buffer({
        data = er.Range { &vertices, size_of(vertices) },
        label = "geometry-vertices",
    })

    // empty, dynamic instance-data vertex buffer, goes into vertex-buffer-slot 1
    _mem.bindings.vertex_buffers[1] = er.make_buffer({
        size = MAX_BUNNIES * size_of(Bunny),
        usage = .STREAM,
        label = "instance-data",
    })

    _mem.pipeline = er.make_pipeline({
        layout = {
            buffers = { 1 = { step_func = .PER_INSTANCE }},
            attrs = {
                shader_quad.ATTR_vs_pos =        { format = .FLOAT2, buffer_index = 0 },
                shader_quad.ATTR_vs_inst_pos =   { format = .FLOAT2, buffer_index = 1 },
                shader_quad.ATTR_vs_inst_color = { format = .FLOAT4, buffer_index = 1 },
            },
        },
        shader = er.make_shader(shader_quad.quad_shader_desc(er.query_backend())),
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

    _mem.bindings.fs.images[shader_quad.SLOT_tex] = er.alloc_image()
    width, height, channels_in_file: i32
    pixels := stb_image.load("../src/bunny_raylib/wabbit.png", &width, &height, &channels_in_file, 0)
    assert(pixels != nil, "couldn't load image")
    // TODO: free pixels?

    er.init_image(_mem.bindings.fs.images[shader_quad.SLOT_tex], {
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

update_frame_stat :: proc(stat: ^Frame_Stat) {
    frame_end := sdl2.GetPerformanceCounter()
    delta_time := f32(frame_end - _mem.frame_start) * 1_000 / f32(sdl2.GetPerformanceFrequency())
    target_frame_time := 1_000 / stat.target_fps
    stat.sleep_time = target_frame_time - delta_time
    stat.fps = 1_000 / delta_time
    stat.delta_time = delta_time
}

log_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []byte, error: mem.Allocator_Error) {
    data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location)
    // log.debugf("%v %v %v byte %v %v %v %v", mode, allocator_data, size, alignment, old_memory, old_size, location)
    return
}

process_inputs :: proc() {
    e: sdl2.Event
    for sdl2.PollEvent(&e) {
        er.ui_process_event(&e)

        #partial switch e.type {
            case .QUIT: {
                _mem.should_quit = true
            }
            case .MOUSEMOTION: {
                _mem.mouse_position.x = e.motion.x
                _mem.mouse_position.y = e.motion.y
            }
            case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP: {
                if e.button.button == 1 {
                    _mem.mouse_left_down = e.type == .MOUSEBUTTONDOWN
                }
                if e.button.button == 3 {
                    _mem.mouse_right_down = e.type == .MOUSEBUTTONDOWN
                }
            }
        }
    }
}
