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

@(private="file") bunnies_speed:  [engine.MAX_SPRITES]Vector2f32
BUNNIES_RECT :: Vector2f32 { 1000, 1000 }

bunnies_spawn :: proc(window_size: Vector2i32, world_position: Vector2f32 = { 0, 0 }) {
    engine.profiler_zone("bunnies_spawn")
    for i := 0; i < 100; i += 1 {
        if _mem.game.render_command_sprites.count < len(_mem.game.render_command_sprites.data) {
            _mem.game.render_command_sprites.data[_mem.game.render_command_sprites.count].position = world_position
            // _mem.game.render_command_sprites.data[_mem.game.render_command_sprites.count].scale = { 1, 1 }
            _mem.game.render_command_sprites.data[_mem.game.render_command_sprites.count].color = {
                f32(rand.float32_range(50, 240)) / 255,
                f32(rand.float32_range(80, 240)) / 255,
                f32(rand.float32_range(100, 240)) / 255,
                1,
            }
            bunnies_speed[_mem.game.render_command_sprites.count].x = rand.float32_range(-1, 1)
            bunnies_speed[_mem.game.render_command_sprites.count].y = rand.float32_range(-1, 1)
            _mem.game.render_command_sprites.count += 1
        }
    }
}

init :: proc() {
    _mem.game.render_command_sprites.data[0].color = { 1, 1, 1, 1 }
    _mem.game.render_command_sprites.data[1].position = { 0, 0 }
    _mem.game.render_command_sprites.data[1].color = { 1, 1, 1, 1 }
    _mem.game.render_command_sprites.data[2].position = { 1, 1 }
    _mem.game.render_command_sprites.data[2].color = { 1, 0, 0, 1 }
    _mem.game.render_command_sprites.data[3].position = { 2, 2 }
    _mem.game.render_command_sprites.data[3].color = { 0, 1, 0, 1 }
    _mem.game.render_command_sprites.data[4].position = { 1.5, 1.5 }
    _mem.game.render_command_sprites.data[4].color = { 0, 0, 1, 1 }
    _mem.game.render_command_sprites.data[5].position = { 100, 100 }
    _mem.game.render_command_sprites.data[5].color = { 1, 1, 0, 1 }
    _mem.game.render_command_sprites.count = 6
}

game_mode_debug :: proc() {
    @(static) entered_at: time.Time

    context.allocator = _mem.game.game_mode.arena.allocator

    window_size := engine.get_window_size()
    mouse_position := engine.mouse_get_position()
    frame_stat := engine.get_frame_stat()
    camera := &_mem.game.world_camera
    window_size_f32 := Vector2f32 { f32(window_size.x), f32(window_size.y) }
    mouse_position_f32 := Vector2f32 { f32(mouse_position.x), f32(mouse_position.y) }

    if game_mode_entering() {
        log.debug("[DEBUG] enter")
        entered_at = time.now()
        // engine.asset_load(_mem.game.asset_image_spritesheet, engine.Image_Load_Options { engine.RENDERER_FILTER_NEAREST, engine.RENDERER_CLAMP_TO_EDGE })

        init()
        camera.zoom = CAMERA_INITIAL_ZOOM
        camera.position.xy = auto_cast(BUNNIES_RECT / 2 / camera.zoom)
    }

    if game_mode_running() {
        game_view_size := window_size_f32 // FIXME:
        camera_update_matrix()

        cursor_center := (mouse_position_f32 - game_view_size / 2) / camera.zoom + camera.position.xy

        {
            if engine.mouse_button_is_down(.Left) && .Mod_1 in _mem.game.player_inputs.modifier {
                bunnies_spawn(window_size, cursor_center)
            }
            if engine.mouse_button_is_down(.Right) && .Mod_1 in _mem.game.player_inputs.modifier {
                _mem.game.render_command_sprites.count = 0
            }
            // if _mem.game.player_inputs.aim != { } {
            //     camera.position.xy += cast([2]f32) _mem.game.player_inputs.aim * frame_stat.delta_time / 10
            // }
            // if _mem.game.player_inputs.zoom != { } {
            //     camera.zoom = math.clamp(camera.zoom + (_mem.game.player_inputs.zoom * frame_stat.delta_time / 10), 1, 128)
            // }

            _mem.game.render_command_sprites.data[0].position = cursor_center
        }

        engine.ui_text("sprite count:     %v", _mem.game.render_command_sprites == nil ? 0 : _mem.game.render_command_sprites.count)

        { // Lines
            engine.profiler_zone("lines")
            engine.r_draw_line({ 0, 0, 0 }, { +1, +1, 0 }, { 1, 0, 0, 1 })
            engine.r_draw_line({ 0, 0, 0 }, { +1, -1, 0 }, { 1, 1, 0, 1 })
            engine.r_draw_line({ 0, 0, 0 }, { -1, -1, 0 }, { 0, 1, 0, 1 })
            engine.r_draw_line({ 0, 0, 0 }, { -1, +1, 0 }, { 0, 1, 1, 1 })
        }

        if _mem.game.render_command_sprites != nil {
            engine.profiler_zone("bunnies_move")
            offset := Vector2i32 { 0, 0 }
            rect := Vector4f32 {
                0,                                  0,
                BUNNIES_RECT.x / f32(CAMERA_INITIAL_ZOOM), BUNNIES_RECT.y / f32(CAMERA_INITIAL_ZOOM),
            }
            { // draw rect
                color := Vector4f32 { 1, 1, 1, 1 }
                engine.r_draw_line(v3(camera.view_projection_matrix * v4({ rect.x + 0,      rect.y + 0 })),      v3(camera.view_projection_matrix * v4({ rect.x + rect.z, rect.y + 0 })),      color)
                engine.r_draw_line(v3(camera.view_projection_matrix * v4({ rect.x + rect.z, rect.y + 0 })),      v3(camera.view_projection_matrix * v4({ rect.x + rect.z, rect.y + rect.w })), color)
                engine.r_draw_line(v3(camera.view_projection_matrix * v4({ rect.x + rect.z, rect.y + rect.w })), v3(camera.view_projection_matrix * v4({ rect.x + 0,      rect.y + rect.w })), color)
                engine.r_draw_line(v3(camera.view_projection_matrix * v4({ rect.x + 0,      rect.y + rect.w })), v3(camera.view_projection_matrix * v4({ rect.x + 0,      rect.y + 0 })),      color)
            }
            // FIXME: do this on the GPU
            for i := 0; i < _mem.game.render_command_sprites.count; i += 1 {
                _mem.game.render_command_sprites.data[i].position += bunnies_speed[i] * frame_stat.delta_time / 100

                if (f32(_mem.game.render_command_sprites.data[i].position.x) > rect.z && bunnies_speed[i].x > 0) || (f32(_mem.game.render_command_sprites.data[i].position.x) < 0 && bunnies_speed[i].x < 0) {
                    bunnies_speed[i].x *= -1
                }
                if (f32(_mem.game.render_command_sprites.data[i].position.y) > rect.w && bunnies_speed[i].y > 0) || (f32(_mem.game.render_command_sprites.data[i].position.y) < 0 && bunnies_speed[i].y < 0) {
                    bunnies_speed[i].y *= -1
                }
            }
        }

        if engine.ui_tree_node(fmt.tprintf("bunnies (%v)###bunnies", _mem.game.render_command_sprites.count), { _mem.game.render_command_sprites.count > 10 ? .Selected : .DefaultOpen }) {
            for i := 0; i < _mem.game.render_command_sprites.count; i += 1 {
                engine.ui_text("%v | pos: ", i)
                engine.ui_same_line()
                engine.ui_set_next_item_width(140)
                engine.ui_input_float2(fmt.tprintf("###pos%v", i), cast(^[2]f32) &_mem.game.render_command_sprites.data[i].position)
                engine.ui_same_line()
                engine.ui_text("| color:")
                engine.ui_same_line()
                engine.ui_color_edit4(fmt.tprintf("###color%v", i), cast(^[4]f32) &_mem.game.render_command_sprites.data[i].color, { .NoInputs })
                engine.ui_same_line()
                engine.ui_text("| speed:")
                engine.ui_same_line()
                engine.ui_set_next_item_width(140)
                engine.ui_input_float2(fmt.tprintf("###speed%v", i), cast(^[2]f32) &bunnies_speed[i])
            }
        }

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

v2 :: proc(value: Vector4f32) -> Vector2f32 {
    return { value.x, value.y }
}
v3 :: proc(value: Vector4f32) -> Vector3f32 {
    return { value.x, value.y, 0 }
}
v4 :: proc(value: Vector2f32) -> Vector4f32 {
    return { value.x, value.y, 0, 1 }
}
