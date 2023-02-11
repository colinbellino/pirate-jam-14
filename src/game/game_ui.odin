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
        if ui.window(ctx, "Debug", rect_with_offset({ 40, 40, 350, 640 }, offset), { .NO_CLOSE }) {
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
            ui.label(ctx, "camera_position");
            ui.label(ctx, fmt.tprintf("%v", game_state.camera_position));
            ui.label(ctx, "mouse_screen_position");
            ui.label(ctx, fmt.tprintf("%v", game_state.mouse_screen_position));
            // ui.label(ctx, "mouse_room_position");
            // ui.label(ctx, fmt.tprintf("%v", game_state.mouse_room_position));
            ui.label(ctx, "mouse_grid_position");
            ui.label(ctx, fmt.tprintf("%v", game_state.mouse_grid_position));
            ui.label(ctx, "current_room_index");
            ui.label(ctx, fmt.tprintf("%v", game_state.current_room_index));

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
                if .SUBMIT in ui.button(ctx, "Start battle") {
                    start_battle(game_state);
                }
                ui.layout_row(ctx, { 170, -1 }, 0);
                ui.label(ctx, "Mode:");
                ui.label(ctx, fmt.tprintf("%v", world_data.battle_mode));
                if world_data.battle_mode == .Started {

                }
            }
        }
    }

    if game_state.debug_ui_window_console {
        if ui.window(ctx, "Logs", rect_with_offset({ 0, 0, renderer_state.rendering_size.x, 500 }, offset), { .NO_CLOSE }) {
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
        if (ui.window(ctx, "Entities", rect_with_offset({ 1240, 40, 320, 640 }, offset), { .NO_CLOSE })) {
            ui.layout_row(ctx, { 80, -1 }, 0);
            ui.label(ctx, "Party:");
            ui.label(ctx, fmt.tprintf("%v", game_state.party));
            ui.label(ctx, "Entities:");
            ui.layout_row(ctx, { 100, 80, -1 }, 0);
            for entity in game_state.entities {
                ui.push_id_uintptr(ctx, uintptr(entity));
                ui.label(ctx, fmt.tprintf("%v", format_entity(game_state, entity)));
                ui.label(ctx, fmt.tprintf("%v", game_state.components_position[entity].grid_position));
                if .SUBMIT in ui.button(ctx, "Inspect") {
                    game_state.debug_ui_entity = entity;
                }
                ui.pop_id(ctx);
            }
        }

        if game_state.debug_ui_entity != 0 {
            entity := game_state.debug_ui_entity;
            if ui.window(ctx, fmt.tprintf("Entity %v", entity), rect_with_offset({ 900, 40, 320, 640 }, offset), { .NO_CLOSE }) {
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

    if ui.window(ctx, "Title", rect_with_offset({ 600, 400, 320, 320 }, offset)) {
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
            entity_set_visibility(game_state, entity, true);
            log.debugf("%v added to the party.", format_entity(game_state, entity));
        }
    }
}
