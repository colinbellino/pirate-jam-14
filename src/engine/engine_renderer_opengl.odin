package engine

IMGUI_ENABLE :: false

when RENDERER == .OpenGL {
    import "core:fmt"
    import "core:log"
    import "core:mem"
    import "core:slice"
    import "core:strings"
    import "core:math/linalg"
    import "vendor:sdl2"
    import gl "vendor:OpenGL"
    import imgui "../odin-imgui"
    import imgui_sdl "imgui_impl_sdl"
    import imgui_opengl "imgui_impl_opengl"

    RENDERER_DEBUG :: gl.GL_DEBUG

    DESIRED_GL_MAJOR_VERSION : i32 : 4
    DESIRED_GL_MINOR_VERSION : i32 : 1

    TEXTURE_MAX     :: 32 // TODO: Get this from OpenGL
    QUAD_MAX        :: 100_000
    INDEX_PER_QUAD  :: 6
    VERTEX_PER_QUAD :: 4
    QUAD_VERTEX_MAX :: QUAD_MAX * VERTEX_PER_QUAD
    QUAD_INDEX_MAX  :: QUAD_MAX * INDEX_PER_QUAD

    // FIXME: remove these globals
    _projection:         Matrix4x4f32 = matrix_ortho3d_f32(0, 1920, 0, 1080, -1, 1)
    _view:               Matrix4x4f32 = matrix4_translate_f32({ 0, 0, 0 })

    Renderer_State :: struct {
        using base:         Renderer_State_Base,
        sdl_state:          imgui_sdl.SDL_State,
        opengl_state:       imgui_opengl.OpenGL_State,
        queries:            [10]u32,
        quad_vertex_array:  ^Vertex_Array,
        quad_vertex_buffer: ^Vertex_Buffer,
        quad_index_buffer:  ^Index_Buffer,
        quad_vertices:      [QUAD_VERTEX_MAX]Vertex_Quad,
        quad_indices:       [QUAD_INDEX_MAX]i32,
        quad_index_count:    int,
        quad_shader:        ^Shader,
        texture_white:      ^Texture,
        texture_0:          ^Texture,
        texture_1:          ^Texture,
    }

    Vertex_Quad :: struct {
        position:       Vector2f32,
        color:          Vector4f32,
        uv:             Vector2f32,
        texture_index:  i32,
    }

    renderer_init :: proc(window: ^Window, allocator: mem.Allocator, vsync: bool = false) -> (ok: bool) {
        profiler_zone("renderer_init")
        _engine.renderer = new(Renderer_State, allocator)
        _engine.renderer.allocator = allocator

        if PROFILER {
            _engine.renderer.arena = cast(^mem.Arena)(cast(^ProfiledAllocatorData)allocator.data).backing_allocator.data
        } else {
            _engine.renderer.arena = cast(^mem.Arena)allocator.data
        }

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

        major: i32; sdl2.GL_GetAttribute(.CONTEXT_MAJOR_VERSION, &major)
        minor: i32; sdl2.GL_GetAttribute(.CONTEXT_MINOR_VERSION, &minor)

        gl.load_up_to(int(major), int(minor), proc(p: rawptr, name: cstring) {
            (cast(^rawptr)p)^ = sdl2.GL_GetProcAddress(name)
        })

        log.infof("OpenGL renderer --------------------------------------------")
        log.infof("  GL VERSION:           %v.%v", major, minor)
        log.infof("  VENDOR:               %v", gl.GetString(gl.VENDOR))
        log.infof("  RENDERER:             %v", gl.GetString(gl.RENDERER))
        log.infof("  VERSION:              %v", gl.GetString(gl.VERSION))
        log.infof("  size_of(Shader):      %v", size_of(Shader))

        gl.GenQueries(len(_engine.renderer.queries), &_engine.renderer.queries[0])

        when IMGUI_ENABLE {
            imgui.create_context()
            imgui.style_colors_dark()
            imgui_sdl.setup_state(&_engine.renderer.sdl_state)
            imgui_opengl.setup_state(&_engine.renderer.opengl_state)
        }

        {
            gl.Enable(gl.BLEND)
            gl.BlendEquation(gl.FUNC_ADD)
            gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

            _engine.renderer.quad_shader = _gl_create_shader("media/shaders/shader_sprite.glsl") or_return
            _gl_bind_shader(_engine.renderer.quad_shader)

            offset : i32 = 0
            for i := 0; i < QUAD_INDEX_MAX; i += INDEX_PER_QUAD {
                _engine.renderer.quad_indices[i + 0] = 0 + offset
                _engine.renderer.quad_indices[i + 1] = 1 + offset
                _engine.renderer.quad_indices[i + 2] = 2 + offset
                _engine.renderer.quad_indices[i + 3] = 2 + offset
                _engine.renderer.quad_indices[i + 4] = 3 + offset
                _engine.renderer.quad_indices[i + 5] = 0 + offset
                offset += VERTEX_PER_QUAD
            }

            index := 0
            for y := 0; y < 300; y += 1 {
                for x := 0; x < 300; x += 1 {
                    color := Vector4f32 { 1, 1, 1, 1 }
                    if x % 2 == 0 {
                        color = { 0, 1, 0, 1 }
                    }
                    create_quad(&index, f32(x), f32(y), i32((x + y) % 2), color)
                    _engine.renderer.quad_index_count += INDEX_PER_QUAD
                }
            }

            _engine.renderer.quad_vertex_array = _gl_create_vertex_array()
            _engine.renderer.quad_vertex_buffer = _gl_create_vertex_buffer(nil, size_of(Vertex_Quad) * QUAD_VERTEX_MAX, gl.DYNAMIC_DRAW)
            _engine.renderer.quad_index_buffer = _gl_create_index_buffer(&_engine.renderer.quad_indices[0], len(_engine.renderer.quad_indices))
            layout := _gl_create_vertex_buffer_layout()
            _gl_push_f32_vertex_buffer_layout(layout, 2)
            _gl_push_f32_vertex_buffer_layout(layout, 4)
            _gl_push_f32_vertex_buffer_layout(layout, 2)
            _gl_push_i32_vertex_buffer_layout(layout, 1)
            _gl_add_buffer_to_vertex_array(_engine.renderer.quad_vertex_array, _engine.renderer.quad_vertex_buffer, layout)

            color_white : u32 = 0xffffffff
            _engine.renderer.texture_white = _gl_create_texture({ 1, 1 }, &color_white) or_return
            _engine.renderer.texture_0 = _gl_load_texture("media/art/spritesheet.png") or_return
            _engine.renderer.texture_1 = _gl_load_texture("media/art/red_pixel.png") or_return
            samplers := [?]i32 { 0, 1 }
            _gl_set_uniform_1iv_to_shader(_engine.renderer.quad_shader, "u_textures", samplers[:])
        }

        _engine.renderer.enabled = true

        ok = true
        return
    }

    renderer_quit :: proc() {
        // FIXME:
    }

    renderer_render_start :: proc() {
        gl.BeginQuery(gl.TIME_ELAPSED, _engine.renderer.queries[0])
        renderer_begin_ui()
    }

    renderer_render_end :: proc() {
        ui_process_commands()

        renderer_draw_ui()
        sdl2.GL_SwapWindow(_engine.platform.window)
        gl.EndQuery(gl.TIME_ELAPSED)
        gl.GetQueryObjectiv(_engine.renderer.queries[0], gl.QUERY_RESULT, &_engine.renderer.draw_duration)
    }

    renderer_begin_ui :: proc() {
        when IMGUI_ENABLE {
            imgui_sdl.update_display_size(_engine.platform.window)
            imgui_sdl.update_mouse(&_engine.renderer.sdl_state, _engine.platform.window)
            imgui_sdl.update_dt(&_engine.renderer.sdl_state, _engine.platform.delta_time)

            imgui.new_frame()
        }
    }

    renderer_process_events :: proc(e: sdl2.Event) {
        when IMGUI_ENABLE {
            imgui_sdl.process_event(e, &_engine.renderer.sdl_state)
        }
    }

    renderer_get_window_pixel_density :: proc(window: ^Window) -> f32 {
        window_size := platform_get_window_size(window)
        output_width: i32
        output_height: i32
        sdl2.GL_GetDrawableSize(window, &output_width, &output_height)
        if output_width == 0 || output_height == 0 {
            log.errorf("sdl2.GL_SetSwapInterval error: %v.", sdl2.GetError())
            return 1
        }
        return f32(output_width) / f32(window_size.x)
    }

    renderer_draw_ui:: proc() {
        when IMGUI_ENABLE {
            profiler_zone("renderer_draw_ui", 0x005500)
            imgui.render()

            // io := imgui.get_io()
            gl.Clear(gl.DEPTH_BUFFER_BIT)
            imgui_opengl.imgui_render(imgui.get_draw_data(), _engine.renderer.opengl_state)
        }
    }

    renderer_quad :: proc(t: f32) {

    }

    renderer_draw :: proc(vertex_array: ^Vertex_Array, index_buffer: ^Index_Buffer, shader: ^Shader) {
        _gl_bind_shader(shader)
        _gl_bind_vertex_array(vertex_array)
        _gl_bind_index_buffer(index_buffer)
        gl.DrawElements(gl.TRIANGLES, i32(index_buffer.count), gl.UNSIGNED_INT, nil)
    }

    renderer_clear :: proc(color: Color) {
        gl.ClearColor(f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255)
        gl.Clear(gl.COLOR_BUFFER_BIT)
    }

    renderer_draw_texture_by_index :: proc(texture_index: int, source: ^Rect, destination: ^RectF32, flip: RendererFlip = .NONE, color: Color = { 255, 255, 255, 255 }) {
        // log.warn("renderer_draw_texture_by_index not implemented!")
    }

    create_quad :: proc(offset: ^int, x, y: f32, texture_index: i32, color: Vector4f32 = { 1, 1, 1, 1 }) {
        _engine.renderer.quad_vertices[offset^] = Vertex_Quad { { x + 0, y + 0 }, color, { 0, 0 }, texture_index }
        offset^ += 1
        _engine.renderer.quad_vertices[offset^] = Vertex_Quad { { x + 1, y + 0 }, color, { 1, 0 }, texture_index }
        offset^ += 1
        _engine.renderer.quad_vertices[offset^] = Vertex_Quad { { x + 1, y + 1 }, color, { 1, 1 }, texture_index }
        offset^ += 1
        _engine.renderer.quad_vertices[offset^] = Vertex_Quad { { x + 0, y + 1, }, color, { 0, 1 }, texture_index }
        offset^ += 1
    }

    renderer_draw_quad_batch :: proc() {
        scale := matrix4_scale_f32({ 10, 10, 0 })
        model_view_projection := _projection * _view * scale

        _gl_subdata_vertex_buffer(_engine.renderer.quad_vertex_buffer, 0, size_of(_engine.renderer.quad_vertices), &_engine.renderer.quad_vertices[0])

        _gl_bind_shader(_engine.renderer.quad_shader)
        _gl_bind_texture(_engine.renderer.texture_0, 0)
        _gl_bind_texture(_engine.renderer.texture_white, 1)
        _gl_bind_vertex_array(_engine.renderer.quad_vertex_array)
        _gl_bind_index_buffer(_engine.renderer.quad_index_buffer)
        _gl_set_uniform_mat4f_to_shader(_engine.renderer.quad_shader, "u_model_view_projection", &model_view_projection)

        gl.DrawElements(gl.TRIANGLES, i32(_engine.renderer.quad_index_count), gl.UNSIGNED_INT, nil)
        // gl.DrawElements(gl.TRIANGLES, i32(_index_buffer.count), gl.UNSIGNED_INT, nil)
    }

    renderer_draw_texture_by_ptr :: proc(texture: ^Texture, source: ^Rect, destination: ^RectF32, flip: RendererFlip = .NONE, color: Color = { 255, 255, 255, 255 }) {
        // log.warn("renderer_draw_texture_by_ptr not implemented!")
    }

    renderer_draw_texture_no_offset :: proc(texture: ^Texture, source: ^Rect, destination: ^RectF32, color: Color = { 255, 255, 255, 255 }) {
        // log.warn("renderer_draw_texture_no_offset not implemented!")
    }

    renderer_set_draw_color :: proc(color: Color) -> i32 {
        // log.warn("renderer_set_draw_color not implemented!")
        return 0
    }

    renderer_draw_fill_rect_i32 :: proc(destination: ^Rect, color: Color) {
        // log.warn("renderer_draw_fill_rect_i32 not implemented!")
    }

    renderer_draw_fill_rect_f32 :: proc(destination: ^RectF32, color: Color) {

    }

    renderer_draw_fill_rect_no_offset :: proc(destination: ^RectF32, color: Color) {
        // log.warn("renderer_draw_fill_rect_no_offset not implemented!")
    }

    renderer_draw_fill_rect_raw :: proc(destination: ^RectF32, color: Color) {
        // model_matrix := matrix4_translate_f32({ destination.x * 6, destination.y * 6, 0 })
        // _gl_set_uniform_4f_to_shader(_engine.renderer.quad_shader, "u_color", { f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255 })
    }

    renderer_make_rect_f32 :: proc(x, y, w, h: i32) -> RectF32 {
        // log.warn("renderer_make_rect_f32 not implemented!")
        return {}
    }

    renderer_set_clip_rect :: proc(rect: ^Rect) {
        // log.warn("renderer_set_clip_rect not implemented!")
    }

    renderer_read_pixels :: proc(rect: ^Rect, format: sdl2.PixelFormatEnum, pixels: rawptr, pitch: i32) {
        // log.warn("renderer_read_pixels not implemented!")
    }

    renderer_create_texture_from_surface :: proc (surface: ^Surface) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
        // log.warn("renderer_create_texture_from_surface not implemented!")
        return
    }

    renderer_create_texture :: proc(pixel_format: u32, texture_access: TextureAccess, width: i32, height: i32) -> (texture: ^Texture, texture_index: int = -1, ok: bool) {
        // log.warn("renderer_create_texture not implemented!")
        return
    }

    renderer_set_texture_blend_mode :: proc(texture: ^Texture, blend_mode: BlendMode) -> (error: i32) {
        // log.warn("renderer_set_texture_blend_mode not implemented!")
        return
    }

    renderer_update_texture :: proc(texture: ^Texture, rect: ^Rect, pixels: rawptr, pitch: i32) -> (error: i32) {
        // log.warn("renderer_update_texture not implemented!")
        return
    }

    renderer_draw_line :: proc(pos1: ^Vector2i32, pos2: ^Vector2i32) -> i32 {
        // log.warn("renderer_draw_line not implemented!")
        return 0
    }

    renderer_query_texture :: proc(texture: ^Texture, width, height: ^i32) -> i32 {
        // log.warn("renderer_query_texture not implemented!")
        return 0
    }

    renderer_set_render_target :: proc(texture: ^Texture) -> i32 {
        // log.warn("renderer_set_render_target not implemented!")
        return 0
    }

    renderer_is_enabled :: proc() -> bool {
        return _engine.renderer != nil && _engine.renderer.enabled
    }

    renderer_ui_show_debug_info_window :: proc(open: ^bool) {
        @static fps_values: [200]f32
        @static fps_i: int
        @static fps_stat: Statistic
        fps_values[fps_i] = f32(_engine.platform.fps)
        fps_i += 1
        if fps_i > len(fps_values) - 1 {
            fps_i = 0
        }
        statistic_begin(&fps_stat)
        for fps in fps_values {
            if fps == 0 {
                continue
            }
            statistic_accumulate(&fps_stat, f64(fps))
        }
        statistic_end(&fps_stat)

        @static frame_duration_values: [200]f32
        @static frame_duration_i: int
        @static frame_duration_stat: Statistic
        frame_duration_values[frame_duration_i] = f32(_engine.platform.frame_duration)
        frame_duration_i += 1
        if frame_duration_i > len(frame_duration_values) - 1 {
            frame_duration_i = 0
        }
        statistic_begin(&frame_duration_stat)
        for frame_duration in frame_duration_values {
            if frame_duration == 0 {
                continue
            }
            statistic_accumulate(&frame_duration_stat, f64(frame_duration))
        }
        statistic_end(&frame_duration_stat)

        when IMGUI_ENABLE {
            fps_overlay := fmt.tprintf("fps %6.0f | min %6.0f| max %6.0f | avg %6.0f", f32(_engine.platform.fps), fps_stat.min, fps_stat.max, fps_stat.average)
            frame_duration_overlay := fmt.tprintf("frame %2.6f | min %2.6f| max %2.6f | avg %2.6f", f32(_engine.platform.frame_duration), frame_duration_stat.min, frame_duration_stat.max, frame_duration_stat.average)

            if open^ {
                imgui.begin("Debug")
                imgui.set_window_size_vec2({ 600, 800 }, .FirstUseEver)
                imgui.set_window_pos_vec2({ 50, 50 }, .FirstUseEver)
                imgui.plot_lines_float_ptr("", &fps_values[0], len(fps_values), 0, fps_overlay, f32(fps_stat.min), f32(fps_stat.max), { 0, 80 })
                imgui.plot_lines_float_ptr("", &frame_duration_values[0], len(frame_duration_values), 0, frame_duration_overlay, f32(frame_duration_stat.min), f32(frame_duration_stat.max), { 0, 80 })
                if imgui.tree_node_ex_str("Frame", .DefaultOpen) {
                    imgui.text(fmt.tprintf("Refresh rate:   %3.0fHz", f32(_engine.renderer.refresh_rate)))
                    imgui.text(fmt.tprintf("Actual FPS:     %5.0f", f32(_engine.platform.fps)))
                    imgui.text(fmt.tprintf("Frame duration: %2.6fms", _engine.platform.frame_duration))
                    imgui.text(fmt.tprintf("Frame delay:    %2.6fms", _engine.platform.frame_delay))
                    imgui.text(fmt.tprintf("Delta time:     %2.6fms", _engine.platform.frame_delay))
                    imgui.tree_pop()
                }
                if imgui.tree_node_ex_str("Refresh rate", .DefaultOpen) {
                    imgui.radio_button("1Hz", &_engine.renderer.refresh_rate, 1)
                    imgui.radio_button("10Hz", &_engine.renderer.refresh_rate, 10)
                    imgui.radio_button("30Hz", &_engine.renderer.refresh_rate, 30)
                    imgui.radio_button("60Hz", &_engine.renderer.refresh_rate, 60)
                    imgui.radio_button("144Hz", &_engine.renderer.refresh_rate, 144)
                    imgui.radio_button("240Hz", &_engine.renderer.refresh_rate, 240)
                    imgui.radio_button("Unlocked", &_engine.renderer.refresh_rate, 999999)
                    imgui.tree_pop()
                }
                imgui.end()
            }
        }
    }

    renderer_ui_show_debug_entity_window :: proc() {
        when IMGUI_ENABLE {
            imgui.begin("Debug")
            imgui.set_window_size_vec2({ 300, 300 }, .FirstUseEver)
            imgui.set_window_pos_vec2({ 500, 500 }, .FirstUseEver)
            // if imgui.tree_node_ex_str("Transform", .DefaultOpen) {
            //     imgui.slider_float4("_model[0]", &_model[0], 0, 2)
            //     imgui.slider_float4("_model[1]", &_model[1], 0, 2)
            //     imgui.slider_float4("_model[2]", &_model[2], 0, 2)
            //     imgui.slider_float4("_model[3]", &_model[3], 0, 200)
            //     imgui.text(fmt.tprintf("_model: %v", _model))
            //     imgui.tree_pop()
            // }
            imgui.end()
        }
    }

    renderer_ui_show_demo_window :: proc(open: ^bool) {
        when IMGUI_ENABLE {
            @static progress_t: f32
            @static progress_sign: f32 = 1
            if progress_t > 1 || progress_t < 0 {
                progress_sign = -progress_sign
            }
            progress_t += _engine.platform.delta_time * progress_sign

            if open^ {
                imgui.show_demo_window(open)

                imgui.begin("Animations")
                imgui.set_window_size_vec2({ 1200, 150 }, .FirstUseEver)
                imgui.set_window_pos_vec2({ 700, 50 }, .FirstUseEver)
                imgui.progress_bar(progress_t, { 0, 100 })
                imgui.end()
            }
        }
    }
}
