package engine2

import "core:log"
import "core:math/linalg"
import "vendor:sdl2"
import gl "vendor:OpenGL"

TEXTURE_MAX           :: 16 // TODO: Get this from OpenGL
DESIRED_MAJOR_VERSION : i32 : 4
DESIRED_MINOR_VERSION : i32 : 1

Renderer_Data_OpenGL :: struct {
    gl_context:     sdl2.GLContext,
    samplers:       [TEXTURE_MAX]i32,
    queries:        [10]u32,
}

renderer_opengl_init :: proc(window: ^Window) -> (ok: bool) {
    r.data = new(Renderer_Data_OpenGL)
    data := cast(^Renderer_Data_OpenGL) r.data

    sdl2.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, DESIRED_MAJOR_VERSION)
    sdl2.GL_SetAttribute(.CONTEXT_MINOR_VERSION, DESIRED_MINOR_VERSION)
    sdl2.GL_SetAttribute(.CONTEXT_PROFILE_MASK, i32(sdl2.GLprofile.CORE))
    sdl2.GL_SetAttribute(.DOUBLEBUFFER, 1)
    sdl2.GL_SetAttribute(.DEPTH_SIZE, 24)
    sdl2.GL_SetAttribute(.STENCIL_SIZE, 8)

    for i in 0 ..< TEXTURE_MAX {
        data.samplers[i] = i32(i)
    }

    data.gl_context = sdl2.GL_CreateContext(window)
    if data.gl_context == nil {
        log.errorf("sdl2.GL_CreateContext error: %v.", sdl2.GetError())
        return
    }

    sdl2.GL_MakeCurrent(window, data.gl_context)

    // 0 for immediate updates, 1 for updates synchronized with the vertical retrace, -1 for adaptive vsync
    interval : i32 = 1
    if sdl2.GL_SetSwapInterval(interval) != 0 {
        log.errorf("sdl2.GL_SetSwapInterval error: %v.", sdl2.GetError())
        return
    }

    gl.load_up_to(int(DESIRED_MAJOR_VERSION), int(DESIRED_MINOR_VERSION), proc(ptr: rawptr, name: cstring) {
        (cast(^rawptr)ptr)^ = sdl2.GL_GetProcAddress(name)
    })

    log.infof("OpenGL renderer --------------------------------------------")
    log.infof("  GL VERSION:           %v.%v", DESIRED_MAJOR_VERSION, DESIRED_MINOR_VERSION)
    log.infof("  VENDOR:               %v", gl.GetString(gl.VENDOR))
    log.infof("  RENDERER:             %v", gl.GetString(gl.RENDERER))
    log.infof("  VERSION:              %v", gl.GetString(gl.VERSION))

    gl.GenQueries(len(data.queries), &data.queries[0])

    // {
    //     gl.Enable(gl.BLEND)
    //     gl.BlendEquation(gl.FUNC_ADD)
    //     gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

    //     offset : i32 = 0
    //     for i := 0; i < QUAD_INDEX_MAX; i += INDEX_PER_QUAD {
    //         r.quad_indices[i + 0] = 0 + offset
    //         r.quad_indices[i + 1] = 1 + offset
    //         r.quad_indices[i + 2] = 2 + offset
    //         r.quad_indices[i + 3] = 2 + offset
    //         r.quad_indices[i + 4] = 3 + offset
    //         r.quad_indices[i + 5] = 0 + offset
    //         offset += VERTEX_PER_QUAD
    //     }

    //     gl.GenVertexArrays(1, &r.quad_vertex_array.renderer_id)

    //     gl.GenBuffers(1, &r.quad_vertex_buffer.renderer_id)
    //     gl.BindBuffer(gl.ARRAY_BUFFER, r.quad_vertex_buffer.renderer_id)
    //     gl.BufferData(gl.ARRAY_BUFFER, size_of(r.quad_vertices), nil, gl.DYNAMIC_DRAW)

    //     r.quad_index_buffer.count = len(r.quad_indices)
    //     gl.GenBuffers(1, &r.quad_index_buffer.renderer_id)
    //     gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, r.quad_index_buffer.renderer_id)
    //     gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, int(r.quad_index_buffer.count * size_of(u32)), &r.quad_indices[0], gl.STATIC_DRAW)

    //     layout := Vertex_Buffer_Layout {}
    //     push_f32_vertex_buffer_layout(&layout, 2) // position
    //     push_f32_vertex_buffer_layout(&layout, 4) // color
    //     push_f32_vertex_buffer_layout(&layout, 2) // texture_coordinates
    //     push_i32_vertex_buffer_layout(&layout, 1) // texture_index
    //     add_buffer_to_vertex_array(&r.quad_vertex_array, &r.quad_vertex_buffer, &layout)

    //     color_white : u32 = 0xffffffff
    //     r.texture_white = create_texture({ 1, 1 }, &color_white, &{ RENDERER_FILTER_LINEAR, RENDERER_CLAMP_TO_EDGE }) or_return

    //     r.texture_slots[0] = r.texture_white
    //     r.quad_vertex_ptr = &r.quad_vertices[0]

    //     gl.GetIntegerv(gl.MAX_TEXTURE_IMAGE_UNITS, &r.max_texture_image_units)

    //     if renderer_shader_load(&r.shader_error, "media/shaders/shader_error.glsl") == false {
    //         log.errorf("Shader error: %v.", gl.GetError())
    //         return
    //     }
    // }

    return true
}

renderer_opengl_deinit :: proc() {
    data := cast(^Renderer_Data_OpenGL) r.data
    sdl2.GL_DeleteContext(data.gl_context)
    free(data)
}

renderer_opengl_resize :: proc(window_size: Vector2i32) {
    // r.rendering_size = Vector2f32 {
    //     f32(_e.platform.window_size.x) * _e.renderer.pixel_density,
    //     f32(_e.platform.window_size.y) * _e.renderer.pixel_density,
    // }

    // gl.Viewport(0, 0, i32(r.rendering_size.x), i32(r.rendering_size.y))
}
