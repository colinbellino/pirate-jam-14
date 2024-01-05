package engine_v2

import "core:fmt"
import "core:log"
import gl "vendor:OpenGL"
import sg "../sokol-odin/sokol/gfx"
import sgl "../sokol-odin/sokol/gl"
import slog "../sokol-odin/sokol/log"

COLOR_WHITE :: Color { 1, 1, 1, 1 }

MAX_BUNNIES     :: 100_000
Bunny :: struct {
    position: Vector2f32,
    color:    Vector4f32,
}

Render_Command_Clear :: struct {
    type:                   Render_Command_Type,
    pass_action:            Pass_Action,
}
Render_Command_Draw_GL :: struct {
    type:                   Render_Command_Type,
    pass_action:            Pass_Action,
}
Render_Command_Draw_Bunnies :: struct {
    type:                   Render_Command_Type,
    pass_action:            Pass_Action,
    pipeline:               Pipeline,
    bindings:               Bindings,
    elements_base:          int,
    elements_num:           int,
    count:                  int,
    data:                   [MAX_BUNNIES]Bunny,
}

Render_Command_Type :: enum {
    Invalid = 0,
    Clear = 1,
    Draw_GL = 2,
    Draw_Bunnies = 3,
}

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

exec_command :: proc(command_ptr: rawptr, window_size: Vector2i32) {
    // log.debugf("exec_command: %v", command_ptr)
    if command_ptr == nil {
        log.errorf("nil command?!")
        return
    }

    type := cast(^Render_Command_Type) command_ptr
    // log.debugf("bla: %v | %v %v", bla, bla^ == .Clear, bla^ == .Draw_GL)

    switch type^ {
        case .Clear: {
            command := cast(^Render_Command_Clear) command_ptr
            begin_default_pass(command.pass_action, window_size.x, window_size.y)
            end_pass()
        }
        case .Draw_GL: {
            command := cast(^Render_Command_Draw_GL) command_ptr
            begin_default_pass(command.pass_action, window_size.x, window_size.y)
                gl_draw()
            end_pass()
        }
        case .Draw_Bunnies: {
            command := cast(^Render_Command_Draw_Bunnies) command_ptr
            begin_default_pass(command.pass_action, window_size.x, window_size.y)
                apply_pipeline(command.pipeline)
                apply_bindings(command.bindings)
                draw(command.elements_base, command.elements_num, command.count)
            end_pass()
        }
        case .Invalid: {
            log.errorf("Invalid command type: %v", type^)
        }
    }
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
