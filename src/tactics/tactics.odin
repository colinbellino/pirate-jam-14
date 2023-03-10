package tactics

foreign import libc "System.framework"
foreign libc {
    @(link_name="mmap")             _mmap               :: proc(addr: rawptr, len: c.size_t, prot: c.int, flags: c.int, fd: c.int, offset: int) -> rawptr ---
    @(link_name="mprotect")         _mprotect           :: proc(addr: rawptr, len: c.size_t, prot: c.int) -> c.int ---
}

PROT_NONE  :: 0x0 /* [MC2] no permissions */
PROT_READ  :: 0x1 /* [MC2] pages can be read */
PROT_WRITE :: 0x2 /* [MC2] pages can be written */
PROT_EXEC  :: 0x4 /* [MC2] pages can be executed */

// Sharing options
MAP_SHARED    :: 0x1 /* [MF|SHM] share changes */
MAP_PRIVATE   :: 0x2 /* [MF|SHM] changes are private */

// Other flags
MAP_FIXED        :: 0x0010 /* [MF|SHM] interpret addr exactly */
MAP_RENAME       :: 0x0020 /* Sun: rename private pages to file */
MAP_NORESERVE    :: 0x0040 /* Sun: don't reserve needed swap area */
MAP_RESERVED0080 :: 0x0080 /* previously unimplemented MAP_INHERIT */
MAP_NOEXTEND     :: 0x0100 /* for MAP_FILE, don't change file size */
MAP_HASSEMAPHORE :: 0x0200 /* region may contain semaphores */
MAP_NOCACHE      :: 0x0400 /* don't cache pages for this mapping */
MAP_JIT          :: 0x0800 /* Allocate a region that will be used for JIT purposes */

// Mapping type
MAP_FILE         :: 0x0000  /* map from file (default) */
MAP_ANONYMOUS    :: 0x1000  /* allocated from memory, swap space */

// Allocation failure result
MAP_FAILED : rawptr = rawptr(~uintptr(0))

reserve :: proc "contextless" (size: uint, base_address: rawptr = nil) -> (data: []byte, err: runtime.Allocator_Error) {
    result := _mmap(base_address, size, PROT_NONE, MAP_ANONYMOUS | MAP_SHARED | MAP_FIXED, -1, 0);
    if result == MAP_FAILED {
        return nil, .Out_Of_Memory
    }
    return ([^]byte)(uintptr(result))[:size], nil
}

commit :: proc "contextless" (data: rawptr, size: uint) -> runtime.Allocator_Error {
    result := _mprotect(data, size, PROT_READ | PROT_WRITE)
    if result != 0 {
        return .Out_Of_Memory
    }
    return nil
}

reserve_and_commit :: proc "contextless" (size: uint, base_address: rawptr = nil) -> (data: []byte, err: runtime.Allocator_Error) {
    data = reserve(size, base_address) or_return
    commit(raw_data(data), size) or_return
    return
}

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
// import engine_logger "../engine/logger"
import "../engine/platform"
import "../engine/renderer"

APP_MEMORY_SIZE      :: PLATFORM_MEMORY_SIZE + RENDERER_MEMORY_SIZE + GAME_MEMORY_SIZE + LOGGER_MEMORY_SIZE;
PLATFORM_MEMORY_SIZE :: 256 * mem.Kilobyte;
RENDERER_MEMORY_SIZE :: 512 * mem.Kilobyte;
GAME_MEMORY_SIZE     :: 2048 * mem.Kilobyte;
LOGGER_MEMORY_SIZE   :: 256 * mem.Kilobyte;
TEMP_MEMORY_SIZE     :: 512 * mem.Kilobyte;

main :: proc() {
    context.allocator = mem.Allocator { default_allocator_proc, nil };

    default_temp_allocator_data := runtime.Default_Temp_Allocator {};
    runtime.default_temp_allocator_init(&default_temp_allocator_data, TEMP_MEMORY_SIZE, context.allocator);
    context.temp_allocator.procedure = default_temp_allocator_proc;
    context.temp_allocator.data = &default_temp_allocator_data;

    base_address :: 2 * mem.Terabyte;
    app_memory, alloc_error := reserve_and_commit(APP_MEMORY_SIZE, rawptr(uintptr((base_address))));
    fmt.printf("app_memory:   %p\n", app_memory);
    if alloc_error > .None {
        fmt.eprintf("Error: %v\n", alloc_error);
        os.exit(1);
    }

    app_arena := mem.Arena {};
    mem.arena_init(&app_arena, app_memory);
    app_allocator := mem.Allocator { platform.arena_allocator_proc, &app_arena };
    arena_name := new(platform.Arena_Name, app_allocator);
    fmt.printf("app_arena:    %p\n", app_arena.data);

    default_logger : runtime.Logger;
    if platform.contains_os_args("no-log") == false {
        // game_memory.logger_state = engine_logger.create_logger(mem.Allocator { engine_logger.allocator_proc, nil });
        // game_memory.logger = game_memory.logger_state.logger;
        options := log.Options { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color };
        data := new(log.File_Console_Logger_Data, app_allocator);
        data.file_handle = os.INVALID_HANDLE;
        data.ident = "";
        default_logger = log.Logger { log.file_console_logger_proc, data, runtime.Logger_Level.Debug, options };
    }
    context.logger = default_logger;

    game_memory := new(game.Game_Memory, app_allocator);
    game_memory.padding_start = 0xAAAA_AAAA_AAAA_AAAA;
    game_memory.padding_end =   0xBBBB_BBBB_BBBB_BBBB;
    game_memory.platform_allocator = platform.make_arena_allocator(.Platform, PLATFORM_MEMORY_SIZE, &game_memory.platform_arena, app_allocator);
    game_memory.renderer_allocator = platform.make_arena_allocator(.Renderer, RENDERER_MEMORY_SIZE, &game_memory.renderer_arena, app_allocator);
    game_memory.game_allocator = platform.make_arena_allocator(.Game, GAME_MEMORY_SIZE, &game_memory.game_arena, app_allocator);
    game_memory.temp_allocator = os.heap_allocator();

    // {
    //     path := fmt.tprintf("mem%i.bin", 0);
    //     success := os.write_entire_file(path, app_arena.data, false);
    //     log.debugf("%s written.", path);
    // }

    platform_ok: bool;
    game_memory.platform_state, platform_ok = platform.init(game_memory.platform_allocator, game_memory.temp_allocator);
    if platform_ok == false {
        log.error("Couldn't platform.init correctly.");
        return;
    }

    // {
    //     path := fmt.tprintf("mem%i.bin", 1);
    //     success := os.write_entire_file(path, app_arena.data, false);
    //     log.debugf("%s written.", path);
    // }

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

    for game_memory.platform_state.quit == false {
        debug.frame_timing_start(game_memory.debug_state);
        defer debug.frame_timing_end(game_memory.debug_state);

        platform.update_and_render(game_memory.platform_state, _game_update, _game_fixed_update, _game_render, game_memory);

        if game_memory.save_memory > 0 {
            path := fmt.tprintf("mem%i.bin", game_memory.save_memory);
            game_memory.save_memory = 0;
            success := os.write_entire_file(path, app_arena.data, false);
            if success == false {
                log.errorf("Couldn't write %s", path);
                return;
            }
            log.debugf("%s written.", path);
        }
        if game_memory.load_memory > 0 {
            path := fmt.tprintf("mem%i.bin", game_memory.load_memory);
            game_memory.load_memory = 0;
            data, success := os.read_entire_file(path);
            if success == false {
                log.errorf("Couldn't read %s", path);
                return;
            }
            // mem.zero(&app_arena.data[0], len(app_arena.data));
            mem.copy(&app_arena.data[0], &data[0], len(app_arena.data));
            log.debugf("app_arena.data: %p", app_arena.data);
            log.debugf("%s read.", path);
        }

        if platform.contains_os_args("no-hot") == false {
            debug.timed_block(game_memory.debug_state, 0);
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
