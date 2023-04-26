package game

import "core:fmt"
import "core:log"
import "core:time"

import "../engine"

draw_debug_windows :: proc(app: ^engine.App, game: ^Game_State) {
    if game.debug_ui_window_info {
        if engine.ui_window(app.ui, "Debug", { 0, 0, 500, game.window_size.y }, { .NO_CLOSE }) {
            if .ACTIVE in engine.ui_header(app.ui, "Memory", { .EXPANDED }) {
                engine.ui_layout_row(app.ui, { 50, 50, 50, 50 }, 0);
                if .SUBMIT in engine.ui_button(app.ui, "Save 1") {
                    app.debug.save_memory = 1;
                }
                if .SUBMIT in engine.ui_button(app.ui, "Save 2") {
                    app.debug.save_memory = 2;
                }
                if .SUBMIT in engine.ui_button(app.ui, "Save 3") {
                    app.debug.save_memory = 3;
                }
                if .SUBMIT in engine.ui_button(app.ui, "Save 4") {
                    app.debug.save_memory = 4;
                }
                engine.ui_layout_row(app.ui, { 50, 50, 50, 50 }, 0);
                if .SUBMIT in engine.ui_button(app.ui, "Load 1") {
                    app.debug.load_memory = 1;
                }
                if .SUBMIT in engine.ui_button(app.ui, "Load 2") {
                    app.debug.load_memory = 2;
                }
                if .SUBMIT in engine.ui_button(app.ui, "Load 3") {
                    app.debug.load_memory = 3;
                }
                if .SUBMIT in engine.ui_button(app.ui, "Load 4") {
                    app.debug.load_memory = 4;
                }

                if .ACTIVE in engine.ui_header(app.ui, "Arenas", { .EXPANDED }) {
                    engine.ui_layout_row(app.ui, { 100, -1 }, 0);
                    engine.ui_label(app.ui, "app");
                    app_offset := app.engine_arena.offset + game.arena.offset;
                    app_length := len(app.engine_arena.data) + len(game.arena.data);
                    engine.ui_label(app.ui, engine.format_arena_usage(app_offset, app_length));
                    engine.ui_layout_row(app.ui, { -1 }, 0);
                    engine.ui_progress_bar(app.ui, f32(app_offset) / f32(app_length), 5);

                    engine.ui_layout_row(app.ui, { 100, -1 }, 0);
                    engine.ui_label(app.ui, "engine");
                    engine.ui_label(app.ui, engine.format_arena_usage(&app.engine_arena));
                    engine.ui_layout_row(app.ui, { -1 }, 0);
                    engine.ui_progress_bar(app.ui, f32(app.engine_arena.offset) / f32(len(app.engine_arena.data)), 5);

                    engine.ui_layout_row(app.ui, { 100, -1 }, 0);
                    engine.ui_label(app.ui, "game");
                    engine.ui_label(app.ui, engine.format_arena_usage(game.arena));
                    engine.ui_layout_row(app.ui, { -1 }, 0);
                    engine.ui_progress_bar(app.ui, f32(game.arena.offset) / f32(len(game.arena.data)), 5);

                    if .ACTIVE in engine.ui_treenode(app.ui, "", { .EXPANDED }) {
                        engine.ui_layout_row(app.ui, { 100, -1 }, 0);
                        engine.ui_label(app.ui, "game_mode");
                        engine.ui_label(app.ui, engine.format_arena_usage(&game.game_mode_arena));
                        engine.ui_progress_bar(app.ui, f32(game.game_mode_arena.offset) / f32(len(game.game_mode_arena.data)), 5);

                        if game.game_mode == .World {
                            world_data := cast(^Game_Mode_World) game.game_mode_data;

                            if world_data.initialized > .Default {
                                engine.ui_layout_row(app.ui, { 100, -1 }, 0);
                                engine.ui_label(app.ui, "world_mode");
                                engine.ui_label(app.ui, engine.format_arena_usage(&world_data.world_mode_arena));
                                engine.ui_layout_row(app.ui, { -1 }, 0);
                                engine.ui_progress_bar(app.ui, f32(world_data.world_mode_arena.offset) / f32(len(world_data.world_mode_arena.data)), 5);
                            }
                        }
                    }
                }
            }

            if .ACTIVE in engine.ui_header(app.ui, "Config", { .EXPANDED }) {
                engine.ui_layout_row(app.ui, { 170, -1 }, 0);
                engine.ui_label(app.ui, "Last code reload");
                engine.ui_label(app.ui, fmt.tprintf("%v", time.time_to_unix(app.debug.last_reload)));
                engine.ui_label(app.ui, "TRACY_ENABLE");
                engine.ui_label(app.ui, fmt.tprintf("%v", app.config.TRACY_ENABLE));
                engine.ui_label(app.ui, "HOT_RELOAD_CODE");
                engine.ui_label(app.ui, fmt.tprintf("%v", app.config.HOT_RELOAD_CODE));
                engine.ui_label(app.ui, "HOT_RELOAD_ASSETS");
                engine.ui_label(app.ui, fmt.tprintf("%v", app.config.HOT_RELOAD_ASSETS));
                engine.ui_label(app.ui, "ASSETS_PATH");
                engine.ui_label(app.ui, fmt.tprintf("%v", app.config.ASSETS_PATH));
            }

            if .ACTIVE in engine.ui_header(app.ui, "Assets", { .EXPANDED }) {
                engine.ui_layout_row(app.ui, { 30, 70, 50, 230, 40, 40 });
                engine.ui_label(app.ui, "id");
                engine.ui_label(app.ui, "state");
                engine.ui_label(app.ui, "type");
                engine.ui_label(app.ui, "filename");
                engine.ui_label(app.ui, " ");
                engine.ui_label(app.ui, " ");

                for i := 0; i < app.assets.assets_count; i += 1 {
                    asset := &app.assets.assets[i];
                    engine.ui_label(app.ui, fmt.tprintf("%v", asset.id));
                    engine.ui_label(app.ui, fmt.tprintf("%v", asset.state));
                    engine.ui_label(app.ui, fmt.tprintf("%v", asset.type));
                    engine.ui_label(app.ui, fmt.tprintf("%v", asset.file_name));
                    engine.ui_push_id_uintptr(app.ui, uintptr(asset.id));
                    if .SUBMIT in engine.ui_button(app.ui, "Load") {
                        engine.asset_load(app, asset.id);
                    }
                    if .SUBMIT in engine.ui_button(app.ui, "Unload") {
                        engine.asset_unload(app, asset.id);
                    }
                    engine.ui_pop_id(app.ui);
                }
            }

            if .ACTIVE in engine.ui_header(app.ui, "Watches", { .EXPANDED }) {
                for file_watch in app.debug.file_watches {
                    if file_watch.asset_id == 0 {
                        continue;
                    }
                    asset := &app.assets.assets[file_watch.asset_id];
                    engine.ui_layout_row(app.ui, { -1 });
                    engine.ui_label(app.ui, asset.file_name);
                }
            }

            if .ACTIVE in engine.ui_header(app.ui, "Platform", { .EXPANDED }) {
                engine.ui_layout_row(app.ui, { 170, -1 });
                engine.ui_label(app.ui, "mouse_position");
                engine.ui_label(app.ui, fmt.tprintf("%v", app.platform.mouse_position));
                engine.ui_label(app.ui, "unlock_framerate");
                engine.ui_label(app.ui, fmt.tprintf("%v", app.platform.unlock_framerate));

                if .ACTIVE in engine.ui_treenode(app.ui, "Inputs", { }) {
                    for player_index := 0; player_index < PLAYER_MAX; player_index += 1 {
                        if .ACTIVE in engine.ui_treenode(app.ui, fmt.tprintf("Player: %v", player_index), { .EXPANDED }) {
                            engine.ui_layout_row(app.ui, { 50, 50, -1 }, 0);
                            engine.ui_label(app.ui, "axis");
                            engine.ui_label(app.ui, "x");
                            engine.ui_label(app.ui, "y");
                            {
                                axis := game.player_inputs[player_index].move;
                                engine.ui_label(app.ui, "move");
                                engine.ui_label(app.ui, fmt.tprintf("%v", axis.x));
                                engine.ui_label(app.ui, fmt.tprintf("%v", axis.y));
                            }

                            engine.ui_layout_row(app.ui, { 50, 50, 50, 50, 50 }, 0);
                            engine.ui_label(app.ui, "key");
                            engine.ui_label(app.ui, "down");
                            engine.ui_label(app.ui, "up");
                            engine.ui_label(app.ui, "pressed");
                            engine.ui_label(app.ui, "released");
                            {
                                using game.player_inputs[player_index].confirm;
                                engine.ui_label(app.ui, "confirm");
                                engine.ui_label(app.ui, fmt.tprintf("%v", down));
                                engine.ui_label(app.ui, fmt.tprintf("%v", !down));
                                engine.ui_label(app.ui, fmt.tprintf("%v", pressed));
                                engine.ui_label(app.ui, fmt.tprintf("%v", released));
                            }
                            {
                                using game.player_inputs[player_index].cancel;
                                engine.ui_label(app.ui, "cancel");
                                engine.ui_label(app.ui, fmt.tprintf("%v", down));
                                engine.ui_label(app.ui, fmt.tprintf("%v", !down));
                                engine.ui_label(app.ui, fmt.tprintf("%v", pressed));
                                engine.ui_label(app.ui, fmt.tprintf("%v", released));
                            }
                        }
                    }
                }

                if .ACTIVE in engine.ui_treenode(app.ui, "Controllers", { }) {
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
                    };
                    axes := [] engine.GameControllerAxis {
                        // .INVALID = -1,
                        .LEFTX,
                        .LEFTY,
                        .RIGHTX,
                        .RIGHTY,
                        .TRIGGERLEFT,
                        .TRIGGERRIGHT,
                        // .MAX,
                    };

                    for joystick_id, controller_state in app.platform.controllers {
                        controller_name := engine.get_controller_name(controller_state.controller);
                        if .ACTIVE in engine.ui_treenode(app.ui, fmt.tprintf("%v (%v)", controller_name, joystick_id), { .EXPANDED }) {
                            engine.ui_layout_row(app.ui, { 90, 50, 50, 50, 50 });
                            engine.ui_label(app.ui, "key");
                            engine.ui_label(app.ui, "down");
                            engine.ui_label(app.ui, "up");
                            engine.ui_label(app.ui, "pressed");
                            engine.ui_label(app.ui, "released");
                            for key in keys {
                                engine.ui_label(app.ui, fmt.tprintf("%v", key));
                                engine.ui_label(app.ui, fmt.tprintf("%v", controller_state.buttons[key].down));
                                engine.ui_label(app.ui, fmt.tprintf("%v", !controller_state.buttons[key].down));
                                engine.ui_label(app.ui, fmt.tprintf("%v", controller_state.buttons[key].pressed));
                                engine.ui_label(app.ui, fmt.tprintf("%v", controller_state.buttons[key].released));
                            }

                            engine.ui_layout_row(app.ui, { 90, 50 });
                            engine.ui_label(app.ui, "axis");
                            engine.ui_label(app.ui, "value");
                            for axis in axes {
                                engine.ui_label(app.ui, fmt.tprintf("%v", axis));
                                engine.ui_label(app.ui, fmt.tprintf("%v", controller_state.axes[axis].value));
                            }
                        }
                    }
                }

                if .ACTIVE in engine.ui_treenode(app.ui, "Keyboard", { }) {
                    keys := [] engine.Scancode {
                        .UP,
                        .DOWN,
                        .LEFT,
                        .RIGHT,
                    };
                    engine.ui_layout_row(app.ui, { 50, 50, 50, 50, 50 }, 0);
                    engine.ui_label(app.ui, "key");
                    engine.ui_label(app.ui, "down");
                    engine.ui_label(app.ui, "up");
                    engine.ui_label(app.ui, "pressed");
                    engine.ui_label(app.ui, "released");
                    for key in keys {
                        engine.ui_label(app.ui, fmt.tprintf("%v", key));
                        engine.ui_label(app.ui, fmt.tprintf("%v", app.platform.keys[key].down));
                        engine.ui_label(app.ui, fmt.tprintf("%v", !app.platform.keys[key].down));
                        engine.ui_label(app.ui, fmt.tprintf("%v", app.platform.keys[key].pressed));
                        engine.ui_label(app.ui, fmt.tprintf("%v", app.platform.keys[key].released));
                    }
                }
            }

            if .ACTIVE in engine.ui_header(app.ui, "Renderer", { .EXPANDED }) {
                engine.ui_layout_row(app.ui, { 170, -1 }, 0);
                engine.ui_label(app.ui, "update_rate");
                engine.ui_label(app.ui, fmt.tprintf("%v", app.platform.update_rate));
                engine.ui_label(app.ui, "display_dpi");
                engine.ui_label(app.ui, fmt.tprintf("%v", app.renderer.display_dpi));
                engine.ui_label(app.ui, "rendering_size");
                engine.ui_label(app.ui, fmt.tprintf("%v", app.renderer.rendering_size));
                engine.ui_label(app.ui, "rendering_scale");
                engine.ui_label(app.ui, fmt.tprintf("%v", app.renderer.rendering_scale));
                engine.ui_layout_row(app.ui, { 50, 50, 50, 50, 50, 50, 50, 50 }, 0);
                scales := []i32 { 1, 2, 3, 4, 5, 6 };
                for scale in scales {
                    if .SUBMIT in engine.ui_button(app.ui, fmt.tprintf("x%i", scale)) {
                        log.debugf("Set rendering_scale: %v", scale);
                        app.renderer.rendering_scale = scale;
                        update_rendering_offset(app.renderer, game);
                    }
                }
                engine.ui_layout_row(app.ui, { 170, -1 }, 0);
                engine.ui_label(app.ui, "rendering_offset");
                engine.ui_label(app.ui, fmt.tprintf("%v", app.renderer.rendering_offset));
                engine.ui_label(app.ui, "textures");
                engine.ui_label(app.ui, fmt.tprintf("%v", len(app.renderer.textures)));
            }

            if .ACTIVE in engine.ui_header(app.ui, "Game", { .EXPANDED }) {
                engine.ui_layout_row(app.ui, { 170, -1 }, 0);
                engine.ui_label(app.ui, "version");
                engine.ui_label(app.ui, game.version);
                engine.ui_label(app.ui, "window_size");
                engine.ui_label(app.ui, fmt.tprintf("%v", game.window_size));
                engine.ui_label(app.ui, "draw_letterbox");
                engine.ui_label(app.ui, fmt.tprintf("%v", game.draw_letterbox));
                engine.ui_label(app.ui, "mouse_screen_position");
                engine.ui_label(app.ui, fmt.tprintf("%v", game.mouse_screen_position));
                engine.ui_label(app.ui, "mouse_grid_position");
                engine.ui_label(app.ui, fmt.tprintf("%v", game.mouse_grid_position));
                engine.ui_label(app.ui, "current_room_index");
                engine.ui_label(app.ui, fmt.tprintf("%v", game.current_room_index));
                engine.ui_label(app.ui, "party");
                engine.ui_label(app.ui, fmt.tprintf("%v", game.party));

                if game.game_mode == .World {
                    world_data := cast(^Game_Mode_World) game.game_mode_data;

                    if world_data.initialized > .Default {
                        if .ACTIVE in engine.ui_treenode(app.ui, "World", { .EXPANDED }) {
                            engine.ui_layout_row(app.ui, { 170, -1 });
                            engine.ui_label(app.ui, "world_mode");
                            engine.ui_label(app.ui, fmt.tprintf("%v", world_data.world_mode));
                        }
                    }
                }
            }
        }
    }

    if game.debug_ui_window_console > 0 {
        height : i32 = 340;
        // if game.debug_ui_window_console == 2 {
        //     height = game.window_size.y - 103;
        // }
        if engine.ui_window(app.ui, "Logs", { 0, 0, game.window_size.x, height }, { .NO_CLOSE, .NO_RESIZE }) {
            engine.ui_layout_row(app.ui, { -1 }, -28);

            if app.logger != nil {
                engine.ui_panel_begin(app.ui, "Log");
                engine.ui_layout_row(app.ui, { -1 }, -1);
                lines := app.logger.lines;
                ctx := engine.ui_get_context(app.ui);
                color := ctx.style.colors[.TEXT];
                for line in lines {
                    height := ctx.text_height(ctx.style.font);
                    RESET     :: engine.Color { 255, 255, 255, 255 };
                    RED       :: engine.Color { 230, 0, 0, 255 };
                    YELLOW    :: engine.Color { 230, 230, 0, 255 };
                    DARK_GREY :: engine.Color { 150, 150, 150, 255 };

                    text_color := RESET;
                    switch line.level {
                        case .Debug:            text_color = DARK_GREY;
                        case .Info:             text_color = RESET;
                        case .Warning:          text_color = YELLOW;
                        case .Error, .Fatal:    text_color = RED;
                    }

                    ctx.style.colors[.TEXT] = engine.cast_color(text_color);
                    engine.ui_layout_row(app.ui, { -1 }, height);
                    engine.ui_text(app.ui, line.text);
                }
                ctx.style.colors[.TEXT] = color;
                if app.logger.buffer_updated {
                    panel := engine.ui_get_current_container(app.ui, );
                    panel.scroll.y = panel.content_size.y;
                    app.logger.buffer_updated = false;
                }
                engine.ui_panel_end(app.ui);

                // @static buf: [128]byte;
                // @static buf_len: int;
                // submitted := false;
                // engine.ui_layout_row(app.ui, { -70, -1 });
                // if .SUBMIT in engine.ui_textbox(app.ui, buf[:], &buf_len) {
                //     engine.ui_set_focus(app.ui, ctx.last_id);
                //     submitted = true;
                // }
                // if .SUBMIT in engine.ui_button(app.ui, "Submit") {
                //     submitted = true;
                // }
                // if submitted {
                //     str := string(buf[:buf_len]);
                //     log.debug(str);
                //     buf_len = 0;
                //     run_debug_command(game, str);
                // }
            }
        }
    }

    if game.debug_ui_window_entities {
        if engine.ui_window(app.ui, "Entities", { game.window_size.x - 360, 0, 360, 640 }, { .NO_CLOSE }) {
            engine.ui_layout_row(app.ui, { 160, -1 }, 0);

            engine.ui_label(app.ui, "entities");
            engine.ui_label(app.ui, fmt.tprintf("%v", len(game.entities.entities)));

            engine.ui_layout_row(app.ui, { 160, -1 }, 0);
            engine.ui_checkbox(app.ui, "Show room only", &game.debug_ui_room_only);

            engine.ui_layout_row(app.ui, { 160, -1 }, 0);
            engine.ui_checkbox(app.ui, "Hide tiles", &game.debug_ui_no_tiles);

            engine.ui_layout_row(app.ui, { 160, -1 }, 0);
            for entity in game.entities.entities {
                component_flag, has_flag := game.entities.components_flag[entity];
                if game.debug_ui_no_tiles && has_flag && .Tile in component_flag.value {
                    continue;
                }

                component_world_info, has_world_info := game.entities.components_world_info[entity];
                if game.debug_ui_room_only && (has_world_info != true || component_world_info.room_index != game.current_room_index) {
                    continue;
                }

                engine.ui_push_id_uintptr(app.ui, uintptr(entity));
                engine.ui_label(app.ui, fmt.tprintf("%v", entity_format(entity, &game.entities)));
                if .SUBMIT in engine.ui_button(app.ui, "Inspect") {
                    if game.debug_ui_entity == entity {
                        game.debug_ui_entity = 0;
                    } else {
                        game.debug_ui_entity = entity;
                    }
                }
                engine.ui_pop_id(app.ui);
            }
        }

        if game.debug_ui_entity != 0 {
            entity := game.debug_ui_entity;
            if engine.ui_window(app.ui, fmt.tprintf("Entity %v", entity), { game.window_size.x - 360 - 360, 0, 360, 640 }, { .NO_CLOSE }) {
                component_name, has_name := game.entities.components_name[entity];
                if has_name {
                    if .ACTIVE in engine.ui_header(app.ui, "Component_Name", { .EXPANDED }) {
                        engine.ui_layout_row(app.ui, { 120, -1 }, 0);
                        engine.ui_label(app.ui, "name");
                        engine.ui_label(app.ui, component_name.name);
                    }
                }

                component_world_info, has_world_info := game.entities.components_world_info[entity];
                if has_world_info {
                    if .ACTIVE in engine.ui_header(app.ui, "Component_World_Info", { .EXPANDED }) {
                        engine.ui_layout_row(app.ui, { 120, -1 }, 0);
                        engine.ui_label(app.ui, "room_index");
                        engine.ui_label(app.ui, fmt.tprintf("%v", component_world_info.room_index));
                    }
                }

                component_position, has_position := game.entities.components_position[entity];
                if has_position {
                    if .ACTIVE in engine.ui_header(app.ui, "Component_Position", { .EXPANDED }) {
                        engine.ui_layout_row(app.ui, { 120, -1 }, 0);
                        engine.ui_label(app.ui, "grid_position");
                        engine.ui_label(app.ui, fmt.tprintf("%v", component_position.grid_position));
                        engine.ui_label(app.ui, "world_position");
                        engine.ui_label(app.ui, fmt.tprintf("%v", component_position.world_position));
                    }
                }

                component_rendering, has_rendering := game.entities.components_rendering[entity];
                if has_rendering {
                    if .ACTIVE in engine.ui_header(app.ui, "Component_Rendering", { .EXPANDED }) {
                        engine.ui_layout_row(app.ui, { 120, -1 }, 0);
                        engine.ui_label(app.ui, "visible");
                        engine.ui_label(app.ui, fmt.tprintf("%v", component_rendering.visible));
                        engine.ui_label(app.ui, "texture_asset");
                        engine.ui_label(app.ui, fmt.tprintf("%v", component_rendering.texture_asset));
                        engine.ui_label(app.ui, "texture_position");
                        engine.ui_label(app.ui, fmt.tprintf("%v", component_rendering.texture_position));
                        engine.ui_label(app.ui, "texture_size");
                        engine.ui_label(app.ui, fmt.tprintf("%v", component_rendering.texture_size));
                    }
                }

                component_z_index, has_z_index := game.entities.components_z_index[entity];
                if has_z_index {
                    if .ACTIVE in engine.ui_header(app.ui, "Component_Z_Index", { .EXPANDED }) {
                        engine.ui_layout_row(app.ui, { 120, -1 }, 0);
                        engine.ui_label(app.ui, "z_index");
                        engine.ui_label(app.ui, fmt.tprintf("%v", component_z_index.z_index));
                    }
                }

                component_animation, has_animation := game.entities.components_animation[entity];
                if has_animation {
                    if .ACTIVE in engine.ui_header(app.ui, "Component_Animation", { .EXPANDED }) {
                        engine.ui_layout_row(app.ui, { 120, -1 }, 0);
                        engine.ui_label(app.ui, "current_frame");
                        engine.ui_label(app.ui, fmt.tprintf("%v", component_animation.current_frame));
                    }
                }

                component_flag, has_flag := game.entities.components_flag[entity];
                if has_flag {
                    if .ACTIVE in engine.ui_header(app.ui, "Component_Flag", { .EXPANDED }) {
                        engine.ui_layout_row(app.ui, { 120, -1 }, 0);
                        engine.ui_label(app.ui, "value");
                        engine.ui_label(app.ui, fmt.tprintf("%v", component_flag.value));
                    }
                }

                component_battle_info, has_battle_info := game.entities.components_battle_info[entity];
                if has_battle_info {
                    if .ACTIVE in engine.ui_header(app.ui, "Component_Battle_Info", { .EXPANDED }) {
                        engine.ui_layout_row(app.ui, { 120, -1 }, 0);
                        engine.ui_label(app.ui, "charge_time");
                        engine.ui_label(app.ui, fmt.tprintf("%v", component_battle_info.charge_time));
                    }
                }
            }
        }
    }

    if game.debug_ui_show_tiles {
        // engine.draw_timers(debug, app.renderer, TARGET_FPS, game.window_size);
    }
}

ui_input_mouse_down :: proc(ui: ^engine.UI_State, mouse_position: Vector2i, button: u8) {
    switch button {
        case engine.BUTTON_LEFT:   engine.ui_input_mouse_down(ui, mouse_position.x, mouse_position.y, .LEFT);
        case engine.BUTTON_MIDDLE: engine.ui_input_mouse_down(ui, mouse_position.x, mouse_position.y, .MIDDLE);
        case engine.BUTTON_RIGHT:  engine.ui_input_mouse_down(ui, mouse_position.x, mouse_position.y, .RIGHT);
    }
}
ui_input_mouse_up :: proc(ui: ^engine.UI_State, mouse_position: Vector2i, button: u8) {
    switch button {
        case engine.BUTTON_LEFT:   engine.ui_input_mouse_up(ui, mouse_position.x, mouse_position.y, .LEFT);
        case engine.BUTTON_MIDDLE: engine.ui_input_mouse_up(ui, mouse_position.x, mouse_position.y, .MIDDLE);
        case engine.BUTTON_RIGHT:  engine.ui_input_mouse_up(ui, mouse_position.x, mouse_position.y, .RIGHT);
    }
}
ui_input_text :: engine.ui_input_text;
ui_input_scroll :: engine.ui_input_scroll;
ui_input_key_down :: proc(ui: ^engine.UI_State, keycode: engine.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    engine.ui_input_key_down(ui, .SHIFT);
        case .RSHIFT:    engine.ui_input_key_down(ui, .SHIFT);
        case .LCTRL:     engine.ui_input_key_down(ui, .CTRL);
        case .RCTRL:     engine.ui_input_key_down(ui, .CTRL);
        case .LALT:      engine.ui_input_key_down(ui, .ALT);
        case .RALT:      engine.ui_input_key_down(ui, .ALT);
        case .RETURN:    engine.ui_input_key_down(ui, .RETURN);
        case .KP_ENTER:  engine.ui_input_key_down(ui, .RETURN);
        case .BACKSPACE: engine.ui_input_key_down(ui, .BACKSPACE);
    }
}
ui_input_key_up :: proc(ui: ^engine.UI_State, keycode: engine.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    engine.ui_input_key_up(ui, .SHIFT);
        case .RSHIFT:    engine.ui_input_key_up(ui, .SHIFT);
        case .LCTRL:     engine.ui_input_key_up(ui, .CTRL);
        case .RCTRL:     engine.ui_input_key_up(ui, .CTRL);
        case .LALT:      engine.ui_input_key_up(ui, .ALT);
        case .RALT:      engine.ui_input_key_up(ui, .ALT);
        case .RETURN:    engine.ui_input_key_up(ui, .RETURN);
        case .KP_ENTER:  engine.ui_input_key_up(ui, .RETURN);
        case .BACKSPACE: engine.ui_input_key_up(ui, .BACKSPACE);
    }
}
