package game

import "core:math"
import "core:fmt"
import "core:log"

import "../engine"

game_ui_debug_window :: proc(open: ^bool) {
    @static fps_values: [200]f32
    @static fps_i: int
    @static fps_stat: engine.Statistic
    fps_values[fps_i] = f32(_game._engine.platform.locked_fps)
    fps_i += 1
    if fps_i > len(fps_values) - 1 {
        fps_i = 0
    }
    engine.statistic_begin(&fps_stat)
    for fps in fps_values {
        if fps == 0 {
            continue
        }
        engine.statistic_accumulate(&fps_stat, f64(fps))
    }
    engine.statistic_end(&fps_stat)

    @static frame_duration_values: [200]f32
    @static frame_duration_i: int
    @static frame_duration_stat: engine.Statistic
    frame_duration_values[frame_duration_i] = f32(_game._engine.platform.frame_duration)
    frame_duration_i += 1
    if frame_duration_i > len(frame_duration_values) - 1 {
        frame_duration_i = 0
    }
    engine.statistic_begin(&frame_duration_stat)
    for frame_duration in frame_duration_values {
        if frame_duration == 0 {
            continue
        }
        engine.statistic_accumulate(&frame_duration_stat, f64(frame_duration))
    }
    engine.statistic_end(&frame_duration_stat)

    // fps_overlay := fmt.tprintf("actual_fps %6.0f | min %6.0f| max %6.0f | avg %6.0f", f32(_game._engine.platform.actual_fps), fps_stat.min, fps_stat.max, fps_stat.average)
    // frame_duration_overlay := fmt.tprintf("frame %2.6f | min %2.6f| max %2.6f | avg %2.6f", f32(_game._engine.platform.frame_duration), frame_duration_stat.min, frame_duration_stat.max, frame_duration_stat.average)

    if open^ {
        if engine.ui_window("Debug") {
            engine.ui_set_window_size_vec2({ 600, 800 }, .FirstUseEver)
            engine.ui_set_window_pos_vec2({ 50, 50 }, .FirstUseEver)
            if engine.ui_tree_node_ex_str("Frame", .DefaultOpen) {
                // engine.ui_plot_lines_float_ptr("", &fps_values[0], len(fps_values), 0, fps_overlay, f32(fps_stat.min), f32(fps_stat.max), { 0, 80 })
                // engine.ui_plot_lines_float_ptr("", &frame_duration_values[0], len(frame_duration_values), 0, frame_duration_overlay, f32(frame_duration_stat.min), f32(frame_duration_stat.max), { 0, 80 })
                engine.ui_text("Refresh rate:   %3.0fHz", f32(_game._engine.renderer.refresh_rate))
                engine.ui_text("Actual FPS:     %5.0f", f32(_game._engine.platform.actual_fps))
                engine.ui_text("Frame duration: %2.6fms", _game._engine.platform.frame_duration)
                engine.ui_text("Frame delay:    %2.6fms", _game._engine.platform.frame_delay)
                engine.ui_text("Delta time:     %2.6fms", _game._engine.platform.frame_delay)
                engine.ui_tree_pop()
            }

            if engine.ui_tree_node("Game", .DefaultOpen) {
                engine.ui_slider_float4("hud_rect", transmute(^[4]f32)(&_game.hud_rect), -1000, 1000)
            }
            if engine.ui_tree_node("Render", .DefaultOpen) {
                engine.ui_slider_float4("hud_rect", transmute(^[4]f32)(&_game.hud_rect), -1000, 1000)
                engine.ui_checkbox("z_index: 0", &_game.debug_render_z_index_0)
                engine.ui_checkbox("z_index: 1", &_game.debug_render_z_index_1)
            }

            if engine.ui_tree_node("Renderer", .DefaultOpen) {
                // engine.ui_slider_int("rendering_scale", &_game._engine.renderer.rendering_scale, 0, 16)
                // engine.ui_slider_int2("rendering_size", transmute(^[2]i32)&_game._engine.renderer.rendering_size, 0, 4000)

                if engine.ui_tree_node("camera: world", .DefaultOpen) {
                    camera := &_game._engine.renderer.world_camera
                    engine.ui_slider_float3("position", transmute(^[3]f32)&camera.position, -100, 100)
                    engine.ui_slider_float("rotation", &camera.rotation, 0, math.TAU)
                    engine.ui_slider_float("zoom", &camera.zoom, 0.2, 20, "%.3f", .AlwaysClamp)
                    if engine.ui_button("Reset zoom") {
                        camera.zoom = _game._engine.renderer.ideal_scale
                    }
                    if engine.ui_tree_node("projection_matrix", .DefaultOpen) {
                        engine.ui_slider_float4("projection_matrix[0]", transmute(^[4]f32)(&camera.projection_matrix[0]), -1, 1)
                        engine.ui_slider_float4("projection_matrix[1]", transmute(^[4]f32)(&camera.projection_matrix[1]), -1, 1)
                        engine.ui_slider_float4("projection_matrix[2]", transmute(^[4]f32)(&camera.projection_matrix[2]), -1, 1)
                        engine.ui_slider_float4("projection_matrix[3]", transmute(^[4]f32)(&camera.projection_matrix[3]), -1, 1)
                    }
                    if engine.ui_tree_node("view_matrix", .DefaultOpen) {
                        engine.ui_slider_float4("view_matrix[0]", transmute(^[4]f32)(&camera.view_matrix[0]), -1, 1)
                        engine.ui_slider_float4("view_matrix[1]", transmute(^[4]f32)(&camera.view_matrix[1]), -1, 1)
                        engine.ui_slider_float4("view_matrix[2]", transmute(^[4]f32)(&camera.view_matrix[2]), -1, 1)
                        engine.ui_slider_float4("view_matrix[3]", transmute(^[4]f32)(&camera.view_matrix[3]), -1, 1)
                    }
                    if engine.ui_tree_node("projection_view_matrix", .DefaultOpen) {
                        engine.ui_slider_float4("projection_view_matrix[0]", transmute(^[4]f32)(&camera.projection_view_matrix[0]), -1, 1, "%.3f", .NoInput)
                        engine.ui_slider_float4("projection_view_matrix[1]", transmute(^[4]f32)(&camera.projection_view_matrix[1]), -1, 1, "%.3f", .NoInput)
                        engine.ui_slider_float4("projection_view_matrix[2]", transmute(^[4]f32)(&camera.projection_view_matrix[2]), -1, 1, "%.3f", .NoInput)
                        engine.ui_slider_float4("projection_view_matrix[3]", transmute(^[4]f32)(&camera.projection_view_matrix[3]), -1, 1, "%.3f", .NoInput)
                    }
                }


                if engine.ui_tree_node("camera: ui", .DefaultOpen) {
                    camera := &_game._engine.renderer.ui_camera
                    engine.ui_slider_float3("position", transmute(^[3]f32)&camera.position, -100, 100)
                    engine.ui_slider_float("rotation", &camera.rotation, 0, math.TAU)
                    engine.ui_slider_float("zoom", &camera.zoom, 0.2, 20, "%.3f", .AlwaysClamp)
                    if engine.ui_button("Reset zoom") {
                        camera.zoom = _game._engine.renderer.ideal_scale
                    }
                    if engine.ui_tree_node("projection_matrix", .DefaultOpen) {
                        engine.ui_slider_float4("projection_matrix[0]", transmute(^[4]f32)(&camera.projection_matrix[0]), -1, 1)
                        engine.ui_slider_float4("projection_matrix[1]", transmute(^[4]f32)(&camera.projection_matrix[1]), -1, 1)
                        engine.ui_slider_float4("projection_matrix[2]", transmute(^[4]f32)(&camera.projection_matrix[2]), -1, 1)
                        engine.ui_slider_float4("projection_matrix[3]", transmute(^[4]f32)(&camera.projection_matrix[3]), -1, 1)
                    }
                    if engine.ui_tree_node("view_matrix", .DefaultOpen) {
                        engine.ui_slider_float4("view_matrix[0]", transmute(^[4]f32)(&camera.view_matrix[0]), -1, 1)
                        engine.ui_slider_float4("view_matrix[1]", transmute(^[4]f32)(&camera.view_matrix[1]), -1, 1)
                        engine.ui_slider_float4("view_matrix[2]", transmute(^[4]f32)(&camera.view_matrix[2]), -1, 1)
                        engine.ui_slider_float4("view_matrix[3]", transmute(^[4]f32)(&camera.view_matrix[3]), -1, 1)
                    }
                    if engine.ui_tree_node("projection_view_matrix", .DefaultOpen) {
                        engine.ui_slider_float4("projection_view_matrix[0]", transmute(^[4]f32)(&camera.projection_view_matrix[0]), -1, 1, "%.3f", .NoInput)
                        engine.ui_slider_float4("projection_view_matrix[1]", transmute(^[4]f32)(&camera.projection_view_matrix[1]), -1, 1, "%.3f", .NoInput)
                        engine.ui_slider_float4("projection_view_matrix[2]", transmute(^[4]f32)(&camera.projection_view_matrix[2]), -1, 1, "%.3f", .NoInput)
                        engine.ui_slider_float4("projection_view_matrix[3]", transmute(^[4]f32)(&camera.projection_view_matrix[3]), -1, 1, "%.3f", .NoInput)
                    }
                }
            }
        }
    }
}

game_ui_debug_windows :: proc() {
    // if engine.renderer_is_enabled() == false do return
    // if _game._engine.renderer.rendering_size == 0 do return

    // if engine.HOT_RELOAD_CODE && time.diff(_game._engine.debug.last_reload, time.now()) < time.Millisecond * 1000 {
    //     if engine.ui_window("Code reloaded", { _game._engine.platform.window_size.x - 190, _game._engine.platform.window_size.y - 80, 170, 60 }, { .NO_CLOSE, .NO_RESIZE }) {
    //         engine.ui_layout_row({ -1 }, 0)
    //         engine.ui_label(fmt.tprintf("Reloaded at: %v", time.time_to_unix(_game._engine.debug.last_reload)))
    //     }
    // }

    // if _game.debug_ui_window_info {
    //     if engine.ui_window("Debug", { 0, 0, 500, _game._engine.platform.window_size.y }, { .NO_CLOSE }) {
    //         if .ACTIVE in engine.ui_header("Memory", { .EXPANDED }) {
    //             engine.ui_layout_row({ 50, 50, 50, 50 }, 0)
    //             if .SUBMIT in engine.ui_button("Save 1") {
    //                 _game._engine.debug.save_memory = 1
    //             }
    //             if .SUBMIT in engine.ui_button("Save 2") {
    //                 _game._engine.debug.save_memory = 2
    //             }
    //             if .SUBMIT in engine.ui_button("Save 3") {
    //                 _game._engine.debug.save_memory = 3
    //             }
    //             if .SUBMIT in engine.ui_button("Save 4") {
    //                 _game._engine.debug.save_memory = 4
    //             }
    //             engine.ui_layout_row({ 50, 50, 50, 50 }, 0)
    //             if .SUBMIT in engine.ui_button("Load 1") {
    //                 _game._engine.debug.load_memory = 1
    //             }
    //             if .SUBMIT in engine.ui_button("Load 2") {
    //                 _game._engine.debug.load_memory = 2
    //             }
    //             if .SUBMIT in engine.ui_button("Load 3") {
    //                 _game._engine.debug.load_memory = 3
    //             }
    //             if .SUBMIT in engine.ui_button("Load 4") {
    //                 _game._engine.debug.load_memory = 4
    //             }

    //             {
    //                 engine.ui_layout_row({ 100, -1 }, 0)
    //                 engine.ui_label("engine")
    //                 engine.ui_label(engine.format_arena_usage(&_game.engine_arena))
    //                 engine.ui_layout_row({ -1 }, 0)
    //                 engine.ui_progress_bar(f32(_game.engine_arena.offset) / f32(len(_game.engine_arena.data)), 5)
    //             }
    //             {
    //                 engine.ui_layout_row({ 100, -1 }, 0)
    //                 engine.ui_label("game")
    //                 engine.ui_label(engine.format_arena_usage(&_game.game_arena))
    //                 engine.ui_layout_row({ -1 }, 0)
    //                 engine.ui_progress_bar(f32(_game.game_arena.offset) / f32(len(_game.game_arena.data)), 5)
    //             }
    //             {
    //                 arena := cast(^mem.Arena)_game.game_mode.allocator.data
    //                 engine.ui_layout_row({ 100, -1 }, 0)
    //                 engine.ui_label("game_mode")
    //                 engine.ui_label(engine.format_arena_usage(arena))
    //                 engine.ui_layout_row({ -1 }, 0)
    //                 engine.ui_progress_bar(f32(arena.offset) / f32(len(arena.data)), 5)
    //             }
    //         }

    //         if .ACTIVE in engine.ui_header("Config", { .EXPANDED }) {
    //             engine.ui_layout_row({ 170, -1 }, 0)
    //             engine.ui_label("Last code reload")
    //             engine.ui_label(fmt.tprintf("%v", time.time_to_unix(_game._engine.debug.last_reload)))
    //             engine.ui_label("ODIN_DEBUG")
    //             engine.ui_label(fmt.tprintf("%v", ODIN_DEBUG))
    //             engine.ui_label("RENDERER_DEBUG")
    //             engine.ui_label(fmt.tprintf("%v", engine.RENDERER_DEBUG))
    //             engine.ui_label("PROFILER")
    //             engine.ui_label(fmt.tprintf("%v", engine.PROFILER))
    //             engine.ui_label("HOT_RELOAD_CODE")
    //             engine.ui_label(fmt.tprintf("%v", engine.HOT_RELOAD_CODE))
    //             engine.ui_label("HOT_RELOAD_ASSETS")
    //             engine.ui_label(fmt.tprintf("%v", engine.HOT_RELOAD_ASSETS))
    //             engine.ui_label("ASSETS_PATH")
    //             engine.ui_label(fmt.tprintf("%v", engine.ASSETS_PATH))
    //         }

    //         if .ACTIVE in engine.ui_header("Game", { .EXPANDED }) {
    //             engine.ui_layout_row({ 170, -1 }, 0)
    //             engine.ui_label("window_size")
    //             engine.ui_label(fmt.tprintf("%v", _game._engine.platform.window_size))
    //             engine.ui_label("FPS")
    //             engine.ui_label(fmt.tprintf("%v", 1 / _game._engine.platform.delta_time))
    //             engine.ui_label("Game_Mode")
    //             engine.ui_label(fmt.tprintf("%v", _game.game_mode.current))
    //             engine.ui_label("draw_letterbox")
    //             engine.ui_label(fmt.tprintf("%v", _game.draw_letterbox))
    //             // engine.ui_label("mouse_screen_position")
    //             // engine.ui_label(fmt.tprintf("%v", _game.mouse_screen_position))
    //             // engine.ui_label("mouse_grid_position")
    //             // engine.ui_label(fmt.tprintf("%v", _game.mouse_grid_position))
    //             // engine.ui_label("party")
    //             // engine.ui_label(fmt.tprintf("%v", _game.party))
    //         }

    //         if .ACTIVE in engine.ui_header("Debug", { .EXPANDED }) {
    //             engine.ui_layout_row({ 170, -1 })
    //             engine.ui_label("debug_ui_window_info")
    //             engine.ui_label(fmt.tprintf("%v", _game.debug_ui_window_info))
    //             engine.ui_label("debug_ui_window_entities")
    //             engine.ui_label(fmt.tprintf("%v", _game.debug_ui_window_entities))
    //             engine.ui_label("debug_ui_no_tiles")
    //             engine.ui_label(fmt.tprintf("%v", _game.debug_ui_no_tiles))
    //             engine.ui_label("debug_ui_room_only")
    //             engine.ui_label(fmt.tprintf("%v", _game.debug_ui_room_only))
    //             engine.ui_label("debug_ui_entity")
    //             engine.ui_label(fmt.tprintf("%v", _game.debug_ui_entity))
    //             engine.ui_label("debug_ui_show_tiles")
    //             engine.ui_label(fmt.tprintf("%v", _game.debug_ui_show_tiles))
    //             engine.ui_label("debug_show_bounding_boxes")
    //             engine.ui_label(fmt.tprintf("%v", _game.debug_show_bounding_boxes))
    //             engine.ui_label("debug_entity_under_mouse")
    //             engine.ui_label(fmt.tprintf("%v", _game.debug_entity_under_mouse))
    //         }

    //         if .ACTIVE in engine.ui_header("Assets", { }) {
    //             engine.ui_layout_row({ 30, 70, 50, 230, 40, 40 })
    //             engine.ui_label("id")
    //             engine.ui_label("state")
    //             engine.ui_label("type")
    //             engine.ui_label("filename")
    //             engine.ui_label(" ")
    //             engine.ui_label(" ")

    //             for i := 0; i < _game._engine.assets.assets_count; i += 1 {
    //                 asset := &_game._engine.assets.assets[i]
    //                 engine.ui_label(fmt.tprintf("%v", asset.id))
    //                 engine.ui_label(fmt.tprintf("%v", asset.state))
    //                 engine.ui_label(fmt.tprintf("%v", asset.type))
    //                 engine.ui_label(fmt.tprintf("%v", asset.file_name))
    //                 engine.ui_push_id_uintptr(uintptr(asset.id))
    //                 if .SUBMIT in engine.ui_button("Load") {
    //                     engine.asset_load(asset.id)
    //                 }
    //                 if .SUBMIT in engine.ui_button("Unload") {
    //                     engine.asset_unload(asset.id)
    //                 }
    //                 engine.ui_pop_id()
    //             }
    //         }

    //         if .ACTIVE in engine.ui_header("Platform", { .EXPANDED }) {
    //             engine.ui_layout_row({ 170, -1 })
    //             engine.ui_label("mouse_position")
    //             engine.ui_label(fmt.tprintf("%v", _game._engine.platform.mouse_position))

    //             if .ACTIVE in engine.ui_treenode("Inputs", { }) {
    //                 engine.ui_layout_row({ 50, 50, -1 }, 0)
    //                 engine.ui_label("axis")
    //                 engine.ui_label("x")
    //                 engine.ui_label("y")
    //                 {
    //                     axis := _game.player_inputs.move
    //                     engine.ui_label("move")
    //                     engine.ui_label(fmt.tprintf("%v", axis.x))
    //                     engine.ui_label(fmt.tprintf("%v", axis.y))
    //                 }

    //                 engine.ui_layout_row({ 50, 50, 50, 50, 50 }, 0)
    //                 engine.ui_label("key")
    //                 engine.ui_label("down")
    //                 engine.ui_label("up")
    //                 engine.ui_label("pressed")
    //                 engine.ui_label("released")
    //                 {
    //                     using _game.player_inputs.confirm
    //                     engine.ui_label("confirm")
    //                     engine.ui_label(fmt.tprintf("%v", down))
    //                     engine.ui_label(fmt.tprintf("%v", !down))
    //                     engine.ui_label(fmt.tprintf("%v", pressed))
    //                     engine.ui_label(fmt.tprintf("%v", released))
    //                 }
    //                 {
    //                     using _game.player_inputs.cancel
    //                     engine.ui_label("cancel")
    //                     engine.ui_label(fmt.tprintf("%v", down))
    //                     engine.ui_label(fmt.tprintf("%v", !down))
    //                     engine.ui_label(fmt.tprintf("%v", pressed))
    //                     engine.ui_label(fmt.tprintf("%v", released))
    //                 }
    //             }

    //             if .ACTIVE in engine.ui_treenode("Controllers", { }) {
    //                 keys := [] engine.GameControllerButton {
    //                     .A,
    //                     .B,
    //                     .X,
    //                     .Y,
    //                     .BACK,
    //                     // .GUIDE,
    //                     .START,
    //                     .LEFTSTICK,
    //                     .RIGHTSTICK,
    //                     .LEFTSHOULDER,
    //                     .RIGHTSHOULDER,
    //                     .DPAD_UP,
    //                     .DPAD_DOWN,
    //                     .DPAD_LEFT,
    //                     .DPAD_RIGHT,
    //                     // .MISC1,
    //                     // .PADDLE1,
    //                     // .PADDLE2,
    //                     // .PADDLE3,
    //                     // .PADDLE4,
    //                     // .TOUCHPAD,
    //                     // .MAX,
    //                 }
    //                 axes := [] engine.GameControllerAxis {
    //                     // .INVALID = -1,
    //                     .LEFTX,
    //                     .LEFTY,
    //                     .RIGHTX,
    //                     .RIGHTY,
    //                     .TRIGGERLEFT,
    //                     .TRIGGERRIGHT,
    //                     // .MAX,
    //                 }

    //                 for joystick_id, controller_state in _game._engine.platform.controllers {
    //                     controller_name := engine.platform_get_controller_name(controller_state.controller)
    //                     if .ACTIVE in engine.ui_treenode(fmt.tprintf("%v (%v)", controller_name, joystick_id), { .EXPANDED }) {
    //                         engine.ui_layout_row({ 90, 50, 50, 50, 50 })
    //                         engine.ui_label("key")
    //                         engine.ui_label("down")
    //                         engine.ui_label("up")
    //                         engine.ui_label("pressed")
    //                         engine.ui_label("released")
    //                         for key in keys {
    //                             engine.ui_label(fmt.tprintf("%v", key))
    //                             engine.ui_label(fmt.tprintf("%v", controller_state.buttons[key].down))
    //                             engine.ui_label(fmt.tprintf("%v", !controller_state.buttons[key].down))
    //                             engine.ui_label(fmt.tprintf("%v", controller_state.buttons[key].pressed))
    //                             engine.ui_label(fmt.tprintf("%v", controller_state.buttons[key].released))
    //                         }

    //                         engine.ui_layout_row({ 90, 50 })
    //                         engine.ui_label("axis")
    //                         engine.ui_label("value")
    //                         for axis in axes {
    //                             engine.ui_label(fmt.tprintf("%v", axis))
    //                             engine.ui_label(fmt.tprintf("%v", controller_state.axes[axis].value))
    //                         }
    //                     }
    //                 }
    //             }

    //             if .ACTIVE in engine.ui_treenode("Keyboard", { }) {
    //                 keys := [] engine.Scancode {
    //                     .UP,
    //                     .DOWN,
    //                     .LEFT,
    //                     .RIGHT,
    //                 }
    //                 engine.ui_layout_row({ 50, 50, 50, 50, 50 }, 0)
    //                 engine.ui_label("key")
    //                 engine.ui_label("down")
    //                 engine.ui_label("up")
    //                 engine.ui_label("pressed")
    //                 engine.ui_label("released")
    //                 for key in keys {
    //                     engine.ui_label(fmt.tprintf("%v", key))
    //                     engine.ui_label(fmt.tprintf("%v", _game._engine.platform.keys[key].down))
    //                     engine.ui_label(fmt.tprintf("%v", !_game._engine.platform.keys[key].down))
    //                     engine.ui_label(fmt.tprintf("%v", _game._engine.platform.keys[key].pressed))
    //                     engine.ui_label(fmt.tprintf("%v", _game._engine.platform.keys[key].released))
    //                 }
    //             }
    //         }

    //         if .ACTIVE in engine.ui_header("Renderer", { .EXPANDED }) {
    //             engine.ui_layout_row({ 170, -1 }, 0)
    //             engine.ui_label("pixel_density")
    //             engine.ui_label(fmt.tprintf("%v", _game._engine.renderer.pixel_density))
    //             engine.ui_label("rendering_size")
    //             engine.ui_label(fmt.tprintf("%v", _game._engine.renderer.rendering_size))
    //             engine.ui_label("rendering_scale")
    //             engine.ui_label(fmt.tprintf("%v", _game._engine.renderer.rendering_scale))
    //             engine.ui_label("rendering_offset")
    //             engine.ui_label(fmt.tprintf("%v", _game._engine.renderer.rendering_offset))
    //             engine.ui_layout_row({ 50, 50, 50, 50, 50, 50, 50, 50 }, 0)
    //             scales := []i32 { 1, 2, 3, 4, 5, 6 }
    //             for scale in scales {
    //                 if .SUBMIT in engine.ui_button(fmt.tprintf("x%i", scale)) {
    //                     log.debugf("Set rendering_scale: %v", scale)
    //                     _game._engine.renderer.rendering_scale = scale
    //                     update_rendering_offset()
    //                 }
    //             }
    //             engine.ui_layout_row({ 170, -1 }, 0)
    //             // engine.ui_label("textures")
    //             // engine.ui_label(fmt.tprintf("%v", len(_game._engine.renderer.textures)))
    //         }
    //     }
    // }
}

game_ui_entities_windows :: proc () {
    if _game.debug_ui_window_entities {
        if engine.ui_window("Entities") {
            engine.ui_set_window_size_vec2({ 600, 800 }, .FirstUseEver)
            engine.ui_set_window_pos_vec2({ 50, 50 }, .FirstUseEver)

            engine.ui_text(fmt.tprintf("entities: %v", len(_game.entities.entities)))
            engine.ui_checkbox("Hide tiles", &_game.debug_ui_no_tiles)

            for entity in _game.entities.entities {
                component_flag, has_flag := _game.entities.components_flag[entity]
                if _game.debug_ui_no_tiles && has_flag && .Tile in component_flag.value {
                    continue
                }

                engine.ui_text(fmt.tprintf("%v", entity_format(entity, &_game.entities)))
                engine.ui_same_line()
                engine.ui_push_id(i32(entity))
                if engine.ui_button("Inspect") {
                    if _game.debug_ui_entity == entity {
                        _game.debug_ui_entity = 0
                    } else {
                        _game.debug_ui_entity = entity
                    }
                }
                engine.ui_pop_id()
            }
        }
    }
}

game_ui_anim_window :: proc(open: ^bool) {
    @static _anim_progress_t: f32
    @static _anim_progress_sign: f32 = 1

    if open^ {
        if _anim_progress_t > 1 {
            _anim_progress_sign = -1
        }
        if _anim_progress_t < 0 {
            _anim_progress_sign = +1
        }
        _anim_progress_t += _game._engine.platform.delta_time * _anim_progress_sign / 1000

        if engine.ui_window("Animations") {
            engine.ui_set_window_size_vec2({ 1200, 150 }, .FirstUseEver)
            engine.ui_set_window_pos_vec2({ 700, 50 }, .FirstUseEver)
            engine.ui_progress_bar(_anim_progress_t, { 0, 100 })
        }
    }
}

game_ui_entity_window :: proc() {
    entity := _game.debug_ui_entity
    if entity != Entity(0) {
        if engine.ui_window("Entity") {
            engine.ui_set_window_size_vec2({ 300, 300 }, .FirstUseEver)
            engine.ui_set_window_pos_vec2({ 500, 500 }, .FirstUseEver)

            engine.ui_text("id:")
            engine.ui_same_line(0, 10)
            engine.ui_text("%v", entity)

            component_name, has_name := _game.entities.components_name[entity]
            if has_name {
                if engine.ui_collapsing_header("Component_Name", engine.Tree_Node_Flags(.DefaultOpen)) {
                    engine.ui_text("name:")
                    engine.ui_same_line(0, 10)
                    engine.ui_text(component_name.name)
                }
            }

            component_transform, has_transform := _game.entities.components_transform[entity]
            if has_transform {
                rect_position := component_transform.world_position * component_transform.size
                // engine.append_debug_rect({ rect_position.x, rect_position.y, component_transform.size.x, component_transform.size.y }, { 255, 0, 0, 100 })
                if engine.ui_collapsing_header("Component_Transform", engine.Tree_Node_Flags(.DefaultOpen)) {
                    engine.ui_text("grid_position:")
                    engine.ui_same_line(0, 10)
                    engine.ui_text("%v", component_transform.grid_position)

                    engine.ui_text("world_position:")
                    engine.ui_same_line(0, 10)
                    engine.ui_text("%v", component_transform.world_position)

                    engine.ui_text("size:")
                    engine.ui_same_line(0, 10)
                    engine.ui_text("%v", component_transform.size)
                }
            }

            component_rendering, has_rendering := &_game.entities.components_rendering[entity]
            if has_rendering {
                if engine.ui_collapsing_header("Component_Rendering", engine.Tree_Node_Flags(.DefaultOpen)) {
                    engine.ui_text("visible:")
                    engine.ui_same_line(0, 10)
                    if engine.ui_button(component_rendering.visible ? "true" : "false") {
                        component_rendering.visible = !component_rendering.visible
                    }

                    engine.ui_text("texture_asset:")
                    engine.ui_same_line(0, 10)
                    engine.ui_text("%v", component_rendering.texture_asset)

                    engine.ui_text("texture_position:")
                    engine.ui_same_line(0, 10)
                    engine.ui_text("%v", component_rendering.texture_position)

                    engine.ui_text("texture_size:")
                    engine.ui_same_line(0, 10)
                    engine.ui_text("%v", component_rendering.texture_size)

                    engine.ui_text("flip:")
                    engine.ui_same_line(0, 10)
                    engine.ui_text("%s", component_rendering.flip)

                    // asset := _game._engine.assets.assets[component_rendering.texture_asset]
                    // asset_info, asset_ok := asset.info.(engine.Asset_Info_Image)
                    texture_position, texture_size, pixel_size := texture_position_and_size(_game._engine.renderer.texture_0, component_rendering.texture_position, component_rendering.texture_size)
                    engine.ui_image(
                        auto_cast(uintptr(_game._engine.renderer.texture_0.renderer_id)),
                        { 80, 80 },
                        { texture_position.x, texture_position.y },
                        { texture_position.x + texture_size.x, texture_position.y + texture_size.y },
                    )
                }
            }

            component_z_index, has_z_index := _game.entities.components_z_index[entity]
            if has_z_index {
                if engine.ui_collapsing_header("Component_Z_Index", engine.Tree_Node_Flags(.DefaultOpen)) {
                    engine.ui_text("z_index:")
                    engine.ui_same_line(0, 10)
                    engine.ui_text("%v", component_z_index.z_index)
                }
            }

            component_animation, has_animation := _game.entities.components_animation[entity]
            if has_animation {
                if engine.ui_collapsing_header("Component_Animation", engine.Tree_Node_Flags(.DefaultOpen)) {
                    engine.ui_text("current_frame:")
                    engine.ui_same_line(0, 10)
                    engine.ui_text("%v", component_animation.current_frame)
                }
            }

            component_flag, has_flag := _game.entities.components_flag[entity]
            if has_flag {
                if engine.ui_collapsing_header("Component_Flag", engine.Tree_Node_Flags(.DefaultOpen)) {
                    engine.ui_text("value:")
                    engine.ui_same_line(0, 10)
                    engine.ui_text("%v", component_flag.value)
                }
            }

            component_meta, has_meta := _game.entities.components_meta[entity]
            if has_meta {
                if engine.ui_collapsing_header("Meta", engine.Tree_Node_Flags(.DefaultOpen)) {
                    for key, value in component_meta.value {
                        engine.ui_text("%v", key)
                        engine.ui_same_line(0, 10)
                        engine.ui_text("%v", value)
                    }
                }
            }
        }
    }
}
