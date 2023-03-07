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

    APP_MEMORY_SIZE      :: 2048 * mem.Kilobyte;
    PLATFORM_MEMORY_SIZE :: 256 * mem.Kilobyte;
    RENDERER_MEMORY_SIZE :: 512 * mem.Kilobyte;
    GAME_MEMORY_SIZE     :: 256 * mem.Kilobyte;

    app_memory := mem.alloc(APP_MEMORY_SIZE);
    game_memory.app_allocator = mem.Allocator { custom_allocator_proc, app_memory };
    // debug.alloc_init(.App, game_memory.app_allocator, APP_MEMORY_SIZE);

    platform_buffer := make([]u8, PLATFORM_MEMORY_SIZE, game_memory.app_allocator);
    game_memory.platform_allocator = mem.Allocator { custom_allocator_proc, &platform_buffer };
    // debug.alloc_init(.Platform, game_memory.platform_allocator, PLATFORM_MEMORY_SIZE);

    renderer_buffer := make([]u8, RENDERER_MEMORY_SIZE, game_memory.app_allocator);
    game_memory.renderer_allocator = mem.Allocator { custom_allocator_proc, &renderer_buffer };
    // debug.alloc_init(.Renderer, game_memory.renderer_allocator, RENDERER_MEMORY_SIZE);

    game_buffer := make([]u8, GAME_MEMORY_SIZE, game_memory.app_allocator);
    game_memory.game_allocator = mem.Allocator { custom_allocator_proc, &game_buffer };
    // debug.alloc_init(.Game, game_memory.game_allocator, GAME_MEMORY_SIZE);

    game_memory.temp_allocator =     os.heap_allocator();

    // game_memory.app_allocator =      platform.make_arena_allocator(.App, APP_ARENA_SIZE, &game_memory.app_arena);
    // game_memory.platform_allocator = platform.make_arena_allocator(.Platform, PLATFORM_ARENA_SIZE, &game_memory.platform_arena, game_memory.app_allocator);
    // game_memory.renderer_allocator = platform.make_arena_allocator(.Renderer, RENDERER_ARENA_SIZE, &game_memory.renderer_arena, game_memory.app_allocator);
    // game_memory.game_allocator =     platform.make_arena_allocator(.Game, GAME_ARENA_SIZE, &game_memory.game_arena, game_memory.app_allocator);
    // game_memory.temp_allocator =     os.heap_allocator();

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

    game_memory.debug_state = debug.debug_init(game_memory.game_allocator);

    code_load("game0.bin");

    for game_memory.platform_state.quit == false {
        debug.frame_timing_start(game_memory.debug_state);
        defer debug.frame_timing_end(game_memory.debug_state);

        platform.update_and_render(game_memory.platform_state, _game_update, _game_fixed_update, _game_render, &game_memory);

        { debug.timed_block(game_memory.debug_state, 0);
            for i in 0 ..< 100 {
                info, info_err := os.stat(fmt.tprintf("game%i.bin", i));
                if info_err == 0 && time.diff(_game_load_timestamp, info.modification_time) > 0 {
                    if code_load(info.name) {
                        game_memory.debug_state = debug.debug_init(game_memory.game_allocator);
                    }
                    break;
                }
            }
        }

        free_all(context.temp_allocator);
    }

    log.debug("Quitting...");
}

// TODO: Move this to engine/

@(private="file") _game_library: dynlib.Library;
@(private="file") _game_update := rawptr(game_update_stub);
@(private="file") _game_fixed_update := rawptr(game_update_stub);
@(private="file") _game_render := rawptr(game_update_stub);
@(private="file") _game_load_timestamp: time.Time;

game_update_stub : platform.Update_Proc : proc(delta_time: f64, game_memory: rawptr) {
    log.debug("game_update_stub");
}

code_load :: proc(path: string) -> (bool) {
    game_library, load_success := dynlib.load_library(path);
    if load_success == false {
        log.errorf("%v not loaded.", path);
        return false;
    }

    if _game_library != nil {
        unload_success := dynlib.unload_library(_game_library);
        assert(unload_success);
        _game_library = nil;
        _game_update = rawptr(game_update_stub);
        _game_fixed_update = rawptr(game_update_stub);
        _game_render = rawptr(game_update_stub);
        log.debug("game.bin unloaded.");
    }

    _game_update = dynlib.symbol_address(game_library, "game_update");
    assert(_game_update != nil, "game_update can't be nil.");
    assert(_game_update != rawptr(game_update_stub), "game_update can't be a stub.");

    _game_fixed_update = dynlib.symbol_address(game_library, "game_fixed_update");
    assert(_game_fixed_update != nil, "game_fixed_update can't be nil.");
    assert(_game_fixed_update != rawptr(game_update_stub), "game_fixed_update can't be a stub.");

    _game_render = dynlib.symbol_address(game_library, "game_render");
    assert(_game_render != nil, "game_render can't be nil.");
    assert(_game_render != rawptr(game_update_stub), "game_render can't be a stub.");

    _game_load_timestamp = time.now();
    _game_library = game_library;

    log.debugf("%v loaded: %v, %v, %v, %v.", path, _game_library, _game_update, _game_fixed_update, _game_render);
    return true;
}

custom_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    // fmt.printf("custom_allocator_proc: %v %v %v %v %v %v %v\n", allocator_data, mode, size, alignment, old_memory, old_size, location);
    // debug.alloc_start(allocator_data, mode, size, alignment, old_memory, old_size, location);
    data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    // debug.alloc_end(data, error);

    return;
}
