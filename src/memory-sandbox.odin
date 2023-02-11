package main


import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:strconv"
import "core:strings"

import "memory"

APP_ARENA_PATH          :: "./state1.mem";
ARENA_SIZE_APP          :: 16;
// ARENA_SIZE_APP          :: 32 * mem.Megabyte;

State :: struct {
    pouet:              i8,
    bla:                i8,
}

App :: struct {
    state:              ^State,
}

arena: mem.Arena;
tracking_allocator: mem.Tracking_Allocator;
app: App;

main :: proc() {
    options := log.Options { .Level, .Time/* , .Short_File_Path, .Line */, .Terminal_Color };
    context.logger = log.create_console_logger(runtime.Logger_Level.Debug, options);

    app_allocator := runtime.Allocator { allocator_proc, nil };
    mem.tracking_allocator_init(&tracking_allocator, app_allocator);
    context.allocator = mem.tracking_allocator(&tracking_allocator);

        buffer := make([]u8, ARENA_SIZE_APP);
        // defer delete(buffer);
        mem.arena_init(&arena, buffer);

    arena_allocator := mem.Allocator { arena_allocator_proc, &arena };
    // context.allocator = arena_allocator;

    app.state = new(State, arena_allocator);

    if len(os.args) > 1 && os.args[1] == "save" {
        app.state.pouet = 12;
        app.state.bla = 34;
        memory.save_arena_to_file(APP_ARENA_PATH, &arena);
    }
    else if len(os.args) > 1 && os.args[1] == "load" {
        log.debugf("state:     %p | %v", &app.state, app.state);
        // log.debugf("arena.data:       %v", arena.data);
        log.debugf("arena.offset:     %v", arena.offset);
        log.debugf("arena.peak_used:  %v", arena.peak_used);
        log.debugf("arena.temp_count: %v", arena.temp_count);
        memory.load_arena_from_file(APP_ARENA_PATH, &arena, app_allocator);
    }

    log.debugf("arena:     %p | %v", &arena, arena);
    log.debugf("state:     %p | %v", &app.state, app.state);
    log.debugf("len(arena.data):     %v", len(arena.data));

    log.info("DONE!");

    // for _, leak in tracking_allocator.allocation_map {
    //     log.warnf("Leaked %v bytes at %v.", leak.size, leak.location);
    // }
    // for bad_free in tracking_allocator.bad_free_array {
    //     log.warnf("Allocation %p was freed badly at %v.", bad_free.location, bad_free.memory);
    // }
}

arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    result, error = mem.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    if error > .None {
        // fmt.eprintf("[ARENA] ERROR: %v %v byte at %v -> %v\n", mode, size, location, error);
        // os.exit(0);
    } else {
        if slice.contains(os.args, "show-alloc") {
            fmt.printf("[ARENA] %v %v byte at %v -> %v\n", mode, size, location, memory.format_arena_usage(&arena));
        }
    }
    return;
}

allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    if slice.contains(os.args, "show-alloc") {
        fmt.printf("[SANDBOX] %v %v byte at %v\n", mode, size, location);
    }
    result, error = runtime.default_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    if error > .None {
        fmt.eprintf("[SANDBOX] alloc error %v\n", error);
        os.exit(0);
    }
    return;
}
