package main

import "core:log"
import "core:mem"
import "core:runtime"
import "vendor:sdl2"

import "debug"
import "engine/logger"
import "engine/platform"
import "engine/renderer"
import "game"

APP_ARENA_SIZE          :: GAME_ARENA_SIZE + PLATFORM_ARENA_SIZE + RENDERER_ARENA_SIZE + size_of(platform.Arena_Name);
PLATFORM_ARENA_SIZE     :: 64 * mem.Kilobyte;
RENDERER_ARENA_SIZE     :: 512 * mem.Kilobyte;
GAME_ARENA_SIZE         :: 512 * mem.Kilobyte;

App :: struct {
    game_state:               ^game.Game_State,
    platform_state:           ^platform.Platform_State,
    renderer_state:           ^renderer.Renderer_State,
    logger_state:             ^logger.Logger_State,
    ui_state:                 ^renderer.UI_State,
}

game_dll: rawptr;
game_update: rawptr;
game_fixed_update: rawptr;
game_render: rawptr;

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

    default_logger: runtime.Logger;
    if platform.contains_os_args("no-log") == false {
        // logger_allocator := mem.Allocator { logger.allocator_proc, nil };
        // app.logger_state = logger.create_logger(logger_allocator);
        // default_logger = app.logger_state.logger;
        options := log.Options { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color };
        default_logger = log.create_console_logger(runtime.Logger_Level.Debug, options);
    }
    context.logger = default_logger;

    temp_platform_allocator := mem.Allocator { runtime.default_allocator_proc, nil };

    app_arena_allocator = platform.make_arena_allocator(.App, APP_ARENA_SIZE, &app_arena);
    platform_arena_allocator = platform.make_arena_allocator(.Platform, PLATFORM_ARENA_SIZE, &platform_arena, app_arena_allocator);
    renderer_arena_allocator = platform.make_arena_allocator(.Renderer, RENDERER_ARENA_SIZE, &renderer_arena, app_arena_allocator);
    game_arena_allocator = platform.make_arena_allocator(.Game, GAME_ARENA_SIZE, &game_arena, app_arena_allocator);

    platform_ok: bool;
    app.platform_state, platform_ok = platform.init(platform_arena_allocator, temp_platform_allocator);
    if platform_ok == false {
        log.error("Couldn't platform.init correctly.");
        return;
    }

    app.game_state = new(game.Game_State, game_arena_allocator);
    app.game_state.window_size = 6 * game.NATIVE_RESOLUTION;

    // TODO: Get window_size from settings
    open_ok := platform.open_window(app.platform_state, "Tactics", app.game_state.window_size);
    if open_ok == false {
        log.error("Couldn't platform.open_window correctly.");
        return;
    }

    renderer_ok: bool;
    app.renderer_state, renderer_ok = renderer.init(app.platform_state.window, renderer_arena_allocator);
    if renderer_ok == false {
        log.error("Couldn't renderer.init correctly.");
        return;
    }

    ui_ok: bool;
    app.ui_state, ui_ok = renderer.ui_init(app.renderer_state, renderer_arena_allocator);
    if ui_ok == false {
        log.error("Couldn't renderer.ui_init correctly.");
        return;
    }

    code_load();

    for app.game_state.quit == false && app.platform_state.quit == false {
        if app.platform_state.keys[.P].released {
            code_load();
        }

        debug.frame_timing_start();
        platform.update_and_render(
            app.game_state.unlock_framerate,
            game_update, game_fixed_update, game_render,
            game_arena_allocator,
            app.game_state, app.platform_state, app.renderer_state, app.logger_state, app.ui_state,
        );
        debug.frame_timing_end();
    }

    log.debug("Quitting...");
}

code_load :: proc() {
    if game_dll != nil {
        sdl2.UnloadObject(game_dll);
        log.debug("game.dll unloaded.");
    }
    game_dll = sdl2.LoadObject("game.bin");
    assert(game_dll != nil, "game.bin can't be nil.");

    game_update = sdl2.LoadFunction(game_dll, "game_update");
    assert(game_update != nil, "game_update can't be nil.");
    game_fixed_update = sdl2.LoadFunction(game_dll, "game_fixed_update");
    assert(game_fixed_update != nil, "game_fixed_update can't be nil.");
    game_render = sdl2.LoadFunction(game_dll, "game_render");
    assert(game_render != nil, "game_render can't be nil.");

    log.debugf("game.dll loaded: %v, %v, %v, %v.", game_dll, game_update, game_fixed_update, game_render);
}
