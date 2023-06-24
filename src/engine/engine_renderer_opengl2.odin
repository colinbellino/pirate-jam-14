package engine

when RENDERER == .OpenGL {
    import "core:os"
    import "core:strings"
    import "core:log"
    import gl "vendor:OpenGL"

    GL_TYPES_SIZES := map[int]i32 {
        gl.FLOAT        = size_of(f32),
        gl.UNSIGNED_INT = size_of(u32),
        gl.BYTE         = size_of(byte),
    }

    // FIXME: Do we need this if we don't have anything else than a renderer_id?!
    Vertex_Buffer :: struct {
        renderer_id: u32,
    }

    _gl_create_vertex_buffer :: proc(data: rawptr, size: int) -> ^Vertex_Buffer {
        vertex_buffer := new(Vertex_Buffer)
        gl.GenBuffers(1, &vertex_buffer.renderer_id)
        gl.BindBuffer(gl.ARRAY_BUFFER, vertex_buffer.renderer_id)
        gl.BufferData(gl.ARRAY_BUFFER, size, data, gl.STATIC_DRAW)
        return vertex_buffer
    }

    _gl_delete_vertex_buffer :: proc(using vertex_buffer: ^Vertex_Buffer) {
        gl.DeleteBuffers(1, &renderer_id)
    }

    _gl_bind_vertex_buffer :: proc(using vertex_buffer: ^Vertex_Buffer) {
        gl.BindBuffer(gl.ARRAY_BUFFER, renderer_id)
    }

    _gl_unbind_vertex_buffer :: proc(using vertex_buffer: ^Vertex_Buffer) {
        gl.BindBuffer(gl.ARRAY_BUFFER, 0)
    }

    Index_Buffer :: struct {
        renderer_id: u32,
        count:       i32,
    }

    _gl_create_index_buffer :: proc(data: rawptr, count: i32) -> ^Index_Buffer {
        index_buffer := new(Index_Buffer)
        index_buffer.count = count
        gl.GenBuffers(1, &index_buffer.renderer_id)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, index_buffer.renderer_id)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, int(index_buffer.count * size_of(u32)), data, gl.STATIC_DRAW)
        return index_buffer
    }

    _gl_delete_index_buffer :: proc(using index_buffer: ^Index_Buffer) {
        gl.DeleteBuffers(1, &renderer_id)
    }

    _gl_bind_index_buffer :: proc(using index_buffer: ^Index_Buffer) {
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, renderer_id)
    }

    _gl_unbind_index_buffer :: proc(using index_buffer: ^Index_Buffer) {
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
    }

    Vertex_Array :: struct {
        renderer_id: u32,
    }

    _gl_create_vertex_array :: proc() -> ^Vertex_Array {
        vertex_array := new(Vertex_Array)
        gl.GenVertexArrays(1, &vertex_array.renderer_id)
        return vertex_array
    }

    _gl_delete_vertex_array :: proc(using vertex_array: ^Vertex_Array) {
        gl.DeleteVertexArrays(1, &renderer_id)
    }

    _gl_bind_vertex_array :: proc(using vertex_array: ^Vertex_Array) {
        gl.BindVertexArray(renderer_id)
    }

    _gl_unbind_vertex_array :: proc(using vertex_array: ^Vertex_Array) {
        gl.BindVertexArray(0)
    }

    Vertex_Buffer_Layout :: struct {
        elements: [dynamic]Vertex_Buffer_Element,
        stride:   i32,
    }

    Vertex_Buffer_Element :: struct {
        type:       u32,
        count:      i32,
        normalized: bool,
    }

    _gl_create_vertex_buffer_layout :: proc() -> ^Vertex_Buffer_Layout {
        layout := new(Vertex_Buffer_Layout)
        return layout
    }

    _gl_add_buffer_to_vertex_array :: proc(vertex_array: ^Vertex_Array, vertex_buffer: ^Vertex_Buffer, layout: ^Vertex_Buffer_Layout) {
        _gl_bind_vertex_array(vertex_array)
        _gl_bind_vertex_buffer(vertex_buffer)

        offset: i32
        for element, index in layout.elements {
            gl.EnableVertexAttribArray(u32(index))
            gl.VertexAttribPointer(u32(index), element.count, element.type, element.normalized, layout.stride, uintptr(offset))
            offset += element.count * GL_TYPES_SIZES[int(element.type)]
        }
    }

    _gl_push_f32_vertex_buffer_layout :: proc(using vertex_buffer_layout: ^Vertex_Buffer_Layout, count: i32) {
        append(&elements, Vertex_Buffer_Element { u32(gl.FLOAT), count, false })
        stride += count * GL_TYPES_SIZES[gl.FLOAT]
    }

    when RENDERER_DEBUG {
        Shader :: struct #packed {
            renderer_id: u32,
            filepath:    string,
            vertex:      string,
            fragment:    string,
        }
    } else {
        Shader :: struct {
            renderer_id: u32,
        }
    }

    Shader_Types :: enum { None = -1, Vertex = 0, Fragment = 1 }

    _gl_create_shader :: proc(filepath: string) -> (shader: ^Shader, ok: bool) #optional_ok {
        shader = new(Shader)
        if _gl_shader_load(shader, filepath) == false {
            log.errorf("Shader error: %v.", gl.GetError())
            return
        }
        ok = true
        return
    }

    _gl_shader_load :: proc(shader: ^Shader, filepath: string, binary_retrievable := false) -> (ok: bool) {
        data: []byte
        data, ok = os.read_entire_file(filepath, context.temp_allocator)
        defer delete(data)
        if ok == false {
            log.errorf("Shader file couldn't be read: %v", filepath)
            return
        }

        log.debugf("Loading shader: %v", filepath)

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
        log.debugf("vertex -----------------------------------------------------\n%v", vertex);
        log.debugf("fragment ---------------------------------------------------\n%v", fragment);

        when RENDERER_DEBUG {
            shader.filepath = filepath
            shader.vertex = vertex
            shader.fragment = fragment
        }
        shader.renderer_id, ok = gl.load_shaders_source(vertex, fragment, binary_retrievable)

        return ok
    }

    _gl_bind_shader :: proc(using shader: ^Shader) {
        gl.UseProgram(renderer_id)
    }

    _gl_unbind_shader :: proc(using shader: ^Shader) {
        gl.UseProgram(0)
    }

    _gl_set_uniform_1i_to_shader :: proc(using shader: ^Shader, name: cstring, value: i32) {
        location := _gl_get_uniform_location_in_shader(shader, name)
        gl.Uniform1i(location, value)
    }
    _gl_set_uniform_1f_to_shader :: proc(using shader: ^Shader, name: cstring, value: f32) {
        location := _gl_get_uniform_location_in_shader(shader, name)
        gl.Uniform1f(location, value)
    }

    _gl_set_uniform_4f_to_shader :: proc(using shader: ^Shader, name: cstring, value: Vector4f32) {
        location := _gl_get_uniform_location_in_shader(shader, name)
        gl.Uniform4f(location, value.x, value.y, value.z, value.w)
    }

    _gl_get_uniform_location_in_shader :: proc(using shader: ^Shader, name: cstring) -> i32 {
        location := gl.GetUniformLocation(renderer_id, name)
        if location == -1 {
            log.warnf("Uniform %v doesn't exist in shader %v.", name, renderer_id)
        }
        return location
    }

    Texture :: struct {
        renderer_id:        u32,
        filepath:           string,
        width:              i32,
        height:             i32,
        channels_in_file:   i32,
        data:               [^]byte,
    }

    _gl_create_texture :: proc(filepath: string) -> (texture: ^Texture, ok: bool) {
        texture = new(Texture)
        texture.filepath = filepath
        // TODO: do we need to flip?
        texture.data = platform_load_image(filepath, &texture.width, &texture.height, &texture.channels_in_file)

        gl.GenTextures(1, &texture.renderer_id)
        gl.BindTexture(gl.TEXTURE_2D, texture.renderer_id)
        log.debugf("_gl_create_texture: %v", texture)

        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, texture.width, texture.height, 0, gl.RGBA, gl.UNSIGNED_BYTE, texture.data)
        gl.BindTexture(gl.TEXTURE_2D, 0)

        ok = true
        return
    }

    _gl_delete_texture :: proc(using texture: ^Texture) {
        gl.DeleteTextures(1, &renderer_id)
    }

    _gl_bind_texture :: proc(using texture: ^Texture, slot: i32) {
        max_texture_image_units: i32; gl.GetIntegerv(gl.MAX_TEXTURE_IMAGE_UNITS, &max_texture_image_units)
        assert(slot < max_texture_image_units)

        gl.ActiveTexture(gl.TEXTURE0 + u32(slot))
        gl.BindTexture(gl.TEXTURE_2D, renderer_id)
    }

    _gl_unbind_texture :: proc(texture: ^Texture) {
        gl.BindTexture(gl.TEXTURE_2D, 0)
    }
}
