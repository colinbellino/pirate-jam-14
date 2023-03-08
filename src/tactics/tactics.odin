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

APP_MEMORY_SIZE      :: 1048 * mem.Kilobyte;
PLATFORM_MEMORY_SIZE :: 256 * mem.Kilobyte;
RENDERER_MEMORY_SIZE :: 512 * mem.Kilobyte;
GAME_MEMORY_SIZE     :: 512 * mem.Kilobyte;

main :: proc() {
    context.allocator = mem.Allocator { default_allocator_proc, nil };

    default_logger : runtime.Logger;
    if platform.contains_os_args("no-log") == false {
        // game_memory.logger_state = engine_logger.create_logger(mem.Allocator { engine_logger.allocator_proc, nil });
        // game_memory.logger = game_memory.logger_state.logger;
        options := log.Options { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color };
        default_logger = log.create_console_logger(runtime.Logger_Level.Debug, options);
    }
    context.logger = default_logger;

    app_arena := mem.Arena {};
    app_allocator := platform.make_arena_allocator(.App, APP_MEMORY_SIZE, &app_arena);

    game_memory := new(game.Game_Memory, app_allocator);
    platform_arena := mem.Arena {};
    game_memory.platform_allocator = platform.make_arena_allocator(.Platform, PLATFORM_MEMORY_SIZE, &platform_arena);
    renderer_arena := mem.Arena {};
    game_memory.renderer_allocator = platform.make_arena_allocator(.Renderer, RENDERER_MEMORY_SIZE, &renderer_arena);
    game_arena := mem.Arena {};
    game_memory.game_allocator = platform.make_arena_allocator(.Game, GAME_MEMORY_SIZE, &game_arena);
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

    game_memory.debug_state = debug.debug_init(game_memory.game_allocator);

    // code_load("game0.bin");
    _game_update = rawptr(game.game_update);
    _game_fixed_update = rawptr(game.game_fixed_update);
    _game_render = rawptr(game.game_render);

    for game_memory.platform_state.quit == false {
        debug.frame_timing_start(game_memory.debug_state);
        defer debug.frame_timing_end(game_memory.debug_state);

        platform.update_and_render(game_memory.platform_state, _game_update, _game_fixed_update, _game_render, game_memory);

        if game_memory.save_memory {
            game_memory.save_memory = false;
            log.debugf("arena:      %p", &app_arena);
            log.debugf("data:       %p", &app_arena.data);
            log.debugf("data[0]:    %p", &app_arena.data[0]);
            log.debugf("offset:     %p", &app_arena.offset);
            success := os.write_entire_file("mem.bin", app_arena.data, false);
            if success == false {
                log.error("Couldn't write mem.bin");
                return;
            }
            log.debug("mem.bin written.");
        }
        if game_memory.load_memory {
            game_memory.load_memory = false;
            data, success := os.read_entire_file("mem.bin");
            log.debugf("len(data): %v %v", len(data), len(app_arena.data));
            if success == false {
                log.error("Couldn't read mem.bin");
                return;
            }
            // mem.zero(&app_arena.data[0], len(app_arena.data));
            mem.copy(&app_arena.data[0], &data[0], len(app_arena.data));
            // copy(app_arena.data[:], data[:]);
            // app_arena.data = data;
            log.debug("mem.bin read.");
        }

        { debug.timed_block(game_memory.debug_state, 0);
            for i in 0 ..< 100 {
                info, info_err := os.stat(fmt.tprintf("game%i.bin", i), context.temp_allocator);
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

heap_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    // fmt.printf("heap_allocator_proc: %v %v %v %v %v %v %v\n", allocator_data, mode, size, alignment, old_memory, old_size, location);
    // debug.alloc_start(allocator_data, mode, size, alignment, old_memory, old_size, location);
    data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    // debug.alloc_end(data, error);

    return;
}

default_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    fmt.printf("DEFAULT_ALLOCATOR: %v %v -> %v\n", mode, size, location);
    data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    if error != .None {
        fmt.eprintf("DEFAULT_ALLOCATOR ERROR: %v\n", error);
    }

    return;
}

default_temp_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    // fmt.printf("DEFAULT_TEMP_ALLOCATOR: %v %v -> %v\n", mode, size, location);
    // data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    data, error = runtime.default_temp_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    if error != .None {
        fmt.eprintf("DEFAULT_TEMP_ALLOCATOR ERROR: %v | %v\n", mode, error);
    }

    return;
}
