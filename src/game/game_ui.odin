package game

import "core:fmt"
import "core:log"
import "core:time"

import "../engine"

draw_debug_windows :: proc(app: ^engine.App, game_state: ^Game_State) {
    platform_state := app.platform_state;
    renderer_state := app.renderer_state;
    logger_state := app.logger_state;
    debug_state := app.debug_state;

    if game_state.debug_ui_window_info {
        if engine.ui_window(renderer_state, "Debug", { 0, 0, 500, game_state.window_size.y }, { .NO_CLOSE }) {

            if .ACTIVE in engine.ui_header(renderer_state, "Memory", { .EXPANDED }) {
                engine.ui_layout_row(renderer_state, { 50, 50, 50, 50 }, 0);
                if .SUBMIT in engine.ui_button(renderer_state, "Save 1") {
                    app.save_memory = 1;
                }
                if .SUBMIT in engine.ui_button(renderer_state, "Save 2") {
                    app.save_memory = 2;
                }
                if .SUBMIT in engine.ui_button(renderer_state, "Save 3") {
                    app.save_memory = 3;
                }
                if .SUBMIT in engine.ui_button(renderer_state, "Save 4") {
                    app.save_memory = 4;
                }
                engine.ui_layout_row(renderer_state, { 50, 50, 50, 50 }, 0);
                if .SUBMIT in engine.ui_button(renderer_state, "Load 1") {
                    app.load_memory = 1;
                }
                if .SUBMIT in engine.ui_button(renderer_state, "Load 2") {
                    app.load_memory = 2;
                }
                if .SUBMIT in engine.ui_button(renderer_state, "Load 3") {
                    app.load_memory = 3;
                }
                if .SUBMIT in engine.ui_button(renderer_state, "Load 4") {
                    app.load_memory = 4;
                }

                if .ACTIVE in engine.ui_header(renderer_state, "Arenas", { .EXPANDED }) {
                    engine.ui_layout_row(renderer_state, { -1 }, 0);
                    if .ACTIVE in engine.ui_treenode(renderer_state, "app", { .EXPANDED }) {
                        app_offset := platform_state.arena.offset + renderer_state.arena.offset + game_state.arena.offset;
                        app_length := len(platform_state.arena.data) + len(renderer_state.arena.data) + len(game_state.arena.data);
                        engine.ui_label(renderer_state, engine.format_arena_usage(app_offset, app_length));
                        engine.ui_progress_bar(renderer_state, f32(app_offset) / f32(app_length), 5);
                    }
                    if .ACTIVE in engine.ui_treenode(renderer_state, "platform", { .EXPANDED }) {
                        engine.ui_label(renderer_state, engine.format_arena_usage(platform_state.arena));
                        engine.ui_progress_bar(renderer_state, f32(platform_state.arena.offset) / f32(len(platform_state.arena.data)), 5);
                    }
                    if .ACTIVE in engine.ui_treenode(renderer_state, "renderer", { .EXPANDED }) {
                        engine.ui_label(renderer_state, engine.format_arena_usage(renderer_state.arena));
                        engine.ui_progress_bar(renderer_state, f32(renderer_state.arena.offset) / f32(len(renderer_state.arena.data)), 5);
                    }
                    if .ACTIVE in engine.ui_treenode(renderer_state, "game", { .EXPANDED }) {
                        engine.ui_label(renderer_state, engine.format_arena_usage(game_state.arena));
                        engine.ui_progress_bar(renderer_state, f32(game_state.arena.offset) / f32(len(game_state.arena.data)), 5);

                        if .ACTIVE in engine.ui_treenode(renderer_state, "game_mode", { .EXPANDED }) {
                            engine.ui_label(renderer_state, engine.format_arena_usage(&game_state.game_mode_arena));
                            engine.ui_progress_bar(renderer_state, f32(game_state.game_mode_arena.offset) / f32(len(game_state.game_mode_arena.data)), 5);

                            if game_state.game_mode == .World {
                                world_data := cast(^Game_Mode_World) game_state.game_mode_data;

                                if world_data.initialized > .Default {
                                    if .ACTIVE in engine.ui_treenode(renderer_state, "world_mode", { .EXPANDED }) {
                                        engine.ui_label(renderer_state, engine.format_arena_usage(&world_data.world_mode_arena));
                                        engine.ui_progress_bar(renderer_state, f32(world_data.world_mode_arena.offset) / f32(len(world_data.world_mode_arena.data)), 5);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if .ACTIVE in engine.ui_header(renderer_state, "Config", { .EXPANDED }) {
                engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
                engine.ui_label(renderer_state, "Last code reload");
                engine.ui_label(renderer_state, fmt.tprintf("%v", time.time_to_unix(app.debug_state.last_reload)));
                engine.ui_label(renderer_state, "PROFILER");
                engine.ui_label(renderer_state, fmt.tprintf("%v", app.config.PROFILER));
                engine.ui_label(renderer_state, "HOT_RELOAD_CODE");
                engine.ui_label(renderer_state, fmt.tprintf("%v", app.config.HOT_RELOAD_CODE));
                engine.ui_label(renderer_state, "HOT_RELOAD_ASSETS");
                engine.ui_label(renderer_state, fmt.tprintf("%v", app.config.HOT_RELOAD_ASSETS));
                engine.ui_label(renderer_state, "ASSETS_PATH");
                engine.ui_label(renderer_state, fmt.tprintf("%v", app.config.ASSETS_PATH));
            }

            if .ACTIVE in engine.ui_header(renderer_state, "Assets", { .EXPANDED }) {
                engine.ui_layout_row(renderer_state, { 30, 70, 50, 230, 40, 40 });
                engine.ui_label(renderer_state, "id");
                engine.ui_label(renderer_state, "state");
                engine.ui_label(renderer_state, "type");
                engine.ui_label(renderer_state, "filename");
                engine.ui_label(renderer_state, " ");
                engine.ui_label(renderer_state, " ");

                for i := 0; i < app.assets.assets_count; i += 1 {
                    asset := &app.assets.assets[i];
                    engine.ui_label(renderer_state, fmt.tprintf("%v", asset.id));
                    engine.ui_label(renderer_state, fmt.tprintf("%v", asset.state));
                    engine.ui_label(renderer_state, fmt.tprintf("%v", asset.type));
                    engine.ui_label(renderer_state, fmt.tprintf("%v", asset.file_name));
                    engine.ui_push_id_uintptr(renderer_state, uintptr(asset.id));
                    if .SUBMIT in engine.ui_button(renderer_state, "Load") {
                        engine.asset_load(app, asset.id);
                    }
                    if .SUBMIT in engine.ui_button(renderer_state, "Unload") {
                        engine.asset_unload(app, asset.id);
                    }
                    engine.ui_pop_id(renderer_state);
                }
            }

            if .ACTIVE in engine.ui_header(renderer_state, "Watches", { .EXPANDED }) {
                for file_watch in debug_state.file_watches {
                    if file_watch.asset_id == 0 {
                        continue;
                    }
                    asset := &app.assets.assets[file_watch.asset_id];
                    engine.ui_layout_row(renderer_state, { -1 });
                    engine.ui_label(renderer_state, asset.file_name);
                }
            }

            if .ACTIVE in engine.ui_header(renderer_state, "Platform", { .EXPANDED }) {
                engine.ui_layout_row(renderer_state, { 170, -1 });
                engine.ui_label(renderer_state, "mouse_position");
                engine.ui_label(renderer_state, fmt.tprintf("%v", platform_state.mouse_position));
                engine.ui_label(renderer_state, "unlock_framerate");
                engine.ui_label(renderer_state, fmt.tprintf("%v", platform_state.unlock_framerate));

                if .ACTIVE in engine.ui_treenode(renderer_state, "Inputs", { }) {
                    for player_index := 0; player_index < PLAYER_MAX; player_index += 1 {
                        if .ACTIVE in engine.ui_treenode(renderer_state, fmt.tprintf("Player: %v", player_index), { .EXPANDED }) {
                            engine.ui_layout_row(renderer_state, { 50, 50, -1 }, 0);
                            engine.ui_label(renderer_state, "axis");
                            engine.ui_label(renderer_state, "x");
                            engine.ui_label(renderer_state, "y");
                            {
                                axis := game_state.player_inputs[player_index].move;
                                engine.ui_label(renderer_state, "move");
                                engine.ui_label(renderer_state, fmt.tprintf("%v", axis.x));
                                engine.ui_label(renderer_state, fmt.tprintf("%v", axis.y));
                            }

                            engine.ui_layout_row(renderer_state, { 50, 50, 50, 50, 50 }, 0);
                            engine.ui_label(renderer_state, "key");
                            engine.ui_label(renderer_state, "down");
                            engine.ui_label(renderer_state, "up");
                            engine.ui_label(renderer_state, "pressed");
                            engine.ui_label(renderer_state, "released");
                            {
                                using game_state.player_inputs[player_index].confirm;
                                engine.ui_label(renderer_state, "confirm");
                                engine.ui_label(renderer_state, fmt.tprintf("%v", down));
                                engine.ui_label(renderer_state, fmt.tprintf("%v", !down));
                                engine.ui_label(renderer_state, fmt.tprintf("%v", pressed));
                                engine.ui_label(renderer_state, fmt.tprintf("%v", released));
                            }
                            {
                                using game_state.player_inputs[player_index].cancel;
                                engine.ui_label(renderer_state, "cancel");
                                engine.ui_label(renderer_state, fmt.tprintf("%v", down));
                                engine.ui_label(renderer_state, fmt.tprintf("%v", !down));
                                engine.ui_label(renderer_state, fmt.tprintf("%v", pressed));
                                engine.ui_label(renderer_state, fmt.tprintf("%v", released));
                            }
                        }
                    }
                }

                if .ACTIVE in engine.ui_treenode(renderer_state, "Controllers", { }) {
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

                    for joystick_id, controller_state in platform_state.controllers {
                        controller_name := engine.get_controller_name(controller_state.controller);
                        if .ACTIVE in engine.ui_treenode(renderer_state, fmt.tprintf("%v (%v)", controller_name, joystick_id), { .EXPANDED }) {
                            engine.ui_layout_row(renderer_state, { 90, 50, 50, 50, 50 });
                            engine.ui_label(renderer_state, "key");
                            engine.ui_label(renderer_state, "down");
                            engine.ui_label(renderer_state, "up");
                            engine.ui_label(renderer_state, "pressed");
                            engine.ui_label(renderer_state, "released");
                            for key in keys {
                                engine.ui_label(renderer_state, fmt.tprintf("%v", key));
                                engine.ui_label(renderer_state, fmt.tprintf("%v", controller_state.buttons[key].down));
                                engine.ui_label(renderer_state, fmt.tprintf("%v", !controller_state.buttons[key].down));
                                engine.ui_label(renderer_state, fmt.tprintf("%v", controller_state.buttons[key].pressed));
                                engine.ui_label(renderer_state, fmt.tprintf("%v", controller_state.buttons[key].released));
                            }

                            engine.ui_layout_row(renderer_state, { 90, 50 });
                            engine.ui_label(renderer_state, "axis");
                            engine.ui_label(renderer_state, "value");
                            for axis in axes {
                                engine.ui_label(renderer_state, fmt.tprintf("%v", axis));
                                engine.ui_label(renderer_state, fmt.tprintf("%v", controller_state.axes[axis].value));
                            }
                        }
                    }
                }

                if .ACTIVE in engine.ui_treenode(renderer_state, "Keyboard", { }) {
                    keys := [] engine.Scancode {
                        .UP,
                        .DOWN,
                        .LEFT,
                        .RIGHT,
                    };
                    engine.ui_layout_row(renderer_state, { 50, 50, 50, 50, 50 }, 0);
                    engine.ui_label(renderer_state, "key");
                    engine.ui_label(renderer_state, "down");
                    engine.ui_label(renderer_state, "up");
                    engine.ui_label(renderer_state, "pressed");
                    engine.ui_label(renderer_state, "released");
                    for key in keys {
                        engine.ui_label(renderer_state, fmt.tprintf("%v", key));
                        engine.ui_label(renderer_state, fmt.tprintf("%v", platform_state.keys[key].down));
                        engine.ui_label(renderer_state, fmt.tprintf("%v", !platform_state.keys[key].down));
                        engine.ui_label(renderer_state, fmt.tprintf("%v", platform_state.keys[key].pressed));
                        engine.ui_label(renderer_state, fmt.tprintf("%v", platform_state.keys[key].released));
                    }
                }
            }

            if .ACTIVE in engine.ui_header(renderer_state, "Renderer", { .EXPANDED }) {
                engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
                engine.ui_label(renderer_state, "update_rate");
                engine.ui_label(renderer_state, fmt.tprintf("%v", platform_state.update_rate));
                engine.ui_label(renderer_state, "display_dpi");
                engine.ui_label(renderer_state, fmt.tprintf("%v", renderer_state.display_dpi));
                engine.ui_label(renderer_state, "rendering_size");
                engine.ui_label(renderer_state, fmt.tprintf("%v", renderer_state.rendering_size));
                engine.ui_label(renderer_state, "rendering_scale");
                engine.ui_label(renderer_state, fmt.tprintf("%v", renderer_state.rendering_scale));
                engine.ui_layout_row(renderer_state, { 50, 50, 50, 50, 50, 50, 50, 50 }, 0);
                scales := []i32 { 1, 2, 3, 4, 5, 6 };
                for scale in scales {
                    if .SUBMIT in engine.ui_button(renderer_state, fmt.tprintf("x%i", scale)) {
                        log.debugf("Set rendering_scale: %v", scale);
                        renderer_state.rendering_scale = scale;
                        update_rendering_offset(renderer_state, game_state);
                    }
                }
                engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
                engine.ui_label(renderer_state, "rendering_offset");
                engine.ui_label(renderer_state, fmt.tprintf("%v", renderer_state.rendering_offset));
                engine.ui_label(renderer_state, "textures");
                engine.ui_label(renderer_state, fmt.tprintf("%v", len(renderer_state.textures)));
            }

            if .ACTIVE in engine.ui_header(renderer_state, "Game", { .EXPANDED }) {
                engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
                engine.ui_label(renderer_state, "version");
                engine.ui_label(renderer_state, game_state.version);
                engine.ui_label(renderer_state, "window_size");
                engine.ui_label(renderer_state, fmt.tprintf("%v", game_state.window_size));
                engine.ui_label(renderer_state, "draw_letterbox");
                engine.ui_label(renderer_state, fmt.tprintf("%v", game_state.draw_letterbox));
                engine.ui_label(renderer_state, "mouse_screen_position");
                engine.ui_label(renderer_state, fmt.tprintf("%v", game_state.mouse_screen_position));
                engine.ui_label(renderer_state, "mouse_grid_position");
                engine.ui_label(renderer_state, fmt.tprintf("%v", game_state.mouse_grid_position));
                engine.ui_label(renderer_state, "current_room_index");
                engine.ui_label(renderer_state, fmt.tprintf("%v", game_state.current_room_index));
                engine.ui_label(renderer_state, "party");
                engine.ui_label(renderer_state, fmt.tprintf("%v", game_state.party));

                if game_state.game_mode == .World {
                    world_data := cast(^Game_Mode_World) game_state.game_mode_data;

                    if world_data.initialized > .Default {
                        if .ACTIVE in engine.ui_treenode(renderer_state, "World", { .EXPANDED }) {
                            engine.ui_layout_row(renderer_state, { 170, -1 });
                            engine.ui_label(renderer_state, "world_mode");
                            engine.ui_label(renderer_state, fmt.tprintf("%v", world_data.world_mode));
                        }
                    }
                }
            }
        }
    }

    if game_state.debug_ui_window_console > 0 {
        height : i32 = 340;
        // if game_state.debug_ui_window_console == 2 {
        //     height = game_state.window_size.y - 103;
        // }
        if engine.ui_window(renderer_state, "Logs", { 0, 0, game_state.window_size.x, height }, { .NO_CLOSE, .NO_RESIZE }) {
            engine.ui_layout_row(renderer_state, { -1 }, -28);

            if logger_state != nil {
                engine.ui_panel_begin(renderer_state, "Log");
                engine.ui_layout_row(renderer_state, { -1 }, -1);
                lines := logger_state.lines;
                ctx := engine.ui_get_context(renderer_state);
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
                    engine.ui_layout_row(renderer_state, { -1 }, height);
                    engine.ui_text(renderer_state, line.text);
                }
                ctx.style.colors[.TEXT] = color;
                if logger_state.buffer_updated {
                    panel := engine.ui_get_current_container(renderer_state, );
                    panel.scroll.y = panel.content_size.y;
                    logger_state.buffer_updated = false;
                }
                engine.ui_panel_end(renderer_state);

                // @static buf: [128]byte;
                // @static buf_len: int;
                // submitted := false;
                // engine.ui_layout_row(renderer_state, { -70, -1 });
                // if .SUBMIT in engine.ui_textbox(renderer_state, buf[:], &buf_len) {
                //     engine.ui_set_focus(renderer_state, ctx.last_id);
                //     submitted = true;
                // }
                // if .SUBMIT in engine.ui_button(renderer_state, "Submit") {
                //     submitted = true;
                // }
                // if submitted {
                //     str := string(buf[:buf_len]);
                //     log.debug(str);
                //     buf_len = 0;
                //     run_debug_command(game_state, str);
                // }
            }
        }
    }

    if game_state.debug_ui_window_entities {
        if engine.ui_window(renderer_state, "Entities", { game_state.window_size.x - 360, 0, 360, 640 }, { .NO_CLOSE }) {
            engine.ui_layout_row(renderer_state, { 160, -1 }, 0);

            engine.ui_label(renderer_state, "entities");
            engine.ui_label(renderer_state, fmt.tprintf("%v", len(game_state.entities.entities)));

            engine.ui_layout_row(renderer_state, { 160, -1 }, 0);
            engine.ui_checkbox(renderer_state, "Show room only", &game_state.debug_ui_room_only);

            engine.ui_layout_row(renderer_state, { 160, -1 }, 0);
            engine.ui_checkbox(renderer_state, "Hide tiles", &game_state.debug_ui_no_tiles);

            engine.ui_layout_row(renderer_state, { 160, -1 }, 0);
            for entity in game_state.entities.entities {
                component_flag, has_flag := game_state.entities.components_flag[entity];
                if game_state.debug_ui_no_tiles && has_flag && .Tile in component_flag.value {
                    continue;
                }

                component_world_info, has_world_info := game_state.entities.components_world_info[entity];
                if game_state.debug_ui_room_only && (has_world_info != true || component_world_info.room_index != game_state.current_room_index) {
                    continue;
                }

                engine.ui_push_id_uintptr(renderer_state, uintptr(entity));
                engine.ui_label(renderer_state, fmt.tprintf("%v", entity_format(entity, &game_state.entities)));
                if .SUBMIT in engine.ui_button(renderer_state, "Inspect") {
                    if game_state.debug_ui_entity == entity {
                        game_state.debug_ui_entity = 0;
                    } else {
                        game_state.debug_ui_entity = entity;
                    }
                }
                engine.ui_pop_id(renderer_state);
            }
        }

        if game_state.debug_ui_entity != 0 {
            entity := game_state.debug_ui_entity;
            if engine.ui_window(renderer_state, fmt.tprintf("Entity %v", entity), { game_state.window_size.x - 360 - 360, 0, 360, 640 }, { .NO_CLOSE }) {
                component_name, has_name := game_state.entities.components_name[entity];
                if has_name {
                    if .ACTIVE in engine.ui_header(renderer_state, "Component_Name", { .EXPANDED }) {
                        engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                        engine.ui_label(renderer_state, "name");
                        engine.ui_label(renderer_state, component_name.name);
                    }
                }

                component_world_info, has_world_info := game_state.entities.components_world_info[entity];
                if has_world_info {
                    if .ACTIVE in engine.ui_header(renderer_state, "Component_World_Info", { .EXPANDED }) {
                        engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                        engine.ui_label(renderer_state, "room_index");
                        engine.ui_label(renderer_state, fmt.tprintf("%v", component_world_info.room_index));
                    }
                }

                component_position, has_position := game_state.entities.components_position[entity];
                if has_position {
                    if .ACTIVE in engine.ui_header(renderer_state, "Component_Position", { .EXPANDED }) {
                        engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                        engine.ui_label(renderer_state, "grid_position");
                        engine.ui_label(renderer_state, fmt.tprintf("%v", component_position.grid_position));
                        engine.ui_label(renderer_state, "world_position");
                        engine.ui_label(renderer_state, fmt.tprintf("%v", component_position.world_position));
                    }
                }

                component_rendering, has_rendering := game_state.entities.components_rendering[entity];
                if has_rendering {
                    if .ACTIVE in engine.ui_header(renderer_state, "Component_Rendering", { .EXPANDED }) {
                        engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                        engine.ui_label(renderer_state, "visible");
                        engine.ui_label(renderer_state, fmt.tprintf("%v", component_rendering.visible));
                        engine.ui_label(renderer_state, "texture_asset");
                        engine.ui_label(renderer_state, fmt.tprintf("%v", component_rendering.texture_asset));
                        engine.ui_label(renderer_state, "texture_position");
                        engine.ui_label(renderer_state, fmt.tprintf("%v", component_rendering.texture_position));
                        engine.ui_label(renderer_state, "texture_size");
                        engine.ui_label(renderer_state, fmt.tprintf("%v", component_rendering.texture_size));
                    }
                }

                component_z_index, has_z_index := game_state.entities.components_z_index[entity];
                if has_z_index {
                    if .ACTIVE in engine.ui_header(renderer_state, "Component_Z_Index", { .EXPANDED }) {
                        engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                        engine.ui_label(renderer_state, "z_index");
                        engine.ui_label(renderer_state, fmt.tprintf("%v", component_z_index.z_index));
                    }
                }

                component_animation, has_animation := game_state.entities.components_animation[entity];
                if has_animation {
                    if .ACTIVE in engine.ui_header(renderer_state, "Component_Animation", { .EXPANDED }) {
                        engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                        engine.ui_label(renderer_state, "current_frame");
                        engine.ui_label(renderer_state, fmt.tprintf("%v", component_animation.current_frame));
                    }
                }

                component_flag, has_flag := game_state.entities.components_flag[entity];
                if has_flag {
                    if .ACTIVE in engine.ui_header(renderer_state, "Component_Flag", { .EXPANDED }) {
                        engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                        engine.ui_label(renderer_state, "value");
                        engine.ui_label(renderer_state, fmt.tprintf("%v", component_flag.value));
                    }
                }

                component_battle_info, has_battle_info := game_state.entities.components_battle_info[entity];
                if has_battle_info {
                    if .ACTIVE in engine.ui_header(renderer_state, "Component_Battle_Info", { .EXPANDED }) {
                        engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                        engine.ui_label(renderer_state, "charge_time");
                        engine.ui_label(renderer_state, fmt.tprintf("%v", component_battle_info.charge_time));
                    }
                }
            }
        }
    }

    if game_state.debug_ui_show_tiles {
        // engine.draw_timers(debug_state, renderer_state, TARGET_FPS, game_state.window_size);
    }
}

ui_input_mouse_down :: proc(renderer_state: ^engine.Renderer_State, mouse_position: Vector2i, button: u8) {
    switch button {
        case engine.BUTTON_LEFT:   engine.ui_input_mouse_down(renderer_state, mouse_position.x, mouse_position.y, .LEFT);
        case engine.BUTTON_MIDDLE: engine.ui_input_mouse_down(renderer_state, mouse_position.x, mouse_position.y, .MIDDLE);
        case engine.BUTTON_RIGHT:  engine.ui_input_mouse_down(renderer_state, mouse_position.x, mouse_position.y, .RIGHT);
    }
}
ui_input_mouse_up :: proc(renderer_state: ^engine.Renderer_State, mouse_position: Vector2i, button: u8) {
    switch button {
        case engine.BUTTON_LEFT:   engine.ui_input_mouse_up(renderer_state, mouse_position.x, mouse_position.y, .LEFT);
        case engine.BUTTON_MIDDLE: engine.ui_input_mouse_up(renderer_state, mouse_position.x, mouse_position.y, .MIDDLE);
        case engine.BUTTON_RIGHT:  engine.ui_input_mouse_up(renderer_state, mouse_position.x, mouse_position.y, .RIGHT);
    }
}
ui_input_text :: engine.ui_input_text;
ui_input_scroll :: engine.ui_input_scroll;
ui_input_key_down :: proc(renderer_state: ^engine.Renderer_State, keycode: engine.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    engine.ui_input_key_down(renderer_state, .SHIFT);
        case .RSHIFT:    engine.ui_input_key_down(renderer_state, .SHIFT);
        case .LCTRL:     engine.ui_input_key_down(renderer_state, .CTRL);
        case .RCTRL:     engine.ui_input_key_down(renderer_state, .CTRL);
        case .LALT:      engine.ui_input_key_down(renderer_state, .ALT);
        case .RALT:      engine.ui_input_key_down(renderer_state, .ALT);
        case .RETURN:    engine.ui_input_key_down(renderer_state, .RETURN);
        case .KP_ENTER:  engine.ui_input_key_down(renderer_state, .RETURN);
        case .BACKSPACE: engine.ui_input_key_down(renderer_state, .BACKSPACE);
    }
}
ui_input_key_up :: proc(renderer_state: ^engine.Renderer_State, keycode: engine.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    engine.ui_input_key_up(renderer_state, .SHIFT);
        case .RSHIFT:    engine.ui_input_key_up(renderer_state, .SHIFT);
        case .LCTRL:     engine.ui_input_key_up(renderer_state, .CTRL);
        case .RCTRL:     engine.ui_input_key_up(renderer_state, .CTRL);
        case .LALT:      engine.ui_input_key_up(renderer_state, .ALT);
        case .RALT:      engine.ui_input_key_up(renderer_state, .ALT);
        case .RETURN:    engine.ui_input_key_up(renderer_state, .RETURN);
        case .KP_ENTER:  engine.ui_input_key_up(renderer_state, .RETURN);
        case .BACKSPACE: engine.ui_input_key_up(renderer_state, .BACKSPACE);
    }
}
