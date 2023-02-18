package main

import "core:log"
import "core:mem"
import "core:runtime"

import platform "engine/platform"
import logger "engine/logger"
import renderer "engine/renderer"
import ui "engine/renderer/ui"

import game "game"

APP_ARENA_SIZE          :: GAME_ARENA_SIZE + PLATFORM_ARENA_SIZE + RENDERER_ARENA_SIZE;
PLATFORM_ARENA_SIZE     :: 16 * mem.Megabyte;
RENDERER_ARENA_SIZE     :: 4 * mem.Megabyte;
GAME_ARENA_SIZE         :: 8 * mem.Megabyte;

App :: struct {
    game:               ^game.Game_State,
    platform:           ^platform.Platform_State,
    renderer:           ^renderer.Renderer_State,
    logger:             ^logger.Logger_State,
    ui:                 ^ui.UI_State,
}

main :: proc() {
    app: App;
    app_arena: mem.Arena;
    app_arena_allocator: mem.Allocator;
    platform_arena: mem.Arena;
    platform_arena_allocator: mem.Allocator;
    renderer_arena: mem.Arena;
    renderer_arena_allocator: mem.Allocator;
    game_arena: mem.Arena;
    game_arena_allocator: mem.Allocator;

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
        mem.arena_init(&app_arena, buffer);
        app_arena_allocator = mem.Allocator { platform.arena_allocator_proc, &app_arena };
    }
    {
        buffer := make([]u8, PLATFORM_ARENA_SIZE, app_arena_allocator);
        mem.arena_init(&platform_arena, buffer);
        platform_arena_allocator = mem.Allocator { platform.arena_allocator_proc, &platform_arena };
    }
    {
        buffer := make([]u8, RENDERER_ARENA_SIZE, app_arena_allocator);
        mem.arena_init(&renderer_arena, buffer);
        renderer_arena_allocator = mem.Allocator { platform.arena_allocator_proc, &renderer_arena };
    }
    {
        buffer := make([]u8, GAME_ARENA_SIZE, app_arena_allocator);
        mem.arena_init(&game_arena, buffer);
        game_arena_allocator = mem.Allocator { platform.arena_allocator_proc, &game_arena };
    }

    temp_platform_allocator := mem.Allocator { runtime.default_allocator_proc, nil };

    platform_ok: bool;
    app.platform, platform_ok = platform.init(platform_arena_allocator, temp_platform_allocator);
    if platform_ok == false {
        log.error("Couldn't platform.init correctly.");
        return;
    }

    app.game = new(game.Game_State, game_arena_allocator);
    app.game.window_size = 6 * game.NATIVE_RESOLUTION;

    // TODO: Get window_size from settings
    open_ok := platform.open_window("Tactics", app.game.window_size);
    if open_ok == false {
        log.error("Couldn't platform.open_window correctly.");
        return;
    }

    renderer_ok: bool;
    app.renderer, renderer_ok = renderer.init(app.platform.window, renderer_arena_allocator);
    if renderer_ok == false {
        log.error("Couldn't renderer.init correctly.");
        return;
    }

    ui_ok: bool;
    app.ui, ui_ok = ui.init(app.renderer, renderer_arena_allocator);
    if ui_ok == false {
        log.error("Couldn't ui.init correctly.");
        return;
    }

    for app.game.quit == false && app.platform.quit == false {
        platform.update_and_render(
            app.game.unlock_framerate,
            platform.Update_Proc(game.game_fixed_update), platform.Update_Proc(game.game_update), platform.Update_Proc(game.game_render),
            game_arena_allocator,
            app.game, app.platform, app.renderer, app.logger, app.ui,
        );
    }

    log.debug("Quitting...");
}
