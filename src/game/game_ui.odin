package game

import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"
import "core:strconv"

import platform "../engine/platform"
import renderer "../engine/renderer"
import ui "../engine/renderer/ui"
import logger "../engine/logger"
import math "../engine/math"

draw_debug_windows :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^ui.UI_State,
    app_arena: ^mem.Arena,
) {
    ctx := &ui_state.ctx;
    offset := renderer_state.rendering_offset;

    if game_state.debug_ui_window_info {
        if ui_window(ctx, "Debug", { 0, 0, 360, 640 }, offset, &game_state.ui_hovered) {
            ui.layout_row(ctx, { -1 }, 0);
            ui.label(ctx, ":: Memory");
            ui.layout_row(ctx, { 170, -1 }, 0);
            ui.label(ctx, "app_arena");
            ui.label(ctx, format_arena_usage(app_arena));
            ui.label(ctx, "game_mode_arena");
            ui.label(ctx, format_arena_usage(game_state.game_mode_arena));

            ui.layout_row(ctx, { -1 }, 0);
            ui.label(ctx, ":: Game");
            ui.layout_row(ctx, { 170, -1 }, 0);
            ui.label(ctx, "version");
            ui.label(ctx, game_state.version);
            ui.label(ctx, "unlock_framerate");
            ui.label(ctx, fmt.tprintf("%v", game_state.unlock_framerate));
            ui.label(ctx, "window_size");
            ui.label(ctx, fmt.tprintf("%v", game_state.window_size));
            ui.label(ctx, "rendering_scale");
            ui.label(ctx, fmt.tprintf("%v", game_state.rendering_scale));
            ui.label(ctx, "draw_letterbox");
            ui.label(ctx, fmt.tprintf("%v", game_state.draw_letterbox));
            ui.label(ctx, "mouse_screen_position");
            ui.label(ctx, fmt.tprintf("%v", game_state.mouse_screen_position));
            ui.label(ctx, "mouse_grid_position");
            ui.label(ctx, fmt.tprintf("%v", game_state.mouse_grid_position));
            ui.label(ctx, "current_room_index");
            ui.label(ctx, fmt.tprintf("%v", game_state.current_room_index));
            ui.label(ctx, "party");
            ui.label(ctx, fmt.tprintf("%v", game_state.party));

            ui.layout_row(ctx, { -1 }, 0);
            ui.label(ctx, ":: Renderer");
            ui.layout_row(ctx, { 170, -1 }, 0);
            ui.label(ctx, "update_rate");
            ui.label(ctx, fmt.tprintf("%v", platform_state.update_rate));
            ui.label(ctx, "display_dpi");
            ui.label(ctx, fmt.tprintf("%v", renderer_state.display_dpi));
            ui.label(ctx, "rendering_size");
            ui.label(ctx, fmt.tprintf("%v", renderer_state.rendering_size));
            ui.label(ctx, "rendering_offset");
            ui.label(ctx, fmt.tprintf("%v", renderer_state.rendering_offset));
            ui.label(ctx, "textures");
            ui.label(ctx, fmt.tprintf("%v", len(renderer_state.textures)));

            if game_state.game_mode == .World {
                world_data := cast(^World_Data) game_state.game_mode_data;

                ui.layout_row(ctx, { -1 }, 0);
                ui.label(ctx, ":: Battle");
                ui.layout_row(ctx, { 170, -1 }, 0);
                ui.layout_row(ctx, { -1 }, 0);
                ui.layout_row(ctx, { 170, -1 }, 0);
                ui.label(ctx, "battle_mode");
                ui.label(ctx, fmt.tprintf("%v", world_data.battle_mode));
                ui.label(ctx, "battle_entities");
                ui.label(ctx, fmt.tprintf("%v", world_data.battle_entities));
                // if world_data.battle_mode == .None {
                //     if .SUBMIT in ui.button(ctx, "Start battle") {
                //         start_battle(game_state);
                //     }
                // }
            }
        }
    }

    if game_state.debug_ui_window_console > 0 {
        height : i32 = 240;
        // if game_state.debug_ui_window_console == 2 {
            height = game_state.window_size.y - 103;
        // }
        if ui_window(ctx, "Logs", { 0, 0, renderer_state.rendering_size.x, height }, offset, &game_state.ui_hovered, { .NO_CLOSE, .NO_RESIZE }) {
            ui.layout_row(ctx, { -1 }, -28);

            if logger_state != nil {
                ui.begin_panel(ctx, "Log");
                ui.layout_row(ctx, { -1 }, -1);
                lines := logger.read_all_lines();
                color := ctx.style.colors[.TEXT];
                for line in lines {
                    height := ctx.text_height(ctx.style.font);
                    RESET     :: ui.Color { 255, 255, 255, 255 };
                    RED       :: ui.Color { 230, 0, 0, 255 };
                    YELLOW    :: ui.Color { 230, 230, 0, 255 };
                    DARK_GREY :: ui.Color { 150, 150, 150, 255 };

                    color := RESET;
                    switch line.level {
                        case .Debug:            color = DARK_GREY;
                        case .Info:             color = RESET;
                        case .Warning:          color = YELLOW;
                        case .Error, .Fatal:    color = RED;
                    }

                    ctx.style.colors[.TEXT] = color;
                    ui.layout_row(ctx, { -1 }, height);
                    ui.text(ctx, line.text);
                }
                ctx.style.colors[.TEXT] = color;
                if logger_state.buffer_updated {
                    panel := ui.get_current_container(ctx);
                    panel.scroll.y = panel.content_size.y;
                    logger_state.buffer_updated = false;
                }
                ui.end_panel(ctx);

                @static buf: [128]byte;
                @static buf_len: int;
                submitted := false;
                ui.layout_row(ctx, { -70, -1 });
                if .SUBMIT in ui.textbox(ctx, buf[:], &buf_len) {
                    ui.set_focus(ctx, ctx.last_id);
                    submitted = true;
                }
                if .SUBMIT in ui.button(ctx, "Submit") {
                    submitted = true;
                }
                if submitted {
                    str := string(buf[:buf_len]);
                    log.debug(str);
                    buf_len = 0;
                    run_command(game_state, str);
                }
            }
        }
    }

    if game_state.debug_ui_window_entities {
        if ui_window(ctx, "Entities", { 1240, 0, 360, 640 }, offset, &game_state.ui_hovered) {
            ui.layout_row(ctx, { 160, -1 }, 0);
            ui.checkbox(ctx, "Room only", &game_state.debug_ui_room_only)

            ui.layout_row(ctx, { 160, -1 }, 0);
            for entity in game_state.entities {
                component_flag, has_flag := game_state.components_flag[entity];
                if has_flag && .Tile in component_flag.value {
                    continue;
                }

                component_world_info, has_world_info := game_state.components_world_info[entity];
                if game_state.debug_ui_room_only && (has_world_info == false || component_world_info.room_index != game_state.current_room_index) {
                    continue;
                }

                ui.push_id_uintptr(ctx, uintptr(entity));
                ui.label(ctx, fmt.tprintf("%v", entity_format(entity, game_state)));
                if .SUBMIT in ui.button(ctx, "Inspect") {
                    game_state.debug_ui_entity = entity;
                }
                ui.pop_id(ctx);
            }
        }

        if game_state.debug_ui_entity != 0 {
            entity := game_state.debug_ui_entity;
            if ui_window(ctx, fmt.tprintf("Entity %v", entity), { 900, 40, 320, 640 }, offset, &game_state.ui_hovered) {
                component_name, has_name := game_state.components_name[entity];
                if has_name {
                    ui.layout_row(ctx, { -1 }, 0);
                    ui.label(ctx, ":: Component_Name");
                    ui.layout_row(ctx, { 120, -1 }, 0);
                    ui.label(ctx, "name");
                    ui.label(ctx, component_name.name);
                }

                component_world_info, has_world_info := game_state.components_world_info[entity];
                if has_world_info {
                    ui.layout_row(ctx, { -1 }, 0);
                    ui.label(ctx, ":: Component_World_Info");
                    ui.layout_row(ctx, { 120, -1 }, 0);
                    ui.label(ctx, "room_index");
                    ui.label(ctx, fmt.tprintf("%v", component_world_info.room_index));
                }

                component_position, has_position := game_state.components_position[entity];
                if has_position {
                    ui.layout_row(ctx, { -1 }, 0);
                    ui.label(ctx, ":: Component_Position");
                    ui.layout_row(ctx, { 120, -1 }, 0);
                    ui.label(ctx, "grid_position");
                    ui.label(ctx, fmt.tprintf("%v", component_position.grid_position));
                    ui.label(ctx, "world_position");
                    ui.label(ctx, fmt.tprintf("%v", component_position.world_position));
                }

                component_rendering, has_rendering := game_state.components_rendering[entity];
                if has_rendering {
                    ui.layout_row(ctx, { -1 }, 0);
                    ui.label(ctx, ":: Component_Rendering");
                    ui.layout_row(ctx, { 120, -1 }, 0);
                    ui.label(ctx, "visible");
                    ui.label(ctx, fmt.tprintf("%v", component_rendering.visible));
                    ui.label(ctx, "texture_index");
                    ui.label(ctx, fmt.tprintf("%v", component_rendering.texture_index));
                    ui.label(ctx, "texture_position");
                    ui.label(ctx, fmt.tprintf("%v", component_rendering.texture_position));
                    ui.label(ctx, "texture_size");
                    ui.label(ctx, fmt.tprintf("%v", component_rendering.texture_size));
                }

                component_animation, has_animation := game_state.components_animation[entity];
                if has_animation {
                    ui.layout_row(ctx, { -1 }, 0);
                    ui.label(ctx, ":: Component_Animation");
                    ui.layout_row(ctx, { 120, -1 }, 0);
                    ui.label(ctx, "current_frame");
                    ui.label(ctx, fmt.tprintf("%v", component_animation.current_frame));
                }

                component_flag, has_flag := game_state.components_flag[entity];
                if has_flag {
                    ui.layout_row(ctx, { -1 }, 0);
                    ui.label(ctx, ":: Component_Flag");
                    ui.layout_row(ctx, { 120, -1 }, 0);
                    ui.label(ctx, "value");
                    ui.label(ctx, fmt.tprintf("%v", component_flag.value));
                }
            }
        }
    }
}

draw_title_menu :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^ui.UI_State,
    app_arena: ^mem.Arena,
) {
    ctx := &ui_state.ctx;
    offset := renderer_state.rendering_offset;

    if ui_window(ctx, "Title", { 600, 400, 320, 320 }, offset, &game_state.ui_hovered) {
        if .SUBMIT in ui.button(ctx, "Start") {
            start_game(game_state);
        }
        if .SUBMIT in ui.button(ctx, "Quit") {
            quit_game(platform_state);
        }
    }
}

rect_with_offset :: proc(rect: ui.Rect, offset: math.Vector2i) -> ui.Rect {
    return { rect.x + offset.x, rect.y + offset.y, rect.w, rect.h };
}

run_command :: proc(game_state: ^Game_State, command: string) {
    if command == "load" {
        load_texture("./media/art/placeholder_0.png");
    }

    if command == "rainbow" {
        log.debug("THIS IS A DEBUG");
        log.info("THIS IS AN INFO");
        log.warn("THIS IS A WARNING");
        log.error("THIS IS AN ERROR");
    }

    if command == "size" {
        log.debugf("SIZE: bool: %v b8: %v b16: %v b32: %v b64: %v", size_of(bool), size_of(b8), size_of(b16), size_of(b32), size_of(b64));
        log.debugf("SIZE: int: %v i8: %v i16: %v i32: %v i64: %v i128: %v", size_of(int), size_of(i8), size_of(i16), size_of(i32), size_of(i64), size_of(i128));
        log.debugf("SIZE: uint: %v u8: %v u16: %v u32: %v u64: %v u128: %v uintptr: %v", size_of(uint), size_of(u8), size_of(u16), size_of(u32), size_of(u64), size_of(u128), size_of(uintptr));
        log.debugf("SIZE: f16: %v f32: %v f64: %v", size_of(f16), size_of(f32), size_of(f64));
        log.debugf("SIZE: complex32: %v complex64: %v complex128: %v", size_of(complex32), size_of(complex64), size_of(complex128));
        log.debugf("SIZE: quaternion64: %v quaternion128: %v quaternion256: %v", size_of(quaternion64), size_of(quaternion128), size_of(quaternion256));
    }

    if strings.has_prefix(command, "add_to_party") {
        parts := strings.split(command, " ");
        id, parse_error := strconv.parse_int(parts[1]);
        if parse_error == false {
            entity := Entity(id);
            add_to_party(game_state, entity);
            entity_set_visibility(entity, true, game_state);
            log.debugf("%v added to the party.", entity_format(entity, game_state));
        }
    }
}

ui_input_mouse_move :: proc(x: i32, y: i32) {
    // log.debugf("mouse_move: %v,%v", x, y);
    ui.input_mouse_move(x, y);
}
ui_input_mouse_down :: proc(x: i32, y: i32, button: u8) {
    switch button {
        case platform.BUTTON_LEFT:   ui.input_mouse_down(x, y, .LEFT);
        case platform.BUTTON_MIDDLE: ui.input_mouse_down(x, y, .MIDDLE);
        case platform.BUTTON_RIGHT:  ui.input_mouse_down(x, y, .RIGHT);
    }
}
ui_input_mouse_up :: proc(x: i32, y: i32, button: u8) {
    switch button {
        case platform.BUTTON_LEFT:   ui.input_mouse_up(x, y, .LEFT);
        case platform.BUTTON_MIDDLE: ui.input_mouse_up(x, y, .MIDDLE);
        case platform.BUTTON_RIGHT:  ui.input_mouse_up(x, y, .RIGHT);
    }
}
ui_input_text :: ui.input_text;
ui_input_scroll :: ui.input_scroll;
ui_input_key_down :: proc(keycode: platform.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    ui.input_key_down(.SHIFT);
        case .RSHIFT:    ui.input_key_down(.SHIFT);
        case .LCTRL:     ui.input_key_down(.CTRL);
        case .RCTRL:     ui.input_key_down(.CTRL);
        case .LALT:      ui.input_key_down(.ALT);
        case .RALT:      ui.input_key_down(.ALT);
        case .RETURN:    ui.input_key_down(.RETURN);
        case .KP_ENTER:  ui.input_key_down(.RETURN);
        case .BACKSPACE: ui.input_key_down(.BACKSPACE);
    }
}
ui_input_key_up :: proc(keycode: platform.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    ui.input_key_up(.SHIFT);
        case .RSHIFT:    ui.input_key_up(.SHIFT);
        case .LCTRL:     ui.input_key_up(.CTRL);
        case .RCTRL:     ui.input_key_up(.CTRL);
        case .LALT:      ui.input_key_up(.ALT);
        case .RALT:      ui.input_key_up(.ALT);
        case .RETURN:    ui.input_key_up(.RETURN);
        case .KP_ENTER:  ui.input_key_up(.RETURN);
        case .BACKSPACE: ui.input_key_up(.BACKSPACE);
    }
}

@(deferred_in_out=ui_scoped_end_window)
ui_window :: proc(ctx: ^ui.Context, title: string, rect: ui.Rect, render_offset: Vector2i, hovered: ^bool, opt := ui.Options { .NO_CLOSE }) -> bool {
    real_rect := rect_with_offset(rect, render_offset);
    opened := ui.begin_window(ctx, title, real_rect, opt);
    if ui.mouse_over(ctx, real_rect) {
        hovered^ = true;
    }
    return opened;
}

@(private="file")
ui_scoped_end_window :: proc(ctx: ^ui.Context, title: string, rect: ui.Rect, offset: Vector2i, hovered: ^bool, opt: ui.Options, opened: bool) {
    ui.scoped_end_window(ctx, title, rect, opt, opened);
}
