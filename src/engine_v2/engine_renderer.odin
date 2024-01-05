package engine_v2

import "core:fmt"
import "core:log"
import gl "vendor:OpenGL"
import sg "../sokol-odin/sokol/gfx"
import sgl "../sokol-odin/sokol/gl"
import slog "../sokol-odin/sokol/log"

Bindings :: sg.Bindings
Pass_Action :: sg.Pass_Action
Pipeline :: sg.Pipeline
Range :: sg.Range
Color :: sg.Color

setup :: sg.setup
shutdown :: sg.shutdown
isvalid :: sg.isvalid
reset_state_cache :: sg.reset_state_cache
push_debug_group :: sg.push_debug_group
pop_debug_group :: sg.pop_debug_group
add_commit_listener :: sg.add_commit_listener
remove_commit_listener :: sg.remove_commit_listener
make_buffer :: sg.make_buffer
make_image :: sg.make_image
make_sampler :: sg.make_sampler
make_shader :: sg.make_shader
make_pipeline :: sg.make_pipeline
make_pass :: sg.make_pass
destroy_buffer :: sg.destroy_buffer
destroy_image :: sg.destroy_image
destroy_sampler :: sg.destroy_sampler
destroy_shader :: sg.destroy_shader
destroy_pipeline :: sg.destroy_pipeline
destroy_pass :: sg.destroy_pass
update_buffer :: sg.update_buffer
update_image :: sg.update_image
append_buffer :: sg.append_buffer
query_buffer_overflow :: sg.query_buffer_overflow
query_buffer_will_overflow :: sg.query_buffer_will_overflow
begin_default_pass :: sg.begin_default_pass
begin_default_passf :: sg.begin_default_passf
begin_pass :: sg.begin_pass
apply_viewport :: sg.apply_viewport
apply_viewportf :: sg.apply_viewportf
apply_scissor_rect :: sg.apply_scissor_rect
apply_scissor_rectf :: sg.apply_scissor_rectf
apply_pipeline :: sg.apply_pipeline
apply_bindings :: sg.apply_bindings
apply_uniforms :: sg.apply_uniforms
draw :: sg.draw
end_pass :: sg.end_pass
commit :: sg.commit
query_desc :: sg.query_desc
query_backend :: sg.query_backend
query_features :: sg.query_features
query_limits :: sg.query_limits
query_pixelformat :: sg.query_pixelformat
query_buffer_state :: sg.query_buffer_state
query_image_state :: sg.query_image_state
query_sampler_state :: sg.query_sampler_state
query_shader_state :: sg.query_shader_state
query_pipeline_state :: sg.query_pipeline_state
query_pass_state :: sg.query_pass_state
query_buffer_info :: sg.query_buffer_info
query_image_info :: sg.query_image_info
query_sampler_info :: sg.query_sampler_info
query_shader_info :: sg.query_shader_info
query_pipeline_info :: sg.query_pipeline_info
query_pass_info :: sg.query_pass_info
query_buffer_desc :: sg.query_buffer_desc
query_image_desc :: sg.query_image_desc
query_sampler_desc :: sg.query_sampler_desc
query_shader_desc :: sg.query_shader_desc
query_pipeline_desc :: sg.query_pipeline_desc
query_pass_desc :: sg.query_pass_desc
query_buffer_defaults :: sg.query_buffer_defaults
query_image_defaults :: sg.query_image_defaults
query_sampler_defaults :: sg.query_sampler_defaults
query_shader_defaults :: sg.query_shader_defaults
query_pipeline_defaults :: sg.query_pipeline_defaults
query_pass_defaults :: sg.query_pass_defaults
alloc_buffer :: sg.alloc_buffer
alloc_image :: sg.alloc_image
alloc_sampler :: sg.alloc_sampler
alloc_shader :: sg.alloc_shader
alloc_pipeline :: sg.alloc_pipeline
alloc_pass :: sg.alloc_pass
dealloc_buffer :: sg.dealloc_buffer
dealloc_image :: sg.dealloc_image
dealloc_sampler :: sg.dealloc_sampler
dealloc_shader :: sg.dealloc_shader
dealloc_pipeline :: sg.dealloc_pipeline
dealloc_pass :: sg.dealloc_pass
init_buffer :: sg.init_buffer
init_image :: sg.init_image
init_sampler :: sg.init_sampler
init_shader :: sg.init_shader
init_pipeline :: sg.init_pipeline
init_pass :: sg.init_pass
uninit_buffer :: sg.uninit_buffer
uninit_image :: sg.uninit_image
uninit_sampler :: sg.uninit_sampler
uninit_shader :: sg.uninit_shader
uninit_pipeline :: sg.uninit_pipeline
uninit_pass :: sg.uninit_pass
fail_buffer :: sg.fail_buffer
fail_image :: sg.fail_image
fail_sampler :: sg.fail_sampler
fail_shader :: sg.fail_shader
fail_pipeline :: sg.fail_pipeline
fail_pass :: sg.fail_pass
enable_frame_stats :: sg.enable_frame_stats
disable_frame_stats :: sg.disable_frame_stats
frame_stats_enabled :: sg.frame_stats_enabled
query_frame_stats :: sg.query_frame_stats
setup_context :: sg.setup_context
activate_context :: sg.activate_context
discard_context :: sg.discard_context
d3d11_device :: sg.d3d11_device
d3d11_device_context :: sg.d3d11_device_context
d3d11_query_buffer_info :: sg.d3d11_query_buffer_info
d3d11_query_image_info :: sg.d3d11_query_image_info
d3d11_query_sampler_info :: sg.d3d11_query_sampler_info
d3d11_query_shader_info :: sg.d3d11_query_shader_info
d3d11_query_pipeline_info :: sg.d3d11_query_pipeline_info
d3d11_query_pass_info :: sg.d3d11_query_pass_info
mtl_device :: sg.mtl_device
mtl_render_command_encoder :: sg.mtl_render_command_encoder
mtl_query_buffer_info :: sg.mtl_query_buffer_info
mtl_query_image_info :: sg.mtl_query_image_info
mtl_query_sampler_info :: sg.mtl_query_sampler_info
mtl_query_shader_info :: sg.mtl_query_shader_info
mtl_query_pipeline_info :: sg.mtl_query_pipeline_info
wgpu_device :: sg.wgpu_device
wgpu_queue :: sg.wgpu_queue
wgpu_command_encoder :: sg.wgpu_command_encoder
wgpu_render_pass_encoder :: sg.wgpu_render_pass_encoder
wgpu_query_buffer_info :: sg.wgpu_query_buffer_info
wgpu_query_image_info :: sg.wgpu_query_image_info
wgpu_query_sampler_info :: sg.wgpu_query_sampler_info
wgpu_query_shader_info :: sg.wgpu_query_shader_info
wgpu_query_pipeline_info :: sg.wgpu_query_pipeline_info
wgpu_query_pass_info :: sg.wgpu_query_pass_info
gl_query_buffer_info :: sg.gl_query_buffer_info
gl_query_image_info :: sg.gl_query_image_info
gl_query_sampler_info :: sg.gl_query_sampler_info
gl_query_shader_info :: sg.gl_query_shader_info
gl_query_pass_info :: sg.gl_query_pass_info

gl_setup :: sgl.setup
gl_shutdown :: sgl.shutdown
gl_rad :: sgl.rad
gl_deg :: sgl.deg
gl_error :: sgl.error
gl_context_error :: sgl.context_error
gl_make_context :: sgl.make_context
gl_destroy_context :: sgl.destroy_context
gl_set_context :: sgl.set_context
gl_get_context :: sgl.get_context
gl_default_context :: sgl.default_context
gl_draw :: sgl.draw
gl_context_draw :: sgl.context_draw
gl_draw_layer :: sgl.draw_layer
gl_context_draw_layer :: sgl.context_draw_layer
gl_make_pipeline :: sgl.make_pipeline
gl_context_make_pipeline :: sgl.context_make_pipeline
gl_destroy_pipeline :: sgl.destroy_pipeline
gl_defaults :: sgl.defaults
gl_viewport :: sgl.viewport
gl_viewportf :: sgl.viewportf
gl_scissor_rect :: sgl.scissor_rect
gl_scissor_rectf :: sgl.scissor_rectf
gl_enable_texture :: sgl.enable_texture
gl_disable_texture :: sgl.disable_texture
gl_texture :: sgl.texture
gl_layer :: sgl.layer
gl_load_default_pipeline :: sgl.load_default_pipeline
gl_load_pipeline :: sgl.load_pipeline
gl_push_pipeline :: sgl.push_pipeline
gl_pop_pipeline :: sgl.pop_pipeline
gl_matrix_mode_modelview :: sgl.matrix_mode_modelview
gl_matrix_mode_projection :: sgl.matrix_mode_projection
gl_matrix_mode_texture :: sgl.matrix_mode_texture
gl_load_identity :: sgl.load_identity
gl_load_matrix :: sgl.load_matrix
gl_load_transpose_matrix :: sgl.load_transpose_matrix
gl_mult_matrix :: sgl.mult_matrix
gl_mult_transpose_matrix :: sgl.mult_transpose_matrix
gl_rotate :: sgl.rotate
gl_scale :: sgl.scale
gl_translate :: sgl.translate
gl_frustum :: sgl.frustum
gl_ortho :: sgl.ortho
gl_perspective :: sgl.perspective
gl_lookat :: sgl.lookat
gl_push_matrix :: sgl.push_matrix
gl_pop_matrix :: sgl.pop_matrix
gl_t2f :: sgl.t2f
gl_c3f :: sgl.c3f
gl_c4f :: sgl.c4f
gl_c3b :: sgl.c3b
gl_c4b :: sgl.c4b
gl_c1i :: sgl.c1i
gl_point_size :: sgl.point_size
gl_begin_points :: sgl.begin_points
gl_begin_lines :: sgl.begin_lines
gl_begin_line_strip :: sgl.begin_line_strip
gl_begin_triangles :: sgl.begin_triangles
gl_begin_triangle_strip :: sgl.begin_triangle_strip
gl_begin_quads :: sgl.begin_quads
gl_v2f :: sgl.v2f
gl_v3f :: sgl.v3f
gl_v2f_t2f :: sgl.v2f_t2f
gl_v3f_t2f :: sgl.v3f_t2f
gl_v2f_c3f :: sgl.v2f_c3f
gl_v2f_c3b :: sgl.v2f_c3b
gl_v2f_c4f :: sgl.v2f_c4f
gl_v2f_c4b :: sgl.v2f_c4b
gl_v2f_c1i :: sgl.v2f_c1i
gl_v3f_c3f :: sgl.v3f_c3f
gl_v3f_c3b :: sgl.v3f_c3b
gl_v3f_c4f :: sgl.v3f_c4f
gl_v3f_c4b :: sgl.v3f_c4b
gl_v3f_c1i :: sgl.v3f_c1i
gl_v2f_t2f_c3f :: sgl.v2f_t2f_c3f
gl_v2f_t2f_c3b :: sgl.v2f_t2f_c3b
gl_v2f_t2f_c4f :: sgl.v2f_t2f_c4f
gl_v2f_t2f_c4b :: sgl.v2f_t2f_c4b
gl_v2f_t2f_c1i :: sgl.v2f_t2f_c1i
gl_v3f_t2f_c3f :: sgl.v3f_t2f_c3f
gl_v3f_t2f_c3b :: sgl.v3f_t2f_c3b
gl_v3f_t2f_c4f :: sgl.v3f_t2f_c4f
gl_v3f_t2f_c4b :: sgl.v3f_t2f_c4b
gl_v3f_t2f_c1i :: sgl.v3f_t2f_c1i
gl_end :: sgl.end

COLOR_WHITE :: Color { 1, 1, 1, 1 }

sokol_init :: proc() {
    sg.setup({
        logger = { func = slog.func },
        allocator = { alloc_fn = sokol_alloc_fn, free_fn = sokol_free_fn },
    })
    if sg.isvalid() == false {
        fmt.panicf("sg.setup error: %v.\n", "no clue how to get errors from sokol_gfx")
    }
    assert(sg.query_backend() == .GLCORE33)

    sgl.setup({
        logger = { func = slog.func },
    })
}

sokol_quit :: proc() {
    sgl.shutdown()
    sg.shutdown()
}

gl_line :: proc(start, end: Vector3f32, color: Vector4f32) {
    sgl.defaults()
    sgl.begin_lines()
        sgl.c4f(color.r, color.g, color.b, color.a)
        sgl.v3f(start.x, start.y, start.z)
        sgl.v3f(end.x,   end.y,   end.z)
    sgl.end()
}

// Stub of v1 renderer

Shader :: struct {
    renderer_id: u32,
}

Texture :: struct {
    renderer_id: u32,
}

Camera_Orthographic :: struct {
    position:                   Vector3f32,
    rotation:                   f32,
    zoom:                       f32,
    projection_matrix:          Matrix4x4f32,
    view_matrix:                Matrix4x4f32,
    view_projection_matrix:     Matrix4x4f32,
}

PALETTE_SIZE  :: 32
PALETTE_MAX   :: 4
Color_Palette :: distinct [PALETTE_SIZE]Color

renderer_make_palette :: proc(colors: [PALETTE_SIZE][4]u8) -> Color_Palette {
    result := Color_Palette {}
    for color, i in colors {
        result[i] = { f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255 }
    }
    return result
}

when RENDERER == .None {
    renderer_reload :: proc(renderer: rawptr) { }
    renderer_render_begin :: proc() { }
    renderer_render_end :: proc() { }
    renderer_process_events :: proc(e: ^Event) { }
    // FIXME:
    renderer_load_texture :: proc(filepath: string, options: rawptr) -> (texture: ^Texture, ok: bool) { return }
    renderer_push_quad :: proc(position: Vector2f32, size: Vector2f32,
        color: Color = COLOR_WHITE, texture: rawptr = nil,
        texture_coordinates: Vector2f32 = { 0, 0 }, texture_size: Vector2f32 = { 1, 1 },
        rotation: f32 = 0, shader: rawptr = nil, palette: i32 = -1, flip: i8 = 0,
        loc := #caller_location,
    ) { }
    renderer_update_camera_projection_matrix :: proc() { }
    renderer_update_camera_view_projection_matrix :: proc() { }
    renderer_change_camera_begin :: proc(camera: ^Camera_Orthographic, loc := #caller_location) { }
    renderer_clear :: proc(color: Color) { }
    renderer_set_viewport :: proc(x, y, width, height: i32) { }
    renderer_update_viewport :: proc() { }
    renderer_shader_create :: proc(filepath: string, asset_id: Asset_Id) -> (shader: rawptr, ok: bool) #optional_ok { return }
    renderer_reload_all_shaders :: proc() -> (ok: bool) { return }
    renderer_shader_delete :: proc(asset_id: Asset_Id) -> (ok: bool) { return }
    renderer_get_window_pixel_density :: proc(window: ^Window) -> (result: f32) { return }
    renderer_set_palette :: proc(index: i32, palette: Color_Palette) { }
    renderer_get_viewport :: proc() -> (result: Vector4i32) { return }
    ui_window_shader :: proc(open: ^bool) { }
    renderer_push_line :: proc(points: []Vector2f32, shader: rawptr, color: Color, loc := #caller_location) { }
    renderer_quit :: proc() { }
    renderer_shader_create_from_asset :: proc(filepath: string, asset_id: Asset_Id) -> (shader: rawptr, ok: bool) #optional_ok { return }
    renderer_unbind_frame_buffer :: proc() { }
    renderer_bind_frame_buffer :: proc(frame_buffer: ^u32) { }
    renderer_rescale_frame_buffer :: proc(width, height: i32, render_buffer, texture_id: u32) { }
    renderer_set_uniform_NEW_1f_to_shader :: proc(shader: rawptr, name: string, value: f32) { }
    renderer_get_texture_size :: proc(texture: ^Texture) -> Vector2i32 { return {} }
    renderer_reload_all_shaders :: proc() -> (ok: bool) { return }
}

when RENDERER == .Sokol {
    renderer_reload :: proc(renderer: rawptr) { }
    renderer_load_texture :: proc(filepath: string, options: rawptr) -> (texture: ^Texture, ok: bool) { return }
    renderer_push_quad :: proc(position: Vector2f32, size: Vector2f32,
        color: Color = COLOR_WHITE, texture: rawptr = nil,
        texture_coordinates: Vector2f32 = { 0, 0 }, texture_size: Vector2f32 = { 1, 1 },
        rotation: f32 = 0, shader: rawptr = nil, palette: i32 = -1, flip: i8 = 0,
        loc := #caller_location,
    ) { }
    renderer_clear :: proc(color: Color) {
        // // FIXME: temp code, remove this
        // pass_action := Pass_Action {}
        // pass_action.colors[0] = { load_action = .CLEAR, clear_value = color }
        // window_size := get_window_size()
        // begin_default_pass(pass_action, window_size.x, window_size.y)
        // gl_draw()
        // end_pass()
    }
    renderer_set_palette :: proc(index: i32, palette: Color_Palette) { }
    renderer_shader_create :: proc(filepath: string, asset_id: Asset_Id) -> (shader: rawptr, ok: bool) #optional_ok { return }
    renderer_shader_delete :: proc(asset_id: Asset_Id) -> (ok: bool) { return }
    renderer_push_line :: proc(points: []Vector2f32, shader: rawptr, color: Color, loc := #caller_location) { }
    renderer_shader_create_from_asset :: proc(filepath: string, asset_id: Asset_Id) -> (shader: rawptr, ok: bool) #optional_ok { return }
    renderer_get_texture_size :: proc(texture: ^Texture) -> Vector2i32 { return {} }
    renderer_quit :: proc() { }
    renderer_reload_all_shaders :: proc() -> (ok: bool) { return }
}
