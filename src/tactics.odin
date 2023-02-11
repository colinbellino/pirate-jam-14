package main

import "core:fmt"
import "core:mem"
import "core:mem/virtual"

import platform "engine/platform"
import logger "engine/logger"
import renderer "engine/renderer"
import ui "engine/renderer/ui"
import ldtk "engine/ldtk"

State :: struct {
    log_state:          logger.State,
    bg_color:           renderer.Color,
    version:            string,
    window_width:       i32,
    window_height:      i32,

    arena:              virtual.Arena,
    show_menu_1:        bool,
    show_menu_2:        bool,
    show_menu_3:        bool,
}

state := State {
    bg_color = {90, 95, 100, 255},
    version = "000000",
    window_width = 1920,
    window_height = 1080,
    show_menu_1 = true,
    show_menu_2 = true,
    show_menu_3 = true,
}

frame_buffer_size :: 6;

main :: proc() {
    track : mem.Tracking_Allocator;
    mem.tracking_allocator_init(&track, context.allocator);
    context.allocator = mem.tracking_allocator(&track);
    context.logger = logger.create_logger();

    platform.init();
    platform.open_window(state.window_width, state.window_height);
    renderer.init(platform.state.window);

    state.version = string(#load("../version.txt") or_else "999999");

    world_path := "../media/levels/world.ldtk";
    ldtk := ldtk.load_file(world_path);
    logger.write_log("[Game] Level %v loaded: %v", world_path, ldtk);

    for platform.state.quit == false {
        platform.process_inputs();

        ui.draw_begin();
        draw_debug_window(&state.bg_color, &state.log_state);
        ui.draw_end();
        renderer.render_frame(state.bg_color);

        if (platform.state.inputs.f1.released) {
            state.show_menu_1 = !state.show_menu_1;
        }
        if (platform.state.inputs.f2.released) {
            state.show_menu_2 = !state.show_menu_2;
        }
        if (platform.state.inputs.f3.released) {
            state.show_menu_3 = !state.show_menu_3;
        }

        if (platform.state.inputs.f12.released) {
            renderer.take_screenshot(platform.state.window);
        }

        // FIXME:
        // platform.state.quit = true;
    }

    // renderer.quit();
    // platform.close_window();
    // platform.quit();

    logger.destroy_logger();

    logger.write_log("[Game] Quitting...");

    for _, leak in track.allocation_map {
        logger.write_log("%v leaked %v bytes", leak.location, leak.size);
    }
    for bad_free in track.bad_free_array {
        logger.write_log("%v allocation %p was freed badly", bad_free.location, bad_free.memory);
    }
}

draw_debug_window :: proc(bg_color: ^renderer.Color, log_state: ^logger.State) {
    ctx := &renderer.state.ui_context

    if state.show_menu_1 {
        if ui.window(ctx, "Debug", {40, 40, 320, 200}) {
            ui.layout_row(ctx, {80, -1}, 0);
            ui.label(ctx, "Version:");
            ui.label(ctx, state.version);
        }
    }

    if state.show_menu_2 {
        if ui.window(ctx, "Shortcuts", {40, 250, 320, 200}) {
            ui.layout_row(ctx, {80, -1}, 0);
            ui.label(ctx, "Screenshot:");
            ui.label(ctx, "F12");
        }
    }

    if state.show_menu_3 {
        if ui.window(ctx, "Logs", {370, 40, 600, 200}) {
            ui.layout_row(ctx, {-1}, -28)
            ui.begin_panel(ctx, "Log")
            ui.layout_row(ctx, {-1}, -1)
            ui.text(ctx, logger.read_log())
            if log_state.log_buf_updated {
                panel := ui.get_current_container(ctx)
                panel.scroll.y = panel.content_size.y
                log_state.log_buf_updated = false
            }
            ui.end_panel(ctx)

            @static buf: [128]byte
            @static buf_len: int
            submitted := false
            ui.layout_row(ctx, {-70, -1})
            if .SUBMIT in ui.textbox(ctx, buf[:], &buf_len) {
                ui.set_focus(ctx, ctx.last_id)
                submitted = true
            }
            if .SUBMIT in ui.button(ctx, "Submit") {
                submitted = true
            }
            if submitted {
                logger.write_log(string(buf[:buf_len]))
                buf_len = 0
            }
        }
    }
}
