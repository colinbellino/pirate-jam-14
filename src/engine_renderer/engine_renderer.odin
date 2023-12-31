package engine_renderer

import "core:runtime"
import "core:mem"
import "core:math/linalg"
import "core:log"
import "core:fmt"
import imgui "../odin-imgui"
import sg "../sokol-odin/sokol/gfx"
import slog "../sokol-odin/sokol/log"
import sgl "../sokol-odin/sokol/gl"
import stb_image "vendor:stb/image"
import "../odin-imgui/imgui_impl_sdl2"
import "../odin-imgui/imgui_impl_opengl3"

Renderer_State :: struct {

}

@(private) state: ^Renderer_State

init :: proc() {
    state = new(Renderer_State)

    sg.setup({
        logger = { func = slog.func },
        allocator = { alloc_fn = alloc_fn, free_fn = free_fn },
    })
    if sg.isvalid() == false {
        fmt.panicf("sg.setup error: %v.\n", "no clue how to get errors from sokol_gfx")
    }
    assert(sg.query_backend() == .GLCORE33)

    sgl.setup({
        logger = { func = slog.func },
    })
}

quit :: proc() {
    sgl.shutdown()
    sg.shutdown()
}

gl_line :: proc(start, end: linalg.Vector3f32, color: linalg.Vector4f32) {
    sgl.defaults()
    sgl.begin_lines()
        sgl.c4f(color.r, color.g, color.b, color.a)
        sgl.v3f(start.x, start.y, start.z)
        sgl.v3f(end.x,   end.y,   end.z)
    sgl.end()
}

gl_draw :: proc() {
    sgl.draw()
}

ui_init :: proc(window, gl_context: rawptr) {
    imgui.CHECKVERSION()
    imgui.CreateContext(nil)
    io := imgui.GetIO()
    io.ConfigFlags += { .NavEnableKeyboard, .NavEnableGamepad }
    when imgui.IMGUI_BRANCH == "docking" {
        io.ConfigFlags += { .DockingEnable /*, .ViewportsEnable */ }
    }

    imgui_impl_sdl2.InitForOpenGL(auto_cast(window), gl_context)
    imgui_impl_opengl3.Init(nil)
}

ui_quit :: proc() {
    imgui_impl_opengl3.Shutdown()
    imgui_impl_sdl2.Shutdown()
    imgui.DestroyContext(nil)
}

ui_frame_begin :: proc() {
    imgui_impl_opengl3.NewFrame()
    imgui_impl_sdl2.NewFrame()
    imgui.NewFrame()
}

ui_frame_end :: proc() {
    imgui.Render()
    imgui_impl_opengl3.RenderDrawData(imgui.GetDrawData())
}

ui_process_event :: imgui_impl_sdl2.ProcessEvent

@(private) alloc_fn :: proc "c" (size: u64, user_data: rawptr) -> rawptr {
    context = runtime.default_context()
    ptr, err := mem.alloc(int(size))
    if err != .None { log.errorf("alloc_fn: %v", err) }
    return ptr
}

@(private) free_fn :: proc "c" (ptr: rawptr, user_data: rawptr) {
    context = runtime.default_context()
    err := mem.free(ptr)
    if err != .None { log.errorf("free_fn: %v", err) }
}
