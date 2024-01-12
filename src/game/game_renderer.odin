package game

import "core:fmt"
import "core:math/linalg/glsl"
import "../engine"
import shader_sprite "../shaders/shader_sprite"
import shader_swipe "../shaders/shader_swipe"
import shader_line "../shaders/shader_line"

CAMERA_ZOOM_INITIAL :: 16
CAMERA_ZOOM_MAX     :: 64

TEXTURE_PADDING         :: 1
GRID_SIZE               :: 8
GRID_SIZE_V2            :: Vector2i32 { GRID_SIZE, GRID_SIZE }
GRID_SIZE_F32           :: f32(GRID_SIZE)
GRID_SIZE_V2F32         :: Vector2f32 { f32(GRID_SIZE), f32(GRID_SIZE) }
MAX_SPRITES             :: 100_000
MAX_POINTS              :: 128
SPRITE_TEXTURE_MAX      :: 4

v4 :: engine.r_v4

Render_Command_Clear :: struct {
    pass_action:            engine.Pass_Action,
}
Render_Command_Draw_GL :: struct {
    pass_action:            engine.Pass_Action,
}
Render_Command_Draw_Sprite :: struct {
    pass_action:            engine.Pass_Action,
    pipeline:               engine.Pipeline,
    bindings:               engine.Bindings,
    vs_uniform:             shader_sprite.Vs_Uniform,
    fs_uniform:             shader_sprite.Fs_Uniform,
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
}
Render_Command_Draw_Swipe :: struct {
    pass_action:            engine.Pass_Action,
    pipeline:               engine.Pipeline,
    bindings:               engine.Bindings,
    vs_uniform:             shader_swipe.Vs_Uniform,
    fs_uniform:             shader_swipe.Fs_Uniform,
    data:                   struct {
        position:               Vector2f32,
        color:                  Vector4f32,
    },
}
Render_Command_Draw_Line :: struct {
    pass_action:            engine.Pass_Action,
    pipeline:               engine.Pipeline,
    bindings:               engine.Bindings,
    // vs_uniform:             shader_line.Vs_Uniform,
    fs_uniform:             shader_line.Fs_Uniform,
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
    transform := engine.matrix4_translate_f32(camera.position)
    camera.view_matrix = engine.matrix4_inverse_f32(transform) * glsl.mat4Rotate({ 0, 0, 1 }, camera.rotation)
    camera.view_projection_matrix = camera.projection_matrix * camera.view_matrix
}

renderer_commands_init :: proc() {
    engine.asset_load(_mem.game.asset_shader_sprite)
    engine.asset_load(_mem.game.asset_shader_swipe)

    engine.asset_load(_mem.game.asset_image_spritesheet)
    engine.asset_load(_mem.game.asset_image_test)
    _mem.game.loaded_textures = {
        _mem.game.asset_image_spritesheet,
        _mem.game.asset_image_test,
        _mem.game.asset_image_spritesheet,
        _mem.game.asset_image_spritesheet,
    }
    _mem.game.render_command_clear = make_render_command_clear()
    _mem.game.render_command_sprites = make_render_command_draw_sprites()
    _mem.game.render_command_gl = make_render_command_draw_gl()
    _mem.game.render_command_swipe = make_render_command_draw_swipe()
}

make_render_command_clear :: proc() -> ^Render_Command_Clear {
    command := new(Render_Command_Clear)
    command.pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0, 0, 0, 1 } }
    return command
}
make_render_command_draw_sprites :: proc() -> ^Render_Command_Draw_Sprite {
    engine.profiler_zone("make_render_command_draw_sprites")
    command := new(Render_Command_Draw_Sprite)
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
        data = { &indices, size_of(indices) },
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
        data = { &vertices, size_of(vertices) },
        label = "geometry-vertices",
    })

    // empty, dynamic instance-data vertex buffer, goes into vertex-buffer-slot 1
    command.bindings.vertex_buffers[1] = engine.sg_make_buffer({
        size = len(command.data) * size_of(command.data[0]),
        usage = .STREAM,
        label = "instance-data",
    })

    asset_id := _mem.game.asset_shader_sprite
    asset_info, asset_info_ok := engine.asset_get_asset_info_shader(asset_id)
    assert(asset_info_ok, fmt.tprintf("shader not loaded: %v", asset_id))

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
        shader = asset_info,
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

    for texture_asset_id, i in _mem.game.loaded_textures {
        texture_asset_info, texture_asset_info_ok := engine.asset_get_asset_info_image(texture_asset_id)
        assert(texture_asset_info_ok)

        command.bindings.fs.images[i] = transmute(engine.Image) texture_asset_info.renderer_id
        state := engine.sg_query_image_state(transmute(engine.Image) texture_asset_info.renderer_id)
        if state == .ALLOC {
            engine.sg_init_image(command.bindings.fs.images[i], {
                width = texture_asset_info.size.x,
                height = texture_asset_info.size.y,
                data = {
                    subimage = { 0 = { 0 = {
                        ptr = texture_asset_info.data,
                        size = u64(texture_asset_info.size.x * texture_asset_info.size.y * texture_asset_info.channels_in_file),
                    }, }, },
                },
            })
        }
    }

    command.fs_uniform.palettes = transmute([128][4]f32) _mem.game.palettes

    return command
}
make_render_command_draw_swipe :: proc() -> ^Render_Command_Draw_Swipe {
    engine.profiler_zone("make_render_command_draw_swipe")
    command := new(Render_Command_Draw_Swipe)
    command.pass_action.colors[0] = { load_action = .DONTCARE }

    // index buffer for static geometry
    indices := [?]u16 {
        0, 1, 2,
        0, 2, 3,
    }
    command.bindings.index_buffer = engine.sg_make_buffer({
        type = .INDEXBUFFER,
        data = { &indices, size_of(indices) },
        label = "geometry-indices",
    })

    // vertex buffer for static geometry, goes into vertex-buffer-slot 0
    vertices := [?]f32 {
        // position
        +0.5, +0.5,
        -0.5, +0.5,
        -0.5, -0.5,
        +0.5, -0.5,
    }
    command.bindings.vertex_buffers[0] = engine.sg_make_buffer({
        data = { &vertices, size_of(vertices) },
        label = "geometry-vertices",
    })

    command.bindings.vertex_buffers[1] = engine.sg_make_buffer({
        size = size_of(command.data),
        usage = .STREAM,
        label = "instance-data",
    })

    asset_id := _mem.game.asset_shader_swipe
    asset_info, asset_info_ok := engine.asset_get_asset_info_shader(asset_id)
    assert(asset_info_ok, fmt.tprintf("shader not loaded: %v", asset_id))

    command.pipeline = engine.sg_make_pipeline({
        layout = {
            buffers = { 1 = { step_func = .PER_INSTANCE }},
            attrs = {
                shader_swipe.ATTR_vs_position =           { format = .FLOAT2, buffer_index = 0 },
                shader_swipe.ATTR_vs_i_position =         { format = .FLOAT2, buffer_index = 1 },
                shader_swipe.ATTR_vs_i_color =            { format = .FLOAT4, buffer_index = 1 },
            },
        },
        shader = asset_info,
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

    return command
}
make_render_command_draw_gl :: proc() -> ^Render_Command_Draw_GL {
    command := new(Render_Command_Draw_GL)
    command.pass_action.colors[0] = { load_action = .DONTCARE }
    return command
}

texture_asset_to_texture_index :: proc(asset_id: Asset_Id) -> u32 {
    for texture_asset_id, i in _mem.game.loaded_textures {
        if texture_asset_id == asset_id {
            return u32(i)
        }
    }
    return 0
}

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
