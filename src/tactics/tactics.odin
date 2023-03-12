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
import "core:slice"

// TODO: can we make it so we don't import engine here and inside the game (maybe import only the types in tactics/)?
import "../engine"
import "../game"

BASE_ADDRESS         :: 2 * mem.Terabyte;
// TODO: merge all engine arenas into one?
// APP_MEMORY_SIZE      :: PLATFORM_MEMORY_SIZE + RENDERER_MEMORY_SIZE + LOGGER_MEMORY_SIZE + DEBUG_MEMORY_SIZE + TEMP_MEMORY_SIZE + GAME_MEMORY_SIZE;
PLATFORM_MEMORY_SIZE :: 256 * mem.Kilobyte;
RENDERER_MEMORY_SIZE :: 512 * mem.Kilobyte;
LOGGER_MEMORY_SIZE   :: 2048 * mem.Kilobyte;
DEBUG_MEMORY_SIZE    :: 1024 * mem.Kilobyte;
GAME_MEMORY_SIZE     :: 2048 * mem.Kilobyte; // FIXME: reduce this once we have fixed the memory alloc issues

TEMP_MEMORY_START_SIZE :: 1024 * mem.Kilobyte;

main :: proc() {
    context.allocator = mem.Allocator { default_allocator_proc, nil };

    default_temp_allocator_data := runtime.Default_Temp_Allocator {};
    runtime.default_temp_allocator_init(&default_temp_allocator_data, TEMP_MEMORY_START_SIZE, context.allocator);
    context.temp_allocator.procedure = default_temp_allocator_proc;
    context.temp_allocator.data = &default_temp_allocator_data;

    // TODO: Get window_size from settings
    app := engine.init_app(
        { 1920, 1080 },
        BASE_ADDRESS, PLATFORM_MEMORY_SIZE, RENDERER_MEMORY_SIZE, LOGGER_MEMORY_SIZE, DEBUG_MEMORY_SIZE, GAME_MEMORY_SIZE,
        context.allocator, context.temp_allocator);
    context.logger = app.logger;

    if slice.contains(os.args, "no-hot") {
        _game_update = rawptr(game.game_update);
        _game_fixed_update = rawptr(game.game_fixed_update);
        _game_render = rawptr(game.game_render);
    } else {
        code_load("game0.bin");
    }

    frame := 0;
    for app.platform_state.quit == false {
        // engine.timed_block(app.debug_state, "total");

        engine.update_and_render(app.platform_state, _game_update, _game_fixed_update, _game_render, app);

        if app.save_memory > 0 {
            path := fmt.tprintf("mem%i.bin", app.save_memory);
            app.save_memory = 0;
            success := os.write_entire_file(path, app.app_arena.data, false);
            if success == false {
                log.errorf("Couldn't write %s", path);
                return;
            }
            log.infof("%s written.", path);
        }
        if app.load_memory > 0 {
            path := fmt.tprintf("mem%i.bin", app.load_memory);
            app.load_memory = 0;
            data, success := os.read_entire_file(path);
            if success == false {
                log.errorf("Couldn't read %s", path);
                return;
            }
            mem.copy(&app.app_arena.data[0], &data[0], len(app.app_arena.data));
            log.infof("%s read.", path);
        }

        if slice.contains(os.args, "no-hot") == false {
            // engine.timed_block(app.debug_state, "hot_reload");
            for i in 0 ..< 100 {
                info, info_err := os.stat(fmt.tprintf("game%i.bin", i), context.temp_allocator);
                if info_err == 0 && time.diff(_game_load_timestamp, info.modification_time) > 0 {
                    if code_load(info.name) {
                        // FIXME: do we need this?
                        // app.debug_state = engine.debug_init(app.debug_allocator);
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

game_update_stub : engine.Update_Proc : proc(delta_time: f64, app: ^engine.App) {
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
    // alloc_start(allocator_data, mode, size, alignment, old_memory, old_size, location);
    data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    // alloc_end(data, error);

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
