package main

import "vendor:sdl2"
import "core:strings"
import "core:runtime"
import "core:os"
import "core:mem"
import "core:math/rand"
import "core:math/linalg"
import "core:math"
import "core:log"
import "core:fmt"
import "core:time"
import "core:c/libc"
import rl "vendor:raylib"
import gl "vendor:OpenGL"
import sg "../sokol-odin/sokol/gfx"
import slog "../sokol-odin/sokol/log"
import sgl "../sokol-odin/sokol/gl"
import stb_image "vendor:stb/image"
import imgui "../odin-imgui"
import "../odin-imgui/imgui_impl_sdl2"
import "../odin-imgui/imgui_impl_opengl3"
import "../engine"

MAX_BUNNIES           :: 100_000
MAX_BATCH_ELEMENTS    :: 8192
DESIRED_MAJOR_VERSION :: 3
DESIRED_MINOR_VERSION :: 3
TARGET_FRAME_RATE     :: 144

Bunny :: struct {
    position: linalg.Vector2f32,
    color:    linalg.Vector4f32,
}

App_Memory :: struct {
    logger: runtime.Logger,
    allocator: runtime.Allocator,
    // Platform stuff
    screen_width: i32,
    screen_height: i32,
    frame_start: u64,
    fps: f32,
    sleep_time: f32,
    mouse_position: [2]i32,
    mouse_left_down: bool,
    mouse_right_down: bool,
    should_quit: bool,
    window: ^sdl2.Window,
    gl_context: sdl2.GLContext,
    // Renderer
    bindings: sg.Bindings,
    pass_action: sg.Pass_Action,
    pipeline: sg.Pipeline,
    // Game
    bunnies_count: int,
    bunnies: [MAX_BUNNIES]Bunny,
    bunnies_speed: [MAX_BUNNIES]linalg.Vector2f32,
    last_reload: time.Time,
}


@(private="package") _mem: ^App_Memory
track: mem.Tracking_Allocator

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

    renderer_load()
    imgui_load()
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
                _mem.bunnies_speed[_mem.bunnies_count].x = rand.float32_range(-250, 250) / 60
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
        sg.update_buffer(_mem.bindings.vertex_buffers[1], {
            ptr = &_mem.bunnies,
            size = u64(_mem.bunnies_count) * size_of(Bunny),
        })
    }

    { // Lines
        sgl.defaults()
        sgl.begin_lines()
            sgl.c4f(1, 0, 0, 1)
            sgl.v3f(0, 0, 0)
            sgl.v3f(+1, +1, 0)
            sgl.c4f(1, 1, 0, 1)
            sgl.v3f(0, 0, 0)
            sgl.v3f(+1, -1, 0)
            sgl.c4f(0, 1, 0, 1)
            sgl.v3f(0, 0, 0)
            sgl.v3f(-1, -1, 0)
            sgl.c4f(0, 1, 1, 1)
            sgl.v3f(0, 0, 0)
            sgl.v3f(-1, +1, 0)
        sgl.end()
    }

    { // Draw
        sg.begin_default_pass(_mem.pass_action, _mem.screen_width, _mem.screen_height)
            sg.apply_pipeline(_mem.pipeline)
            sg.apply_bindings(_mem.bindings)
            sg.draw(0, 6, _mem.bunnies_count)
            sgl.draw()
        sg.end_pass()

        sg.commit()
    }

    { // GUI
        imgui_impl_opengl3.NewFrame()
        imgui_impl_sdl2.NewFrame()
        imgui.NewFrame()

        // imgui.ShowDemoWindow(nil)
        imgui.Begin("Stats", nil, .AlwaysAutoResize)
        imgui.Text(strings.clone_to_cstring(fmt.tprintf("bunnies_count: %v", _mem.bunnies_count), context.temp_allocator))
        imgui.Text(strings.clone_to_cstring(fmt.tprintf("fps:           %3.0f", _mem.fps), context.temp_allocator))
        imgui.Text(strings.clone_to_cstring(fmt.tprintf("last_reload:   %v", _mem.last_reload), context.temp_allocator))
        @(static) fps_plot := engine.Statistic_Plot {}
        imgui.SetNextItemWidth(400)
        engine.ui_statistic_plots(&fps_plot, _mem.fps, "fps", min = 0, max = 5_000)
        imgui.End()

        imgui.Render()
        imgui_impl_opengl3.RenderDrawData(imgui.GetDrawData())

        when imgui.IMGUI_BRANCH == "docking" {
            backup_current_window := sdl2.GL_GetCurrentWindow()
            backup_current_context := sdl2.GL_GetCurrentContext()
            imgui.UpdatePlatformWindows()
            imgui.RenderPlatformWindowsDefault()
            sdl2.GL_MakeCurrent(backup_current_window, backup_current_context);
        }
    }

    sdl2.GL_SwapWindow(_mem.window)

    _mem.fps, _mem.sleep_time = calculate_fps()
    sdl2.SetWindowTitle(_mem.window, strings.clone_to_cstring(fmt.tprintf("SDL+Sokol (_mem.bunnies_count: %v, fps: %v)", _mem.bunnies_count, _mem.fps), context.temp_allocator))
    if _mem.sleep_time > 0 {
        sdl2.Delay(u32(_mem.sleep_time))
    }

    return _mem.should_quit, false
}

@(export) app_reload :: proc(app_memory: ^App_Memory) {
    _mem = app_memory
    context.allocator = _mem.allocator
    context.logger = _mem.logger
    _mem.last_reload = time.now()
    renderer_load()
    imgui_load()
    log.debugf("App reloaded at %v", _mem.last_reload)
}

@(export) app_quit :: proc(app_memory: ^App_Memory) {
    context.allocator = _mem.allocator
    context.logger = _mem.logger
    sg.shutdown()
    // free(_mem)

    {
        if len(track.allocation_map) > 0 {
            fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
            for _, entry in track.allocation_map {
                fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
            }
        }
        if len(track.bad_free_array) > 0 {
            fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
            for entry in track.bad_free_array {
                fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
            }
        }
        mem.tracking_allocator_destroy(&track)
    }
}

init_window :: proc(screen_width, screen_height: i32) -> ^sdl2.Window {
    if sdl_res := sdl2.Init(sdl2.INIT_EVERYTHING); sdl_res < 0 {
        fmt.panicf("sdl2.init returned %v.", sdl_res)
    }

    _mem.window = sdl2.CreateWindow("SDL+Sokol", screen_width / 2, screen_height / 4, screen_width, screen_height, { .SHOWN, .OPENGL })
    if _mem.window == nil {
        fmt.panicf("sdl2.CreateWindow failed.\n")
    }

    // sdl2.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, DESIRED_MAJOR_VERSION)
    // sdl2.GL_SetAttribute(.CONTEXT_MINOR_VERSION, DESIRED_MINOR_VERSION)
    sdl2.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))

    gl.load_up_to(int(DESIRED_MAJOR_VERSION), int(DESIRED_MINOR_VERSION), proc(ptr: rawptr, name: cstring) {
        (cast(^rawptr)ptr)^ = sdl2.GL_GetProcAddress(name)
    })

    _mem.gl_context = sdl2.GL_CreateContext(_mem.window)
    if _mem.gl_context == nil {
        fmt.panicf("sdl2.GL_CreateContext error: %v.\n", sdl2.GetError())
    }
    fmt.printf("GL version: %s\n", gl.GetString(gl.VERSION))

    sdl2.GL_SetSwapInterval(0)

    return _mem.window
}

renderer_load :: proc() {
    sg.setup({
        logger = { func = slog.func },
        allocator = { alloc_fn = alloc_fn, free_fn = free_fn },
    })
    if sg.isvalid() == false {
        fmt.panicf("sg.setup error: %v.\n", "no clue how to get errors from sokol_gfx")
    }
    log.infof("backend used: %v", sg.query_backend())
    assert(sg.query_backend() == .GLCORE33)

    sgl.setup({
        logger = { func = slog.func },
    })

    _mem.pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.9, 0.9, 0.9, 1.0 } }
    _mem.bindings.fs.images[SLOT_tex] = sg.alloc_image()
    _mem.bindings.fs.samplers[SLOT_smp] = sg.make_sampler(sg.Sampler_Desc {
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    })

    // vertex buffer for static geometry, goes into vertex-buffer-slot 0
    s := f32(0.05)
    vertices := [?]f32 {
        // positions
        -s, +s,
        +s, +s,
        +s, -s,
        -s, -s,
    }
    _mem.bindings.vertex_buffers[0] = sg.make_buffer({
        data = sg.Range { &vertices, size_of(vertices) },
        label = "geometry-vertices",
    })

    // index buffer for static geometry
    indices := [?]u16 {
        0, 1, 2,
        0, 2, 3,
    }
    _mem.bindings.index_buffer = sg.make_buffer({
        type = .INDEXBUFFER,
        data = sg.Range { &indices, size_of(indices) },
        label = "geometry-indices",
    })

    // empty, dynamic instance-data vertex buffer, goes into vertex-buffer-slot 1
    _mem.bindings.vertex_buffers[1] = sg.make_buffer({
        size = MAX_BUNNIES * size_of(Bunny),
        usage = .STREAM,
        label = "instance-data",
    })

    _mem.pipeline = sg.make_pipeline({
        layout = {
            buffers = { 1 = { step_func = .PER_INSTANCE }},
            attrs = {
                ATTR_vs_pos =        { format = .FLOAT2, buffer_index = 0 },
                ATTR_vs_inst_pos =   { format = .FLOAT2, buffer_index = 1 },
                ATTR_vs_inst_color = { format = .FLOAT4, buffer_index = 1 },
            },
        },
        shader = sg.make_shader(quad_shader_desc(sg.query_backend())),
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

    width, height, channels_in_file: i32
    {
        pixels := stb_image.load("../src/bunny_raylib/wabbit.png", &width, &height, &channels_in_file, 0)
        assert(pixels != nil, "couldn't load image")
        // TODO: free pixels?

        desc := sg.Image_Desc {
            width = width,
            height = height,
        }
        desc.data.subimage[0][0] = {
            ptr = pixels,
            size = u64(width * height * channels_in_file),
        }
        sg.init_image(_mem.bindings.fs.images[SLOT_tex], desc)
    }
}

imgui_load :: proc() {
    imgui.CHECKVERSION()
    imgui.CreateContext(nil)
    // defer imgui.DestroyContext(nil)
    io := imgui.GetIO()
    io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad}
    when imgui.IMGUI_BRANCH == "docking" {
        io.ConfigFlags += { .DockingEnable }
        io.ConfigFlags += { .ViewportsEnable }

        style := imgui.GetStyle()
        style.WindowRounding = 0
        style.Colors[imgui.Col.WindowBg].w =1
    }

    imgui_impl_sdl2.InitForOpenGL(_mem.window, &_mem.gl_context)
    // defer imgui_impl_sdl2.Shutdown()
    imgui_impl_opengl3.Init(nil)
    // defer imgui_impl_opengl3.Shutdown()
}

calculate_fps :: proc() -> (f32, f32) {
    frame_end := sdl2.GetPerformanceCounter()
    frame_time := f32(frame_end - _mem.frame_start) * 1_000 / f32(sdl2.GetPerformanceFrequency())
    target_frame_time := 1_000 / f32(TARGET_FRAME_RATE)
    sleep_time := target_frame_time - frame_time
    fps := 1_000 / frame_time
    return fps, sleep_time
}

alloc_fn :: proc "c" (size: u64, user_data: rawptr) -> rawptr {
    context = runtime.default_context()
    context.logger = _mem.logger
    ptr, err := mem.alloc(int(size), allocator = _mem.  allocator)
    if err != .None { log.errorf("alloc_fn: %v", err) }
    return ptr
}

free_fn :: proc "c" (ptr: rawptr, user_data: rawptr) {
    context = runtime.default_context()
    context.logger = _mem.logger
    err := mem.free(ptr, allocator = _mem.allocator)
    if err != .None { log.errorf("free_fn: %v", err) }
}

log_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []byte, error: mem.Allocator_Error) {
    data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location)
    // log.debugf("%v %v %v byte %v %v %v %v", mode, allocator_data, size, alignment, old_memory, old_size, location)
    return
}

process_inputs :: proc() {
    e: sdl2.Event
    for sdl2.PollEvent(&e) {
        imgui_impl_sdl2.ProcessEvent(&e)

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
