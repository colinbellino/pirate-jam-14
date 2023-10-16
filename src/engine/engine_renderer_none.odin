package engine

import "core:time"
import "vendor:sdl2"

when RENDERER == .None {
    RENDERER_DEBUG :: 0
    RENDERER_LINEAR :: 0
    RENDERER_NEAREST :: 0
    RENDERER_CLAMP_TO_EDGE :: 0
    RENDERER_FILTER_LINEAR :: 0
    RENDERER_FILTER_NEAREST :: 0

    Renderer_State :: struct {
        enabled:                    bool,
        pixel_density:              f32,
        refresh_rate:               i32,
        draw_duration:              i32,
        ideal_scale:                f32,
        debug_notification:         UI_Notification,
        ui_camera:                  Camera_Orthographic,
        world_camera:               Camera_Orthographic,
        current_camera:             ^Camera_Orthographic,
        previous_camera:            ^Camera_Orthographic,
        native_resolution:          Vector2f32,
        rendering_size:             Vector2f32,
        texture_white:              ^Texture,
        stats:                      Renderer_Stats,
        game_view_position:         Vector2f32,
        game_view_size:             Vector2f32,
    }

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

    renderer_render_begin :: proc() { }
    renderer_render_end :: proc() { }
    renderer_process_events :: proc(e: ^sdl2.Event) { }
    renderer_load_texture :: proc(filepath: string, options: ^Image_Load_Options) -> (texture: ^Texture, ok: bool) { return }
    renderer_push_quad :: proc(position: Vector2f32, size: Vector2f32,
        color: Color = { 1, 1, 1, 1 }, texture: ^Texture = _e.renderer.texture_white,
        texture_coordinates: Vector2f32 = { 0, 0 }, texture_size: Vector2f32 = { 1, 1 },
        rotation: f32 = 0,
        shader: ^Shader = nil, loc := #caller_location,
    ) { }
    renderer_update_camera_matrix :: proc() { }
    renderer_change_camera_begin :: proc(camera: ^Camera_Orthographic, loc := #caller_location) { }
    renderer_clear :: proc(color: Color) { }
    renderer_set_viewport :: proc(x, y, width, height: i32) { }
    renderer_update_viewport :: proc() { }
    renderer_shader_create :: proc(filepath: string, asset_id: Asset_Id) -> (shader: ^Shader, ok: bool) #optional_ok { return }
    debug_reload_shaders :: proc() -> (ok: bool) { return }
    renderer_reload :: proc(renderer: ^Renderer_State) { }
    renderer_is_enabled :: proc() -> (enabled: bool) { return true }
    renderer_shader_delete :: proc(asset_id: Asset_Id) -> (ok: bool) { return }
    renderer_init :: proc(window: ^Window, native_resolution: Vector2f32, allocator := context.allocator) -> (ok: bool) {
        _e.renderer = new(Renderer_State, allocator)
        return true
    }
    renderer_get_window_pixel_density :: proc(window: ^Window) -> (result: f32) { return }
}
