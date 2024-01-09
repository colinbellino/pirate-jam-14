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
MAX_SPRITES :: 100_000

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

Render_Command_Type :: enum {
    Invalid = 0,
    Clear = 1,
    Draw_GL = 2,
    Draw_Sprite = 3,
}
Render_Command_Clear :: struct {
    type:                   Render_Command_Type,
    pass_action:            Pass_Action,
}
Render_Command_Draw_GL :: struct {
    type:                   Render_Command_Type,
    pass_action:            Pass_Action,
}
Render_Command_Draw_Sprite :: struct {
    type:                   Render_Command_Type,
    pass_action:            Pass_Action,
    pipeline:               Pipeline,
    bindings:               Bindings,
    count:                  int,
    data:                   [MAX_SPRITES] struct {
        position:               Vector2f32,
        scale:                  Vector2f32,
        color:                  Vector4f32,
        texture_position:       Vector2f32,
        texture_size:           Vector2f32,
        texture_index:          f32,
        palette:                f32,
    },
    vs_uniform:             struct {
        projection_view:        Matrix4x4f32,
    },
    fs_uniform:             struct {
        palettes:               [PALETTE_MAX]Color_Palette,
    },
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

r_command_exec :: proc(command_ptr: rawptr, loc := #caller_location) {
    if command_ptr == nil {
        log.warnf("Can't exec nil render command: %v", loc)
        return
    }

    type := cast(^Render_Command_Type) command_ptr
    assert(type^ != .Invalid, "Invalid render command type")
    // log.debugf("r_exec_command: %v", type^)

    window_size := get_window_size()

    #partial switch type^ {
        case .Clear: {
            command := cast(^Render_Command_Clear) command_ptr
            sg_begin_default_pass(command.pass_action, window_size.x, window_size.y)
            sg_end_pass()
        }
        case .Draw_GL: {
            command := cast(^Render_Command_Draw_GL) command_ptr
            sg_begin_default_pass(command.pass_action, window_size.x, window_size.y)
                sgl_draw()
            sg_end_pass()
        }
        case .Draw_Sprite: {
            command := cast(^Render_Command_Draw_Sprite) command_ptr
            sg_begin_default_pass(command.pass_action, window_size.x, window_size.y)
                sg_apply_pipeline(command.pipeline)
                sg_apply_bindings(command.bindings)
                sg_apply_uniforms(.VS, 0, { &command.vs_uniform, size_of(command.vs_uniform) })
                sg_apply_uniforms(.FS, 0, { &command.fs_uniform, size_of(command.fs_uniform) })
                sg_draw(0, 6, command.count)
            sg_end_pass()
        }
        case .Invalid: {
            fmt.panicf("Invalid command type: %v", type^)
        }
    }
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
