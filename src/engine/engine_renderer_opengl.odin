package engine

IMGUI_ENABLE :: true

when RENDERER == .OpenGL {
    import "core:fmt"
    import "core:log"
    import "core:mem"
    import "core:slice"
    import "core:strings"
    import "core:math"
    import "core:math/linalg"
    import "vendor:sdl2"
    import gl "vendor:OpenGL"
    import imgui "../odin-imgui"
    import imgui_sdl "imgui_impl_sdl"
    import imgui_opengl "imgui_impl_opengl"

    RENDERER_DEBUG :: gl.GL_DEBUG

    DESIRED_GL_MAJOR_VERSION : i32 : 4
    DESIRED_GL_MINOR_VERSION : i32 : 1

    TEXTURE_MAX     :: 16 // TODO: Get this from OpenGL
    QUAD_MAX        :: 1_000
    INDEX_PER_QUAD  :: 6
    VERTEX_PER_QUAD :: 4
    QUAD_VERTEX_MAX :: QUAD_MAX * VERTEX_PER_QUAD
    QUAD_INDEX_MAX  :: QUAD_MAX * INDEX_PER_QUAD
    UNIFORM_MAX     :: 10

    _r : ^Renderer_State

    Renderer_State :: struct {
        using base:                 Renderer_State_Base,
        sdl_state:                  imgui_sdl.SDL_State,
        opengl_state:               imgui_opengl.OpenGL_State,
        queries:                    [10]u32,
        max_texture_image_units:    i32,
        quad_vertex_array:          ^Vertex_Array,
        quad_vertex_buffer:         ^Vertex_Buffer,
        quad_index_buffer:          ^Index_Buffer,
        quad_vertices:              [QUAD_VERTEX_MAX]Vertex_Quad,
        quad_vertex_ptr:            ^Vertex_Quad,
        quad_indices:               [QUAD_INDEX_MAX]i32,
        quad_index_count:           int,
        texture_slots:              [TEXTURE_MAX]^Texture, // TODO: Can we just have list of renderer_id ([]u32)?
        texture_slot_index:         int,
        quad_shader:                ^Shader,
        LOCATION_NAME_MVP:          string,
        LOCATION_NAME_TEXTURES:     string,
        LOCATION_NAME_COLOR:        string,
        LOCATION_NAME_TEXELS_PER_PIXEL: string,
        texture_white:              ^Texture,
        texture_0:                  ^Texture,
        texture_1:                  ^Texture,
        texture_2:                  ^Texture,
        texture_3:                  ^Texture,
        ui_camera:                  Camera_Orthographic,
        world_camera:               Camera_Orthographic,
        current_camera:             ^Camera_Orthographic,
        previous_camera:            ^Camera_Orthographic,
        native_resolution:          Vector2f32,
        ideal_scale:                f32,
        stats:                      Renderer_Stats,
    }

    Color :: struct {
        r, g, b, a: f32,
    }

    Camera_Orthographic :: struct {
        position:                   Vector3f32,
        rotation:                   f32,
        zoom:                       f32,

        projection_matrix:          Matrix4x4f32,
        view_matrix:                Matrix4x4f32,
        projection_view_matrix:     Matrix4x4f32,
    }

    Renderer_Stats :: struct {
        quad_count: u32,
        draw_count: u32,
    }

    Vertex_Quad :: struct {
        position:               Vector2f32,
        scale:                  Vector2f32,
        color:                  Color,
        texture_coordinates:    Vector2f32,
        texture_index:          i32,
    }

    renderer_init :: proc(window: ^Window, native_resolution: Vector2f32, allocator := context.allocator) -> (ok: bool) {
        profiler_zone("renderer_init")
        _engine.renderer = new(Renderer_State, allocator)
        _r = _engine.renderer
        _r.LOCATION_NAME_MVP = strings.clone("u_model_view_projection")
        _r.LOCATION_NAME_TEXTURES = strings.clone("u_textures")
        _r.LOCATION_NAME_COLOR = strings.clone("u_color")
        _r.LOCATION_NAME_TEXELS_PER_PIXEL = strings.clone("u_texels_per_pixel")

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

        interval : i32 = 1
        if sdl2.GL_SetSwapInterval(interval) != 0 {
            log.errorf("sdl2.GL_SetSwapInterval error: %v.", sdl2.GetError())
            return
        }

        renderer_reload(_r)

        log.infof("OpenGL renderer --------------------------------------------")
        log.infof("  GL VERSION:           %v.%v", DESIRED_GL_MAJOR_VERSION, DESIRED_GL_MINOR_VERSION)
        log.infof("  VENDOR:               %v", gl.GetString(gl.VENDOR))
        log.infof("  RENDERER:             %v", gl.GetString(gl.RENDERER))
        log.infof("  VERSION:              %v", gl.GetString(gl.VERSION))
        log.infof("  size_of(Shader):      %v", size_of(Shader))

        gl.GenQueries(len(_r.queries), &_r.queries[0])

        {
            gl.Enable(gl.BLEND)
            gl.BlendEquation(gl.FUNC_ADD)
            gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

            offset : i32 = 0
            for i := 0; i < QUAD_INDEX_MAX; i += INDEX_PER_QUAD {
                _r.quad_indices[i + 0] = 0 + offset
                _r.quad_indices[i + 1] = 1 + offset
                _r.quad_indices[i + 2] = 2 + offset
                _r.quad_indices[i + 3] = 2 + offset
                _r.quad_indices[i + 4] = 3 + offset
                _r.quad_indices[i + 5] = 0 + offset
                offset += VERTEX_PER_QUAD
            }

            _r.quad_vertex_array = _gl_create_vertex_array()
            _r.quad_vertex_buffer = _gl_create_vertex_buffer(nil, size_of(Vertex_Quad) * QUAD_VERTEX_MAX, gl.DYNAMIC_DRAW)
            _r.quad_index_buffer = _gl_create_index_buffer(&_r.quad_indices[0], len(_r.quad_indices))
            layout := _gl_create_vertex_buffer_layout()
            _gl_push_f32_vertex_buffer_layout(layout, 2) // position
            _gl_push_f32_vertex_buffer_layout(layout, 2) // scale
            _gl_push_f32_vertex_buffer_layout(layout, 4) // color
            _gl_push_f32_vertex_buffer_layout(layout, 2) // texture_coordinates
            _gl_push_i32_vertex_buffer_layout(layout, 1) // texture_index
            _gl_add_buffer_to_vertex_array(_r.quad_vertex_array, _r.quad_vertex_buffer, layout)

            color_white : u32 = 0xffffffff
            _r.texture_white = _gl_create_texture({ 1, 1 }, &color_white) or_return

            _r.texture_slots[0] = _r.texture_white
            _r.quad_vertex_ptr = &_r.quad_vertices[0]

            gl.GetIntegerv(gl.MAX_TEXTURE_IMAGE_UNITS, &_r.max_texture_image_units)
        }

        _r.enabled = true
        _r.native_resolution = native_resolution
        _r.pixel_density = renderer_get_window_pixel_density(_engine.platform.window)

        if _engine.platform.window_size.x > _engine.platform.window_size.y {
            _r.ideal_scale = math.floor(f32(_engine.platform.window_size.y) / _r.native_resolution.y)
        } else {
            _r.ideal_scale = math.floor(f32(_engine.platform.window_size.x) / _r.native_resolution.x)
        }
        _r.ui_camera.zoom = _r.ideal_scale

        {
            rendering_size := Vector2f32 { f32(_engine.platform.window_size.x), f32(_engine.platform.window_size.y) }
            _r.world_camera.zoom = _r.ideal_scale
        }

        ok = true
        return
    }

    renderer_reload :: proc(renderer: ^Renderer_State) {
        _r = renderer
        gl.load_up_to(int(DESIRED_GL_MAJOR_VERSION), int(DESIRED_GL_MINOR_VERSION), proc(ptr: rawptr, name: cstring) {
            (cast(^rawptr)ptr)^ = sdl2.GL_GetProcAddress(name)
        })

        when IMGUI_ENABLE {
            imgui.create_context()
            imgui.style_colors_dark()
            imgui_sdl.setup_state(&_r.sdl_state)
            imgui_opengl.setup_state(&_r.opengl_state)
        }
    }

    renderer_quit :: proc() {
        // FIXME:
    }

    renderer_render_begin :: proc() {
        profiler_zone("renderer_begin", 0x005500)

        _r.stats = {}
        when PROFILER {
            gl.BeginQuery(gl.TIME_ELAPSED, _r.queries[0])
        }

        _r.previous_camera = nil

        renderer_batch_begin()
    }

    renderer_render_end :: proc() {
        profiler_zone("renderer_end", 0x005500)

        renderer_batch_end()
        renderer_flush()

        renderer_draw_ui()

        when PROFILER {
            profiler_zone("query", 0x005500)
            gl.EndQuery(gl.TIME_ELAPSED)
            gl.GetQueryObjectiv(_r.queries[0], gl.QUERY_RESULT, &_r.draw_duration)
        }

        {
            profiler_zone("swap", 0x005500)
            sdl2.GL_SwapWindow(_engine.platform.window)
        }
    }

    renderer_batch_begin :: proc() {
        _r.quad_index_count = 0
        _r.quad_vertex_ptr = &_r.quad_vertices[0]
    }

    renderer_batch_end :: proc() {
        profiler_zone("renderer_batch_end", 0x005500)
        // _gl_subdata_vertex_buffer(_r.quad_vertex_buffer, 0, size_of(_r.quad_vertices), &_r.quad_vertices[0])
    }

    renderer_flush :: proc(loc := #caller_location) {
        profiler_zone("renderer_flush", 0x005500)

        if _r.quad_index_count == 0 {
            log.warnf("Flush with nothing to draw. (%v)", loc);
            return
        }

        if _r.current_camera == nil {
            log.warnf("Flush with no camera. (%v)", loc);
            return
        }

        _gl_set_uniform_mat4f_to_shader(_r.quad_shader, _r.LOCATION_NAME_MVP, &_r.current_camera.projection_view_matrix)

        _gl_subdata_vertex_buffer(_r.quad_vertex_buffer, 0, size_of(_r.quad_vertices), &_r.quad_vertices[0])
        for i in 0..< _r.texture_slot_index {
            _gl_bind_texture(_r.texture_slots[i], i32(i))
        }

        _gl_bind_vertex_array(_r.quad_vertex_array)
        _gl_bind_index_buffer(_r.quad_index_buffer)
        gl.DrawElements(gl.TRIANGLES, i32(_r.quad_index_count), gl.UNSIGNED_INT, nil)

        // log.debugf("flush (%v) | %v", loc, camera_name(_r.current_camera));

        _r.stats.draw_count += 1
    }

    @(private="package")
    renderer_begin_ui :: proc() {
        when IMGUI_ENABLE {
            imgui_sdl.update_display_size(_engine.platform.window)
            imgui_sdl.update_mouse(&_r.sdl_state, _engine.platform.window)
            imgui_sdl.update_dt(&_r.sdl_state, _engine.platform.delta_time)

            imgui.new_frame()
        }
    }

    renderer_change_camera_begin :: proc(camera: ^Camera_Orthographic, loc := #caller_location) {
        if _r.previous_camera != nil && camera != _r.current_camera {
            renderer_batch_end()
            renderer_flush()
            renderer_batch_begin()
        }

        _r.current_camera = camera

        // log.debugf("change_camera_begin (%v) | %v => %v", loc, camera_name(_r.previous_camera), camera_name(_r.current_camera));
    }

    renderer_process_events :: proc(e: sdl2.Event) {
        when IMGUI_ENABLE {
            imgui_sdl.process_event(e, &_r.sdl_state)
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

    renderer_draw_ui:: proc() {
        profiler_zone("renderer_draw_ui", 0x005500)
        when IMGUI_ENABLE {
            imgui.render()

            // io := imgui.get_io()
            gl.Clear(gl.DEPTH_BUFFER_BIT)
            imgui_opengl.imgui_render(imgui.get_draw_data(), _r.opengl_state)
        }
    }

    // FIXME: Debug procs, we want to be able to do this from game code
    renderer_scene_init :: proc() -> bool {
        context.allocator = _engine.allocator
        _r.quad_shader = _gl_create_shader("media/shaders/shader_aa_sprite.glsl") or_return
        _gl_bind_shader(_r.quad_shader)

        _r.texture_slot_index = 0

        samplers: [TEXTURE_MAX]i32
        for i in 0 ..< TEXTURE_MAX {
            samplers[i] = i32(i)
        }
        _gl_set_uniform_1iv_to_shader(_r.quad_shader, _r.LOCATION_NAME_TEXTURES, samplers[:])

        _r.texture_0 = _gl_load_texture("media/art/spritesheet.processed.png") or_return
        _r.texture_1 = _gl_load_texture("media/art/aa_test.png") or_return
        _r.texture_2 = _gl_load_texture("media/art/nyan.png") or_return
        _r.texture_3 = _gl_load_texture("media/art/nyan.processed.png") or_return

        _r.world_camera.position = { 128, 72, 0 }

        return true
    }

    renderer_set_viewport :: proc(size: Vector2f32) {
        gl.Viewport(0, 0, i32(size.x), i32(size.y))
    }

    renderer_update_camera_matrix :: proc() {
        // TODO: Apply letterbox here
        // FIXME: don't do this every frame
        rendering_size := Vector2f32 { _r.native_resolution.x * _r.ideal_scale, _r.native_resolution.y * _r.ideal_scale }

        _r.ui_camera.projection_matrix = matrix_ortho3d_f32(
            0, rendering_size.x / _r.ui_camera.zoom,
            rendering_size.y / _r.ui_camera.zoom, 0,
            -1, 1,
        )
        _r.ui_camera.view_matrix = matrix4_translate_f32(_r.ui_camera.position) * matrix4_rotate_f32(_r.ui_camera.rotation, { 0, 0, 1 })
        _r.ui_camera.projection_view_matrix = _r.ui_camera.projection_matrix * _r.ui_camera.view_matrix

        _r.world_camera.projection_matrix = matrix_ortho3d_f32(
            -rendering_size.x / 2 / _r.world_camera.zoom, +rendering_size.x / 2 / _r.world_camera.zoom,
            +rendering_size.y / 2 / _r.world_camera.zoom, -rendering_size.y / 2 / _r.world_camera.zoom,
            -1, 1,
        )
        _r.world_camera.view_matrix = matrix4_translate_f32(_r.world_camera.position) * matrix4_rotate_f32(_r.world_camera.rotation, { 0, 0, 1 })
        _r.world_camera.view_matrix = matrix4_inverse_f32(_r.world_camera.view_matrix)
        _r.world_camera.projection_view_matrix = _r.world_camera.projection_matrix * _r.world_camera.view_matrix

        assert(_r.quad_shader != nil)
        _gl_bind_shader(_r.quad_shader)
    }

    renderer_clear :: proc(color: Color) {
        gl.ClearColor(color.r, color.g, color.b, color.a)
        gl.Clear(gl.COLOR_BUFFER_BIT)
    }

    renderer_push_quad :: proc(position: Vector2f32, size: Vector2f32, color: Color = { 1, 1, 1, 1 }, texture: ^Texture = _r.texture_white, texture_coordinates : Vector2f32 = { 0, 0 }, texture_size : Vector2f32 = { 1, 1 }, flip: Renderer_Flip = { .None }) {
        if _r.current_camera == nil {
            _r.current_camera = &_r.world_camera
        }

        if
            _r.quad_index_count >= QUAD_INDEX_MAX ||
            _r.texture_slot_index > TEXTURE_MAX - 1 ||
            (_r.quad_index_count > 0 && _r.current_camera != _r.previous_camera)
        {
            // log.debugf("push_quad %v | %v => %v", position, camera_name(_r.previous_camera), camera_name(_r.current_camera));
            renderer_batch_end()
            renderer_flush()
            renderer_batch_begin()
        }

        texture_index : i32 = 0
        for i := 1; i < _r.texture_slot_index; i+= 1{
            if _r.texture_slots[i] == texture {
                texture_index = i32(i)
                break
            }
        }

        if texture_index == 0 {
            texture_index = i32(_r.texture_slot_index)
            _r.texture_slots[_r.texture_slot_index] = texture
            _r.texture_slot_index += 1
        }

        scale := Vector2f32 { 1, 1 }

        coordinates := []Vector2f32 {
            { 0, 0 },
            { texture_size.x, 0 },
            { texture_size.x, texture_size.y },
            { 0, texture_size.y },
        }

        // FIXME: the flip is not working correctly with the AA shader
        if .Horizontal in flip {
            slice.swap(coordinates, 0, 1)
            slice.swap(coordinates, 2, 3)
            scale.x = -scale.x
        }
        if .Vertical in flip {
            slice.swap(coordinates, 0, 3)
            slice.swap(coordinates, 1, 2)
            scale.y = -scale.y
        }

        _r.quad_vertex_ptr.position = { position.x, position.y }
        _r.quad_vertex_ptr.scale = scale
        _r.quad_vertex_ptr.color = color
        _r.quad_vertex_ptr.texture_coordinates = texture_coordinates + coordinates[0]
        _r.quad_vertex_ptr.texture_index = texture_index
        _r.quad_vertex_ptr = mem.ptr_offset(_r.quad_vertex_ptr, 1)

        _r.quad_vertex_ptr.position = { position.x + size.x, position.y }
        _r.quad_vertex_ptr.scale = scale
        _r.quad_vertex_ptr.color = color
        _r.quad_vertex_ptr.texture_coordinates = texture_coordinates + coordinates[1]
        _r.quad_vertex_ptr.texture_index = texture_index
        _r.quad_vertex_ptr = mem.ptr_offset(_r.quad_vertex_ptr, 1)

        _r.quad_vertex_ptr.position = { position.x + size.x, position.y + size.y }
        _r.quad_vertex_ptr.scale = scale
        _r.quad_vertex_ptr.color = color
        _r.quad_vertex_ptr.texture_coordinates = texture_coordinates + coordinates[2]
        _r.quad_vertex_ptr.texture_index = texture_index
        _r.quad_vertex_ptr = mem.ptr_offset(_r.quad_vertex_ptr, 1)

        _r.quad_vertex_ptr.position = { position.x, position.y + size.y }
        _r.quad_vertex_ptr.scale = scale
        _r.quad_vertex_ptr.color = color
        _r.quad_vertex_ptr.texture_coordinates = texture_coordinates + coordinates[3]
        _r.quad_vertex_ptr.texture_index = texture_index
        _r.quad_vertex_ptr = mem.ptr_offset(_r.quad_vertex_ptr, 1)

        _r.quad_index_count += INDEX_PER_QUAD
        _r.stats.quad_count += 1
        _r.previous_camera = _r.current_camera
    }

    renderer_is_enabled :: proc() -> bool {
        return _r != nil && _r.enabled
    }

    camera_name :: proc(camera: ^Camera_Orthographic) -> string {
        if camera != nil && camera == &_r.ui_camera {
            return "ui"
        }
        if camera != nil && camera == &_r.world_camera {
            return "world"
        }
        return "nil"
    }
}
