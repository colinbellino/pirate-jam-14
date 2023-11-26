package engine

import "core:log"
import "core:mem"
import "core:time"
import "vendor:sdl2"

when RENDERER == .None {
    Renderer_State :: struct {
        arena:                      Named_Virtual_Arena,
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
        game_view_resized:          bool,
        frame_buffer:               u32,
        render_buffer:              u32,
        buffer_texture_id:          u32,
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

    RENDERER_DEBUG :: 0
    RENDERER_LINEAR :: 0
    RENDERER_NEAREST :: 0
    RENDERER_CLAMP_TO_EDGE :: 0
    RENDERER_FILTER_LINEAR :: 0
    RENDERER_FILTER_NEAREST :: 0
    RENDERER_ARENA_SIZE :: mem.Megabyte * 100

    @(private="package")
    _renderer: ^Renderer_State

    renderer_init :: proc(window: ^Window, native_resolution: Vector2f32, allocator := context.allocator) -> (renderer_state: ^Renderer_State, ok: bool) #optional_ok {
        _renderer = mem_named_arena_virtual_bootstrap_new_or_panic(Renderer_State, "arena", RENDERER_ARENA_SIZE, "renderer")
        log.infof("Renderer (None) ------------------------------------------")
        return nil, true
    }
    renderer_reload :: proc(renderer: ^Renderer_State) { }
    renderer_is_enabled :: proc() -> (enabled: bool) { return }
    renderer_render_begin :: proc() { }
    renderer_render_end :: proc() { }
    renderer_process_events :: proc(e: ^sdl2.Event) { }
    renderer_load_texture :: proc(filepath: string, options: ^Image_Load_Options) -> (texture: ^Texture, ok: bool) { return }
    renderer_push_quad :: proc(position: Vector2f32, size: Vector2f32,
        color: Color = { 1, 1, 1, 1 }, texture: ^Texture = nil,
        texture_coordinates: Vector2f32 = { 0, 0 }, texture_size: Vector2f32 = { 1, 1 },
        rotation: f32 = 0, shader: ^Shader = nil, palette: i32 = -1,
        loc := #caller_location,
    ) { }
    renderer_update_camera_matrix :: proc() { }
    renderer_change_camera_begin :: proc(camera: ^Camera_Orthographic, loc := #caller_location) { }
    renderer_clear :: proc(color: Color) { }
    renderer_set_viewport :: proc(x, y, width, height: i32) { }
    renderer_update_viewport :: proc() { }
    renderer_shader_create :: proc(filepath: string, asset_id: Asset_Id) -> (shader: ^Shader, ok: bool) #optional_ok { return }
    debug_reload_shaders :: proc() -> (ok: bool) { return }
    renderer_shader_delete :: proc(asset_id: Asset_Id) -> (ok: bool) { return }
    renderer_get_window_pixel_density :: proc(window: ^Window) -> (result: f32) { return }
    renderer_set_palette :: proc(index: i32, palette: Color_Palette) { }
    renderer_get_viewport :: proc() -> (result: Vector4i32) { return }
    ui_window_shader :: proc(open: ^bool) { }
    renderer_push_line :: proc(points: []Vector2f32, shader: ^Shader, color: Color, loc := #caller_location) { }
    renderer_quit :: proc() { }
    renderer_shader_create_from_asset :: proc(filepath: string, asset_id: Asset_Id) -> (shader: ^Shader, ok: bool) #optional_ok { return }
    renderer_unbind_frame_buffer :: proc() { }
    renderer_bind_frame_buffer :: proc(frame_buffer: ^u32) { }
    renderer_rescale_frame_buffer :: proc(width, height: i32, render_buffer, texture_id: u32) { }
}
