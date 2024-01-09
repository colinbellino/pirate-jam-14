package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:math/rand"
import "core:os"
import "core:path/slashpath"
import "core:strings"
import "core:time"
import stb_image "vendor:stb/image"
import engine "../engine_v2"
import shader_sprite "../shaders/shader_sprite"

CAMERA_INITIAL_ZOOM :: 16

palettes_init :: proc() {
    _mem.game.palettes[0] = engine.r_make_palette({
        /*  0 */ { 0, 0, 0, 255 },
        /*  1 */ { 34, 32, 52, 255 },
        /*  2 */ { 69, 40, 60, 255 },
        /*  3 */ { 102, 57, 49, 255 },
        /*  4 */ { 143, 86, 59, 255 },
        /*  5 */ { 223, 113, 38, 255 },
        /*  6 */ { 217, 160, 102, 255 },
        /*  7 */ { 238, 195, 154, 255 },
        /*  8 */ { 251, 242, 54, 255 },
        /*  9 */ { 153, 229, 80, 255 },
        /* 10 */ { 106, 190, 48, 255 },
        /* 11 */ { 55, 148, 110, 255 },
        /* 12 */ { 75, 105, 47, 255 },
        /* 13 */ { 82, 75, 36, 255 },
        /* 14 */ { 50, 60, 57, 255 },
        /* 15 */ { 63, 63, 116, 255 },
        /* 16 */ { 48, 96, 130, 255 },
        /* 17 */ { 91, 110, 225, 255 },
        /* 18 */ { 99, 155, 255, 255 },
        /* 19 */ { 95, 205, 228, 255 },
        /* 20 */ { 203, 219, 252, 255 },
        /* 21 */ { 255, 255, 255, 255 },
        /* 22 */ { 155, 173, 183, 255 },
        /* 23 */ { 132, 126, 135, 255 },
        /* 24 */ { 105, 106, 106, 255 },
        /* 25 */ { 89, 86, 82, 255 },
        /* 26 */ { 118, 66, 138, 255 },
        /* 27 */ { 172, 50, 50, 255 },
        /* 28 */ { 217, 87, 99, 255 },
        /* 29 */ { 215, 123, 186, 255 },
        /* 30 */ { 143, 151, 74, 255 },
        /* 31 */ { 138, 111, 48, 255 },
    })
    _mem.game.palettes[1] =  engine.r_make_palette({
        /*  0 */ { 0, 0, 0, 255 },
        /*  1 */ { 34, 32, 52, 255 },
        /*  2 */ { 69, 40, 60, 255 },
        /*  3 */ { 102, 57, 49, 255 },
        /*  4 */ { 143, 86, 59, 255 },
        /*  5 */ { 223, 113, 38, 255 },
        /*  6 */ { 217, 160, 102, 255 },
        /*  7 */ { 238, 195, 154, 255 },
        /*  8 */ { 251, 242, 54, 255 },
        /*  9 */ { 153, 229, 80, 255 },
        /* 10 */ { 106, 190, 48, 255 },
        /* 11 */ { 55, 148, 110, 255 },
        /* 12 */ { 75, 105, 47, 255 },
        /* 13 */ { 82, 75, 36, 255 },
        /* 14 */ { 50, 60, 57, 255 },
        /* 15 */ { 55, 148, 110, 255 },
        /* 16 */ { 48, 96, 130, 255 },
        /* 17 */ { 106, 190, 48, 255 },
        /* 18 */ { 99, 155, 255, 255 },
        /* 19 */ { 95, 205, 228, 255 },
        /* 20 */ { 203, 219, 252, 255 },
        /* 21 */ { 255, 255, 255, 255 },
        /* 22 */ { 155, 173, 183, 255 },
        /* 23 */ { 132, 126, 135, 255 },
        /* 24 */ { 105, 106, 106, 255 },
        /* 25 */ { 89, 86, 82, 255 },
        /* 26 */ { 118, 66, 138, 255 },
        /* 27 */ { 172, 50, 50, 255 },
        /* 28 */ { 217, 87, 99, 255 },
        /* 29 */ { 215, 123, 186, 255 },
        /* 30 */ { 143, 151, 74, 255 },
        /* 31 */ { 138, 111, 48, 255 },
    })
}

camera_update_matrix :: proc() {
    camera := &_mem.game.world_camera
    window_size := engine.get_window_size()
    window_size_f32 := Vector2f32 { f32(window_size.x), f32(window_size.y) }

    camera.projection_matrix = engine.matrix_ortho3d_f32(
        -window_size_f32.x / 2 / camera.zoom,    +window_size_f32.x / 2 / camera.zoom,
        +window_size_f32.y / 2 / camera.zoom,    -window_size_f32.y / 2 / camera.zoom,
        -1,    +1,
    )
    { // update camera matrix
        transform := engine.matrix4_translate_f32(camera.position)
        camera.view_matrix = engine.matrix4_inverse_f32(transform)
        camera.view_projection_matrix = camera.projection_matrix * camera.view_matrix
    }
}

renderer_commands_init :: proc() {
    _mem.game.render_command_clear = make_render_command_clear({ 0.2, 0.2, 0.2, 1 })
    _mem.game.render_command_sprites = make_render_command_draw_sprites()
    _mem.game.render_command_gl = make_render_command_draw_gl()
    append(&_mem.game.render_commands, _mem.game.render_command_clear)
    append(&_mem.game.render_commands, _mem.game.render_command_sprites)
    append(&_mem.game.render_commands, _mem.game.render_command_gl)
}

make_render_command_clear :: proc(color: Color = { 0, 0, 0, 1 }) -> ^engine.Render_Command_Clear {
    command := new(engine.Render_Command_Clear)
    command.type = .Clear
    command.pass_action.colors[0] = { load_action = .CLEAR, clear_value = color }
    return command
}
make_render_command_draw_sprites :: proc() -> ^engine.Render_Command_Draw_Sprite {
    engine.profiler_zone("sprites_init")
    command := new(engine.Render_Command_Draw_Sprite)
    command.type = .Draw_Sprite
    command.pass_action.colors[0] = { load_action = .DONTCARE }
    command.bindings.fs.samplers[shader_sprite.SLOT_smp] = engine.sg_make_sampler({
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    })

    // index buffer for static geometry
    indices := [?]u16 {
        0, 1, 2,
        0, 2, 3,
    }
    command.bindings.index_buffer = engine.sg_make_buffer({
        type = .INDEXBUFFER,
        data = engine.Range { &indices, size_of(indices) },
        label = "geometry-indices",
    })

    // vertex buffer for static geometry, goes into vertex-buffer-slot 0
    vertices := [?]f32 {
        // position     // uv
        +0.5, +0.5,     1, 1,
        -0.5, +0.5,     0, 1,
        -0.5, -0.5,     0, 0,
        +0.5, -0.5,     1, 0,
    }
    command.bindings.vertex_buffers[0] = engine.sg_make_buffer({
        data = engine.Range { &vertices, size_of(vertices) },
        label = "geometry-vertices",
    })

    // empty, dynamic instance-data vertex buffer, goes into vertex-buffer-slot 1
    command.bindings.vertex_buffers[1] = engine.sg_make_buffer({
        size = len(command.data) * size_of(command.data[0]),
        usage = .STREAM,
        label = "instance-data",
    })

    command.pipeline = engine.sg_make_pipeline({
        layout = {
            buffers = { 1 = { step_func = .PER_INSTANCE }},
            attrs = {
                shader_sprite.ATTR_vs_position =           { format = .FLOAT2, buffer_index = 0 },
                shader_sprite.ATTR_vs_uv =                 { format = .FLOAT2, buffer_index = 0 },
                shader_sprite.ATTR_vs_i_position =         { format = .FLOAT2, buffer_index = 1 },
                shader_sprite.ATTR_vs_i_scale =            { format = .FLOAT2, buffer_index = 1 },
                shader_sprite.ATTR_vs_i_color =            { format = .FLOAT4, buffer_index = 1 },
                shader_sprite.ATTR_vs_i_t_position =       { format = .FLOAT2, buffer_index = 1 },
                shader_sprite.ATTR_vs_i_t_size =           { format = .FLOAT2, buffer_index = 1 },
                shader_sprite.ATTR_vs_i_t_index =          { format = .FLOAT,  buffer_index = 1 },
                shader_sprite.ATTR_vs_i_palette =          { format = .FLOAT,  buffer_index = 1 },
            },
        },
        shader = engine.sg_make_shader(shader_sprite.sprite_shader_desc(engine.sg_query_backend())),
        index_type = .UINT16,
        cull_mode = .NONE,
        depth = {
            compare = .LESS_EQUAL,
            write_enabled = true,
        },
        colors = {
            0 = {
                write_mask = .RGBA,
                blend = {
                    enabled = true,
                    src_factor_rgb = .SRC_ALPHA,
                    dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                },
            },
        },
        label = "instancing-pipeline",
    })

    images := [?]Asset_Id {
        _mem.game.asset_image_spritesheet,
        _mem.game.asset_image_units,
        _mem.game.asset_image_units,
        _mem.game.asset_image_units,
    }
    for asset_id, i in images {
        asset_info, asset_info_ok := engine.asset_get_asset_info_image(asset_id)
        assert(asset_info_ok)

        command.bindings.fs.images[i] = transmute(engine.Image) asset_info.renderer_id
        state := engine.sg_query_image_state(transmute(engine.Image) asset_info.renderer_id)
        if state == .ALLOC {
            engine.sg_init_image(command.bindings.fs.images[i], {
                width = asset_info.size.x,
                height = asset_info.size.y,
                data = {
                    subimage = { 0 = { 0 = {
                        ptr = asset_info.data,
                        size = u64(asset_info.size.x * asset_info.size.y * asset_info.channels_in_file),
                    }, }, },
                },
            })
        }

        log.debugf("asset_id: %v -> texture_index: %v", asset_id, i)
    }

    command.fs_uniform.palettes = _mem.game.palettes

    return command
}
make_render_command_draw_gl :: proc() -> ^engine.Render_Command_Draw_GL {
    command := new(engine.Render_Command_Draw_GL)
    command.type = .Draw_GL
    command.pass_action.colors[0] = { load_action = .DONTCARE }
    return command
}
