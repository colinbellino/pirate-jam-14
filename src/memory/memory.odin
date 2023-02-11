package game_memory

import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"

custom_arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    log.warnf("Arena alloc (%v) %v byte at %v", mode, size, location);
    result, error = mem.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    if error > .None {
        log.errorf("Arena alloc error %v", error);
        os.exit(0);
    }
    return;
}

custom_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    log.warnf("Custom alloc (%v) %v byte at %v", mode, size, location);
    result, error = runtime.default_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    if error > .None {
        log.errorf("Custom alloc error %v", error);
        os.exit(0);
    }
    return;
}

save_arena_to_file :: proc(filepath: string, arena: ^mem.Arena) {
    os.write_entire_file(filepath, arena.data[:len(arena.data)]);
    log.debugf("Saved arena to file: %v", filepath);
}

load_arena_from_file :: proc(filepath: string, arena: ^mem.Arena) {
    data, ok := os.read_entire_file_from_filename(filepath);
    defer delete(data);

    if data == nil {
        log.errorf("Error loading arena from file: empty");
        return;
    }
    if ok == false {
        log.errorf("Error loading arena from file: unknown");
        return;
    }
    log.debugf("Loaded arena from file: %v", filepath);
    mem.arena_init(arena, data);
}
