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

begin_default_pass :: sg.begin_default_pass
make_pipeline :: sg.make_pipeline
apply_pipeline :: sg.apply_pipeline
apply_bindings :: sg.apply_bindings
make_sampler :: sg.make_sampler
make_shader :: sg.make_shader
make_buffer :: sg.make_buffer
update_buffer :: sg.update_buffer
draw :: sg.draw
end_pass :: sg.end_pass
query_backend :: sg.query_backend
commit :: sg.commit
init_image :: sg.init_image
alloc_image :: sg.alloc_image
gl_draw :: sgl.draw

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

Color :: struct {
    r, g, b, a: f32,
}
PALETTE_SIZE  :: 32
PALETTE_MAX   :: 4
Color_Palette :: distinct [PALETTE_SIZE]Color

Camera_Orthographic :: struct {
    position:                   Vector3f32,
    rotation:                   f32,
    zoom:                       f32,
    projection_matrix:          Matrix4x4f32,
    view_matrix:                Matrix4x4f32,
    view_projection_matrix:     Matrix4x4f32,
}

renderer_init :: proc(window: ^Window, native_resolution: Vector2f32, allocator := context.allocator) -> (renderer_state: rawptr, ok: bool) #optional_ok {
    log.infof("Renderer (Sokol) ------------------------------------------")
    return nil, true
}
renderer_reload :: proc(renderer: rawptr) { }
renderer_is_enabled :: proc() -> (enabled: bool) { return true } // FIXME:
renderer_render_begin :: proc() { }
renderer_render_end :: proc() { }
renderer_process_events :: proc(e: ^Event) { }
// FIXME:
// renderer_load_texture :: proc(filepath: string, options: ^Asset_Load_Options_Image) -> (texture: ^Texture, ok: bool) { return }
renderer_load_texture :: proc(filepath: string, options: rawptr) -> (texture: ^Texture, ok: bool) { return }
renderer_push_quad :: proc(position: Vector2f32, size: Vector2f32,
    color: Color = { 1, 1, 1, 1 }, texture: rawptr = nil,
    texture_coordinates: Vector2f32 = { 0, 0 }, texture_size: Vector2f32 = { 1, 1 },
    rotation: f32 = 0, shader: rawptr = nil, palette: i32 = -1, flip: i8 = 0,
    loc := #caller_location,
) { }
renderer_update_camera_projection_matrix :: proc() { }
renderer_update_camera_view_projection_matrix :: proc() { }
renderer_change_camera_begin :: proc(camera: ^Camera_Orthographic, loc := #caller_location) { }
renderer_clear :: proc(color: Color)
 {
    // FIXME: temp code, remove this
    pass_action := Pass_Action {}
    pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.9, 0.9, 0.9, 1.0 } }
    window_size := get_window_size()
    begin_default_pass(pass_action, window_size.x, window_size.y)
    gl_draw()
    end_pass()
}
renderer_set_viewport :: proc(x, y, width, height: i32) { }
renderer_update_viewport :: proc() { }
renderer_shader_create :: proc(filepath: string, asset_id: Asset_Id) -> (shader: rawptr, ok: bool) #optional_ok { return }
debug_reload_shaders :: proc() -> (ok: bool) { return }
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
renderer_make_palette :: proc(colors: [PALETTE_SIZE][4]u8) -> Color_Palette {
    result := Color_Palette {}
    for color, i in colors {
        result[i] = { f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255 }
    }
    return result
}
