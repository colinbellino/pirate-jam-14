package game

import "core:slice"
import "core:path/filepath"
import "core:math"
import "core:log"
import "core:fmt"
import "../engine"
import "../tools"

game_ui_debug :: proc() {
    engine.profiler_zone("game_ui_debug")
    when engine.IMGUI_ENABLE == false || DEBUG_UI_ENABLE == false {
        return
    }

    if _mem.game.debug_draw_top_bar {
        if engine.ui_main_menu_bar() {
            window_size := engine.get_window_size()
            if engine.ui_menu("Windows") {
                engine.ui_menu_item_bool_ptr("Game", "", &_mem.game.debug_ui_window_game, false)
                engine.ui_menu_item_bool_ptr("Console", "²", &_mem.game.debug_ui_window_console, true)
                engine.ui_menu_item_bool_ptr("Main", "F1", &_mem.game.debug_ui_window_debug, true)
                engine.ui_menu_item_bool_ptr("Entities", "F2", &_mem.game.debug_ui_window_entities, true)
                engine.ui_menu_item_bool_ptr("Assets", "F3", &_mem.game.debug_ui_window_assets, true)
                engine.ui_menu_item_bool_ptr("Anim", "F4", &_mem.game.debug_ui_window_anim, true)
                engine.ui_menu_item_bool_ptr("Battle", "F5", &_mem.game.debug_ui_window_battle, true)
                engine.ui_menu_item_bool_ptr("Shader", "F6", &_mem.game.debug_ui_window_shader, true)
                engine.ui_menu_item_bool_ptr("IMGUI Demo", "", &_mem.game.debug_ui_window_demo, true)
            }
            if engine.ui_menu("Draw") {
                engine.ui_checkbox("Tiles", &_mem.game.debug_draw_tiles)
                engine.ui_checkbox("Entities", &_mem.game.debug_draw_entities)
                engine.ui_checkbox("Fog", &_mem.game.debug_draw_fog)
                engine.ui_checkbox("GL", &_mem.game.debug_draw_gl)
                engine.ui_checkbox("Bounding box", &_mem.game.debug_show_bounding_boxes)
            }
            if engine.ui_menu("Cheats") {
                // engine.ui_checkbox("cheat_move_anywhere", &_mem.game.cheat_move_anywhere)
                // engine.ui_checkbox("cheat_move_repeatedly", &_mem.game.cheat_move_repeatedly)
                // engine.ui_checkbox("cheat_act_anywhere",  &_mem.game.cheat_act_anywhere)
                // engine.ui_checkbox("cheat_act_repeatedly",  &_mem.game.cheat_act_repeatedly)
                engine.ui_text("No cheats, only bucket!")
            }
            if engine.ui_menu(fmt.tprintf("Window size: %ix%i", i32(window_size.x), i32(window_size.y))) {
                if engine.ui_menu_item_ex("960x540", "", window_size == { 960, 540 }, true) { engine.set_window_size({ 960, 540 }) }
                if engine.ui_menu_item_ex("1920x1080", "", window_size == { 1920, 1080 }, true) { engine.set_window_size({ 1920, 1080 }) }
                if engine.ui_menu_item_ex("3840x2160", "", window_size == { 3840, 2160 }, true) { engine.set_window_size({ 3840, 2160 }) }
            }
            frame_stat := engine.get_frame_stat()
            if engine.ui_menu(fmt.tprintf("Refresh rate: %vHz", frame_stat.target_fps)) {
                if engine.ui_menu_item_ex("1Hz", "", frame_stat.target_fps == 1, true) { engine.set_target_fps(1) }
                if engine.ui_menu_item_ex("10Hz", "", frame_stat.target_fps == 10, true) { engine.set_target_fps(10) }
                if engine.ui_menu_item_ex("30Hz", "", frame_stat.target_fps == 30, true) { engine.set_target_fps(30) }
                if engine.ui_menu_item_ex("60Hz", "", frame_stat.target_fps == 60, true) { engine.set_target_fps(60) }
                if engine.ui_menu_item_ex("144Hz", "", frame_stat.target_fps == 144, true) { engine.set_target_fps(144) }
                if engine.ui_menu_item_ex("240Hz", "", frame_stat.target_fps == 240, true) { engine.set_target_fps(240) }
                if engine.ui_menu_item_ex("320Hz", "", frame_stat.target_fps == 320, true) { engine.set_target_fps(320) }
                if engine.ui_menu_item_ex("Unlocked", "", frame_stat.target_fps == 9999, true) { engine.set_target_fps(9999); engine.p_set_vsync(0) }
            }
            time_scale := engine.get_time_scale()
            if engine.ui_menu(fmt.tprintf("Time scale: x%1.2f", time_scale)) {
                if engine.ui_menu_item_ex("x0.25", "", time_scale == 0.25, true) { engine.set_time_scale(0.25) }
                if engine.ui_menu_item_ex("x0.5", "", time_scale == 0.5, true) { engine.set_time_scale(0.5) }
                if engine.ui_menu_item_ex("x1", "", time_scale == 1, true) { engine.set_time_scale(1) }
                if engine.ui_menu_item_ex("x2", "", time_scale == 2, true) { engine.set_time_scale(2) }
                if engine.ui_menu_item_ex("x5", "", time_scale == 5, true) { engine.set_time_scale(5) }
                if engine.ui_menu_item_ex("x10", "", time_scale == 10, true) { engine.set_time_scale(10) }
                if engine.ui_menu_item_ex("x100", "", time_scale == 100, true) { engine.set_time_scale(100) }
                if engine.ui_menu_item_ex("Unlocked", "", time_scale == 999999, true) { engine.set_time_scale(999999) }
            }
        }
    }

    debug_ui_window_debug(&_mem.game.debug_ui_window_debug)
    debug_ui_window_anim(&_mem.game.debug_ui_window_anim)
    debug_ui_window_shader(&_mem.game.debug_ui_window_shader)
    if _mem.game.debug_ui_window_entities {
        if engine.ui_window("Entities", &_mem.game.debug_ui_window_entities) {
            engine.ui_set_window_size_vec2({ 600, 800 }, .FirstUseEver)
            engine.ui_set_window_pos_vec2({ 50, 50 }, .FirstUseEver)

            engine.ui_text("Entities: %v", engine.entity_get_entities_count())

            if engine.ui_collapsing_header("Grid", {}) {
                @(static) hovered_entity : Entity = 0
                engine.ui_text("debug_ui_entity: %v", _mem.game.debug_ui_entity)
                engine.ui_text("hovered_entity: %v", engine.entity_format(hovered_entity))

                draw_list := engine.ui_get_foreground_draw_list()
                origin := engine.ui_get_item_rect_min()
                line_height : f32 = 17
                x : f32 = origin.x
                y : f32 = origin.y + line_height
                size : f32 = 10
                spacing : f32 = 4
                entities_per_row := 20
                total_height := math.floor(f32(engine.entity_get_entities_count()) / f32(entities_per_row)) * (size + spacing) + line_height
                window_pos := engine.ui_get_window_pos()
                window_size := engine.ui_get_window_size()
                window_end := window_size.y - f32(y)
                engine.ui_dummy({ -1, total_height })
                for entity, i in engine.entity_get_entities() {
                    if i > 0 && i % entities_per_row == 0 {
                        y += size + spacing
                        x = origin.x
                    }
                    if window_pos.y + window_size.y - y <= line_height || window_pos.y - y >= -line_height {
                        continue
                    }
                    color := engine.Vec4 { 0.0, 0.5, 0.5, 1 }
                    if entity_has_flag(entity, .Tile) {
                        color = { 0.5, 0.5, 0, 1 }
                    }
                    engine.ui_draw_list_add_rect_filled(draw_list, { x, y }, { x + size, y + size }, engine.ui_get_color_u32_vec4(color))

                    if engine.ui_is_mouse_hovering_rect({ x - spacing / 2, y - spacing / 2 }, { x + size + spacing / 2, y + size + spacing / 2 }) {
                        hovered_entity = entity
                        if engine.ui_is_mouse_clicked(.Left) {
                            if _mem.game.debug_ui_entity == entity {
                                _mem.game.debug_ui_entity = 0
                            } else {
                                _mem.game.debug_ui_entity = entity
                            }
                        }
                    }

                    // if slice.contains(_mem.game.battle_data.entities[:], entity) {
                    //     engine.ui_draw_list_add_rect_filled(draw_list, { x + 1, y + 1 }, { x + 4, y + 4 }, engine.ui_get_color_u32_vec4({ 1, 1, 1, 0.8 }))
                    // }
                    if entity_has_flag(entity, .Unit) {
                        engine.ui_draw_list_add_rect_filled(draw_list, { x + 5, y + 1 }, { x + 9, y + 4 }, engine.ui_get_color_u32_vec4({ 1, 0, 0, 0.8 }))
                    }

                    x += size + spacing
                }
            }

            if engine.ui_collapsing_header("List", { .DefaultOpen }) {
                engine.ui_text("Filters:")
                engine.ui_checkbox("tiles", &_mem.game.debug_ui_entity_tiles)
                // engine.ui_same_line()
                // engine.ui_checkbox("units", &_mem.game.debug_ui_entity_units)
                engine.ui_same_line()
                engine.ui_checkbox("children", &_mem.game.debug_ui_entity_children)
                engine.ui_same_line()
                engine.ui_checkbox("other", &_mem.game.debug_ui_entity_other)

                columns := []string { "id", "name", "actions" }
                if engine.ui_table(columns) {
                    for entity in engine.entity_get_entities() {
                        component_flag, err_flag := engine.entity_get_component_err(entity, Component_Flag)
                        component_name, err_name := engine.entity_get_component_err(entity, engine.Component_Name)
                        component_transform, err_transform := engine.entity_get_component_err(entity, engine.Component_Transform)

                        show_row := true
                        if err_flag == .None && .Tile in component_flag.value {
                            show_row = _mem.game.debug_ui_entity_tiles
                        }
                        else if err_transform == .None && component_transform.parent != Entity(0) {
                            show_row = _mem.game.debug_ui_entity_children
                        } else {
                            show_row = _mem.game.debug_ui_entity_other
                        }
                        if show_row == false {
                            continue
                        }

                        engine.ui_table_next_row()

                        for column, i in columns {
                            engine.ui_table_set_column_index(i32(i))
                            switch column {
                                case "id": engine.ui_text("%v", entity)
                                case "name": {
                                    if err_transform == .None && component_transform.parent != Entity(0) {
                                        engine.ui_text("  %v", engine.entity_get_name(entity))
                                    } else {
                                        engine.ui_text("%v", engine.entity_get_name(entity))
                                    }
                                }
                                case "actions": {
                                    engine.ui_push_id(i32(entity))
                                    if engine.ui_button("Inspect") {
                                        if _mem.game.debug_ui_entity == entity {
                                            _mem.game.debug_ui_entity = 0
                                        } else {
                                            _mem.game.debug_ui_entity = entity
                                        }
                                    }
                                    engine.ui_pop_id()
                                }
                                case: engine.ui_text("x")
                            }
                        }
                    }
                }
            }
        }
        entity := _mem.game.debug_ui_entity
        if engine.ui_window("Entity", cast(^bool) &_mem.game.debug_ui_entity) {
            engine.ui_set_window_size_vec2({ 300, 300 }, .FirstUseEver)
            engine.ui_set_window_pos_vec2({ 500, 500 }, .FirstUseEver)

            engine.ui_text("id:")
            engine.ui_same_line_ex(0, 10)
            engine.ui_text("%v", entity)

            component_name, err_name := engine.entity_get_component_err(entity, engine.Component_Name)
            if err_name == .None {
                if engine.ui_collapsing_header("Component_Name", { .DefaultOpen }) {
                    engine.ui_text("name:")
                    engine.ui_same_line_ex(0, 10)
                    engine.ui_text(component_name.name)
                }
            }

            component_transform, err_transform := engine.entity_get_component_err(entity, engine.Component_Transform)
            if err_transform == .None {
                rect_position := component_transform.position * component_transform.scale
                if engine.ui_collapsing_header("Component_Transform", { .DefaultOpen }) {
                    engine.ui_text("component: %p, position: %p, scale: %p", component_transform, &component_transform.position, &component_transform.scale)
                    engine.ui_slider_float2("position", transmute(^[2]f32)(&component_transform.position), 0, 1024)
                    engine.ui_input_float2("position2", transmute(^[2]f32)(&component_transform.position))
                    engine.ui_slider_float2("scale", transmute(^[2]f32)(&component_transform.scale), -10, 10)
                    engine.ui_input_float2("scale2", transmute(^[2]f32)(&component_transform.scale))
                    engine.ui_text("parent: %v", engine.entity_format(component_transform.parent))
                }
            }

            component_sprite, err_sprite := engine.entity_get_component_err(entity, engine.Component_Sprite)
            if err_sprite == .None {
                if engine.ui_collapsing_header("Component_Sprite", { .DefaultOpen }) {
                    engine.ui_checkbox("hidden", &component_sprite.hidden)
                    engine.ui_same_line()
                    if engine.ui_button("Hide all others") {
                        for other_entity in engine.entity_get_entities_with_components({ engine.Component_Sprite }) {
                            if other_entity != entity {
                                other_component_sprite := engine.entity_get_component(other_entity, engine.Component_Sprite)
                                other_component_sprite.hidden = true
                            }
                        }
                    }
                    engine.ui_input_int("texture_asset", transmute(^i32) &component_sprite.texture_asset)
                    engine.ui_input_int2("texture_position", transmute(^[2]i32)(&component_sprite.texture_position))
                    engine.ui_input_int2("texture_size", transmute(^[2]i32)(&component_sprite.texture_size))
                    engine.ui_input_int("texture_padding", &component_sprite.texture_padding)
                    engine.ui_input_int("z_index", &component_sprite.z_index)
                    engine.ui_color_edit4("tint", transmute(^[4]f32) &component_sprite.tint)
                    engine.ui_input_int("palette", transmute(^i32) &component_sprite.palette)
                    engine.ui_text("shader_asset: %v", component_sprite.shader_asset)

                    asset_info, asset_ok := engine.asset_get_asset_info_image(component_sprite.texture_asset)
                    if asset_ok {
                        engine.ui_text("texture: %v", asset_info)
                        texture_position, texture_size := engine.texture_position_and_size(asset_info.size, component_sprite.texture_position, component_sprite.texture_size, component_sprite.texture_padding)
                        engine.ui_text("texture_position: %v", texture_position)
                        engine.ui_text("texture_size:     %v", texture_size)
                        // engine.ui_image(
                        //     &asset_info.renderer_id,
                        //     { 80, 80 },
                        //     { texture_position.x, texture_position.y },
                        //     { texture_position.x + texture_size.x, texture_position.y + texture_size.y },
                        //     transmute(engine.Vec4) component_sprite.tint, {},
                        // )
                    }
                }
            }

            component_limbs, err_limbs := engine.entity_get_component_err(entity, Component_Limbs)
            if err_limbs == .None {
                if engine.ui_collapsing_header("Component_Limbs", { .DefaultOpen }) {
                    if component_limbs.hand_left != 0 {
                        engine.ui_text("hand_left:  %s", engine.entity_format(component_limbs.hand_left))
                        engine.ui_text("hand_right: %s", engine.entity_format(component_limbs.hand_right))
                    }
                }
            }

            component_flag, err_flag := engine.entity_get_component_err(entity, Component_Flag)
            if err_flag == .None {
                if engine.ui_collapsing_header("Component_Flag", { .DefaultOpen }) {
                    engine.ui_text("value:")
                    engine.ui_same_line_ex(0, 10)
                    engine.ui_text("%v", component_flag.value)
                }
            }

            component_tile_meta, err_tile_meta := engine.entity_get_component_err(entity, engine.Component_Tile_Meta)
            if err_tile_meta == .None {
                if engine.ui_collapsing_header("Component_Meta", { .DefaultOpen }) {
                    engine.ui_text("entity_uid:")
                    engine.ui_same_line_ex(0, 10)
                    engine.ui_text("%v", component_tile_meta.entity_uid)
                }
            }

            component_path, err_path := engine.entity_get_component_err(entity, Component_Path)
            if err_path == .None {
                if engine.ui_collapsing_header("Component_Path", { .DefaultOpen }) {
                    engine.ui_text("previous:")
                    engine.ui_same_line_ex(0, 10)
                    engine.ui_text("%v", component_path.previous)
                }
            }

            component_mess_creator, err_mess_creator := engine.entity_get_component_err(entity, Component_Mess_Creator)
            if err_mess_creator == .None {
                if engine.ui_collapsing_header("Component_Mess_Creator", { .DefaultOpen }) {
                    engine.ui_checkbox("on_click", &component_mess_creator.on_click)
                    engine.ui_checkbox("on_death", &component_mess_creator.on_death)
                    engine.ui_checkbox("on_timer", &component_mess_creator.on_timer)
                    engine.ui_text("timer_at:       %v", component_mess_creator.timer_at)
                    engine.ui_text("timer_cooldown: %v", component_mess_creator.timer_cooldown)
                }
            }

            component_mess, err_mess := engine.entity_get_component_err(entity, Component_Mess)
            if err_mess == .None {
                if engine.ui_collapsing_header("Component_Mess", { .DefaultOpen }) {
                    engine.ui_text("clean_progress: %v", component_mess.progress)
                }
            }

            component_collider, err_collider := engine.entity_get_component_err(entity, Component_Collider)
            if err_collider == .None {
                if engine.ui_collapsing_header("Component_Collider", { .DefaultOpen }) {
                    engine.ui_text("type: %v", component_collider.type)
                    engine.ui_text("box:  %v", component_collider.box)
                    engine.ui_input_float2("offset", transmute(^[2]f32) &component_collider.offset)
                    if .Interact in component_collider.type {
                        if engine.ui_button("Trigger interact (primary)") {
                            interactive := engine.entity_get_component(entity, Component_Interactive_Primary)
                            entity_interact(entity, _mem.game.play.player, cast(^Component_Interactive) interactive)
                        }
                        if engine.ui_button("Trigger interact (secondary)") {
                            interactive := engine.entity_get_component(entity, Component_Interactive_Secondary)
                            entity_interact(entity, _mem.game.play.player, cast(^Component_Interactive) interactive)
                        }
                        if engine.ui_button("Trigger interact (adventurer)") {
                            interactive := engine.entity_get_component(entity, Component_Interactive_Adventurer)
                            entity_interact(entity, _mem.game.play.adventurer, cast(^Component_Interactive) interactive)
                        }
                    }
                }
            }

            component_dead, err_dead := engine.entity_get_component_err(entity, Component_Dead)
            if err_dead == .None {
                if engine.ui_collapsing_header("Component_Dead", { .DefaultOpen }) {

                }
            }

            component_interactive_primary, err_interactive_primary := engine.entity_get_component_err(entity, Component_Interactive_Primary)
            if err_interactive_primary == .None {
                if engine.ui_collapsing_header("Component_Interactive_Primary", { .DefaultOpen }) {
                    engine.ui_text("type:         %v", component_interactive_primary.type)
                    engine.ui_text("progress:     %v", component_interactive_primary.progress)
                    engine.ui_text("cooldown_end: %v", component_interactive_primary.cooldown_end)
                    engine.ui_text("done:         %v", component_interactive_primary.done)
                }
            }
            component_interactive_secondary, err_interactive_secondary := engine.entity_get_component_err(entity, Component_Interactive_Secondary)
            if err_interactive_secondary == .None {
                if engine.ui_collapsing_header("Component_Interactive_Secondary", { .DefaultOpen }) {
                    engine.ui_text("type:         %v", component_interactive_secondary.type)
                    engine.ui_text("progress:     %v", component_interactive_secondary.progress)
                    engine.ui_text("cooldown_end: %v", component_interactive_secondary.cooldown_end)
                    engine.ui_text("done:         %v", component_interactive_secondary.done)
                }
            }
            component_interactive_adventurer, err_interactive_adventurer := engine.entity_get_component_err(entity, Component_Interactive_Adventurer)
            if err_interactive_adventurer == .None {
                if engine.ui_collapsing_header("Component_Interactive_Adventurer", { .DefaultOpen }) {
                    engine.ui_text("type:         %v", component_interactive_adventurer.type)
                    engine.ui_text("progress:     %v", component_interactive_adventurer.progress)
                    engine.ui_text("cooldown_end: %v", component_interactive_adventurer.cooldown_end)
                    engine.ui_text("done:         %v", component_interactive_adventurer.done)
                }
            }

            component_carrier, err_carrier := engine.entity_get_component_err(entity, Component_Carrier)
            if err_carrier == .None {
                if engine.ui_collapsing_header("Component_Carrier", { .DefaultOpen }) {
                    engine.ui_text("target:         %v", engine.entity_get_name(component_carrier.target))
                }
            }

            component_adventurer, err_adventurer := engine.entity_get_component_err(entity, Component_Adventurer)
            if err_adventurer == .None {
                if engine.ui_collapsing_header("Component_Adventurer", { .DefaultOpen }) {
                    engine.ui_text("mode: %v", component_adventurer.mode)
                    for m in Adventurer_Mode {
                        if engine.ui_button_disabled(fmt.tprintf("%v", m), component_adventurer.mode == m) {
                            component_adventurer.mode = m
                        }
                        engine.ui_same_line()
                    }
                    engine.ui_new_line()
                }
            }

            component_animator, err_animator := engine.entity_get_component_err(entity, Component_Animator)
            if err_animator == .None {
                if engine.ui_collapsing_header("Component_Animator", { .DefaultOpen }) {
                    engine.ui_text("current: %v", component_animator.current)
                    for key in component_animator.animations {
                        if engine.ui_button_disabled(fmt.tprintf("%v", key), component_animator.current == key) {
                            entity_change_animation(entity, key)
                        }
                        engine.ui_same_line()
                    }
                    engine.ui_new_line()
                }
            }

            component_move, err_move := engine.entity_get_component_err(entity, Component_Move)
            if err_move == .None {
                if engine.ui_collapsing_header("Component_Move", { .DefaultOpen }) {
                    engine.ui_text("velocity: %v", component_move.velocity)
                }
            }

            component_self_destruct, err_self_destruct := engine.entity_get_component_err(entity, Component_Self_Destruct)
            if err_self_destruct == .None {
                if engine.ui_collapsing_header("Component_Self_Destruct", { .DefaultOpen }) {
                    engine.ui_text("ends_at: %v", component_self_destruct.ends_at)
                }
            }
        }
    }

    engine.ui_window_logger_console(&_mem.game.debug_ui_window_console)
    engine.ui_window_assets(&_mem.game.debug_ui_window_assets)
    engine.ui_window_animation(&_mem.game.debug_ui_window_anim)
    engine.ui_window_notification()
    engine.ui_show_demo_window(&_mem.game.debug_ui_window_demo)
}

debug_ui_window_debug :: proc(open: ^bool) {
    if open^ == false {
        return
    }

    if engine.ui_window("Main", open) {
        engine.ui_set_window_size_vec2({ 600, 800 }, .FirstUseEver)
        engine.ui_set_window_pos_vec2({ 50, 50 }, .FirstUseEver)

        time_scale := engine.get_time_scale()

        if engine.ui_collapsing_header("General", { .DefaultOpen }) {
            if engine.ui_input_float("time_scale", &time_scale) {
                engine.set_time_scale(time_scale)
            }
            engine.ui_text("Game states:")
            engine.ui_same_line()
            _mem.game.debug_force_transition = nil
            if engine.ui_button_disabled("Init", _mem.game.game_mode.current == int(Game_Mode.Init)) {
                _mem.game.debug_force_transition = .Init
            }
            engine.ui_same_line()
            if engine.ui_button_disabled("Title", _mem.game.game_mode.current == int(Game_Mode.Title)) {
                _mem.game.debug_force_transition = .Title
            }
            engine.ui_same_line()
            if engine.ui_button_disabled("Play", _mem.game.game_mode.current == int(Game_Mode.Play)) {
                _mem.game.debug_force_transition = .Play
            }
            engine.ui_same_line()
            if engine.ui_button_disabled("Game_Over", _mem.game.game_mode.current == int(Game_Mode.Game_Over)) {
                _mem.game.debug_force_transition = .Game_Over
            }
            engine.ui_same_line()
            if engine.ui_button_disabled("Debug", _mem.game.game_mode.current == int(Game_Mode.Debug)) {
                _mem.game.debug_force_transition = .Debug
            }
            engine.ui_text("mouse_position:       %v", engine.mouse_get_position())
            engine.ui_text("mouse_world_position: %v", _mem.game.mouse_world_position)
            engine.ui_text("mouse_grid_position:  %v", _mem.game.mouse_grid_position)
            if engine.ui_tree_node("Config") {
                engine.ui_text("RENDERER_ENABLE:   %v", engine.RENDERER_ENABLE)
                engine.ui_text("ASSETS_PATH:       %v", engine.ASSETS_PATH)
                engine.ui_text("HOT_RELOAD_CODE:   %v", engine.HOT_RELOAD_CODE)
                engine.ui_text("HOT_RELOAD_ASSETS: %v", engine.HOT_RELOAD_ASSETS)
                engine.ui_text("LOG_ALLOC:         %v", engine.LOG_ALLOC)
                engine.ui_text("IN_GAME_LOGGER:    %v", engine.IN_GAME_LOGGER)
                engine.ui_text("IMGUI_ENABLE:      %v", engine.IMGUI_ENABLE)
                engine.ui_text("TRACY_ENABLE:      %v", engine.TRACY_ENABLE)
            }

            if engine.ui_tree_node("Debug") {
                engine.ui_text("render_enabled:             %v", _mem.game.render_enabled)
                engine.ui_text("debug_ui_window_game:       %v", _mem.game.debug_ui_window_game)
                engine.ui_text("debug_ui_window_console:    %v", _mem.game.debug_ui_window_console)
                engine.ui_text("debug_ui_window_debug:      %v", _mem.game.debug_ui_window_debug)
                engine.ui_text("debug_ui_window_entities:   %v", _mem.game.debug_ui_window_entities)
                engine.ui_text("debug_ui_window_assets:     %v", _mem.game.debug_ui_window_assets)
                engine.ui_text("debug_ui_window_anim:       %v", _mem.game.debug_ui_window_anim)
                engine.ui_text("debug_ui_window_battle:     %v", _mem.game.debug_ui_window_battle)
                engine.ui_text("debug_ui_window_shader:     %v", _mem.game.debug_ui_window_shader)
                engine.ui_text("debug_ui_window_demo:       %v", _mem.game.debug_ui_window_demo)
                engine.ui_text("debug_ui_entity:            %v", _mem.game.debug_ui_entity)
                engine.ui_text("debug_ui_entity_tiles:      %v", _mem.game.debug_ui_entity_tiles)
                engine.ui_text("debug_ui_entity_units:      %v", _mem.game.debug_ui_entity_units)
                engine.ui_text("debug_ui_entity_children:   %v", _mem.game.debug_ui_entity_children)
                engine.ui_text("debug_ui_entity_other:      %v", _mem.game.debug_ui_entity_other)
                engine.ui_text("debug_ui_shader_asset_id:   %v", _mem.game.debug_ui_shader_asset_id)
                engine.ui_text("debug_draw_tiles:           %v", _mem.game.debug_draw_tiles)
                engine.ui_text("debug_show_bounding_boxes:  %v", _mem.game.debug_show_bounding_boxes)
                engine.ui_text("debug_entity_under_mouse:   %v", _mem.game.debug_entity_under_mouse)
                engine.ui_text("debug_draw_entities:        %v", _mem.game.debug_draw_entities)
                engine.ui_text("debug_draw_fog:             %v", _mem.game.debug_draw_fog)
            }
        }

        if engine.ui_collapsing_header("Game", { .DefaultOpen }) {
            if _mem.game.game_mode.current == int(Game_Mode.Play) {
                adv_transform := engine.entity_get_component(_mem.game.play.adventurer, engine.Component_Transform)
                adv_move := engine.entity_get_component(_mem.game.play.adventurer, Component_Move)
                start := world_to_grid_position(adv_transform.position)
                @(static) end := Vector2i32 { 5, -6 }
                path, ok := find_path(start, end)
                engine.ui_input_int2("start", cast(^[2]i32) &start)
                engine.ui_input_int2("end", cast(^[2]i32) &end)
                if engine.ui_button("Find path") {
                    path, ok := find_path(start, end)
                    log.debugf("path: %v -> %v", path, ok)
                    adv_move.path_current = 0
                    adv_move.path = path
                }
                engine.ui_text("water_level:   %v", _mem.game.play.water_level)
                if engine.ui_button("Refill water") {
                    _mem.game.play.water_level = WATER_LEVEL_MAX
                }
                engine.ui_text("current_level: %v", _mem.game.play.current_level_index)
                for level, i in _mem.game.play.levels {
                    if level == nil { continue }
                    current := _mem.game.play.current_level_index == i ? "*" : " "
                    if engine.ui_tree_node(fmt.tprintf("%v %v | id: %v, size: %v, position: %v, entities: %v %v###level%i", current, i, level.id, level.size, level.position, len(level.entities), level.id)) {
                        engine.ui_text("%#v", level)
                    }
                }
            }
        }

        if engine.ui_collapsing_header("Memory"/* , { .DefaultOpen } */) {
            if engine.ui_tree_node("arenas", { .DefaultOpen }) {
                engine.ui_text("engine:")
                engine.ui_widget_arenas()
                engine.ui_text("game:")
                engine.ui_memory_arena_progress(&_mem.game.arena)
                engine.ui_memory_arena_progress(&_mem.game.game_mode.arena)
                // if _mem.game.battle_data != nil {
                //     engine.ui_memory_arena_progress(&_mem.game.battle_data.mode.arena)
                //     engine.ui_memory_arena_progress(&_mem.game.battle_data.turn_arena)
                //     engine.ui_memory_arena_progress(&_mem.game.battle_data.plan_arena)
                // }
            }

            if engine.ui_tree_node("frame") {
                resource_usage, resource_usage_previous := tools.mem_get_usage()
                @(static) process_alloc_plot := engine.Statistic_Plot {}
                // engine.ui_text("process_memory: %v", resource_usage)
                engine.ui_statistic_plots(&process_alloc_plot, f32(resource_usage), "process_memory")

                frame_memory_usage := resource_usage - resource_usage_previous
                @(static) frame_memory_alloc_plot := engine.Statistic_Plot {}
                // engine.ui_text("frame_alloc:    %v", frame_memory_usage)
                engine.ui_statistic_plots(&frame_memory_alloc_plot, f32(frame_memory_usage), "frame_alloc")
            }
        }

        if engine.ui_collapsing_header("Inputs") {
            if engine.ui_tree_node("Player") {
                {
                    Row :: struct { name: string, value: ^engine.Vector2f32 }
                    rows := []Row {
                        { "move", &_mem.game.player_inputs.move },
                        { "aim", &_mem.game.player_inputs.aim },
                    }
                    columns := []string { "axis", "value" }
                    if engine.ui_table(columns) {
                        for row in rows {
                            engine.ui_table_next_row()
                            for column, column_index in columns {
                                engine.ui_table_set_column_index(i32(column_index))
                                switch column {
                                    case "axis": engine.ui_text("%v", row.name)
                                    case "value": engine.ui_text("%v", row.value)
                                }
                            }
                        }
                    }
                }

                {
                    Row :: struct { name: string, value: ^engine.Key_State }
                    rows := []Row {
                        { "confirm", &_mem.game.player_inputs.confirm },
                        { "cancel", &_mem.game.player_inputs.cancel },
                        { "back", &_mem.game.player_inputs.back },
                        { "start", &_mem.game.player_inputs.start },
                        { "debug_0", &_mem.game.player_inputs.debug_0 },
                        { "debug_1", &_mem.game.player_inputs.debug_1 },
                        { "debug_2", &_mem.game.player_inputs.debug_2 },
                        { "debug_3", &_mem.game.player_inputs.debug_3 },
                        { "debug_4", &_mem.game.player_inputs.debug_4 },
                        { "debug_5", &_mem.game.player_inputs.debug_5 },
                        { "debug_6", &_mem.game.player_inputs.debug_6 },
                        { "debug_7", &_mem.game.player_inputs.debug_7 },
                        { "debug_8", &_mem.game.player_inputs.debug_8 },
                        { "debug_9", &_mem.game.player_inputs.debug_9 },
                        { "debug_10", &_mem.game.player_inputs.debug_10 },
                        { "debug_11", &_mem.game.player_inputs.debug_11 },
                        { "debug_12", &_mem.game.player_inputs.debug_12 },
                    }
                    columns := []string { "key", "down", "up", "pressed", "released" }
                    if engine.ui_table(columns) {
                        for row in rows {
                            engine.ui_table_next_row()
                            for column, column_index in columns {
                                engine.ui_table_set_column_index(i32(column_index))
                                switch column {
                                    case "key": engine.ui_text("%v", row.name)
                                    case "down": engine.ui_text("%v", row.value.down)
                                    case "up": engine.ui_text("%v", row.value.down == false)
                                    case "pressed": engine.ui_text("%v", row.value.pressed)
                                    case "released": engine.ui_text("%v", row.value.released)
                                }
                            }
                        }
                    }
                }
            }

            engine.ui_widget_mouse()
            engine.ui_widget_keyboard()
            engine.ui_widget_controllers()
        }

        engine.ui_widget_audio()

        if engine.ui_collapsing_header("size_of") {
            engine.ui_text("bool:  %v | b8:    %v | b16:   %v | b32:    %v | b64:   %v", size_of(bool), size_of(b8), size_of(b16), size_of(b32), size_of(b64))
            engine.ui_text("int:   %v | i8:    %v | i16:   %v | i32:    %v | i64:   %v | i128:  %v", size_of(int), size_of(i8), size_of(i16), size_of(i32), size_of(i64), size_of(i128))
            engine.ui_text("uint:  %v | u8:    %v | u16:   %v | u32:    %v | u64:   %v | u128:  %v | uintptr: %v", size_of(uint), size_of(u8), size_of(u16), size_of(u32), size_of(u64), size_of(u128), size_of(uintptr))
            engine.ui_text("i16le: %v | i32le: %v | i64le: %v | i128le: %v | u16le: %v | u32le: %v | u64le:   %v | u128le: %v", size_of(i16le), size_of(i32le), size_of(i64le), size_of(i128le), size_of(u16le), size_of(u32le), size_of(u64le), size_of(u128le))
            engine.ui_text("i16be: %v | i32be: %v | i64be: %v | i128be: %v | u16be: %v | u32be: %v | u64be:   %v | u128be: %v", size_of(i16be), size_of(i32be), size_of(i64be), size_of(i128be), size_of(u16be), size_of(u32be), size_of(u64be), size_of(u128be))
            engine.ui_text("f16:   %v | f32:   %v | f64:   %v", size_of(f16), size_of(f32), size_of(f64))
            engine.ui_text("f16le: %v | f32le: %v | f64le: %v", size_of(f16le), size_of(f32le), size_of(f64le))
            engine.ui_text("f16be: %v | f32be: %v | f64be: %v", size_of(f16be), size_of(f32be), size_of(f64be))
            engine.ui_text("complex32:    %v | complex64:     %v | complex128:    %v", size_of(complex32), size_of(complex64), size_of(complex128))
            engine.ui_text("quaternion64: %v | quaternion128: %v | quaternion256: %v", size_of(quaternion64), size_of(quaternion128), size_of(quaternion256))
            engine.ui_text("rune:   %v", size_of(rune))
            engine.ui_text("string: %v | cstring: %v", size_of(string), size_of(cstring))
            engine.ui_text("rawptr: %v", size_of(rawptr))
            engine.ui_text("typeid: %v", size_of(typeid))
            engine.ui_text("any:    %v", size_of(any))
        }

        if engine.ui_collapsing_header("Frame") {
            frame_stat := engine.get_frame_stat()
            @(static) locked_fps_plot := engine.Statistic_Plot {}
            engine.ui_statistic_plots(&locked_fps_plot, frame_stat.fps, "fps", "%4.0f", 0, 1000)

            engine.ui_text("Refresh rate:   %vHz",    engine.get_refresh_rate())
            engine.ui_text("FPS:            %5.0f",   frame_stat.fps)
            engine.ui_text("Delta time:     %2.6fms", frame_stat.delta_time)
            engine.ui_text("CPU time:       %2.6fms", frame_stat.cpu_time)
            engine.ui_text("GPU time:       %2.6fms", frame_stat.gpu_time)
            engine.ui_text("Sleep time:     %2.6fms", frame_stat.sleep_time)
        }

        if engine.ui_collapsing_header("Renderer") {
            window_size := engine.get_window_size()
            engine.ui_text("window_size:        %v", window_size)
            engine.ui_text("pixel_density:      %v", engine.get_pixel_density())

            if engine.ui_tree_node(fmt.tprintf("sprites (%v)###sprites", _mem.game.render_command_sprites.count), { _mem.game.render_command_sprites.count > 10 ? .Selected : .DefaultOpen }) {
                for i := 0; i < _mem.game.render_command_sprites.count; i += 1 {
                    engine.ui_text("%4.0f | pos: ", f32(i))
                    engine.ui_same_line()
                    engine.ui_set_next_item_width(140)
                    engine.ui_input_float2(fmt.tprintf("###pos%v", i), cast(^[2]f32) &_mem.game.render_command_sprites.data[i].position)
                    engine.ui_same_line()
                    engine.ui_text("| color:")
                    engine.ui_same_line()
                    engine.ui_color_edit4(fmt.tprintf("###color%v", i), cast(^[4]f32) &_mem.game.render_command_sprites.data[i].color, { .NoInputs })
                    engine.ui_same_line()
                    engine.ui_text("| scale: %v", _mem.game.render_command_sprites.data[i].scale)
                    engine.ui_same_line()
                    engine.ui_text("| texture_position: %v", _mem.game.render_command_sprites.data[i].texture_position)
                    engine.ui_same_line()
                    engine.ui_text("| texture_size: %v", _mem.game.render_command_sprites.data[i].texture_size)
                    engine.ui_same_line()
                    engine.ui_text("| texture_index: %v", _mem.game.render_command_sprites.data[i].texture_index)
                }
            }

            if engine.ui_tree_node(fmt.tprintf("lines (%v)###lines", _mem.game.render_command_line.fs_uniform.points_count)) {
                engine.ui_text("%#v", _mem.game.render_command_line.fs_uniform)
            }

            if engine.ui_tree_node("camera: world", { .DefaultOpen }) {
                camera := &_mem.game.world_camera
                engine.ui_slider_float3("position", transmute(^[3]f32)&camera.position, -100, 100)
                engine.ui_same_line()
                if engine.ui_button("reset position") {
                    camera.position = {}
                }
                engine.ui_slider_float("rotation", &camera.rotation, 0, math.TAU)
                engine.ui_input_float("zoom", &camera.zoom)
                engine.ui_same_line()
                if engine.ui_button("Reset zoom") {
                    camera.zoom = CAMERA_ZOOM_INITIAL
                }
                if engine.ui_button("Reset camera") {
                    camera.position = {}
                    camera.zoom = CAMERA_ZOOM_INITIAL
                    camera.rotation = 0
                }
                if engine.ui_tree_node("projection_matrix") {
                    engine.ui_slider_float4("projection_matrix[0]", &camera.projection_matrix[0], -1, 1)
                    engine.ui_slider_float4("projection_matrix[1]", &camera.projection_matrix[1], -1, 1)
                    engine.ui_slider_float4("projection_matrix[2]", &camera.projection_matrix[2], -1, 1)
                    engine.ui_slider_float4("projection_matrix[3]", &camera.projection_matrix[3], -1, 1)
                }
                if engine.ui_tree_node("view_matrix") {
                    engine.ui_slider_float4("view_matrix[0]", &camera.view_matrix[0], -1, 1)
                    engine.ui_slider_float4("view_matrix[1]", &camera.view_matrix[1], -1, 1)
                    engine.ui_slider_float4("view_matrix[2]", &camera.view_matrix[2], -1, 1)
                    engine.ui_slider_float4("view_matrix[3]", &camera.view_matrix[3], -1, 1)
                }
                if engine.ui_tree_node("view_projection_matrix", { .DefaultOpen }) {
                    engine.ui_slider_float4_ex("view_projection_matrix[0]", &camera.view_projection_matrix[0], -1, 1, "%.3f", { .NoInput })
                    engine.ui_slider_float4_ex("view_projection_matrix[1]", &camera.view_projection_matrix[1], -1, 1, "%.3f", { .NoInput })
                    engine.ui_slider_float4_ex("view_projection_matrix[2]", &camera.view_projection_matrix[2], -1, 1, "%.3f", { .NoInput })
                    engine.ui_slider_float4_ex("view_projection_matrix[3]", &camera.view_projection_matrix[3], -1, 1, "%.3f", { .NoInput })
                }
            }
        }
    }
}

debug_ui_window_shader :: proc(open: ^bool) {
    if open^ == false {
        return
    }

    if engine.ui_window("Shader", open) {
        engine.ui_set_window_size_vec2({ 600, 800 }, .FirstUseEver)
        engine.ui_set_window_pos_vec2({ 50, 50 }, .FirstUseEver)

        columns := []string { "id", "file_name", "info", "actions" }
        if engine.ui_table(columns) {
            for asset in engine.asset_get_all() {
                if asset.type != .Shader {
                    continue
                }

                engine.ui_table_next_row()

                for column, i in columns {
                    engine.ui_table_set_column_index(i32(i))
                    switch column {
                        case "id": engine.ui_text("%v", asset.id)
                        case "state": engine.ui_text("%v", asset.state)
                        case "file_name": {
                            if asset.state == .Errored { engine.ui_push_style_color(.Text, { 1, 0.2, 0.2, 1 }) }
                            if asset.id == _mem.game.debug_ui_shader_asset_id { engine.ui_push_style_color(.Text, { 0.2, 1, 1, 1 }) }
                            engine.ui_text("%v", filepath.base(asset.file_name))
                            if asset.state == .Errored { engine.ui_pop_style_color(1) }
                            if asset.id == _mem.game.debug_ui_shader_asset_id { engine.ui_pop_style_color(1) }
                        }
                        case "info": {
                            if asset.state != .Loaded {
                                engine.ui_text("-")
                                continue
                            }
                            asset_info := asset.info.(engine.Asset_Info_Shader)
                            engine.ui_text("asset_info: %v, state: %v", asset_info, asset.state)
                        }
                        case "actions": {
                            engine.ui_push_id(i32(asset.id))
                            if engine.ui_button("Use") {
                                if asset.state == .Loaded {
                                    engine.asset_unload(asset.id)
                                }
                                engine.asset_load(asset.id)
                                _mem.game.debug_ui_shader_asset_id = asset.id
                            }
                            engine.ui_pop_id()
                        }
                        case: engine.ui_text("x")
                    }
                }
            }
        }

        engine.ui_push_item_width(500)

        engine.ui_input_int("shader_asset_id", transmute(^i32) &_mem.game.debug_ui_shader_asset_id)
    }
}

debug_ui_window_anim :: proc(open: ^bool) {
    if open^ == false {
        return
    }

    if engine.ui_window("Animations: Game", open) {
        engine.ui_set_window_size_vec2({ 1200, 150 }, .FirstUseEver)
        engine.ui_set_window_pos_vec2({ 700, 50 }, .FirstUseEver)

        if engine.ui_tree_node("Debug") {
            speed : f32 = 1
            engine.ui_slider_float("speed", &speed, 0, 10)

            @(static) progress : f32 = 0
            progress += engine.get_frame_stat().delta_time / 1000 * speed
            if progress > 1 {
                progress = 0
            }

            sprite_index : i8 = 0
            if engine.ui_tree_node("Sprite", { .DefaultOpen }) {
                animation_sprite := []engine.Animation_Step(i8) {
                    { t = 0.0, value = 0, },
                    { t = 0.2, value = 1, },
                    { t = 0.4, value = 2, },
                    { t = 0.6, value = 3, },
                    { t = 0.8, value = 4, },
                    { t = 1.0, value = 5, },
                }
                sprite_index = engine.animation_lerp_value(animation_sprite, progress)
                engine.ui_text("sprite_index:            %v", sprite_index)
                engine.ui_animation_plot("sprite_index", animation_sprite)
            }

            color := Vector4f32 { 1, 1, 1, 1 }
            if engine.ui_tree_node("Color") {
                animation_color := []engine.Animation_Step(Vector4f32) {
                    { t = 0.0, value = { 0.0, 0.0, 1.0, 1 } },
                    { t = 0.5, value = { 0.0, 1.0, 0.5, 1 } },
                    { t = 1.0, value = { 1.0, 1.0, 1.0, 1 } },
                }
                color = engine.animation_lerp_value(animation_color, progress)
                engine.ui_color_edit4("animation_color", transmute(^[4]f32)&color.r, {})
                engine.ui_animation_plot("animation_color", animation_color)
            }

            engine.ui_slider_float("progress", &progress, 0, 1)
        }
    }
}
