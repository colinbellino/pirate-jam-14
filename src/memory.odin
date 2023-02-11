package main

import "core:fmt"
import "core:slice"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"
import "core:strconv"
import "core:strings"

APP_ARENA_PATH          :: "state.mem";
ARENA_SIZE_APP          :: 16;

State :: struct {
    pouet:              i8,
    bla:                i8,
}

App :: struct {
    arena:              mem.Arena,
    state:              ^State,
}

app : App = App {};
tracking_allocator : mem.Tracking_Allocator;

main :: proc() {
    options := log.Options { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color };
    context.logger = log.create_console_logger(runtime.Logger_Level.Debug, options);

    default_allocator := runtime.Allocator { custom_allocator_proc, nil };
    mem.tracking_allocator_init(&tracking_allocator, default_allocator);
    context.allocator = mem.tracking_allocator(&tracking_allocator);

    buffer := make([]u8, ARENA_SIZE_APP);
    mem.arena_init(&app.arena, buffer);
    delete(buffer);

    app_allocator := mem.Allocator { custom_arena_allocator_proc, &app.arena };
    // context.allocator = app_allocator;

    app.state = new(State, app_allocator);

    // log.debugf("arena:     %p | %v", &app.arena, app.arena);
    // log.debugf("state:     %p | %v", &app.state, app.state);

    if len(os.args) > 1 && os.args[1] == "save" {
        app.state.pouet = 12;
        app.state.bla = 34;
        os.write_entire_file(APP_ARENA_PATH, app.arena.data[:len(app.arena.data)]);
        log.debugf("saved state to file: %v", app.state);
    }
    else if len(os.args) > 1 && os.args[1] == "load" {
        data, ok := os.read_entire_file_from_filename(APP_ARENA_PATH);
        if data == nil {
            log.errorf("error loading state: empty");
            return;
        }
        if ok == false {
            log.errorf("error loading state: ???");
            return;
        }
        defer delete(data);
        log.debug("loaded state from file");
        mem.arena_init(&app.arena, data);
    }


    log.debugf("arena:     %p | %v", &app.arena, app.arena);
    log.debugf("state:     %p | %v", &app.state, app.state);
    log.info("done!");
}

custom_arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    log.warnf("arena alloc %v at %v", size, location);
    result, error = mem.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    if error > .None {
        log.errorf("arena alloc error %v", error);
    }
    return;
}

custom_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    log.infof("alloc %v at %v", size, location);
    result, error = runtime.default_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    if error > .None {
        log.errorf("alloc error %v", error);
    }
    return;
}
