package engine

when RENDERER == .OpenGL {
    import "core:fmt"
    import "core:log"
    import "core:mem"
    import "core:strings"
    import "core:time"
    import "vendor:sdl2"
    import gl "vendor:OpenGL"

    // Color_F32 :: struct {
    //     r: f32,
    //     g: f32,
    //     b: f32,
    //     a: f32,
    // }

    renderer_init :: proc(window: ^Window, allocator: mem.Allocator, vsync: bool = false) -> (ok: bool) {
        profiler_zone("renderer_init")
        _engine.renderer = new(Renderer_State, allocator)
        _engine.renderer.allocator = allocator

        if TRACY_ENABLE {
            _engine.renderer.arena = cast(^mem.Arena)(cast(^ProfiledAllocatorData)allocator.data).backing_allocator.data
        } else {
            _engine.renderer.arena = cast(^mem.Arena)allocator.data
        }

        // FIXME:
        // if vsync == false {
        //     sdl2.SetHint(sdl2.HINT_RENDER_VSYNC, cstring("0"))
        // }

        {
            DESIRED_GL_MAJOR_VERSION : i32 : 4
            DESIRED_GL_MINOR_VERSION : i32 : 5

            log.info("Setting up the OpenGL...")
            sdl2.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, DESIRED_GL_MAJOR_VERSION)
            sdl2.GL_SetAttribute(.CONTEXT_MINOR_VERSION, DESIRED_GL_MINOR_VERSION)
            sdl2.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))
            sdl2.GL_SetAttribute(.DOUBLEBUFFER, 1)
            sdl2.GL_SetAttribute(.DEPTH_SIZE, 24)
            sdl2.GL_SetAttribute(.STENCIL_SIZE, 8)

            gl_context := sdl2.GL_CreateContext(_engine.platform.window)
            if gl_context == nil {
                log.errorf("sdl2.GL_CreateContext error: %v.", sdl2.GetError())
                return
            }

            sdl2.GL_MakeCurrent(_engine.platform.window, gl_context)
            // defer sdl.gl_delete_context(gl_context)

            if sdl2.GL_SetSwapInterval(1) != 0 {
                log.errorf("sdl2.GL_SetSwapInterval error: %v.", sdl2.GetError())
                return
            }

            major: i32
            minor: i32
            sdl2.GL_GetAttribute(.CONTEXT_MAJOR_VERSION, &major)
            sdl2.GL_GetAttribute(.CONTEXT_MINOR_VERSION, &minor)
            log.debugf("GL version: %v.%v", major, minor);

            gl.load_up_to(int(major), int(minor), proc(p: rawptr, name: cstring) {
                (cast(^rawptr)p)^ = sdl2.GL_GetProcAddress(name)
            })
        }

        ok = true
        return
    }

    renderer_clear :: proc(color: Color) {
        gl.ClearColor(f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255)
        gl.Clear(gl.COLOR_BUFFER_BIT)
    }

    renderer_present :: proc() {
        sdl2.GL_SwapWindow(_engine.platform.window)
    }

    renderer_draw_texture :: proc() {

    }

    renderer_draw_texture_by_index :: proc() {

    }

    renderer_draw_texture_by_ptr :: proc() {

    }

    renderer_draw_texture_no_offset :: proc() {

    }

    renderer_set_draw_color :: proc() {

    }

    renderer_draw_fill_rect :: proc() {

    }

    renderer_draw_fill_rect_i32 :: proc() {

    }

    renderer_draw_fill_rect_f32 :: proc() {

    }

    renderer_draw_fill_rect_no_offset :: proc() {

    }

    renderer_draw_fill_rect_raw :: proc() {

    }

    renderer_make_rect_f32 :: proc() {

    }

    renderer_set_clip_rect :: proc() {

    }

    renderer_read_pixels :: proc() {

    }

    renderer_create_texture_from_surface :: proc() {

    }

    renderer_create_texture :: proc() {

    }

    renderer_set_texture_blend_mode :: proc() {

    }

    renderer_update_texture :: proc() {

    }

    renderer_get_display_dpi :: proc() {

    }

    renderer_draw_line :: proc() {

    }

    renderer_query_texture :: proc() {

    }

    renderer_set_render_target :: proc() {

    }

    renderer_is_enabled :: proc() -> bool {
        return true
    }
}
