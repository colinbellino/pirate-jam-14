package engine

when RENDERER == .OpenGL {
    import "core:fmt"
    import "core:log"
    import "core:mem"
    import "core:os"
    import "core:strings"
    import "core:time"
    import "vendor:sdl2"
    import gl "vendor:OpenGL"

    DESIRED_GL_MAJOR_VERSION : i32 : 4
    DESIRED_GL_MINOR_VERSION : i32 : 1

    program: u32
    program_success: bool
    vertex_array_object: u32
    vertex_buffer_object: u32

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

        gl.load_up_to(int(major), int(minor), proc(p: rawptr, name: cstring) {
            (cast(^rawptr)p)^ = sdl2.GL_GetProcAddress(name)
        })

        log.infof("OpenGL renderer -------------------------------------")
        log.infof("  GL VERSION:           %v.%v", major, minor)
        log.infof("  VENDOR:               %v", gl.GetString(gl.VENDOR))
        log.infof("  RENDERER:             %v", gl.GetString(gl.RENDERER))
        log.infof("  VERSION:              %v", gl.GetString(gl.VERSION))

        {
            // load shaders
            // program, program_success = gl.load_shaders_file("media/shaders/shader_triangle.vert", "media/shaders/shader_triangle.frag")
            program, program_success = _load_shader_file("media/shaders/shader_triangle.glsl")
            if program_success == false {
                log.errorf("Shader error: %v.", gl.GetError())
                return
            }
            // defer gl.DeleteProgram(program)

            // vertex_buffer_object: u32
            gl.GenBuffers(1, &vertex_buffer_object)
            // defer gl.DeleteBuffers(1, &vertex_buffer_object)
            gl.BindBuffer(gl.ARRAY_BUFFER, vertex_buffer_object)

            Vertex :: struct {
                position: [2]f32,
                color:    [4]f32,
            }
            vertex_data := [?]Vertex {
                { { -0.5, -0.5 }, { 1.0, 0.0, 0.0, 1.0 } },
                { { +0.5, -0.5 }, { 0.0, 1.0, 0.0, 1.0 } },
                { { -0.5, +0.5 }, { 0.0, 0.0, 1.0, 1.0 } },
                { { +0.5, +0.5 }, { 0.0, 1.0, 1.0, 1.0 } },
            }
            index_position : u32 = 0
            index_color : u32 = 1
            gl.BufferData(gl.ARRAY_BUFFER, size_of(vertex_data), &vertex_data[0], gl.STATIC_DRAW)

            // vertex_array_object: u32
            gl.GenVertexArrays(1, &vertex_array_object)
            // defer gl.DeleteVertexArrays(1, &vertex_array_object)
            gl.BindVertexArray(vertex_array_object)
            gl.EnableVertexAttribArray(index_position)
            gl.VertexAttribPointer(index_position, 2, gl.FLOAT, gl.FALSE, size_of(Vertex), 0)
            gl.EnableVertexAttribArray(index_color)
            gl.VertexAttribPointer(index_color, 4, gl.FLOAT, gl.FALSE, size_of(Vertex), 0)

            /*
            Some things i learned about OpenGL:
            - Vertex can contain more data than position (color, texture info, normal, etc).
            - To bind a buffer or vertex array means to select it, then the next operationss will be done in this context.
            */
        }

        _engine.renderer.enabled = false // TODO: set to true when render is done

        ok = true
        return
    }


    renderer_quad :: proc(t: f32) {
        // setup shader program and uniforms
        gl.UseProgram(program)
        gl.Uniform1f(gl.GetUniformLocation(program, "time"), t)
        // log.debugf("t: %v", t);

        // draw stuff
        gl.BindVertexArray(vertex_array_object)
        gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
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
        return _engine.renderer != nil && _engine.renderer.enabled
    }

    Shader_Types :: enum { None = -1, Vertex = 0, Fragment = 1 }

    _load_shader_file :: proc(filename: string, binary_retrievable := false) -> (program_id: u32, ok: bool) {
        data: []byte
        data, ok = os.read_entire_file(filename, context.temp_allocator)
        defer delete(data)
        if ok == false {
            log.errorf("Shader file couldn't be read: %v", filename)
            return
        }

        log.debugf("Loading shader: %v", filename);

        builders := [2]strings.Builder {}
        type := Shader_Types.None
        it := string(data)
        for line in strings.split_lines_iterator(&it) {
            if strings.has_prefix(line, "#shader") {
                if strings.contains(line, "vertex") {
                    type = .Vertex
                } else if strings.contains(line, "fragment") {
                    type = .Fragment
                }
                // log.debugf("  %v", type);
                // log.debugf("  ------------------------------------------------------");
            } else {
                // log.debugf("  %v", line);
                strings.write_string(&builders[type], line)
                strings.write_rune(&builders[type], '\n')
            }
        }

        return gl.load_shaders_source(strings.to_string(builders[Shader_Types.Vertex]), strings.to_string(builders[Shader_Types.Fragment]), binary_retrievable)
    }
}
