package main

import "core:log"
import "core:mem"
import "core:runtime"
import "core:slice"
import "core:fmt"
import "core:os"

import platform "engine/platform"
import logger "engine/logger"
import renderer "engine/renderer"
import ui "engine/renderer/ui"

import game "game"

APP_ARENA_SIZE          :: 16 * mem.Megabyte;
TEMP_ARENA_SIZE         :: 8 * mem.Kilobyte;

App :: struct {
    game:               ^game.Game_State,
    platform:           ^platform.Platform_State,
    renderer:           ^renderer.Renderer_State,
    logger:             ^logger.Logger_State,
    ui:                 ^ui.UI_State,
}

main :: proc() {
    arena: mem.Arena;
    temp_arena: mem.Arena;
    app: App;

    default_allocator := mem.Allocator { platform.allocator_proc, nil };
    app_tracking_allocator : mem.Tracking_Allocator;
    mem.tracking_allocator_init(&app_tracking_allocator, default_allocator);
    default_allocator = mem.tracking_allocator(&app_tracking_allocator);

    // FIXME: this is allocating everytime we log something
    logger_allocator := mem.Allocator { logger.allocator_proc, nil };
    app.logger = logger.create_logger(logger_allocator);
    context.logger = app.logger.logger;
    // options := log.Options { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color };
    // context.logger = log.create_console_logger(runtime.Logger_Level.Debug, options);

    {
        buffer := make([]u8, APP_ARENA_SIZE, default_allocator);
        mem.arena_init(&arena, buffer);
    }
    arena_allocator := mem.Allocator { platform.arena_allocator_proc, &arena };

    {
        buffer := make([]u8, TEMP_ARENA_SIZE, arena_allocator);
        mem.arena_init(&temp_arena, buffer);
    }

    // temp_platform_allocator := mem.Allocator { temp_platform_allocator_proc, &temp_arena };
    temp_platform_allocator := mem.Allocator { runtime.default_allocator_proc, nil };

    platform_ok: bool;
    app.platform, platform_ok = platform.init(arena_allocator, temp_platform_allocator);
    if platform_ok == false {
        log.error("Couldn't platform.init correctly.");
        return;
    }

    app.game = new(game.Game_State, arena_allocator);
    app.game.window_size = 6 * game.NATIVE_RESOLUTION;

    // TODO: Get window_size from settings
    open_ok := platform.open_window("Tactics", app.game.window_size);
    if open_ok == false {
        log.error("Couldn't platform.open_window correctly.");
        return;
    }

    renderer_ok: bool;
    renderer_allocator := arena_allocator;
    app.renderer, renderer_ok = renderer.init(app.platform.window, renderer_allocator);
    if renderer_ok == false {
        log.error("Couldn't renderer.init correctly.");
        return;
    }

    ui_ok: bool;
    app.ui, ui_ok = ui.init(app.renderer, renderer_allocator);
    if ui_ok == false {
        log.error("Couldn't ui.init correctly.");
        return;
    }

    for app.platform.quit == false {
        platform.update_and_render(
            app.game.unlock_framerate,
            platform.Update_Proc(game.fixed_update), platform.Update_Proc(game.variable_update), platform.Update_Proc(game.render),
            arena_allocator,
            app.game, app.platform, app.renderer, app.logger, app.ui,
        );
    }

    log.debug("Quitting...");
}

temp_platform_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    result, error = mem.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    if slice.contains(os.args, "show-alloc-temp") {
        fmt.printf("[TEMP_ARENA] %v %v byte at %v\n", mode, size, location);
    }

    if error != .None && error != .Mode_Not_Implemented {
        fmt.eprintf("[TEMP_ARENA] ERROR: %v %v byte at %v -> %v\n", mode, size, location, error);
        os.exit(0);
    }

    return;
}
