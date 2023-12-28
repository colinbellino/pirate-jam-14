package main

import "core:fmt"
import "core:runtime"
import "core:log"
import "core:strings"
import "core:math/linalg"
import "core:math/rand"
import "core:math"
import "core:c/libc"
import "vendor:sdl2"
import rl "vendor:raylib"
import gl "vendor:OpenGL"
import sg "../sokol-odin/sokol/gfx"
import slog "../sokol-odin/sokol/log"
import stb_image "vendor:stb/image"
import imgui "../odin-imgui"
import "../odin-imgui/imgui_impl_sdl2"
import "../odin-imgui/imgui_impl_opengl3"
import "../engine"

MAX_BUNNIES           :: 30_000
MAX_BATCH_ELEMENTS    :: 8192
DESIRED_MAJOR_VERSION :: 3
DESIRED_MINOR_VERSION :: 3
TARGET_FRAME_RATE     :: 144

Bunny :: struct {
    position: linalg.Vector2f32,
    color:    linalg.Vector4f32,
}

frame_start: u64
fps, sleep_time: f32

main :: proc() {
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })

    screen_width : i32 = 800
    screen_height : i32 = 800
    window := init_window(screen_width, screen_height)

    bindings := sg.Bindings {}
    pass_action := sg.Pass_Action {}
    pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.9, 0.9, 0.9, 1.0 } }

    bindings.fs.images[SLOT_tex] = sg.alloc_image()
    bindings.fs.samplers[SLOT_smp] = sg.make_sampler(sg.Sampler_Desc {
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    })

    // Platform stuff
    mouse_position: [2]i32
    mouse_left_down: bool
    mouse_right_down: bool

    // vertex buffer for static geometry, goes into vertex-buffer-slot 0
    s := f32(0.05)
    vertices := [?]f32 {
        // positions
        -s, +s,
        +s, +s,
        +s, -s,
        -s, -s,
    }
    bindings.vertex_buffers[0] = sg.make_buffer({
        data = sg.Range { &vertices, size_of(vertices) },
        label = "geometry-vertices",
    })

    // index buffer for static geometry
    indices := [?]u16 {
        0, 1, 2,
        0, 2, 3,
    }
    bindings.index_buffer = sg.make_buffer({
        type = .INDEXBUFFER,
        data = sg.Range { &indices, size_of(indices) },
        label = "geometry-indices",
    })

    // empty, dynamic instance-data vertex buffer, goes into vertex-buffer-slot 1
    bindings.vertex_buffers[1] = sg.make_buffer({
        size = MAX_BUNNIES * size_of(Bunny),
        usage = .STREAM,
        label = "instance-data",
    })

    desc := sg.Pipeline_Desc {
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
    }
    pip := sg.make_pipeline(desc)

    width, height, channels_in_file: i32
    {
        pixels := stb_image.load("src/bunny_raylib/wabbit.png", &width, &height, &channels_in_file, 0)
        // TODO: free pixels?

        desc := sg.Image_Desc {
            width = width,
            height = height,
        }
        desc.data.subimage[0][0] = {
            ptr = pixels,
            size = u64(width * height * channels_in_file),
        }
        sg.init_image(bindings.fs.images[SLOT_tex], desc)
    }

    bunnies_count := 0
    bunnies := [MAX_BUNNIES]Bunny {}
    bunnies_speed := [MAX_BUNNIES]linalg.Vector2f32 {}

    should_quit := false
    for should_quit == false {
        frame_start = sdl2.GetPerformanceCounter()

        {
            e: sdl2.Event
            for sdl2.PollEvent(&e) {
                imgui_impl_sdl2.ProcessEvent(&e)

                #partial switch e.type {
                    case .QUIT: {
                        should_quit = true
                    }
                    case .MOUSEMOTION: {
                        mouse_position.x = e.motion.x
                        mouse_position.y = e.motion.y
                    }
                    case .MOUSEBUTTONDOWN, .MOUSEBUTTONUP: {
                        if e.button.button == 1 {
                            mouse_left_down = e.type == .MOUSEBUTTONDOWN
                        }
                        if e.button.button == 3 {
                            mouse_right_down = e.type == .MOUSEBUTTONDOWN
                        }
                    }
                }
            }
        }

        if mouse_left_down {
            for i := 0; i < 100; i += 1 {
                if bunnies_count < MAX_BUNNIES {
                    bunnies[bunnies_count].position = { f32(mouse_position.x), -f32(mouse_position.y) }
                    bunnies_speed[bunnies_count].x = rand.float32_range(-250, 250) / 60
                    bunnies_speed[bunnies_count].y = rand.float32_range(-250, 250) / 30
                    bunnies[bunnies_count].color = {
                        f32(rand.float32_range(50, 240)) / 255,
                        f32(rand.float32_range(80, 240)) / 255,
                        f32(rand.float32_range(100, 240)) / 255,
                        1,
                    }
                    bunnies_count += 1
                }
            }
        }
        if mouse_right_down {
            bunnies_count = 0
        }

        for i := 0; i < bunnies_count; i += 1 {
            bunnies[i].position.x += bunnies_speed[i].x
            bunnies[i].position.y += bunnies_speed[i].y

            if (f32(bunnies[i].position.x) > f32(screen_width) * 1.3) || (f32(bunnies[i].position.x) < -f32(screen_width) * 1.3) {
                bunnies_speed[i].x *= -1
            }
            if (f32(bunnies[i].position.y) > f32(screen_height) * 2.2) || (f32(bunnies[i].position.y) < -f32(screen_height) * 2.2) {
                bunnies_speed[i].y *= -1
            }
        }

        if bunnies_count > 0 {
            sg.update_buffer(bindings.vertex_buffers[1], {
                ptr = &bunnies,
                size = u64(bunnies_count) * size_of(Bunny),
            })
        }

        {
            sg.begin_default_pass(pass_action, screen_width, screen_height)
            sg.apply_pipeline(pip)
            sg.apply_bindings(bindings)
            sg.draw(0, 6, bunnies_count)
            sg.end_pass()
            sg.commit()
        }

        {
            imgui_impl_opengl3.NewFrame()
            imgui_impl_sdl2.NewFrame()
            imgui.NewFrame()

            // imgui.ShowDemoWindow(nil)
            imgui.Begin("Stats", nil, .AlwaysAutoResize)
            imgui.Text(strings.clone_to_cstring(fmt.tprintf("bunnies_count: %v", bunnies_count), context.temp_allocator))
            imgui.Text(strings.clone_to_cstring(fmt.tprintf("fps:           %3.0f", fps), context.temp_allocator))
            @(static) fps_plot := engine.Statistic_Plot {}
            imgui.SetNextItemWidth(400)
            engine.ui_statistic_plots(&fps_plot, fps, "fps", min = 0, max = 500)
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

        sdl2.GL_SwapWindow(window)

        fps, sleep_time = calculate_fps()
        sdl2.SetWindowTitle(window, strings.clone_to_cstring(fmt.tprintf("SDL+Sokol (bunnies_count: %v, fps: %v)", bunnies_count, fps), context.temp_allocator))
        if sleep_time > 0 {
            sdl2.Delay(u32(sleep_time))
        }
    }
}

init_window :: proc(screen_width, screen_height: i32) -> ^sdl2.Window {
    if sdl_res := sdl2.Init(sdl2.INIT_EVERYTHING); sdl_res < 0 {
        fmt.panicf("sdl2.init returned %v.", sdl_res)
    }

    window := sdl2.CreateWindow("SDL+Sokol", screen_width / 2, screen_height / 2, screen_width, screen_height, { .SHOWN, .OPENGL })
    if window == nil {
        fmt.panicf("sdl2.CreateWindow failed.\n")
    }

    sdl2.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, DESIRED_MAJOR_VERSION)
    sdl2.GL_SetAttribute(.CONTEXT_MINOR_VERSION, DESIRED_MINOR_VERSION)
    sdl2.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))

    gl.load_up_to(int(DESIRED_MAJOR_VERSION), int(DESIRED_MINOR_VERSION), proc(ptr: rawptr, name: cstring) {
        (cast(^rawptr)ptr)^ = sdl2.GL_GetProcAddress(name)
    })

    gl_context := sdl2.GL_CreateContext(window)
    if gl_context == nil {
        fmt.panicf("sdl2.GL_CreateContext error: %v.\n", sdl2.GetError())
    }
    fmt.printf("GL version: %s\n", gl.GetString(gl.VERSION))

    sdl2.GL_SetSwapInterval(0)

    sg.setup({
        logger = { func = slog.func },
    })
    if sg.isvalid() == false {
        fmt.panicf("sg.setup error: %v.\n", "no clue how to get errors from sokol_gfx")
    }
    log.debugf("backend used: %v", sg.query_backend())
    assert(sg.query_backend() == .GLCORE33)

    {
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

        imgui.StyleColorsDark(nil)

        imgui_impl_sdl2.InitForOpenGL(window, gl_context)
        // defer imgui_impl_sdl2.Shutdown()
        imgui_impl_opengl3.Init(nil)
        // defer imgui_impl_opengl3.Shutdown()
    }

    return window
}

calculate_fps :: proc() -> (f32, f32) {
    frame_end := sdl2.GetPerformanceCounter()
    frame_time := f32(frame_end - frame_start) * 1_000 / f32(sdl2.GetPerformanceFrequency())
    target_frame_time := 1_000 / f32(TARGET_FRAME_RATE)
    sleep_time := target_frame_time - frame_time
    fps := 1_000 / frame_time
    return fps, sleep_time
}
