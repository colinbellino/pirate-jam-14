package engine

IMGUI_ENABLE :: #config(IMGUI_ENABLE, true)
GPU_PROFILER :: #config(GPU_PROFILER, true)

when RENDERER == .OpenGL {
    import "core:fmt"
    import "core:log"
    import "core:math"
    import "core:mem"
    import "core:os"
    import "core:strings"
    import "vendor:sdl2"
    import gl "vendor:OpenGL"

    import imgui "../odin-imgui"
    import imgui_opengl "imgui_impl_opengl"
    import imgui_sdl "imgui_impl_sdl"

    RENDERER_DEBUG :: gl.GL_DEBUG

    DESIRED_MAJOR_VERSION : i32 : 4
    DESIRED_MINOR_VERSION : i32 : 1

    TEXTURE_MAX     :: 16 // TODO: Get this from OpenGL
    QUAD_MAX        :: 100_000
    INDEX_PER_QUAD  :: 6
    VERTEX_PER_QUAD :: 4
    QUAD_VERTEX_MAX :: QUAD_MAX * VERTEX_PER_QUAD
    QUAD_INDEX_MAX  :: QUAD_MAX * INDEX_PER_QUAD
    UNIFORM_MAX     :: 10
    QUAD_POSITIONS := []Vector2f32 {
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

    @(private="file")
    _r : ^Renderer_State

    Renderer_State :: struct {
        using base:                 Renderer_State_Base,
        sdl_state:                  imgui_sdl.SDL_State,
        opengl_state:               imgui_opengl.OpenGL_State,
        queries:                    [10]u32,
        max_texture_image_units:    i32,
        quad_vertex_array:          Vertex_Array,
        quad_vertex_buffer:         Vertex_Buffer,
        quad_index_buffer:          Index_Buffer,
        quad_vertices:              [QUAD_VERTEX_MAX]Vertex_Quad,
        quad_vertex_ptr:            ^Vertex_Quad,
        quad_indices:               [QUAD_INDEX_MAX]i32,
        quad_index_count:           int,
        texture_slots:              [TEXTURE_MAX]^Texture, // TODO: Can we just have list of renderer_id ([]u32)?
        texture_slot_index:         int,
        quad_shader:                Shader,
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
        draw_ui:                    bool,
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

    Vertex_Quad :: struct #packed {
        position:               Vector2f32,
        color:                  Color,
        texture_coordinates:    Vector2f32,
        texture_index:          i32,
    }

    Shader :: struct #packed {
        renderer_id:            u32,
        uniform_location_cache: map[string]i32,
        filepath:               string,
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

    Texture :: struct {
        renderer_id:        u32,
        filepath:           string,
        width:              i32,
        height:             i32,
        bytes_per_pixel:    i32,
        // TODO: keep the data only in debug builds?
        data:               [^]byte,
    }

    renderer_init :: proc(window: ^Window, native_resolution: Vector2f32, allocator := context.allocator) -> (ok: bool) {
        profiler_zone("renderer_init")
        _e.renderer = new(Renderer_State, allocator)
        _r = _e.renderer
        _r.LOCATION_NAME_MVP = strings.clone("u_model_view_projection")
        _r.LOCATION_NAME_TEXTURES = strings.clone("u_textures")
        _r.LOCATION_NAME_COLOR = strings.clone("u_color")
        _r.LOCATION_NAME_TEXELS_PER_PIXEL = strings.clone("u_texels_per_pixel")

        sdl2.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, DESIRED_MAJOR_VERSION)
        sdl2.GL_SetAttribute(.CONTEXT_MINOR_VERSION, DESIRED_MINOR_VERSION)
        sdl2.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))
        sdl2.GL_SetAttribute(.DOUBLEBUFFER, 1)
        sdl2.GL_SetAttribute(.DEPTH_SIZE, 24)
        sdl2.GL_SetAttribute(.STENCIL_SIZE, 8)

        gl_context := sdl2.GL_CreateContext(_e.platform.window)
        if gl_context == nil {
            log.errorf("sdl2.GL_CreateContext error: %v.", sdl2.GetError())
            return
        }

        sdl2.GL_MakeCurrent(_e.platform.window, gl_context)
        // defer sdl.gl_delete_context(gl_context)

        // 0 for immediate updates, 1 for updates synchronized with the vertical retrace, -1 for adaptive vsync
        interval : i32 = 1
        if sdl2.GL_SetSwapInterval(interval) != 0 {
            log.errorf("sdl2.GL_SetSwapInterval error: %v.", sdl2.GetError())
            return
        }

        renderer_reload(_r)

        log.infof("OpenGL renderer --------------------------------------------")
        log.infof("  GL VERSION:           %v.%v", DESIRED_MAJOR_VERSION, DESIRED_MINOR_VERSION)
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

            gl.GenVertexArrays(1, &_r.quad_vertex_array.renderer_id)

            gl.GenBuffers(1, &_r.quad_vertex_buffer.renderer_id)
            gl.BindBuffer(gl.ARRAY_BUFFER, _r.quad_vertex_buffer.renderer_id)
            gl.BufferData(gl.ARRAY_BUFFER, size_of(_r.quad_vertices), nil, gl.DYNAMIC_DRAW)

            _r.quad_index_buffer.count = len(_r.quad_indices)
            gl.GenBuffers(1, &_r.quad_index_buffer.renderer_id)
            gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, _r.quad_index_buffer.renderer_id)
            gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, int(_r.quad_index_buffer.count * size_of(u32)), &_r.quad_indices[0], gl.STATIC_DRAW)

            layout := Vertex_Buffer_Layout {}
            push_f32_vertex_buffer_layout(&layout, 2) // position
            // push_f32_vertex_buffer_layout(&layout, 2) // scale
            push_f32_vertex_buffer_layout(&layout, 4) // color
            push_f32_vertex_buffer_layout(&layout, 2) // texture_coordinates
            push_i32_vertex_buffer_layout(&layout, 1) // texture_index
            add_buffer_to_vertex_array(&_r.quad_vertex_array, &_r.quad_vertex_buffer, &layout)

            color_white : u32 = 0xffffffff
            _r.texture_white = create_texture({ 1, 1 }, &color_white) or_return

            _r.texture_slots[0] = _r.texture_white
            _r.quad_vertex_ptr = &_r.quad_vertices[0]

            gl.GetIntegerv(gl.MAX_TEXTURE_IMAGE_UNITS, &_r.max_texture_image_units)
        }

        _r.enabled = true
        _r.native_resolution = native_resolution
        _r.pixel_density = renderer_get_window_pixel_density(_e.platform.window)

        if _e.platform.window_size.x > _e.platform.window_size.y {
            _r.ideal_scale = math.floor(f32(_e.platform.window_size.y) / _r.native_resolution.y)
        } else {
            _r.ideal_scale = math.floor(f32(_e.platform.window_size.x) / _r.native_resolution.x)
        }
        _r.ui_camera.zoom = _r.ideal_scale

        {
            // rendering_size := Vector2f32 { f32(_e.platform.window_size.x), f32(_e.platform.window_size.y) }
            _r.world_camera.zoom = _r.ideal_scale
        }

        ok = true
        return
    }

    renderer_reload :: proc(renderer: ^Renderer_State) {
        _r = renderer
        gl.load_up_to(int(DESIRED_MAJOR_VERSION), int(DESIRED_MINOR_VERSION), proc(ptr: rawptr, name: cstring) {
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

        when GPU_PROFILER {
            gl.BeginQuery(gl.TIME_ELAPSED, _r.queries[0])
        }

        _r.previous_camera = nil
        _r.stats = {}

        renderer_batch_begin()
    }

    renderer_render_end :: proc() {
        profiler_zone("renderer_end", 0x005500)

        renderer_batch_end()
        renderer_flush()
        renderer_draw_ui()

        when GPU_PROFILER {
            profiler_zone("query", 0x005500)
            gl.EndQuery(gl.TIME_ELAPSED)
            gl.GetQueryObjectiv(_r.queries[0], gl.QUERY_RESULT, &_r.draw_duration)
        }

        {
            profiler_zone("swap", 0x005500)
            sdl2.GL_SwapWindow(_e.platform.window)
        }
    }

    renderer_batch_begin :: proc() {
        _r.quad_index_count = 0
        _r.quad_vertex_ptr = &_r.quad_vertices[0]
    }

    renderer_batch_end :: proc() {
        // profiler_zone("renderer_batch_end", 0x005500)
    }

    renderer_flush :: proc(loc := #caller_location) {
        profiler_zone("renderer_flush", 0x005500)

        if _r.quad_index_count == 0 {
            // log.warnf("Flush with nothing to draw. (%v)", loc);
            return
        }

        if _r.current_camera == nil {
            log.warnf("Flush with no camera. (%v)", loc);
            return
        }

        set_uniform_mat4f_to_shader(&_r.quad_shader, _r.LOCATION_NAME_MVP, &_r.current_camera.projection_view_matrix)
        gl.BindBuffer(gl.ARRAY_BUFFER, _r.quad_vertex_buffer.renderer_id)
        {
            profiler_zone("BufferSubData")
            gl.BufferSubData(gl.ARRAY_BUFFER, 0, size_of(_r.quad_vertices), &_r.quad_vertices[0])
        }
        for i in 0..< _r.texture_slot_index {
            bind_texture(_r.texture_slots[i], i32(i))
        }

        gl.BindVertexArray(_r.quad_vertex_array.renderer_id)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, _r.quad_index_buffer.renderer_id)
        gl.DrawElements(gl.TRIANGLES, i32(_r.quad_index_count), gl.UNSIGNED_INT, nil)

        _r.stats.draw_count += 1
    }

    @(private="package")
    renderer_begin_ui :: proc() {
        when IMGUI_ENABLE {
            imgui_sdl.update_display_size(_e.platform.window)
            imgui_sdl.update_mouse(&_r.sdl_state, _e.platform.window)
            imgui_sdl.update_dt(&_r.sdl_state, _e.platform.delta_time)

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

        // log.debugf("change_camera_begin (%v) | %v => %v", loc, _camera_name(_r.previous_camera), _camera_name(_r.current_camera));
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

            if _r.draw_ui {
                gl.Clear(gl.DEPTH_BUFFER_BIT)
                imgui_opengl.imgui_render(imgui.get_draw_data(), _r.opengl_state)
            }
        }
    }

    debug_reload_shaders :: proc() -> (ok: bool) {
        ok = renderer_shader_load(&_r.quad_shader, "media/shaders/shader_aa_sprite.glsl")
        ok = renderer_scene_init()
        log.warnf("debug_reload_shaders: %v", ok)
        return
    }

    // FIXME: Debug procs, we want to be able to do this from game code
    renderer_scene_init :: proc() -> bool {
        context.allocator = _e.allocator
        _r.quad_shader = create_shader("media/shaders/shader_aa_sprite.glsl") or_return
        gl.UseProgram(_r.quad_shader.renderer_id)

        _r.texture_slot_index = 0

        samplers: [TEXTURE_MAX]i32
        for i in 0 ..< TEXTURE_MAX {
            samplers[i] = i32(i)
        }
        set_uniform_1iv_to_shader(&_r.quad_shader, _r.LOCATION_NAME_TEXTURES, samplers[:])

        _r.texture_0 = load_texture("media/art/spritesheet.processed.png") or_return
        _r.texture_1 = load_texture("media/art/aa_test.png") or_return
        _r.texture_2 = load_texture("media/art/nyan.png") or_return
        _r.texture_3 = load_texture("media/art/nyan.processed.png") or_return

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

        assert(_r.quad_shader.renderer_id != 0)
        gl.UseProgram(_r.quad_shader.renderer_id)
    }

    renderer_clear :: proc(color: Color) {
        assert_color_is_f32(color)
        gl.ClearColor(color.r, color.g, color.b, color.a)
        gl.Clear(gl.COLOR_BUFFER_BIT)
    }

    renderer_push_quad :: proc(position: Vector2f32, size: Vector2f32, color: Color = { 1, 1, 1, 1 }, texture: ^Texture = _r.texture_white, texture_coordinates : Vector2f32 = { 0, 0 }, texture_size : Vector2f32 = { 1, 1 }, flip: Renderer_Flip = { .None }, loc := #caller_location) {
        // profiler_zone("renderer_push_quad")
        assert_color_is_f32(color, loc)

        if _r.current_camera == nil {
            _r.current_camera = &_r.world_camera
        }

        if
            _r.quad_index_count >= QUAD_INDEX_MAX ||
            _r.texture_slot_index > TEXTURE_MAX - 1 ||
            (_r.quad_index_count > 0 && _r.current_camera != _r.previous_camera)
        {
            renderer_batch_end()
            renderer_flush()
            renderer_batch_begin()
        }


        texture_index : i32 = 0
        for i := 1; i < _r.texture_slot_index; i+= 1 {
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

        // TODO: use SIMD instructions for this
        for i := 0 ; i < VERTEX_PER_QUAD; i += 1 {
            _r.quad_vertex_ptr.position.x = position.x + size.x * QUAD_POSITIONS[i].x
            _r.quad_vertex_ptr.position.y = position.y + size.y * QUAD_POSITIONS[i].y
            _r.quad_vertex_ptr.color = color
            _r.quad_vertex_ptr.texture_coordinates.x = texture_coordinates.x + texture_size.x * QUAD_POSITIONS[i].x
            _r.quad_vertex_ptr.texture_coordinates.y = texture_coordinates.y + texture_size.y * QUAD_POSITIONS[i].y
            _r.quad_vertex_ptr.texture_index = texture_index
            _r.quad_vertex_ptr = mem.ptr_offset(_r.quad_vertex_ptr, 1)
        }

        _r.quad_index_count += INDEX_PER_QUAD
        _r.stats.quad_count += 1
        _r.previous_camera = _r.current_camera
    }

    renderer_is_enabled :: proc() -> bool {
        return _r != nil && _r.enabled
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
        // log.debugf("vertex -----------------------------------------------------\n%v", vertex);
        // log.debugf("fragment ---------------------------------------------------\n%v", fragment);

        // when RENDERER_DEBUG {
        //     shader.filepath = filepath
        //     shader.vertex = vertex
        //     shader.fragment = fragment
        // }
        shader.renderer_id, ok = gl.load_shaders_source(vertex, fragment, binary_retrievable)

        return
    }

    _camera_name :: proc(camera: ^Camera_Orthographic) -> string {
        if camera != nil && camera == &_r.ui_camera {
            return "ui"
        }
        if camera != nil && camera == &_r.world_camera {
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

    @(private="file")
    create_shader :: proc(filepath: string) -> (shader: Shader, ok: bool) #optional_ok {
        if renderer_shader_load(&shader, filepath) == false {
            log.errorf("Shader error: %v.", gl.GetError())
            return
        }
        ok = true
        return
    }

    @(private="file")
    set_uniform_1i_to_shader :: proc(using shader: ^Shader, name: string, value: i32) {
        location := get_uniform_location_in_shader(shader, name)
        gl.Uniform1i(location, value)
    }
    @(private="file")
    set_uniform_1f_to_shader :: proc(using shader: ^Shader, name: string, value: f32) {
        location := get_uniform_location_in_shader(shader, name)
        gl.Uniform1f(location, value)
    }
    @(private="file")
    set_uniform_4f_to_shader :: proc(using shader: ^Shader, name: string, value: Vector4f32) {
        location := get_uniform_location_in_shader(shader, name)
        gl.Uniform4f(location, value.x, value.y, value.z, value.w)
    }
    @(private="file")
    set_uniform_mat4f_to_shader :: proc(using shader: ^Shader, name: string, value: ^Matrix4x4f32) {
        location := get_uniform_location_in_shader(shader, name)
        gl.UniformMatrix4fv(location, 1, false, cast([^]f32) value)
    }
    @(private="file")
    set_uniform_1iv_to_shader :: proc(using shader: ^Shader, name: string, value: []i32) {
        location := get_uniform_location_in_shader(shader, name)
        gl.Uniform1iv(location, i32(len(value)), &value[0])
    }

    @(private="file")
    get_uniform_location_in_shader :: proc(using shader: ^Shader, name: string) -> i32 {
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
    create_texture :: proc(size: Vector2i32, color: ^u32) -> (texture: ^Texture, ok: bool) {
        texture = new(Texture)

        gl.GenTextures(1, &texture.renderer_id)
        gl.BindTexture(gl.TEXTURE_2D, texture.renderer_id)

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, size.x, size.y, 0, gl.RGBA, gl.UNSIGNED_BYTE, color)

        ok = true
        return
    }

    @(private="file")
    load_texture :: proc(filepath: string) -> (texture: ^Texture, ok: bool) {
        texture = new(Texture)
        texture.filepath = filepath
        texture.data = platform_load_image(filepath, &texture.width, &texture.height, &texture.bytes_per_pixel)

        gl.GenTextures(1, &texture.renderer_id)
        gl.BindTexture(gl.TEXTURE_2D, texture.renderer_id)

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)

        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, texture.width, texture.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, &texture.data[0])

        ok = true
        return
    }

    @(private="file")
    bind_texture :: proc(using texture: ^Texture, slot: i32) {
        assert(slot < _r.max_texture_image_units)
        gl.ActiveTexture(gl.TEXTURE0 + u32(slot))
        gl.BindTexture(gl.TEXTURE_2D, renderer_id)
    }

    assert_color_is_f32 :: proc(color: Color, loc := #caller_location) {
        assert(color.r >= 0 && color.r <= 1 && color.g >= 0 && color.g <= 1 && color.b >= 0 && color.b <= 1 && color.a >= 0 && color.a <= 1, fmt.tprintf("Invalid color: %v", color), loc)
    }
}
