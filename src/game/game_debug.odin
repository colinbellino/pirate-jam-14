package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:path/slashpath"
import "core:strings"
import "core:time"
import stb_image "vendor:stb/image"
import "../engine"

@(private="file") bunnies_speed:  [MAX_SPRITES]Vector2f32
BUNNIES_RECT :: Vector2f32 { 1000, 1000 }

bunnies_spawn :: proc(world_position: Vector2f32 = { 0, 0 }) {
    engine.profiler_zone("bunnies_spawn")
    for i := 0; i < 100; i += 1 {
        asset_info, asset_info_ok := engine.asset_get_asset_info_image(_mem.game.asset_image_units)
        texture_position, texture_size, pixel_size := engine.texture_position_and_size(asset_info.size, grid_position(4, 1), GRID_SIZE_V2, TEXTURE_PADDING)
        if _mem.game.render_command_sprites.count < len(_mem.game.render_command_sprites.data) {

            _mem.game.render_command_sprites.data[_mem.game.render_command_sprites.count] = {}
            _mem.game.render_command_sprites.data[_mem.game.render_command_sprites.count].position = world_position
            _mem.game.render_command_sprites.data[_mem.game.render_command_sprites.count].scale = { 2, 2 }
            _mem.game.render_command_sprites.data[_mem.game.render_command_sprites.count].texture_position = texture_position
            _mem.game.render_command_sprites.data[_mem.game.render_command_sprites.count].texture_size = texture_size
            _mem.game.render_command_sprites.data[_mem.game.render_command_sprites.count].texture_index = 1
            _mem.game.render_command_sprites.data[_mem.game.render_command_sprites.count].palette = 1
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

        mem.zero(&_mem.game.render_command_sprites.data, len(_mem.game.render_command_sprites.data))
        _mem.game.render_command_sprites.count = 0

        camera.zoom = CAMERA_ZOOM_INITIAL
        camera.position.xy = auto_cast(BUNNIES_RECT / 2 / camera.zoom)
    }

    if game_mode_running() {
        camera_update_matrix()

        spawn_position := _mem.game.mouse_world_position / (camera.zoom / 2)

        if engine.ui_is_any_window_hovered() == false && engine.mouse_button_is_down(.Left) {
            bunnies_spawn(spawn_position)
        }
        if engine.ui_is_any_window_hovered() == false && engine.mouse_button_is_down(.Right) {
            _mem.game.render_command_sprites.count = 0
        }
        _mem.game.render_command_sprites.data[0].position = spawn_position

        engine.ui_text("sprite count:     %v", _mem.game.render_command_sprites == nil ? 0 : _mem.game.render_command_sprites.count)

        { // Lines
            engine.profiler_zone("lines")
            engine.r_draw_line(v4({ 0, 0 }), v4({ +1, +1 }), { 1, 0, 0, 1 })
            engine.r_draw_line(v4({ 0, 0 }), v4({ +1, -1 }), { 1, 1, 0, 1 })
            engine.r_draw_line(v4({ 0, 0 }), v4({ -1, -1 }), { 0, 1, 0, 1 })
            engine.r_draw_line(v4({ 0, 0 }), v4({ -1, +1 }), { 0, 1, 1, 1 })
        }

        {
            engine.profiler_zone("bunnies_move")
            offset := Vector2i32 { 0, 0 }
            rect := Vector4f32 {
                0,                                  0,
                BUNNIES_RECT.x / f32(CAMERA_ZOOM_INITIAL), BUNNIES_RECT.y / f32(CAMERA_ZOOM_INITIAL),
            }
            engine.r_draw_rect(rect, { 1, 1, 1, 1 }, camera.view_projection_matrix)
            for i := 0; i < _mem.game.render_command_sprites.count; i += 1 {
                _mem.game.render_command_sprites.data[i].position += bunnies_speed[i] * frame_stat.delta_time / 100

                if (f32(_mem.game.render_command_sprites.data[i].position.x) > rect.z * 2 && bunnies_speed[i].x > 0) || (f32(_mem.game.render_command_sprites.data[i].position.x) < 0 && bunnies_speed[i].x < 0) {
                    bunnies_speed[i].x *= -1
                }
                if (f32(_mem.game.render_command_sprites.data[i].position.y) > rect.w * 2 && bunnies_speed[i].y > 0) || (f32(_mem.game.render_command_sprites.data[i].position.y) < 0 && bunnies_speed[i].y < 0) {
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
