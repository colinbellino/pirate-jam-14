package engine_v2

import "core:fmt"
import "core:log"
import "core:strings"
import gl "vendor:OpenGL"
import sg "../sokol-odin/sokol/gfx"
import sgl "../sokol-odin/sokol/gl"
import slog "../sokol-odin/sokol/log"

import "../shaders"

COLOR_WHITE   :: Color { 1, 1, 1, 1 }
PALETTE_SIZE  :: 32
PALETTE_MAX   :: 4
Color_Palette :: distinct [PALETTE_SIZE]Color

Shader :: sg.Shader

Texture :: struct {
    renderer_id:        u32,
    filepath:           string,
    size:               Vector2i32,
    channels_in_file:   i32,
    data:               [^]byte,
}

Camera_Orthographic :: struct {
    position:                   Vector3f32,
    rotation:                   f32,
    zoom:                       f32,
    projection_matrix:          Matrix4x4f32,
    view_matrix:                Matrix4x4f32,
    view_projection_matrix:     Matrix4x4f32,
}

r_sokol_init :: proc() {
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

r_sokol_quit :: proc() {
    sgl.shutdown()
    sg.shutdown()
}

r_draw_line :: proc(start, end: Vector3f32, color: Vector4f32) {
    sgl.defaults()
    sgl.begin_lines()
        sgl.c4f(color.r, color.g, color.b, color.a)
        sgl.v3f(start.x, start.y, start.z)
        sgl.v3f(end.x,   end.y,   end.z)
    sgl.end()
}

r_make_palette :: proc(colors: [PALETTE_SIZE][4]u8) -> Color_Palette {
    result := Color_Palette {}
    for color, i in colors {
        result[i] = { f32(color.r) / 255, f32(color.g) / 255, f32(color.b) / 255, f32(color.a) / 255 }
    }
    return result
}

r_load_texture :: proc(filepath: string, options: rawptr) -> (texture: ^Texture, ok: bool) {
    texture = new(Texture)
    texture.filepath = strings.clone(filepath)
    texture.data = platform_load_image(filepath, &texture.size.x, &texture.size.y, &texture.channels_in_file)
    texture.renderer_id = transmute(u32) sg_alloc_image()
    return texture, true
}

r_shader_create_from_asset :: proc(filepath: string, asset_id: Asset_Id) -> (shader: Shader, ok: bool) #optional_ok {
    desc, desc_ok := shaders.shaders[filepath]
    if desc_ok == false {
        log.debugf("Couldn't find shader description, did you forget to import the shader_*.odin file?")
        return {}, false
    }
    return sg_make_shader(desc(sg_query_backend())), true
}
// Stub of v1 renderer

renderer_reload_all_shaders :: proc() -> (ok: bool) { return }
renderer_shader_create :: proc(filepath: string, asset_id: Asset_Id) -> (shader: rawptr, ok: bool) #optional_ok { return }
renderer_shader_delete :: proc(asset_id: Asset_Id) -> (ok: bool) { return }
renderer_push_line :: proc(points: []Vector2f32, shader: rawptr, color: Color, loc := #caller_location) { }
