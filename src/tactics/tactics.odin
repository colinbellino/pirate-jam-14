package tactics

import "core:dynlib"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:time"

import "../debug"
import "../game"
// import engine_logger "../engine/logger"
import "../engine/platform"
import "../engine/renderer"

APP_ARENA_SIZE          :: GAME_ARENA_SIZE + PLATFORM_ARENA_SIZE + RENDERER_ARENA_SIZE + size_of(platform.Arena_Name);
PLATFORM_ARENA_SIZE     :: 64 * mem.Kilobyte;
RENDERER_ARENA_SIZE     :: 512 * mem.Kilobyte;
GAME_ARENA_SIZE         :: 512 * mem.Kilobyte;

main :: proc() {
    game_memory: game.Game_Memory;

    if platform.contains_os_args("no-log") == false {
        // game_memory.logger_state = engine_logger.create_logger(mem.Allocator { engine_logger.allocator_proc, nil });
        // game_memory.logger = game_memory.logger_state.logger;
        options := log.Options { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color };
        game_memory.logger = log.create_console_logger(runtime.Logger_Level.Debug, options);
    }
    context.logger = game_memory.logger;

    game_memory.app_allocator = platform.make_arena_allocator(.App, APP_ARENA_SIZE, &game_memory.app_arena);
    game_memory.platform_allocator = platform.make_arena_allocator(.Platform, PLATFORM_ARENA_SIZE, &game_memory.platform_arena, game_memory.app_allocator);
    game_memory.renderer_allocator = platform.make_arena_allocator(.Renderer, RENDERER_ARENA_SIZE, &game_memory.renderer_arena, game_memory.app_allocator);
    game_memory.game_allocator = platform.make_arena_allocator(.Game, GAME_ARENA_SIZE, &game_memory.game_arena, game_memory.app_allocator);
    game_memory.temp_allocator = os.heap_allocator();

    platform_ok: bool;
    game_memory.platform_state, platform_ok = platform.init(game_memory.platform_allocator, game_memory.temp_allocator);
    if platform_ok == false {
        log.error("Couldn't platform.init correctly.");
        return;
    }

    // TODO: Get window_size from settings
    open_window_ok := platform.open_window(game_memory.platform_state, "Tactics", { 1920, 1080 });
    if open_window_ok == false {
        log.error("Couldn't platform.open_window correctly.");
        return;
    }

    renderer_ok: bool;
    game_memory.renderer_state, renderer_ok = renderer.init(game_memory.platform_state.window, game_memory.renderer_allocator);
    if renderer_ok == false {
        log.error("Couldn't renderer.init correctly.");
        return;
    }

    ui_ok: bool;
    game_memory.ui_state, ui_ok = renderer.ui_init(game_memory.renderer_state);
    if ui_ok == false {
        log.error("Couldn't renderer.ui_init correctly.");
        return;
    }

    game_memory.debug_state = new(debug.Debug_State, game_memory.temp_allocator);
    game_memory.debug_state.running = true;

    code_load("game0.bin");

    for game_memory.platform_state.quit == false {
        debug.frame_timing_start(game_memory.debug_state);
        defer debug.frame_timing_end(game_memory.debug_state);

        platform.update_and_render(game_memory.platform_state, _game_update, _game_fixed_update, _game_render, &game_memory);

        { debug.timed_block(game_memory.debug_state, "hot_reload");
            check_code_reload();
        }

        free_all(context.temp_allocator);
    }

    log.debug("Quitting...");
}

// TODO: Move this to engine/

@(private="file") _game_library: dynlib.Library;
@(private="file") _game_update: rawptr;
@(private="file") _game_fixed_update: rawptr;
@(private="file") _game_render: rawptr;
@(private="file") _game_load_timestamp: time.Time;

game_stub : platform.Update_Proc : proc(delta_time: f64, game_memory: rawptr) {
    log.debug("game_stub");
}

check_code_reload :: proc() {
    for i in 0 ..< 100 {
        info, info_err := os.stat(fmt.tprintf("game%i.bin", i));
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
