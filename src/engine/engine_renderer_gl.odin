package engine

when RENDERER == .OpenGL {
    import "core:fmt"
    import "core:log"
    import "core:mem"
    import "core:strings"
    import "core:time"
    import "vendor:sdl2"
    import gl "vendor:OpenGL"

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

    renderer_draw_texture_by_index :: proc(texture_index: int, source: ^Rect, destination: ^RectF32, flip: RendererFlip = .NONE, color: Color = { 255, 255, 255, 255 }) {
        log.warn("renderer_draw_texture_by_index not implemented!")
    }

    renderer_draw_texture_by_ptr :: proc(texture: ^Texture, source: ^Rect, destination: ^RectF32, flip: RendererFlip = .NONE, color: Color = { 255, 255, 255, 255 }) {
        log.warn("renderer_draw_texture_by_ptr not implemented!")
    }

    renderer_draw_texture_no_offset :: proc(texture: ^Texture, source: ^Rect, destination: ^RectF32, color: Color = { 255, 255, 255, 255 }) {
        log.warn("renderer_draw_texture_no_offset not implemented!")
    }

    renderer_set_draw_color :: proc(color: Color) -> i32 {
        log.warn("renderer_set_draw_color not implemented!")
        return 0
    }

    renderer_draw_fill_rect_i32 :: proc(destination: ^Rect, color: Color) {
        log.warn("renderer_draw_fill_rect_i32 not implemented!")
    }

    renderer_draw_fill_rect_f32 :: proc(destination: ^RectF32, color: Color) {
        log.warn("renderer_draw_fill_rect_f32 not implemented!")
    }

    renderer_draw_fill_rect_no_offset :: proc(destination: ^RectF32, color: Color) {
        log.warn("renderer_draw_fill_rect_no_offset not implemented!")
    }

    renderer_draw_fill_rect_raw :: proc(destination: ^RectF32, color: Color) {
        log.warn("renderer_draw_fill_rect_raw not implemented!")
    }

    renderer_make_rect_f32 :: proc(x, y, w, h: i32) -> RectF32 {
        log.warn("renderer_make_rect_f32 not implemented!")
        return {}
    }

    renderer_set_clip_rect :: proc(rect: ^Rect) {
        log.warn("renderer_set_clip_rect not implemented!")
    }

    renderer_read_pixels :: proc(rect: ^Rect, format: sdl2.PixelFormatEnum, pixels: rawptr, pitch: i32) {
        log.warn("renderer_read_pixels not implemented!")
    }

    renderer_create_texture_from_surface :: proc (surface: ^Surface) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
        log.warn("renderer_create_texture_from_surface not implemented!")
        return
    }

    renderer_create_texture :: proc(pixel_format: u32, texture_access: TextureAccess, width: i32, height: i32) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
        log.warn("renderer_create_texture not implemented!")
        return
    }

    renderer_set_texture_blend_mode :: proc(texture: ^Texture, blend_mode: BlendMode) -> (error: i32) {
        log.warn("renderer_set_texture_blend_mode not implemented!")
        return
    }

    renderer_update_texture :: proc(texture: ^Texture, rect: ^Rect, pixels: rawptr, pitch: i32) -> (error: i32) {
        log.warn("renderer_update_texture not implemented!")
        return
    }

    renderer_get_display_dpi :: proc(window: ^Window) -> f32 {
        log.warn("renderer_get_display_dpi not implemented!")
        return 0
    }

    renderer_draw_line :: proc(pos1: ^Vector2i, pos2: ^Vector2i) -> i32 {
        log.warn("renderer_draw_line not implemented!")
        return 0
    }

    renderer_query_texture :: proc(texture: ^Texture, width, height: ^i32) -> i32 {
        log.warn("renderer_query_texture not implemented!")
        return 0
    }

    renderer_set_render_target :: proc(texture: ^Texture) -> i32 {
        log.warn("renderer_set_render_target not implemented!")
        return 0
    }

    renderer_is_enabled :: proc() -> bool {
        log.warn("renderer_is_enabled not implemented!")
        return true
    }
}
