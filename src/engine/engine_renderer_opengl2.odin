package engine

when RENDERER == .OpenGL {
    import "core:fmt"
    import "core:log"
    import "core:mem"
    import "core:os"
    import "core:runtime"
    import "core:strings"
    import "core:time"
    import gl "vendor:OpenGL"

    // FIXME: Do we need this if we don't have anything else than a renderer_id?!
    Vertex_Buffer :: struct {
        renderer_id: u32,
    }
    Index_Buffer :: struct {
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


    _gl_create_index_buffer :: proc(data: rawptr, count: int) -> ^Index_Buffer{
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
}
