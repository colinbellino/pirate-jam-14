package engine

when RENDERER == .OpenGL {
    import "core:fmt"
    import "core:log"
    import "core:mem"
    import "core:os"
    import "core:runtime"
    import "core:strings"
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
        using vertex_buffer := new(Vertex_Buffer)
        gl.GenBuffers(1, &renderer_id)
        gl.BindBuffer(gl.ARRAY_BUFFER, renderer_id)
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
    }

    _gl_create_index_buffer :: proc(data: rawptr, count: int) -> ^Index_Buffer {
        using index_buffer := new(Index_Buffer)
        gl.GenBuffers(1, &renderer_id)
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, renderer_id)
        gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, count * size_of(u32), data, gl.STATIC_DRAW)
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

    _gl_create_vertex_array :: proc() -> (vertex_array: ^Vertex_Array) {
        vertex_array = new(Vertex_Array)
        using vertex_array
        gl.GenVertexArrays(1, &renderer_id)
        return
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

    _gl_add_buffer_to_vertex_array :: proc(using vertex_array: ^Vertex_Array, vertex_buffer: ^Vertex_Buffer, layout: ^Vertex_Buffer_Layout) {
        _gl_bind_vertex_buffer(vertex_buffer)

        offset: i32
        for element, index in layout.elements {
            gl.EnableVertexAttribArray(u32(index))
            gl.VertexAttribPointer(u32(index), element.count, element.type, element.normalized, layout.stride, uintptr(offset))
            offset += element.count * GL_TYPES_SIZES[int(element.type)]
        }
    }

    Vertex_Buffer_Element :: struct {
        type:       u32,
        count:      i32,
        normalized: bool,
    }

    Vertex_Buffer_Layout :: struct {
        elements: [dynamic]Vertex_Buffer_Element,
        stride:   i32,
    }

    _gl_push_f32_vertex_buffer_layout :: proc(using vertex_buffer_layout: ^Vertex_Buffer_Layout, count: i32) {
        append(&elements, Vertex_Buffer_Element { u32(gl.FLOAT), count, false })
        stride += GL_TYPES_SIZES[gl.FLOAT]
    }
}
