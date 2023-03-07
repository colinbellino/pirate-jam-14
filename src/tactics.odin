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
import engine_logger "engine/logger"
import "engine/platform"
import "engine/renderer"

APP_ARENA_SIZE          :: GAME_ARENA_SIZE + PLATFORM_ARENA_SIZE + RENDERER_ARENA_SIZE + size_of(platform.Arena_Name);
PLATFORM_ARENA_SIZE     :: 64 * mem.Kilobyte;
RENDERER_ARENA_SIZE     :: 512 * mem.Kilobyte;
GAME_ARENA_SIZE         :: 512 * mem.Kilobyte;

App_Memory :: struct {
    app_arena:              mem.Arena,
    app_allocator:          mem.Allocator,
    platform_arena:         mem.Arena,
    platform_allocator:     mem.Allocator,
    renderer_arena:         mem.Arena,
    renderer_allocator:     mem.Allocator,
    game_arena:             mem.Arena,
    game_allocator:         mem.Allocator,
    temp_allocator:         mem.Allocator,

    logger:                 runtime.Logger,

    game_state:             ^uintptr,
    platform_state:         ^platform.Platform_State,
    renderer_state:         ^renderer.Renderer_State,
    logger_state:           ^engine_logger.Logger_State,
    ui_state:               ^renderer.UI_State,
    debug_state:            ^debug.Debug_State,
}

main :: proc() {
    app: App_Memory;

    if platform.contains_os_args("no-log") == false {
        // app.logger_state = engine_logger.create_logger(mem.Allocator { engine_logger.allocator_proc, nil });
        // app.logger = app.logger_state.logger;
        options := log.Options { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color };
        app.logger = log.create_console_logger(runtime.Logger_Level.Debug, options);
    }
    context.logger = app.logger;

    app.temp_allocator = mem.Allocator { runtime.default_allocator_proc, nil };

    app.app_allocator = platform.make_arena_allocator(.App, APP_ARENA_SIZE, &app.app_arena);
    app.platform_allocator = platform.make_arena_allocator(.Platform, PLATFORM_ARENA_SIZE, &app.platform_arena, app.app_allocator);
    app.renderer_allocator = platform.make_arena_allocator(.Renderer, RENDERER_ARENA_SIZE, &app.renderer_arena, app.app_allocator);
    app.game_allocator = platform.make_arena_allocator(.Game, GAME_ARENA_SIZE, &app.game_arena, app.app_allocator);

    platform_ok: bool;
    app.platform_state, platform_ok = platform.init(app.platform_allocator, app.temp_allocator);
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
    app.renderer_state, renderer_ok = renderer.init(app.platform_state.window, app.renderer_allocator);
    if renderer_ok == false {
        log.error("Couldn't renderer.init correctly.");
        return;
    }

    ui_ok: bool;
    app.ui_state, ui_ok = renderer.ui_init(app.renderer_state);
    if ui_ok == false {
        log.error("Couldn't renderer.ui_init correctly.");
        return;
    }

    code_load("game.bin");

    app.game_state = new(uintptr, app.game_allocator);
    app.debug_state = new(debug.Debug_State, app.temp_allocator);
    app.debug_state.running = true;

    for app.platform_state.quit == false {
        debug.frame_timing_start(app.debug_state);
        defer debug.frame_timing_end(app.debug_state);

        platform.update_and_render(
            true,
            _game_update, _game_fixed_update, _game_render,
            app.game_allocator,
            app.game_state, app.platform_state, app.renderer_state, app.logger_state, app.ui_state, app.debug_state,
        );

        { debug.timed_block(app.debug_state, "hot_reload");
            check_code_reload();
        }
    }

    log.debug("Quitting...");
}

// TODO: Move this to engine/

@(private="file") _game_library: dynlib.Library;
@(private="file") _game_update: rawptr;
@(private="file") _game_fixed_update: rawptr;
@(private="file") _game_render: rawptr;
@(private="file") _game_load_timestamp: time.Time;

game_stub :: proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    game_state: ^uintptr, platform_state, renderer_state, logger_state, ui_state, debug_state: rawptr,
) {
    log.debug("game_stub");
}

check_code_reload :: proc() {
    for i in 0 ..< 100 {
        info, info_err := os.stat(fmt.tprintf("game-hot%i.bin", i));
        diff := time.diff(_game_load_timestamp, info.modification_time);
        if info_err == 0 && diff > 0 {
            code_load(info.name);
            break;
        }
    }
}

code_load :: proc(path: string) {
    if _game_library != nil {
        _game_update = rawptr(game_stub);
        _game_fixed_update = rawptr(game_stub);
        _game_render = rawptr(game_stub);
        unload_success := dynlib.unload_library(_game_library);
        assert(unload_success);
        _game_library = nil;
        log.debug("_game_library unloaded.");
    }

    game_library, load_success := dynlib.load_library(path);
    if load_success == false {
        log.errorf("%v not loaded.", path);
        return;
    }
    _game_library = game_library;

    _game_update = dynlib.symbol_address(_game_library, "game_update");
    assert(_game_update != nil, "game_update can't be nil.");
    assert(_game_update != rawptr(game_stub), "game_update can't be game_stub.");

    _game_fixed_update = dynlib.symbol_address(_game_library, "game_fixed_update");
    assert(_game_fixed_update != nil, "game_fixed_update can't be nil.");
    assert(_game_fixed_update != rawptr(game_stub), "game_fixed_update can't be game_stub.");

    _game_render = dynlib.symbol_address(_game_library, "game_render");
    assert(_game_render != nil, "game_render can't be nil.");
    assert(_game_render != rawptr(game_stub), "game_render can't be game_stub.");

    _game_load_timestamp = time.now();

    log.debugf("%v loaded: %v, %v, %v, %v.", path, _game_library, _game_update, _game_fixed_update, _game_render);
}
