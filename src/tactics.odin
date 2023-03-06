package main

import "core:dynlib"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:time"
import "vendor:sdl2"

import "debug"
import "engine/logger"
import "engine/platform"
import "engine/renderer"

APP_ARENA_SIZE          :: GAME_ARENA_SIZE + PLATFORM_ARENA_SIZE + RENDERER_ARENA_SIZE + size_of(platform.Arena_Name);
PLATFORM_ARENA_SIZE     :: 64 * mem.Kilobyte;
RENDERER_ARENA_SIZE     :: 512 * mem.Kilobyte;
GAME_ARENA_SIZE         :: 512 * mem.Kilobyte;

App :: struct {
    game_state:               ^uintptr,
    platform_state:           ^platform.Platform_State,
    renderer_state:           ^renderer.Renderer_State,
    logger_state:             ^logger.Logger_State,
    ui_state:                 ^renderer.UI_State,
}

game_stub :: proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    game_state: ^uintptr, platform_state, renderer_state, logger_state, ui_state, debug_state: rawptr,
) {
    log.debug("game_stub");
}

game_library: dynlib.Library;
game_update: rawptr;
game_fixed_update: rawptr;
game_render: rawptr;
game_load_timestamp: time.Time;

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

    // TODO: Get window_size from settings
    open_ok := platform.open_window(app.platform_state, "Tactics", { 1920, 1080 });
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

    code_load("game.bin");

    app.game_state = new(uintptr, game_arena_allocator);
    debug_state := new(debug.Debug_State, temp_platform_allocator);
    debug_state.running = true;

    for app.platform_state.quit == false {
        debug.frame_timing_start(debug_state);
        platform.update_and_render(
            false,
            game_update, game_fixed_update, game_render,
            game_arena_allocator,
            app.game_state, app.platform_state, app.renderer_state, app.logger_state, app.ui_state, debug_state,
        );
        debug.frame_timing_end(debug_state);

        // if app.platform_state.code_reload_requested {
        //     code_load();
        //     app.platform_state.code_reload_requested = false;
        // }

        for i in 0 ..< 100 {
            info, info_err := os.stat(fmt.tprintf("game-hot%i.bin", i));
            diff := time.diff(game_load_timestamp, info.modification_time);
            if info_err == 0 && diff > 0 {
                code_load(info.name);
                break;
            }
        }
    }

    log.debug("Quitting...");
}

code_load :: proc(path: string) {
    if game_library != nil {
        game_update = rawptr(game_stub);
        game_fixed_update = rawptr(game_stub);
        game_render = rawptr(game_stub);
        unload_success := dynlib.unload_library(game_library);
        assert(unload_success);
        game_library = nil;
        log.debug("game_library unloaded.");
    }

    load_success: bool;
    game_library, load_success = dynlib.load_library(path);
    assert(load_success);
    assert(game_library != nil, "game.bin can't be nil.");

    game_update = dynlib.symbol_address(game_library, "game_update");
    assert(game_update != nil, "game_update can't be nil.");
    assert(game_update != rawptr(game_stub), "game_update can't be game_stub.");

    game_fixed_update = dynlib.symbol_address(game_library, "game_fixed_update");
    assert(game_fixed_update != nil, "game_fixed_update can't be nil.");
    assert(game_fixed_update != rawptr(game_stub), "game_fixed_update can't be game_stub.");

    game_render = dynlib.symbol_address(game_library, "game_render");
    assert(game_render != nil, "game_render can't be nil.");
    assert(game_render != rawptr(game_stub), "game_render can't be game_stub.");

    game_load_timestamp = time.now();

    log.debugf("%v loaded: %v, %v, %v, %v.", path, game_library, game_update, game_fixed_update, game_render);
}
