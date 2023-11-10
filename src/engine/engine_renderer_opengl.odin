package engine

import "core:c"
import "core:c/libc"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import glm "core:math/linalg/glsl"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:strings"
import "core:time"
import "vendor:sdl2"
import gl "vendor:OpenGL"
import "../tools"
import imgui "../odin-imgui"
import "../odin-imgui/imgui_impl_sdl2"
import "../odin-imgui/imgui_impl_opengl3"

when RENDERER == .OpenGL {
    RENDERER_DEBUG :: gl.GL_DEBUG
    RENDERER_FILTER_LINEAR :: gl.LINEAR
    RENDERER_FILTER_NEAREST :: gl.NEAREST
    RENDERER_CLAMP_TO_EDGE :: gl.CLAMP_TO_EDGE

    DESIRED_MAJOR_VERSION : i32 : 4
    DESIRED_MINOR_VERSION : i32 : 1

    TEXTURE_MAX     :: 16 // TODO: Get this from OpenGL
    QUAD_MAX        :: 1_000
    INDEX_PER_QUAD  :: 6
    VERTEX_PER_QUAD :: 4
    QUAD_VERTEX_MAX :: QUAD_MAX * VERTEX_PER_QUAD
    QUAD_INDEX_MAX  :: QUAD_MAX * INDEX_PER_QUAD
    UNIFORM_MAX     :: 10
    PALETTE_SIZE    :: 32
    PALETTE_MAX     :: 4

    QUAD_POSITIONS  := [?]Vector4f32 {
        { -0.5, -0.5, 0, 1 },
        {  0.5, -0.5, 0, 1 },
        {  0.5,  0.5, 0, 1 },
        { -0.5,  0.5, 0, 1 },
    }
    QUAD_COORDINATES := [?]Vector2f32 {
        { 0, 0 },
        { 1, 0 },
        { 1, 1 },
        { 0, 1 },
    }
    GL_TYPES_SIZES := map[int]u32 {
        gl.FLOAT         = size_of(f32),
        gl.INT           = size_of(i32),
        gl.UNSIGNED_INT  = size_of(u32),
        gl.UNSIGNED_BYTE = size_of(byte),
    }

    Renderer_State :: struct {
        enabled:                    bool,
        pixel_density:              f32,
        refresh_rate:               i32,
        draw_duration:              i32,
        gl_context:                 sdl2.GLContext,
        queries:                    [10]u32,
        max_texture_image_units:    i32,
        quad_vertex_array:          Vertex_Array,
        quad_vertex_buffer:         Vertex_Buffer,
        quad_index_buffer:          Index_Buffer,
        quad_vertices:              [QUAD_VERTEX_MAX]Quad,
        quad_vertex_ptr:            ^Quad,
        quad_indices:               [QUAD_INDEX_MAX]i32,
        quad_index_count:           int,
        shaders:                    map[Asset_Id]^Shader,
        shader_error:               Shader,
        shader_line:                Shader,
        current_shader:             ^Shader,
        samplers:                   [TEXTURE_MAX]i32,
        texture_slots:              [TEXTURE_MAX]^Texture, // TODO: Can we just have list of renderer_id ([]u32)?
        texture_slot_index:         int,
        palettes:                   [PALETTE_MAX]Color_Palette,
        texture_white:              ^Texture,
        ui_camera:                  Camera_Orthographic,
        world_camera:               Camera_Orthographic,
        buffer_camera:              Camera_Orthographic,
        current_camera:             ^Camera_Orthographic,
        previous_camera:            ^Camera_Orthographic,
        native_resolution:          Vector2f32,
        ideal_scale:                f32,
        stats:                      Renderer_Stats,
        draw_ui:                    bool,
        frame_buffer:               u32,
        render_buffer:              u32,
        buffer_texture_id:          u32,
        debug_notification:         UI_Notification,
        game_view_position:         Vector2f32,
        game_view_size:             Vector2f32,
        game_view_resized:          bool,
    }

    Color_Palette :: distinct [PALETTE_SIZE]Color

    Renderer_Stats :: struct {
        quad_count: u32,
        draw_count: u32,
    }

    Shader :: struct {
        renderer_id:            u32,
        uniform_location_cache: map[string]i32,
        vertex:                 string,
        fragment:               string,
    }
    Shader_Types :: enum { None = -1, Vertex = 0, Fragment = 1 }

    Vertex_Buffer :: struct {
        renderer_id: u32,
    }

    Index_Buffer :: struct {
        renderer_id: u32,
        count:       u32,
    }

    Vertex_Array :: struct {
        renderer_id: u32,
    }

    Vertex_Buffer_Layout :: struct {
        elements: [dynamic]Vertex_Buffer_Element,
        stride:   u32,
    }

    Vertex_Buffer_Element :: struct {
        type:       u32,
        count:      u32,
        normalized: bool,
    }

    when ODIN_DEBUG {
        Texture :: struct {
            renderer_id:        u32,
            filepath:           string,
            width:              i32,
            height:             i32,
            bytes_per_pixel:    i32,
            data:               [^]byte,

            texture_min_filter: i32,
            texture_mag_filter: i32,
            texture_wrap_s:     i32,
            texture_wrap_t:     i32,
        }
    } else {
        Texture :: struct {
            renderer_id:        u32,
            filepath:           string,
            width:              i32,
            height:             i32,
            bytes_per_pixel:    i32,
            data:               [^]byte,
        }
    }

    renderer_init :: proc(window: ^Window, native_resolution: Vector2f32) -> (ok: bool) {
        context.allocator = _e.allocator
        profiler_zone("renderer_init", PROFILER_COLOR_ENGINE)

        log.infof("Renderer (OpenGL) ------------------------------------------")
        _e.renderer = new(Renderer_State)

        defer {
            if ok {
                log.infof("  Init:                 OK")
            } else {
                log.error("  Init:                 KO")
            }
        }

        sdl2.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, DESIRED_MAJOR_VERSION)
        sdl2.GL_SetAttribute(.CONTEXT_MINOR_VERSION, DESIRED_MINOR_VERSION)
        sdl2.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))
        sdl2.GL_SetAttribute(.DOUBLEBUFFER, 1)
        sdl2.GL_SetAttribute(.DEPTH_SIZE, 24)
        sdl2.GL_SetAttribute(.STENCIL_SIZE, 8)

        for i in 0 ..< TEXTURE_MAX {
            _e.renderer.samplers[i] = i32(i)
        }

        _e.renderer.gl_context = sdl2.GL_CreateContext(_e.platform.window)
        if _e.renderer.gl_context == nil {
            log.errorf("sdl2.GL_CreateContext error: %v.", sdl2.GetError())
            return
        }

        sdl2.GL_MakeCurrent(_e.platform.window, _e.renderer.gl_context)

        // 0 for immediate updates, 1 for updates synchronized with the vertical retrace, -1 for adaptive vsync
        interval : i32 = 1
        if sdl2.GL_SetSwapInterval(interval) != 0 {
            log.errorf("sdl2.GL_SetSwapInterval error: %v.", sdl2.GetError())
            return
        }

        renderer_reload(_e.renderer)

        log.infof("  GL VERSION:           %v.%v", DESIRED_MAJOR_VERSION, DESIRED_MINOR_VERSION)
        log.infof("  VENDOR:               %v", gl.GetString(gl.VENDOR))
        log.infof("  RENDERER:             %v", gl.GetString(gl.RENDERER))
        log.infof("  VERSION:              %v", gl.GetString(gl.VERSION))

        gl.GenQueries(len(_e.renderer.queries), &_e.renderer.queries[0])

        // Notes: this is supported only in 4.3+
        // gl.DebugMessageCallback(_debug_message_callback, nil)
        // _debug_message_callback :: proc "c" (source: u32, type: u32, id: u32, severity: u32, length: i32, message: cstring, userParam: rawptr) {
        //     context = _e.ctx
        //     log.debugf("_debug_message_callback: %v, %v, %v, %v, %v", source, type, severity, length, message)
        // }

        {
            gl.Enable(gl.BLEND)
            gl.BlendEquation(gl.FUNC_ADD)
            gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

            offset : i32 = 0
            for i := 0; i < QUAD_INDEX_MAX; i += INDEX_PER_QUAD {
                _e.renderer.quad_indices[i + 0] = 0 + offset
                _e.renderer.quad_indices[i + 1] = 1 + offset
                _e.renderer.quad_indices[i + 2] = 2 + offset
                _e.renderer.quad_indices[i + 3] = 2 + offset
                _e.renderer.quad_indices[i + 4] = 3 + offset
                _e.renderer.quad_indices[i + 5] = 0 + offset
                offset += VERTEX_PER_QUAD
            }

            gl.GenVertexArrays(1, &_e.renderer.quad_vertex_array.renderer_id)

            gl.GenBuffers(1, &_e.renderer.quad_vertex_buffer.renderer_id)
            gl.BindBuffer(gl.ARRAY_BUFFER, _e.renderer.quad_vertex_buffer.renderer_id)
            gl.BufferData(gl.ARRAY_BUFFER, size_of(_e.renderer.quad_vertices), nil, gl.DYNAMIC_DRAW)

            _e.renderer.quad_index_buffer.count = len(_e.renderer.quad_indices)
            gl.GenBuffers(1, &_e.renderer.quad_index_buffer.renderer_id)
            gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, _e.renderer.quad_index_buffer.renderer_id)
            gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, int(_e.renderer.quad_index_buffer.count * size_of(u32)), &_e.renderer.quad_indices[0], gl.STATIC_DRAW)

            layout := Vertex_Buffer_Layout {}
            push_f32_vertex_buffer_layout(&layout, 2) // position
            push_f32_vertex_buffer_layout(&layout, 4) // color
            push_f32_vertex_buffer_layout(&layout, 2) // texture_coordinates
            push_i32_vertex_buffer_layout(&layout, 1) // texture_index
            push_i32_vertex_buffer_layout(&layout, 1) // palette_index
            add_buffer_to_vertex_array(&_e.renderer.quad_vertex_array, &_e.renderer.quad_vertex_buffer, &layout)

            color_white : u32 = 0xffffffff
            _e.renderer.texture_white = create_texture({ 1, 1 }, &color_white, &{ RENDERER_FILTER_LINEAR, RENDERER_CLAMP_TO_EDGE }) or_return

            _e.renderer.texture_slots[0] = _e.renderer.texture_white
            _e.renderer.quad_vertex_ptr = &_e.renderer.quad_vertices[0]

            gl.GetIntegerv(gl.MAX_TEXTURE_IMAGE_UNITS, &_e.renderer.max_texture_image_units)

            if renderer_shader_load(&_e.renderer.shader_error, "media/shaders/shader_error.glsl") == false {
                log.errorf("Shader error: %v.", gl.GetError())
                return
            }
            // FIXME: load this via assets pipeline
            if renderer_shader_load(&_e.renderer.shader_line, "media/shaders/shader_test.glsl") == false {
                log.errorf("Shader error: %v.", gl.GetError())
                return
            }
        }

        _e.renderer.enabled = true
        _e.renderer.native_resolution = native_resolution
        _e.renderer.pixel_density = renderer_get_window_pixel_density(_e.platform.window)

        renderer_create_frame_buffer(&_e.renderer.frame_buffer, &_e.renderer.render_buffer, &_e.renderer.buffer_texture_id)

        ok = true
        return
    }

    renderer_reload :: proc(renderer: ^Renderer_State) {
        _e.renderer = renderer
        gl.load_up_to(int(DESIRED_MAJOR_VERSION), int(DESIRED_MINOR_VERSION), proc(ptr: rawptr, name: cstring) {
            (cast(^rawptr)ptr)^ = sdl2.GL_GetProcAddress(name)
        })

        // TODO: move to an UI package
        when IMGUI_ENABLE {
            imgui.CHECKVERSION()
            imgui.CreateContext(nil)
            io := imgui.GetIO()
            io.ConfigFlags += { .NavEnableKeyboard, .NavEnableGamepad }
            when imgui.IMGUI_BRANCH == "docking" {
                io.ConfigFlags += { .DockingEnable }
                // io.ConfigFlags += { .ViewportsEnable }
            }
            imgui.StyleColorsDark(nil)
            ok := imgui_impl_sdl2.InitForOpenGL(_e.platform.window, _e.renderer.gl_context)
            if ok == false {
                log.errorf("Couldn't init imgui sdl")
                os.exit(1)
            }
            ok = imgui_impl_opengl3.Init(nil)
            if ok == false {
                log.errorf("Couldn't init imgui opengl")
                os.exit(1)
            }

            // FIXME:
            // imgui.SetAllocatorFunctions(imgui_alloc, imgui_free, &_e.allocator)
            // result := sdl2.SetMemoryFunctions(sdl_malloc, sdl_calloc, sdl_realloc, sdl_free)
            // if result < 0 {
            //     log.errorf("SetMemoryFunctions error: %v", sdl2.GetError())
            // }
        }

        renderer_update_viewport()
    }

    renderer_quit :: proc() {
        // when IMGUI_ENABLE {
        //     imgui_impl_opengl3.Shutdown()
        //     imgui_impl_sdl2.Shutdown()
        //     imgui.DestroyContext(nil)

        //     // FIXME:
        //     imgui.SetAllocatorFunctions(imgui_alloc, imgui_free, &_e.allocator)
        //     result := sdl2.SetMemoryFunctions(sdl_malloc, sdl_calloc, sdl_realloc, sdl_free)
        //     if result < 0 {
        //         log.errorf("SetMemoryFunctions error: %v", sdl2.GetError())
        //     }
        // }

        // sdl2.GL_DeleteContext(_e.renderer.gl_context)
    }

    renderer_render_begin :: proc() {
        context.allocator = _e.allocator
        profiler_zone("renderer_begin", PROFILER_COLOR_ENGINE)

        _e.renderer.previous_camera = nil
        _e.renderer.stats = {}

        when GPU_PROFILER {
            gl.BeginQuery(gl.TIME_ELAPSED, _e.renderer.queries[0])
        }

        when IMGUI_ENABLE {
            imgui_impl_opengl3.NewFrame()
            imgui_impl_sdl2.NewFrame()
            imgui.NewFrame()
        }

        renderer_batch_begin()
    }

    renderer_render_end :: proc() {
        context.allocator = _e.allocator
        profiler_zone("renderer_end", PROFILER_COLOR_ENGINE)

        renderer_batch_end()
        renderer_flush()
        renderer_draw_ui()

        when GPU_PROFILER {
            profiler_zone("query", PROFILER_COLOR_ENGINE)
            gl.EndQuery(gl.TIME_ELAPSED)
            gl.GetQueryObjectiv(_e.renderer.queries[0], gl.QUERY_RESULT, &_e.renderer.draw_duration)
        }

        {
            profiler_zone("swap", PROFILER_COLOR_ENGINE)
            sdl2.GL_SwapWindow(_e.platform.window)
        }
    }

    renderer_batch_begin :: proc() {
        context.allocator = _e.allocator
        _e.renderer.texture_slot_index = 0
        _e.renderer.quad_index_count = 0
        _e.renderer.quad_vertex_ptr = &_e.renderer.quad_vertices[0]

        if _e.renderer.current_shader == nil {
            gl.UseProgram(0)
        } else {
            gl.UseProgram(_e.renderer.current_shader.renderer_id)

            // FIXME:
            if _e.renderer.current_shader == &_e.renderer.shader_line {
                points := []Vector2f32 {
                    { 500, 500 },
                    { 1200, 500 },
                    { 1200, 0 },
                    { 200, 800 },
                }
                renderer_set_uniform_mat4f_to_shader(_e.renderer.current_shader, "u_model_view_projection", &_e.renderer.current_camera.projection_view_matrix)
                renderer_set_uniform_1f_to_shader(_e.renderer.current_shader,    "u_time", f32(platform_get_ticks()))
                renderer_set_uniform_1i_to_shader(_e.renderer.current_shader,    "u_points_count", i32(len(points)))
                renderer_set_uniform_2fv_to_shader(_e.renderer.current_shader,   "u_points", points[:], len(points))
            } else {
                // TODO: set the uniforms on a per shader basis
                renderer_set_uniform_mat4f_to_shader(_e.renderer.current_shader, "u_model_view_projection", &_e.renderer.current_camera.projection_view_matrix)
                renderer_set_uniform_1f_to_shader(_e.renderer.current_shader,    "u_time", f32(platform_get_ticks()))
                renderer_set_uniform_1iv_to_shader(_e.renderer.current_shader,   "u_textures", _e.renderer.samplers[:])
                renderer_set_uniform_4fv_to_shader(_e.renderer.current_shader,   "u_palettes", transmute(^[]Vector4f32) &_e.renderer.palettes[0][0], PALETTE_SIZE * PALETTE_MAX * 4)
            }
        }
    }

    renderer_batch_end :: proc() {
        // profiler_zone("renderer_batch_end", PROFILER_COLOR_ENGINE)
    }

    renderer_flush :: proc(loc := #caller_location) {
        profiler_zone("renderer_flush", PROFILER_COLOR_ENGINE)
        context.allocator = _e.allocator

        when IMGUI_ENABLE && IMGUI_GAME_VIEW {
            renderer_bind_frame_buffer(&_e.renderer.frame_buffer)
        }

        if _e.renderer.quad_index_count == 0 {
            // log.warnf("Flush with nothing to draw. (%v)", loc)
            return
        }

        if _e.renderer.current_camera == nil {
            log.warnf("Flush with no camera. (%v)", loc)
            return
        }

        if _e.renderer.current_shader == nil {
            log.warnf("Flush with no shader. (%v)", loc)
            return
        }

        gl.UseProgram(_e.renderer.current_shader.renderer_id)

        {
            profiler_zone("BufferSubData", PROFILER_COLOR_ENGINE)
            gl.BindBuffer(gl.ARRAY_BUFFER, _e.renderer.quad_vertex_buffer.renderer_id)
            ptr := gl.MapBuffer(gl.ARRAY_BUFFER, gl.WRITE_ONLY)
            mem.copy(ptr, &_e.renderer.quad_vertices, size_of(_e.renderer.quad_vertices))
            gl.UnmapBuffer(gl.ARRAY_BUFFER)
        }
        for i in 0..< _e.renderer.texture_slot_index {
            bind_texture(_e.renderer.texture_slots[i], i32(i))
        }

        gl.BindVertexArray(_e.renderer.quad_vertex_array.renderer_id)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, _e.renderer.quad_index_buffer.renderer_id)
        gl.DrawElements(gl.TRIANGLES, i32(_e.renderer.quad_index_count), gl.UNSIGNED_INT, nil)

        when IMGUI_ENABLE && IMGUI_GAME_VIEW {
            renderer_unbind_frame_buffer()
        }

        _e.renderer.stats.draw_count += 1
    }

    renderer_change_camera_begin :: proc(camera: ^Camera_Orthographic, loc := #caller_location) {
        if _e.renderer.previous_camera != nil && camera != _e.renderer.current_camera {
            renderer_batch_end()
            renderer_flush()
            renderer_batch_begin()
        }

        _e.renderer.current_camera = camera

        // log.debugf("change_camera_begin (%v) | %v => %v", loc, _camera_name(_e.renderer.previous_camera), _camera_name(_e.renderer.current_camera))
    }

    renderer_process_events :: proc(event: ^sdl2.Event) {
        when IMGUI_ENABLE {
            imgui_impl_sdl2.ProcessEvent(event)
        }
    }

    renderer_get_window_pixel_density :: proc(window: ^Window) -> f32 {
        window_size := platform_get_window_size(window)
        output_width: i32
        output_height: i32
        sdl2.GL_GetDrawableSize(window, &output_width, &output_height)
        if output_width == 0 || output_height == 0 {
            log.errorf("sdl2.GL_GetDrawableSize error: %v.", sdl2.GetError())
            return 1
        }
        return f32(output_width) / f32(window_size.x)
    }

    renderer_draw_ui :: proc() {
        profiler_zone("renderer_draw_ui", PROFILER_COLOR_ENGINE)
        when IMGUI_ENABLE {
            imgui.Render()
            imgui_impl_opengl3.RenderDrawData(imgui.GetDrawData())

            when imgui.IMGUI_BRANCH == "docking" {
                backup_current_window := sdl2.GL_GetCurrentWindow()
                backup_current_context := sdl2.GL_GetCurrentContext()
                imgui.UpdatePlatformWindows()
                imgui.RenderPlatformWindowsDefault()
                sdl2.GL_MakeCurrent(backup_current_window, backup_current_context)
            }
        }
    }

    debug_reload_shaders :: proc() -> (ok: bool) {
        for asset in _e.assets.assets {
            if asset.type != .Shader || asset.state != .Loaded {
                continue
            }

            asset_info, asset_info_ok := asset.info.(Asset_Info_Shader)
            if asset_info_ok == false {
                log.errorf("Couldn't reload shader: %v", asset.id)
                continue
            }
            ok = renderer_shader_load(asset_info.shader, asset.file_name)
        }
        ui_create_notification("Shaders reloaded.", 3000)
        return
    }

    renderer_get_viewport :: proc() -> Vector4i32 {
        viewport: Vector4i32
        gl.GetIntegerv(gl.VIEWPORT, transmute(^i32) &viewport)
        return viewport
    }
    renderer_set_viewport :: proc(x, y, width, height: i32) {
        gl.Viewport(x, y, width, height);
    }

    renderer_update_viewport :: proc(loc := #caller_location) {
        when IMGUI_GAME_VIEW {
            _e.renderer.ideal_scale = math.max(math.floor(_e.renderer.game_view_size.x / _e.renderer.native_resolution.x), 1)
        } else {
            _e.renderer.game_view_size = Vector2f32 {
                f32(_e.platform.window_size.x) * _e.renderer.pixel_density,
                f32(_e.platform.window_size.y) * _e.renderer.pixel_density,
            }

            if _e.renderer.game_view_size.x > _e.renderer.game_view_size.y {
                _e.renderer.ideal_scale = math.max(math.floor(_e.renderer.game_view_size.x / _e.renderer.native_resolution.x), 1)
            } else {
                _e.renderer.ideal_scale = math.max(math.floor(_e.renderer.game_view_size.y / _e.renderer.native_resolution.y), 1)
            }
        }

        renderer_set_viewport(0, 0, i32(_e.renderer.game_view_size.x), i32(_e.renderer.game_view_size.y))
    }

    // FIXME: don't do this every frame
    renderer_update_camera_matrix :: proc() {
        game_view_size := &_e.renderer.game_view_size
        ui_camera := &_e.renderer.ui_camera
        world_camera := &_e.renderer.world_camera

        _e.renderer.ui_camera.projection_matrix = matrix_ortho3d_f32(
            0, game_view_size.x / ui_camera.zoom,
            game_view_size.y / ui_camera.zoom, 0,
            -1, 1,
        )
        ui_camera.view_matrix = matrix4_translate_f32(ui_camera.position) * matrix4_rotate_f32(ui_camera.rotation, { 0, 0, 1 })
        ui_camera.projection_view_matrix = ui_camera.projection_matrix * ui_camera.view_matrix

        world_camera.projection_matrix = matrix_ortho3d_f32(
            -game_view_size.x / 2 / world_camera.zoom, +game_view_size.x / 2 / world_camera.zoom,
            +game_view_size.y / 2 / world_camera.zoom, -game_view_size.y / 2 / world_camera.zoom,
            -1, 1,
        )
        world_camera.view_matrix = matrix4_translate_f32(world_camera.position) * matrix4_rotate_f32(world_camera.rotation, { 0, 0, 1 })
        world_camera.view_matrix = matrix4_inverse_f32(world_camera.view_matrix)
        world_camera.projection_view_matrix = world_camera.projection_matrix * world_camera.view_matrix
    }

    renderer_clear :: proc(color: Color) {
        assert_color_is_f32(color)
        gl.ClearColor(color.r, color.g, color.b, color.a)
        gl.Clear(gl.COLOR_BUFFER_BIT)
    }

    renderer_push_quad :: proc(position: Vector2f32, size: Vector2f32,
        color: Color = { 1, 1, 1, 1 }, texture: ^Texture = _e.renderer.texture_white,
        texture_coordinates: Vector2f32 = { 0, 0 }, texture_size: Vector2f32 = { 1, 1 },
        rotation: f32 = 0, shader: ^Shader = nil, palette: i32 = -1,
        loc := #caller_location,
    ) {
        assert_color_is_f32(color, loc)
        _batch_begin_if_necessary(shader)
        _quad_me_daddy(position, size, rotation, color, texture, texture_coordinates, texture_size, palette)
    }

    renderer_push_line :: proc(position: Vector2f32, size: Vector2f32, loc := #caller_location) {
        shader := &_e.renderer.shader_line
        _batch_begin_if_necessary(shader)

        rotation := f32(0)
        color := Color { 1, 1, 1, 1 }
        texture := _e.renderer.texture_white
        texture_coordinates := Vector2f32 { 0, 0 }
        texture_size := Vector2f32 { 1, 1 }
        palette_index := i32(0)
        _quad_me_daddy(position, size, rotation, color, texture, texture_coordinates, texture_size, palette_index)
    }

    _quad_me_daddy :: proc(position, size: Vector2f32, rotation: f32, color: Color, texture: ^Texture, texture_coordinates, texture_size: Vector2f32, palette_index: i32) {
        texture_index : i32 = 0
        for i := 1; i < _e.renderer.texture_slot_index; i+= 1 {
            if _e.renderer.texture_slots[i] == texture {
                texture_index = i32(i)
                break
            }
        }

        if texture_index == 0 {
            texture_index = i32(_e.renderer.texture_slot_index)
            _e.renderer.texture_slots[_e.renderer.texture_slot_index] = texture
            _e.renderer.texture_slot_index += 1
        }

        // TODO: this is super expensive to do on the CPU, is it worth it to do it on the GPU?
        // Might not be worth it because we would have to memcpy more vertex data every frame...
        transform := glm.mat4Translate({ position.x, position.y, 1 }) * glm.mat4Rotate({ 0, 0, 1 }, rotation) * glm.mat4Scale({ size.x, size.y, 0 })

        // TODO: use SIMD instructions for this
        for i := 0; i < VERTEX_PER_QUAD; i += 1 {
            _e.renderer.quad_vertex_ptr.position = Vector4f32(transform * QUAD_POSITIONS[i]).xy
            _e.renderer.quad_vertex_ptr.color = color
            _e.renderer.quad_vertex_ptr.texture_coordinates = texture_coordinates + texture_size * QUAD_COORDINATES[i]
            _e.renderer.quad_vertex_ptr.texture_index = texture_index
            _e.renderer.quad_vertex_ptr.palette_index = palette_index
            _e.renderer.quad_vertex_ptr = mem.ptr_offset(_e.renderer.quad_vertex_ptr, 1)
        }

        _e.renderer.quad_index_count += INDEX_PER_QUAD
        _e.renderer.stats.quad_count += 1
        _e.renderer.previous_camera = _e.renderer.current_camera
    }

    _batch_begin_if_necessary :: proc(shader: ^Shader) {
        if _e.renderer.current_camera == nil {
            _e.renderer.current_camera = &_e.renderer.world_camera
        }
        shader_with_fallback := shader
        if shader == nil {
            shader_with_fallback = &_e.renderer.shader_error
        }

        max_quad_reached := _e.renderer.quad_index_count >= QUAD_INDEX_MAX
        max_texture_reached := _e.renderer.texture_slot_index > TEXTURE_MAX - 1
        camera_changed := _e.renderer.quad_index_count > 0 && _e.renderer.current_camera != _e.renderer.previous_camera
        shader_changed := _e.renderer.current_shader != shader_with_fallback
        if max_quad_reached || max_texture_reached || camera_changed || shader_changed {
            renderer_batch_end()
            // log.warnf("_batch_begin_if_necessary TRUE \n-> max_quad_reached %v || max_texture_reached %v || camera_changed %v || shader_changed: %v", max_quad_reached, max_texture_reached, camera_changed, shader_changed)
            // log.debugf("%v -> %v", shader_with_fallback.renderer_id, _e.renderer.current_shader.renderer_id)
            renderer_flush()
            renderer_batch_begin()
        }

        _e.renderer.current_shader = shader_with_fallback
    }

    renderer_is_enabled :: proc() -> bool {
        return _e.renderer != nil && _e.renderer.enabled
    }

    renderer_shader_load :: proc(shader: ^Shader, filepath: string, binary_retrievable := false) -> (ok: bool) {
        data : []byte
        data, ok = os.read_entire_file(filepath, context.temp_allocator)
        if ok == false {
            log.errorf("Shader file couldn't be read: %v", filepath)
            return
        }

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
                strings.write_rune(&builders[type], '/')
                strings.write_rune(&builders[type], '/')
                strings.write_string(&builders[type], line)
                strings.write_rune(&builders[type], '\n')

                // log.debugf("  %v", type)
                // log.debugf("  ----------------------------------------------------------")
            } else {
                if type == .None {
                    continue
                }
                strings.write_string(&builders[type], line)
                strings.write_rune(&builders[type], '\n')
            }
        }

        vertex := strings.to_string(builders[Shader_Types.Vertex])
        fragment := strings.to_string(builders[Shader_Types.Fragment])
        // log.debugf("vertex -----------------------------------------------------\n%v", vertex)
        // log.debugf("fragment ---------------------------------------------------\n%v", fragment)

        // when RENDERER_DEBUG {
        //     shader.filepath = filepath
        //     shader.vertex = vertex
        //     shader.fragment = fragment
        // }
        shader.renderer_id, ok = gl.load_shaders_source(vertex, fragment, binary_retrievable)

        return
    }

    _camera_name :: proc(camera: ^Camera_Orthographic) -> string {
        if camera != nil && camera == &_e.renderer.ui_camera {
            return "ui"
        }
        if camera != nil && camera == &_e.renderer.world_camera {
            return "world"
        }
        return "nil"
    }

    @(private="file")
    add_buffer_to_vertex_array :: proc(vertex_array: ^Vertex_Array, vertex_buffer: ^Vertex_Buffer, layout: ^Vertex_Buffer_Layout) {
        gl.BindVertexArray(vertex_array.renderer_id)
        gl.BindBuffer(gl.ARRAY_BUFFER, vertex_buffer.renderer_id)

        offset: u32
        for element, index in layout.elements {
            gl.EnableVertexAttribArray(u32(index))
            gl.VertexAttribPointer(u32(index), i32(element.count), element.type, element.normalized, i32(layout.stride), cast(uintptr)offset)
            offset += element.count * get_size_of_type(element.type)
        }
    }

    @(private="file")
    get_size_of_type :: proc(type: u32) -> u32 {
        size, exists := GL_TYPES_SIZES[int(type)]
        if exists {
            return size
        }
        log.errorf("Unknown GL type: %v", type)
        return 0
    }

    @(private="file")
    push_f32_vertex_buffer_layout :: proc(using vertex_buffer_layout: ^Vertex_Buffer_Layout, count: u32) {
        append(&elements, Vertex_Buffer_Element { u32(gl.FLOAT), count, false })
        stride += count * get_size_of_type(gl.FLOAT)
    }
    @(private="file")
    push_i32_vertex_buffer_layout :: proc(using vertex_buffer_layout: ^Vertex_Buffer_Layout, count: u32) {
        append(&elements, Vertex_Buffer_Element { u32(gl.INT), count, false })
        stride += count * get_size_of_type(gl.INT)
    }

    renderer_shader_create_from_asset :: proc(filepath: string, asset_id: Asset_Id) -> (shader: ^Shader, ok: bool) #optional_ok {
        shader = new(Shader)
        _e.renderer.shaders[asset_id] = shader
        if renderer_shader_load(shader, filepath) == false {
            log.errorf("Shader error: %v.", gl.GetError())
            return
        }
        ok = true
        return
    }

    renderer_shader_delete :: proc(asset_id: Asset_Id) -> bool {
        free(_e.renderer.shaders[asset_id])
        delete_key(&_e.renderer.shaders, asset_id)
        // TODO: delete shader
        // gl.DeleteShader(id)
        return true
    }

    renderer_set_uniform_1ui_to_shader :: proc(using shader: ^Shader, name: string, value: u32) {
        location := renderer_get_uniform_location_in_shader(shader, name)
        gl.Uniform1ui(location, value)
    }
    renderer_set_uniform_1i_to_shader :: proc(using shader: ^Shader, name: string, value: i32) {
        location := renderer_get_uniform_location_in_shader(shader, name)
        gl.Uniform1i(location, value)
    }
    renderer_set_uniform_1f_to_shader :: proc(using shader: ^Shader, name: string, value: f32) {
        location := renderer_get_uniform_location_in_shader(shader, name)
        gl.Uniform1f(location, value)
    }
    renderer_set_uniform_1iv_to_shader :: proc(using shader: ^Shader, name: string, value: []i32) {
        location := renderer_get_uniform_location_in_shader(shader, name)
        gl.Uniform1iv(location, i32(len(value)), &value[0])
    }
    renderer_set_uniform_2fv_to_shader :: proc(using shader: ^Shader, name: string, value: []Vector2f32, count: int) {
        location := renderer_get_uniform_location_in_shader(shader, name)
        gl.Uniform2fv(location, i32(count), &value[0][0])
    }
    renderer_set_uniform_4f_to_shader :: proc(using shader: ^Shader, name: string, value: Vector4f32) {
        location := renderer_get_uniform_location_in_shader(shader, name)
        gl.Uniform4f(location, value.x, value.y, value.z, value.w)
    }
    renderer_set_uniform_4fv_to_shader :: proc(using shader: ^Shader, name: string, value: ^[]Vector4f32, count: int) {
        location := renderer_get_uniform_location_in_shader(shader, name)
        gl.Uniform4fv(location, i32(count), transmute(^f32) value)
    }
    renderer_set_uniform_mat4f_to_shader :: proc(using shader: ^Shader, name: string, value: ^Matrix4x4f32) {
        location := renderer_get_uniform_location_in_shader(shader, name)
        gl.UniformMatrix4fv(location, 1, false, cast([^]f32) value)
    }

    renderer_get_uniform_location_in_shader :: proc(using shader: ^Shader, name: string) -> i32 {
        location, exists := shader.uniform_location_cache[name]
        if exists {
            return location
        }
        location = gl.GetUniformLocation(renderer_id, strings.clone_to_cstring(name))
        if location == -1 {
            log.warnf("Uniform %v doesn't exist in shader %v.", name, renderer_id)
        }
        shader.uniform_location_cache[name] = location
        return location
    }

    @(private="file")
    create_texture :: proc(size: Vector2i32, color: ^u32, options : ^Image_Load_Options) -> (texture: ^Texture, ok: bool) {
        texture = new(Texture)
        when ODIN_DEBUG {
            texture.texture_min_filter = options.filter
            texture.texture_mag_filter = options.filter
            texture.texture_wrap_s = options.wrap
            texture.texture_wrap_t = options.wrap
        }

        gl.GenTextures(1, &texture.renderer_id)
        gl.BindTexture(gl.TEXTURE_2D, texture.renderer_id)

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, options.filter)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, options.filter)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, options.wrap)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, options.wrap)

        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, size.x, size.y, 0, gl.RGBA, gl.UNSIGNED_BYTE, color)

        ok = true
        return
    }

    renderer_load_texture :: proc(filepath: string, options: ^Image_Load_Options) -> (texture: ^Texture, ok: bool) {
        texture = new(Texture)
        texture.filepath = strings.clone(filepath)
        texture.data = platform_load_image(filepath, &texture.width, &texture.height, &texture.bytes_per_pixel)
        when ODIN_DEBUG {
            texture.texture_min_filter = options.filter
            texture.texture_mag_filter = options.filter
            texture.texture_wrap_s = options.wrap
            texture.texture_wrap_t = options.wrap
        }
        if texture.data == nil {
            ok = false
            return
        }

        gl.GenTextures(1, &texture.renderer_id)
        gl.BindTexture(gl.TEXTURE_2D, texture.renderer_id)

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, options.filter)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, options.filter)
        if options.wrap != 0 {
            gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, options.wrap)
            gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, options.wrap)
        }
        if texture.bytes_per_pixel == 2 {
            gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RG8, texture.width, texture.height, 0, gl.RG, gl.UNSIGNED_BYTE, &texture.data[0])
        } else {
            gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, texture.width, texture.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, &texture.data[0])
        }

        ok = true
        return
    }

    @(private="file")
    bind_texture :: proc(using texture: ^Texture, slot: i32) {
        assert(slot < _e.renderer.max_texture_image_units)
        gl.ActiveTexture(gl.TEXTURE0 + u32(slot))
        gl.BindTexture(gl.TEXTURE_2D, renderer_id)
    }

    assert_color_is_f32 :: proc(color: Color, loc := #caller_location) {
        assert(color.r >= 0 && color.r <= 1 && color.g >= 0 && color.g <= 1 && color.b >= 0 && color.b <= 1 && color.a >= 0 && color.a <= 1, fmt.tprintf("Invalid color: %v", color), loc)
    }

    renderer_create_frame_buffer :: proc(frame_buffer, render_buffer, texture_id: ^u32) {
        WIDTH :: 1920
        HEIGHT :: 1080
        gl.GenFramebuffers(1, frame_buffer)
        gl.BindFramebuffer(gl.FRAMEBUFFER, frame_buffer^)

        gl.GenTextures(1, texture_id)
        gl.BindTexture(gl.TEXTURE_2D, texture_id^)
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, WIDTH, HEIGHT, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture_id^, 0)

        gl.GenRenderbuffers(1, render_buffer)
        gl.BindRenderbuffer(gl.RENDERBUFFER, render_buffer^)
        gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, WIDTH, HEIGHT)
        gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, render_buffer^)

        if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
            log.errorf("Framebuffer is not complete.")
        }

        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
        gl.BindTexture(gl.TEXTURE_2D, 0)
        gl.BindRenderbuffer(gl.RENDERBUFFER, 0)
    }

    renderer_bind_frame_buffer :: proc(frame_buffer: ^u32) {
        gl.BindFramebuffer(gl.FRAMEBUFFER, frame_buffer^)
    }

    renderer_unbind_frame_buffer :: proc() {
        gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
    }

    renderer_rescale_frame_buffer :: proc(width, height: i32, render_buffer, texture_id: u32) {
        gl.BindTexture(gl.TEXTURE_2D, texture_id)
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture_id, 0)

        gl.BindRenderbuffer(gl.RENDERBUFFER, render_buffer)
        gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, width, height)
        gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, render_buffer)
    }

    renderer_set_palette :: proc(index: i32, palette: Color_Palette) {
        assert(index >= 0 && index < PALETTE_MAX, "Palette index out of range.")
        _e.renderer.palettes[index] = palette
    }

    renderer_make_palette :: proc(colors: [PALETTE_SIZE][4]u8) -> Color_Palette {
        result := Color_Palette {}
        for color, i in colors {
            result[i] = { f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255 }
        }
        return result
    }
}

sdl_malloc : sdl2.malloc_func : proc "c" (size: c.size_t) -> rawptr {
    context = runtime.default_context()
    ptr := libc.malloc(size)
    fmt.printf("sdl_alloc: %v | %v\n", ptr, size)
    return ptr

    // ptr, error := mem.alloc(int(size), mem.DEFAULT_ALIGNMENT, _e.allocator)
    // fmt.printf("sdl_alloc: %v | %v\n", ptr, size)
    // if error != .None {
    //     fmt.eprintf("sdl_malloc error: %v\n", error)
    // }
    // return ptr
}
sdl_calloc : sdl2.calloc_func : proc "c" (nmemb, size: c.size_t) -> rawptr {
    context = runtime.default_context()
    fmt.printf("sdl_calloc: %v | %v\n", nmemb, size)
    return libc.calloc(nmemb, size)

    // len := int(nmemb * size)
    // ptr, error := mem.alloc(len, mem.DEFAULT_ALIGNMENT, _e.allocator)
    // if error != .None {
    //     fmt.eprintf("sdl_calloc error: %v\n", error)
    // }
    // return mem.zero(ptr, len)
}
sdl_realloc : sdl2.realloc_func : proc "c" (ptr: rawptr, size: c.size_t) -> rawptr {
    context = runtime.default_context()
    fmt.printf("sdl_realloc: %v\n", size)
    return libc.realloc(ptr, size)

    // ptr_new, error := mem.resize(ptr, int(size), int(size), mem.DEFAULT_ALIGNMENT, _e.allocator)
    // if error != .None {
    //     fmt.eprintf("sdl_realloc error: %v\n", error)
    // }
    // return ptr_new
}
sdl_free : sdl2.free_func : proc "c" (ptr: rawptr) {
    context = runtime.default_context()
    fmt.printf("sdl_free: %v\n", ptr)
    libc.free(ptr)

    // error := mem.free(ptr, _e.allocator)
    // if error != .None {
    //     fmt.eprintf("sdl_free error: %v\n", error)
    // }
}

imgui_alloc : imgui.MemAllocFunc : proc "c" (size: c.size_t, user_data: rawptr) -> rawptr {
    context = runtime.default_context()
    allocator := (cast(^mem.Allocator) user_data)^
    ptr, error := mem.alloc(int(size), mem.DEFAULT_ALIGNMENT, allocator)
    fmt.printf("imgui_alloc: %v | %v\n", ptr, size)
    if error != .None {
        fmt.eprintf("imgui_alloc error: %v\n", error)
    }
    return ptr
}
imgui_free : imgui.MemFreeFunc : proc "c" (ptr: rawptr, user_data: rawptr) {
    context = runtime.default_context()
    allocator := (cast(^mem.Allocator) user_data)^
    error := mem.free(ptr, allocator)
    fmt.printf("imgui_free: %v\n", ptr)
    if error != .None {
        fmt.eprintf("imgui_free error: %v\n", error)
    }
}
