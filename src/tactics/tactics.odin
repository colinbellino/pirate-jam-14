package tactics

import "core:c"
import "core:dynlib"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"
import "core:time"

import "../debug"
import "../game"
import engine_logger "../engine/logger"
import "../engine/platform"
import "../engine/renderer"
import "../bla"

BASE_ADDRESS         :: 2 * mem.Terabyte;
APP_MEMORY_SIZE      :: PLATFORM_MEMORY_SIZE + RENDERER_MEMORY_SIZE + GAME_MEMORY_SIZE + LOGGER_MEMORY_SIZE + TEMP_MEMORY_SIZE;
PLATFORM_MEMORY_SIZE :: 256 * mem.Kilobyte;
RENDERER_MEMORY_SIZE :: 5120 * mem.Kilobyte;
GAME_MEMORY_SIZE     :: 2048 * mem.Kilobyte;
LOGGER_MEMORY_SIZE   :: 2048 * mem.Kilobyte;
TEMP_MEMORY_SIZE     :: 512 * mem.Kilobyte;

main :: proc() {
    context.allocator = mem.Allocator { default_allocator_proc, nil };

    default_temp_allocator_data := runtime.Default_Temp_Allocator {};
    runtime.default_temp_allocator_init(&default_temp_allocator_data, TEMP_MEMORY_SIZE, context.allocator);
    context.temp_allocator.procedure = default_temp_allocator_proc;
    context.temp_allocator.data = &default_temp_allocator_data;

    app_memory, alloc_error := bla.reserve_and_commit(APP_MEMORY_SIZE, rawptr(uintptr((BASE_ADDRESS))));
    // fmt.printf("app_memory:   %p\n", app_memory);
    if alloc_error > .None {
        fmt.eprintf("Error: %v\n", alloc_error);
        os.exit(1);
    }

    app_arena := mem.Arena {};
    mem.arena_init(&app_arena, app_memory);
    app_allocator := mem.Allocator { platform.arena_allocator_proc, &app_arena };
    arena_name := new(platform.Arena_Name, app_allocator);

    game_memory := new(game.Game_Memory, app_allocator);

    default_logger : runtime.Logger;
    if platform.contains_os_args("no-log") == false {
        game_memory.game_allocator = platform.make_arena_allocator(.Logger, LOGGER_MEMORY_SIZE, &game_memory.logger_arena, app_allocator);
        game_memory.logger_state = engine_logger.create_state_logger(game_memory.game_allocator);

        options := log.Options { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color };
        data := new(log.File_Console_Logger_Data, app_allocator);
        data.file_handle = os.INVALID_HANDLE;
        data.ident = "";
        console_logger := log.Logger { log.file_console_logger_proc, data, runtime.Logger_Level.Debug, options };

        default_logger = log.create_multi_logger(console_logger, game_memory.logger_state.logger);
    }
    context.logger = default_logger;

    game_memory.marker_0 = bla.Memory_Marker { '#', '#', '#', '#', 'G', 'A', 'M', 'E', '_', 'M', 'E', 'M', '0', '#', '#', '#' };
    game_memory.marker_1 = bla.Memory_Marker { '#', '#', '#', '#', 'G', 'A', 'M', 'E', '_', 'M', 'E', 'M', '1', '#', '#', '#' };
    game_memory.platform_allocator = platform.make_arena_allocator(.Platform, PLATFORM_MEMORY_SIZE, &game_memory.platform_arena, app_allocator);
    game_memory.renderer_allocator = platform.make_arena_allocator(.Renderer, RENDERER_MEMORY_SIZE, &game_memory.renderer_arena, app_allocator);
    game_memory.game_allocator = platform.make_arena_allocator(.Game, GAME_MEMORY_SIZE, &game_memory.game_arena, app_allocator);
    // game_memory.temp_allocator = os.heap_allocator();
    game_memory.temp_allocator = context.temp_allocator;

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

    if platform.contains_os_args("no-hot") {
        _game_update = rawptr(game.game_update);
        _game_fixed_update = rawptr(game.game_fixed_update);
        _game_render = rawptr(game.game_render);
    } else {
        code_load("game0.bin");
    }

    frame := 0;
    for game_memory.platform_state.quit == false {
        debug.frame_timing_start(game_memory.debug_state);
        defer debug.frame_timing_end(game_memory.debug_state);

        debug.timed_block(game_memory.debug_state, "total");

        platform.update_and_render(game_memory.platform_state, _game_update, _game_fixed_update, _game_render, game_memory);

        if game_memory.save_memory > 0 {
            path := fmt.tprintf("mem%i.bin", game_memory.save_memory);
            game_memory.save_memory = 0;
            success := os.write_entire_file(path, app_arena.data, false);
            if success == false {
                log.errorf("Couldn't write %s", path);
                return;
            }
            log.infof("%s written.", path);
        }
        if game_memory.load_memory > 0 {
            path := fmt.tprintf("mem%i.bin", game_memory.load_memory);
            game_memory.load_memory = 0;
            data, success := os.read_entire_file(path);
            if success == false {
                log.errorf("Couldn't read %s", path);
                return;
            }
            mem.copy(&app_arena.data[0], &data[0], len(app_arena.data));
            log.infof("%s read.", path);
        }

        if platform.contains_os_args("no-hot") == false {
            debug.timed_block(game_memory.debug_state, "hot_reload");
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

        frame += 1;
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
        // log.errorf("%v not loaded.", path);
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

    if error != .None && error != .Mode_Not_Implemented && mode != .Free {
        fmt.eprintf("DEFAULT_TEMP_ALLOCATOR ERROR: %v | %v -> %v\n", mode, error, location);
    }

    return;
}
