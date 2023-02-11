package game

import "core:fmt"
import "core:log"
import "core:mem"

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

    if game_state.show_menu_1 {
        if ui.window(ctx, "Debug", rect_with_offset({ 40, 40, 320, 640 }, offset)) {
            ui.layout_row(ctx, {80, -1}, 0);
            ui.label(ctx, "App arena:");
            ui.label(ctx, format_arena_usage(app_arena));
            ui.label(ctx, "Game mode:");
            ui.label(ctx, format_arena_usage(game_state.game_mode_arena));
            ui.label(ctx, "Textures:");
            ui.label(ctx, fmt.tprintf("%v", len(renderer_state.textures)));
            ui.label(ctx, "Version:");
            ui.label(ctx, game_state.version);
            ui.label(ctx, "Target FPS:");
            ui.label(ctx, fmt.tprintf("%v", platform_state.update_rate));
        }
    }

    if game_state.show_menu_2 {
        if ui.window(ctx, "Logs", rect_with_offset({ 0, 0, renderer_state.rendering_size.x, 500 }, offset)) {
            ui.layout_row(ctx, {-1}, -28);

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

    if game_state.show_menu_3 {
        if ui.window(ctx, "Entities", rect_with_offset({ 1240, 40, 320, 640 }, offset)) {
            ui.layout_row(ctx, {80, -1}, 0);
            ui.label(ctx, "Party:");
            ui.label(ctx, fmt.tprintf("%v", game_state.party));
            ui.label(ctx, "Entities:");
            ui.layout_row(ctx, {100, 80, -1}, 0);
            for entity in game_state.entities {
                ui.push_id_uintptr(ctx, uintptr(entity));
                ui.label(ctx, fmt.tprintf("%v", format_entity(game_state, entity)));
                ui.label(ctx, fmt.tprintf("%v", game_state.components_position[entity].grid_position));
                if .SUBMIT in ui.button(ctx, "Recruit") {
                    add_to_party(game_state, entity);
                    make_entity_visible(game_state, entity);
                }
                ui.pop_id(ctx);
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
