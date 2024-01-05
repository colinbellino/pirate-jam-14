package game

import "core:log"
import "core:time"
import "core:fmt"
import "core:math/rand"
import stb_image "vendor:stb/image"
import engine "../engine_v2"
import shader_sprite "../shaders/shader_sprite"

MAX_BUNNIES     :: 100_000
bunnies_speed:  [MAX_BUNNIES]Vector2f32
cmd_bunnies: ^engine.Render_Command_Draw_Bunnies
commands: [3]rawptr

make_render_command_clear :: proc(color: Color = { 0, 0, 0, 1 }) -> ^engine.Render_Command_Clear {
    command := new(engine.Render_Command_Clear, _mem.game.arena.allocator)
    command.type = .Clear
    command.pass_action.colors[0] = { load_action = .CLEAR, clear_value = color }
    return command
}
make_render_command_draw_bunnies :: proc() -> ^engine.Render_Command_Draw_Bunnies {
    engine.profiler_zone("bunnies_init")
    command := new(engine.Render_Command_Draw_Bunnies, _mem.game.arena.allocator)
    command.type = .Draw_Bunnies
    command.elements_base = 0
    command.elements_num = 6
    command.pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.2, 0.2, 0.2, 1.0 } }
    command.bindings.fs.samplers[shader_sprite.SLOT_smp] = engine.make_sampler({
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    })

    // index buffer for static geometry
    indices := [?]u16 {
        0, 1, 2,
        0, 2, 3,
    }
    command.bindings.index_buffer = engine.make_buffer({
        type = .INDEXBUFFER,
        data = engine.Range { &indices, size_of(indices) },
        label = "geometry-indices",
    })

    // vertex buffer for static geometry, goes into vertex-buffer-slot 0
    vertices := [?]f32 {
        -1, +1,
        +1, +1,
        +1, -1,
        -1, -1,
    } * 0.05
    command.bindings.vertex_buffers[0] = engine.make_buffer({
        data = engine.Range { &vertices, size_of(vertices) },
        label = "geometry-vertices",
    })

    // empty, dynamic instance-data vertex buffer, goes into vertex-buffer-slot 1
    command.bindings.vertex_buffers[1] = engine.make_buffer({
        size = u64(len(command.data)) * size_of(engine.Bunny),
        usage = .STREAM,
        label = "instance-data",
    })

    command.pipeline = engine.make_pipeline({
        layout = {
            buffers = { 1 = { step_func = .PER_INSTANCE }},
            attrs = {
                shader_sprite.ATTR_vs_pos =        { format = .FLOAT2, buffer_index = 0 },
                shader_sprite.ATTR_vs_inst_pos =   { format = .FLOAT2, buffer_index = 1 },
                shader_sprite.ATTR_vs_inst_color = { format = .FLOAT4, buffer_index = 1 },
            },
        },
        shader = engine.make_shader(shader_sprite.sprite_shader_desc(engine.query_backend())),
        index_type = .UINT16,
        cull_mode = .BACK,
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

    // FIXME: don't load image here
    command.bindings.fs.images[shader_sprite.SLOT_tex] = engine.alloc_image()
    width, height, channels_in_file: i32
    pixels := stb_image.load("../src/bunny_raylib/wabbit.png", &width, &height, &channels_in_file, 0)
    assert(pixels != nil, "couldn't load image")
    // TODO: free pixels?

    engine.init_image(command.bindings.fs.images[shader_sprite.SLOT_tex], {
        width = width,
        height = height,
        data = {
            subimage = { 0 = { 0 = {
                ptr = pixels,
                size = u64(width * height * channels_in_file),
            }, }, },
        },
    })

    return command
}
make_render_command_draw_gl :: proc() -> ^engine.Render_Command_Draw_GL {
    command := new(engine.Render_Command_Draw_GL, _mem.game.arena.allocator)
    command.type = .Draw_GL
    command.pass_action.colors[0] = { load_action = .DONTCARE }
    return command
}

bunnies_spawn :: proc(cmd_bunnies: ^engine.Render_Command_Draw_Bunnies, window_size: Vector2i32, spawn_position: Vector2f32 = { 0, 0 }) {
    engine.profiler_zone("bunnies_spawn")
    for i := 0; i < 100; i += 1 {
        if cmd_bunnies.count < len(cmd_bunnies.data) {
            cmd_bunnies.data[cmd_bunnies.count].position = spawn_position
            cmd_bunnies.data[cmd_bunnies.count].color = {
                f32(rand.float32_range(50, 240)) / 255,
                f32(rand.float32_range(80, 240)) / 255,
                f32(rand.float32_range(100, 240)) / 255,
                1,
            }
            bunnies_speed[cmd_bunnies.count].x = rand.float32_range(-250, 250) / 30
            bunnies_speed[cmd_bunnies.count].y = rand.float32_range(-250, 250) / 30
            cmd_bunnies.count += 1
        }
    }
}

init :: proc() {
    window_size := engine.get_window_size()
    cmd_bunnies = make_render_command_draw_bunnies()
    cmd_clear := make_render_command_clear({ 0.2, 0.2, 0.2, 1 })
    cmd_gl := make_render_command_draw_gl()
    commands[0] = cmd_clear
    commands[1] = cmd_bunnies
    commands[2] = cmd_gl
    log.debugf("commands: %v", commands)
    bunnies_spawn(cmd_bunnies, window_size)
}

game_mode_debug :: proc() {
    @(static) entered_at: time.Time

    window_size := engine.get_window_size()
    mouse_position := engine.mouse_get_position()
    frame_stat := engine.get_frame_stat()

    if game_mode_entering() {
        log.debug("[DEBUG] enter")
        entered_at = time.now()
        // engine.asset_load(_mem.game.asset_image_spritesheet, engine.Image_Load_Options { engine.RENDERER_FILTER_NEAREST, engine.RENDERER_CLAMP_TO_EDGE })
    }

    if game_mode_running() {
        {
            if cmd_bunnies == nil {
                init()
            }

            // state := engine.query_pipeline_state(cmd_bunnies.pipeline)
            // if state == .INVALID {
            //     init()
            // }

            if engine.mouse_button_is_down(.Left) && .Mod_1 in _mem.game.player_inputs.modifier {
                // FIXME: translate mouse position (window space) to render space
                bunnies_spawn(cmd_bunnies, window_size, { f32(mouse_position.x), f32(mouse_position.y) })
            }
            if engine.mouse_button_is_down(.Right) && .Mod_1 in _mem.game.player_inputs.modifier {
                cmd_bunnies.count = 0
            }
        }

        { // Lines
            engine.profiler_zone("lines")
            engine.gl_line({ 0, 0, 0 }, { +1, +1, 0 }, { 1, 0, 0, 1 })
            engine.gl_line({ 0, 0, 0 }, { +1, -1, 0 }, { 1, 1, 0, 1 })
            engine.gl_line({ 0, 0, 0 }, { -1, -1, 0 }, { 0, 1, 0, 1 })
            engine.gl_line({ 0, 0, 0 }, { -1, +1, 0 }, { 0, 1, 1, 1 })
        }

        if cmd_bunnies != nil {
                engine.profiler_zone("bunnies_move")
                offset := Vector2i32 { 0, 0 }
                @(static) ratio := Vector2f32 { 1, 1 }
                ratio = { 1_000 / f32(window_size.x), 1_000 / f32(window_size.y) }
                engine.ui_input_float2("ratio", cast(^[2]f32) &ratio)
                for i := 0; i < cmd_bunnies.count; i += 1 {
                    cmd_bunnies.data[i].position.x += bunnies_speed[i].x * frame_stat.delta_time / 10
                    cmd_bunnies.data[i].position.y += bunnies_speed[i].y * frame_stat.delta_time / 10

                    if (f32(cmd_bunnies.data[i].position.x) > f32(window_size.x) * ratio.x) || (f32(cmd_bunnies.data[i].position.x) < -f32(window_size.x) * ratio.x) {
                        bunnies_speed[i].x *= -1
                    }
                    if (f32(cmd_bunnies.data[i].position.y) > f32(window_size.y) * ratio.y) || (f32(cmd_bunnies.data[i].position.y) < -f32(window_size.y) * ratio.y) {
                        bunnies_speed[i].y *= -1
                    }
                }
        }

        if cmd_bunnies != nil && cmd_bunnies.count > 0 {
            {
                engine.profiler_zone("bunnies_update")
                engine.update_buffer(cmd_bunnies.bindings.vertex_buffers[1], {
                    ptr = &cmd_bunnies.data,
                    size = u64(cmd_bunnies.count) * size_of(engine.Bunny),
                })
            }

            if engine.ui_tree_node(fmt.tprintf("bunnies (%v)###bunnies", cmd_bunnies.count)) {
                for i := 0; i < cmd_bunnies.count; i += 1 {
                    engine.ui_text("%v pos: %v, color: %v, speed: %v", i, cmd_bunnies.data[i].position, cmd_bunnies.data[i].color, bunnies_speed[i])
                }
            }
        }

        for command, i in commands {
            engine.exec_command(command, window_size)
        }
        engine.commit()

        start_battle := false
        time_scale := engine.get_time_scale()
        if time_scale > 99 && time.diff(time.time_add(entered_at, time.Duration(f32(time.Second) / time_scale)), time.now()) > 0 {
            start_battle = true
        }

        if start_battle {
            log.debugf("DEBUG -> BATTLE")
            game_mode_transition(.Battle)
        }
    }

    if game_mode_exiting() {
        log.debug("[DEBUG] exit")
    }
}
