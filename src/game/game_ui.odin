package game

import "core:fmt"
import "core:log"
import "core:time"

import "../engine"

draw_debug_windows :: proc() {
    if _game._engine.renderer.rendering_size == 0 {
        return
    }

    if engine.HOT_RELOAD_CODE && time.diff(_game._engine.debug.last_reload, time.now()) < time.Millisecond * 1000 {
        if engine.ui_window("Code reloaded", { _game.window_size.x - 190, _game.window_size.y - 80, 170, 60 }, { .NO_CLOSE, .NO_RESIZE }) {
            engine.ui_layout_row({ -1 }, 0)
            engine.ui_label(fmt.tprintf("Reloaded at: %v", time.time_to_unix(_game._engine.debug.last_reload)))
        }
    }

    if _game.debug_ui_window_info {
        if engine.ui_window("Debug", { 0, 0, 500, _game.window_size.y }, { .NO_CLOSE }) {
            if .ACTIVE in engine.ui_header("Memory", { }) {
                engine.ui_layout_row({ 50, 50, 50, 50 }, 0)
                if .SUBMIT in engine.ui_button("Save 1") {
                    _game._engine.debug.save_memory = 1
                }
                if .SUBMIT in engine.ui_button("Save 2") {
                    _game._engine.debug.save_memory = 2
                }
                if .SUBMIT in engine.ui_button("Save 3") {
                    _game._engine.debug.save_memory = 3
                }
                if .SUBMIT in engine.ui_button("Save 4") {
                    _game._engine.debug.save_memory = 4
                }
                engine.ui_layout_row({ 50, 50, 50, 50 }, 0)
                if .SUBMIT in engine.ui_button("Load 1") {
                    _game._engine.debug.load_memory = 1
                }
                if .SUBMIT in engine.ui_button("Load 2") {
                    _game._engine.debug.load_memory = 2
                }
                if .SUBMIT in engine.ui_button("Load 3") {
                    _game._engine.debug.load_memory = 3
                }
                if .SUBMIT in engine.ui_button("Load 4") {
                    _game._engine.debug.load_memory = 4
                }
            }

            if .ACTIVE in engine.ui_header("Config", { .EXPANDED }) {
                engine.ui_layout_row({ 170, -1 }, 0)
                engine.ui_label("Last code reload")
                engine.ui_label(fmt.tprintf("%v", time.time_to_unix(_game._engine.debug.last_reload)))
                engine.ui_label("TRACY_ENABLE")
                engine.ui_label(fmt.tprintf("%v", engine.TRACY_ENABLE))
                engine.ui_label("HOT_RELOAD_CODE")
                engine.ui_label(fmt.tprintf("%v", engine.HOT_RELOAD_CODE))
                engine.ui_label("HOT_RELOAD_ASSETS")
                engine.ui_label(fmt.tprintf("%v", engine.HOT_RELOAD_ASSETS))
                engine.ui_label("ASSETS_PATH")
                engine.ui_label(fmt.tprintf("%v", engine.ASSETS_PATH))
            }

            if .ACTIVE in engine.ui_header("Game", { .EXPANDED }) {
                engine.ui_layout_row({ 170, -1 }, 0)
                engine.ui_label("window_size")
                engine.ui_label(fmt.tprintf("%v", _game.window_size))
                engine.ui_label("FPS")
                engine.ui_label(fmt.tprintf("%v", u32(1 / _game._engine.platform.prev_frame_duration)))
                engine.ui_label("Game_Mode")
                engine.ui_label(fmt.tprintf("%v", _game.game_mode))
                // engine.ui_label("draw_letterbox")
                // engine.ui_label(fmt.tprintf("%v", _game.draw_letterbox))
                // engine.ui_label("mouse_screen_position")
                // engine.ui_label(fmt.tprintf("%v", _game.mouse_screen_position))
                // engine.ui_label("mouse_grid_position")
                // engine.ui_label(fmt.tprintf("%v", _game.mouse_grid_position))
                // engine.ui_label("current_room_index")
                // engine.ui_label(fmt.tprintf("%v", _game.current_room_index))
                // engine.ui_label("party")
                // engine.ui_label(fmt.tprintf("%v", _game.party))
            }

            if .ACTIVE in engine.ui_header("Debug", { .EXPANDED }) {
                engine.ui_layout_row({ 170, -1 })
                engine.ui_label("debug_ui_window_info")
                engine.ui_label(fmt.tprintf("%v", _game.debug_ui_window_info))
                engine.ui_label("debug_ui_window_entities")
                engine.ui_label(fmt.tprintf("%v", _game.debug_ui_window_entities))
                engine.ui_label("debug_ui_no_tiles")
                engine.ui_label(fmt.tprintf("%v", _game.debug_ui_no_tiles))
                engine.ui_label("debug_ui_room_only")
                engine.ui_label(fmt.tprintf("%v", _game.debug_ui_room_only))
                engine.ui_label("debug_ui_entity")
                engine.ui_label(fmt.tprintf("%v", _game.debug_ui_entity))
                engine.ui_label("debug_ui_show_tiles")
                engine.ui_label(fmt.tprintf("%v", _game.debug_ui_show_tiles))
                engine.ui_label("debug_show_bounding_boxes")
                engine.ui_label(fmt.tprintf("%v", _game.debug_show_bounding_boxes))
                engine.ui_label("debug_entity_under_mouse")
                engine.ui_label(fmt.tprintf("%v", _game.debug_entity_under_mouse))
            }

            if .ACTIVE in engine.ui_header("Assets", { }) {
                engine.ui_layout_row({ 30, 70, 50, 230, 40, 40 })
                engine.ui_label("id")
                engine.ui_label("state")
                engine.ui_label("type")
                engine.ui_label("filename")
                engine.ui_label(" ")
                engine.ui_label(" ")

                for i := 0; i < _game._engine.assets.assets_count; i += 1 {
                    asset := &_game._engine.assets.assets[i]
                    engine.ui_label(fmt.tprintf("%v", asset.id))
                    engine.ui_label(fmt.tprintf("%v", asset.state))
                    engine.ui_label(fmt.tprintf("%v", asset.type))
                    engine.ui_label(fmt.tprintf("%v", asset.file_name))
                    engine.ui_push_id_uintptr(uintptr(asset.id))
                    if .SUBMIT in engine.ui_button("Load") {
                        engine.asset_load(asset.id)
                    }
                    if .SUBMIT in engine.ui_button("Unload") {
                        engine.asset_unload(asset.id)
                    }
                    engine.ui_pop_id()
                }
            }

            if .ACTIVE in engine.ui_header("Platform", { .EXPANDED }) {
                engine.ui_layout_row({ 170, -1 })
                engine.ui_label("mouse_position")
                engine.ui_label(fmt.tprintf("%v", _game._engine.platform.mouse_position))
                engine.ui_label("unlock_framerate")
                engine.ui_label(fmt.tprintf("%v", _game._engine.platform.unlock_framerate))

                if .ACTIVE in engine.ui_treenode("Inputs", { }) {
                    engine.ui_layout_row({ 50, 50, -1 }, 0)
                    engine.ui_label("axis")
                    engine.ui_label("x")
                    engine.ui_label("y")
                    {
                        axis := _game.player_inputs.move
                        engine.ui_label("move")
                        engine.ui_label(fmt.tprintf("%v", axis.x))
                        engine.ui_label(fmt.tprintf("%v", axis.y))
                    }

                    engine.ui_layout_row({ 50, 50, 50, 50, 50 }, 0)
                    engine.ui_label("key")
                    engine.ui_label("down")
                    engine.ui_label("up")
                    engine.ui_label("pressed")
                    engine.ui_label("released")
                    {
                        using _game.player_inputs.confirm
                        engine.ui_label("confirm")
                        engine.ui_label(fmt.tprintf("%v", down))
                        engine.ui_label(fmt.tprintf("%v", !down))
                        engine.ui_label(fmt.tprintf("%v", pressed))
                        engine.ui_label(fmt.tprintf("%v", released))
                    }
                    {
                        using _game.player_inputs.cancel
                        engine.ui_label("cancel")
                        engine.ui_label(fmt.tprintf("%v", down))
                        engine.ui_label(fmt.tprintf("%v", !down))
                        engine.ui_label(fmt.tprintf("%v", pressed))
                        engine.ui_label(fmt.tprintf("%v", released))
                    }
                }

                if .ACTIVE in engine.ui_treenode("Controllers", { }) {
                    keys := [] engine.GameControllerButton {
                        .A,
                        .B,
                        .X,
                        .Y,
                        .BACK,
                        // .GUIDE,
                        .START,
                        .LEFTSTICK,
                        .RIGHTSTICK,
                        .LEFTSHOULDER,
                        .RIGHTSHOULDER,
                        .DPAD_UP,
                        .DPAD_DOWN,
                        .DPAD_LEFT,
                        .DPAD_RIGHT,
                        // .MISC1,
                        // .PADDLE1,
                        // .PADDLE2,
                        // .PADDLE3,
                        // .PADDLE4,
                        // .TOUCHPAD,
                        // .MAX,
                    }
                    axes := [] engine.GameControllerAxis {
                        // .INVALID = -1,
                        .LEFTX,
                        .LEFTY,
                        .RIGHTX,
                        .RIGHTY,
                        .TRIGGERLEFT,
                        .TRIGGERRIGHT,
                        // .MAX,
                    }

                    for joystick_id, controller_state in _game._engine.platform.controllers {
                        controller_name := engine.get_controller_name(controller_state.controller)
                        if .ACTIVE in engine.ui_treenode(fmt.tprintf("%v (%v)", controller_name, joystick_id), { .EXPANDED }) {
                            engine.ui_layout_row({ 90, 50, 50, 50, 50 })
                            engine.ui_label("key")
                            engine.ui_label("down")
                            engine.ui_label("up")
                            engine.ui_label("pressed")
                            engine.ui_label("released")
                            for key in keys {
                                engine.ui_label(fmt.tprintf("%v", key))
                                engine.ui_label(fmt.tprintf("%v", controller_state.buttons[key].down))
                                engine.ui_label(fmt.tprintf("%v", !controller_state.buttons[key].down))
                                engine.ui_label(fmt.tprintf("%v", controller_state.buttons[key].pressed))
                                engine.ui_label(fmt.tprintf("%v", controller_state.buttons[key].released))
                            }

                            engine.ui_layout_row({ 90, 50 })
                            engine.ui_label("axis")
                            engine.ui_label("value")
                            for axis in axes {
                                engine.ui_label(fmt.tprintf("%v", axis))
                                engine.ui_label(fmt.tprintf("%v", controller_state.axes[axis].value))
                            }
                        }
                    }
                }

                if .ACTIVE in engine.ui_treenode("Keyboard", { }) {
                    keys := [] engine.Scancode {
                        .UP,
                        .DOWN,
                        .LEFT,
                        .RIGHT,
                    }
                    engine.ui_layout_row({ 50, 50, 50, 50, 50 }, 0)
                    engine.ui_label("key")
                    engine.ui_label("down")
                    engine.ui_label("up")
                    engine.ui_label("pressed")
                    engine.ui_label("released")
                    for key in keys {
                        engine.ui_label(fmt.tprintf("%v", key))
                        engine.ui_label(fmt.tprintf("%v", _game._engine.platform.keys[key].down))
                        engine.ui_label(fmt.tprintf("%v", !_game._engine.platform.keys[key].down))
                        engine.ui_label(fmt.tprintf("%v", _game._engine.platform.keys[key].pressed))
                        engine.ui_label(fmt.tprintf("%v", _game._engine.platform.keys[key].released))
                    }
                }
            }

            if .ACTIVE in engine.ui_header("Renderer", { .EXPANDED }) {
                engine.ui_layout_row({ 170, -1 }, 0)
                engine.ui_label("update_rate")
                engine.ui_label(fmt.tprintf("%v", _game._engine.platform.update_rate))
                engine.ui_label("display_dpi")
                engine.ui_label(fmt.tprintf("%v", _game._engine.renderer.display_dpi))
                engine.ui_label("rendering_size")
                engine.ui_label(fmt.tprintf("%v", _game._engine.renderer.rendering_size))
                engine.ui_label("rendering_scale")
                engine.ui_label(fmt.tprintf("%v", _game._engine.renderer.rendering_scale))
                engine.ui_label("rendering_offset")
                engine.ui_label(fmt.tprintf("%v", _game._engine.renderer.rendering_offset))
                engine.ui_layout_row({ 50, 50, 50, 50, 50, 50, 50, 50 }, 0)
                scales := []i32 { 1, 2, 3, 4, 5, 6 }
                for scale in scales {
                    if .SUBMIT in engine.ui_button(fmt.tprintf("x%i", scale)) {
                        log.debugf("Set rendering_scale: %v", scale)
                        _game._engine.renderer.rendering_scale = scale
                        update_rendering_offset(_game._engine.renderer)
                    }
                }
                engine.ui_layout_row({ 170, -1 }, 0)
                engine.ui_label("textures")
                engine.ui_label(fmt.tprintf("%v", len(_game._engine.renderer.textures)))
            }
        }
    }


    if _game.debug_ui_window_entities {
        if engine.ui_window("Entities", { _game.window_size.x - 360, 0, 360, 640 }, { .NO_CLOSE }) {
            engine.ui_layout_row({ 160, -1 }, 0)

            engine.ui_label("entities")
            engine.ui_label(fmt.tprintf("%v", len(_game.entities.entities)))

            engine.ui_layout_row({ 160, -1 }, 0)
            engine.ui_checkbox("Show room only", &_game.debug_ui_room_only)

            engine.ui_layout_row({ 160, -1 }, 0)
            engine.ui_checkbox("Hide tiles", &_game.debug_ui_no_tiles)

            engine.ui_layout_row({ 160, -1 }, 0)
            for entity in _game.entities.entities {
                component_flag, has_flag := _game.entities.components_flag[entity]
                if _game.debug_ui_no_tiles && has_flag && .Tile in component_flag.value {
                    continue
                }

                engine.ui_push_id_uintptr(uintptr(entity))
                engine.ui_label(fmt.tprintf("%v", entity_format(entity, &_game.entities)))
                if .SUBMIT in engine.ui_button("Inspect") {
                    if _game.debug_ui_entity == entity {
                        _game.debug_ui_entity = 0
                    } else {
                        _game.debug_ui_entity = entity
                    }
                }
                engine.ui_pop_id()
            }
        }

        if _game.debug_ui_entity != 0 {
            entity := _game.debug_ui_entity
            if engine.ui_window(fmt.tprintf("Entity %v", entity), { _game.window_size.x - 360 - 360, 0, 360, 640 }, { .NO_CLOSE }) {
                component_name, has_name := _game.entities.components_name[entity]
                if has_name {
                    if .ACTIVE in engine.ui_header("Component_Name", { .EXPANDED }) {
                        engine.ui_layout_row({ 120, -1 }, 0)
                        engine.ui_label("name")
                        engine.ui_label(component_name.name)
                    }
                }

                component_transform, has_transform := _game.entities.components_transform[entity]
                if has_transform {
                    rect_position := component_transform.world_position * component_transform.size
                    engine.append_debug_rect({ rect_position.x, rect_position.y, component_transform.size.x, component_transform.size.y }, { 255, 0, 0, 100 })
                    if .ACTIVE in engine.ui_header("Component_Transform", { .EXPANDED }) {
                        engine.ui_layout_row({ 120, -1 }, 0)
                        engine.ui_label("grid_position")
                        engine.ui_label(fmt.tprintf("%v", component_transform.grid_position))
                        engine.ui_label("world_position")
                        engine.ui_label(fmt.tprintf("%v", component_transform.world_position))
                        engine.ui_label("size")
                        engine.ui_label(fmt.tprintf("%v", component_transform.size))
                    }
                }

                component_rendering, has_rendering := &_game.entities.components_rendering[entity]
                if has_rendering {
                    if .ACTIVE in engine.ui_header("Component_Rendering", { .EXPANDED }) {
                        engine.ui_layout_row({ 120, -1 }, 0)
                        engine.ui_label("visible")
                        if .SUBMIT in engine.ui_button(component_rendering.visible ? "true": "false") {
                            component_rendering.visible = !component_rendering.visible
                        }
                        engine.ui_label("texture_asset")
                        engine.ui_label(fmt.tprintf("%v", component_rendering.texture_asset))
                        engine.ui_label("texture_position")
                        engine.ui_label(fmt.tprintf("%v", component_rendering.texture_position))
                        engine.ui_label("texture_size")
                        engine.ui_label(fmt.tprintf("%v", component_rendering.texture_size))
                    }
                }

                component_z_index, has_z_index := _game.entities.components_z_index[entity]
                if has_z_index {
                    if .ACTIVE in engine.ui_header("Component_Z_Index", { .EXPANDED }) {
                        engine.ui_layout_row({ 120, -1 }, 0)
                        engine.ui_label("z_index")
                        engine.ui_label(fmt.tprintf("%v", component_z_index.z_index))
                    }
                }

                component_animation, has_animation := _game.entities.components_animation[entity]
                if has_animation {
                    if .ACTIVE in engine.ui_header("Component_Animation", { .EXPANDED }) {
                        engine.ui_layout_row({ 120, -1 }, 0)
                        engine.ui_label("current_frame")
                        engine.ui_label(fmt.tprintf("%v", component_animation.current_frame))
                    }
                }

                component_flag, has_flag := _game.entities.components_flag[entity]
                if has_flag {
                    if .ACTIVE in engine.ui_header("Component_Flag", { .EXPANDED }) {
                        engine.ui_layout_row({ 120, -1 }, 0)
                        engine.ui_label("value")
                        engine.ui_label(fmt.tprintf("%v", component_flag.value))
                    }
                }

                component_meta, has_meta := _game.entities.components_meta[entity]
                if has_meta {
                    if .ACTIVE in engine.ui_header("Meta", { .EXPANDED }) {
                        engine.ui_layout_row({ 120, -1 }, 0)
                        for key, value in component_meta.value {
                            engine.ui_label(fmt.tprintf("%v", key))
                            engine.ui_label(fmt.tprintf("%v", value))
                        }
                    }
                }
            }
        }
    }
}

ui_input_mouse_down :: proc(mouse_position: Vector2i, button: u8) {
    switch button {
        case engine.BUTTON_LEFT:   engine.ui_input_mouse_down(mouse_position.x, mouse_position.y, .LEFT)
        case engine.BUTTON_MIDDLE: engine.ui_input_mouse_down(mouse_position.x, mouse_position.y, .MIDDLE)
        case engine.BUTTON_RIGHT:  engine.ui_input_mouse_down(mouse_position.x, mouse_position.y, .RIGHT)
    }
}
ui_input_mouse_up :: proc(mouse_position: Vector2i, button: u8) {
    switch button {
        case engine.BUTTON_LEFT:   engine.ui_input_mouse_up(mouse_position.x, mouse_position.y, .LEFT)
        case engine.BUTTON_MIDDLE: engine.ui_input_mouse_up(mouse_position.x, mouse_position.y, .MIDDLE)
        case engine.BUTTON_RIGHT:  engine.ui_input_mouse_up(mouse_position.x, mouse_position.y, .RIGHT)
    }
}
ui_input_text :: engine.ui_input_text
ui_input_scroll :: engine.ui_input_scroll
ui_input_key_down :: proc(keycode: engine.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    engine.ui_input_key_down(.SHIFT)
        case .RSHIFT:    engine.ui_input_key_down(.SHIFT)
        case .LCTRL:     engine.ui_input_key_down(.CTRL)
        case .RCTRL:     engine.ui_input_key_down(.CTRL)
        case .LALT:      engine.ui_input_key_down(.ALT)
        case .RALT:      engine.ui_input_key_down(.ALT)
        case .RETURN:    engine.ui_input_key_down(.RETURN)
        case .KP_ENTER:  engine.ui_input_key_down(.RETURN)
        case .BACKSPACE: engine.ui_input_key_down(.BACKSPACE)
    }
}
ui_input_key_up :: proc(keycode: engine.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    engine.ui_input_key_up(.SHIFT)
        case .RSHIFT:    engine.ui_input_key_up(.SHIFT)
        case .LCTRL:     engine.ui_input_key_up(.CTRL)
        case .RCTRL:     engine.ui_input_key_up(.CTRL)
        case .LALT:      engine.ui_input_key_up(.ALT)
        case .RALT:      engine.ui_input_key_up(.ALT)
        case .RETURN:    engine.ui_input_key_up(.RETURN)
        case .KP_ENTER:  engine.ui_input_key_up(.RETURN)
        case .BACKSPACE: engine.ui_input_key_up(.BACKSPACE)
    }
}
