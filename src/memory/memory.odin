package game_memory

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:slice"

arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    if slice.contains(os.args, "show-alloc") {
        fmt.printf("[ARENA] %v %v byte at %v\n", mode, size, location);
    }
    result, error = mem.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    if error > .None {
        fmt.eprintf("[ARENA] ERROR: %v %v byte at %v -> %v\n", mode, size, location, error);
        // os.exit(0);
    }
    return;
}

save_arena_to_file :: proc(filepath: string, arena: ^mem.Arena) {
    using os;

    handle, open_error := open(filepath, O_RDWR | O_CREATE, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
    defer close(handle);
    if open_error > 0 {
        log.errorf("open_error: %v", open_error);
        return;
    }

    write(handle, arena.data);
    write(handle, mem.any_to_bytes(arena.offset));
    write(handle, mem.any_to_bytes(arena.peak_used));
    write(handle, mem.any_to_bytes(arena.temp_count));
    log.debugf("Saved arena to file: %v", filepath);
}

load_arena_from_file :: proc(filepath: string, arena: ^mem.Arena, allocator: mem.Allocator) {
    // data, ok := os.read_entire_file_from_filename(filepath, allocator);
    // defer delete(data);

    using os;

    handle, open_error := open(filepath, O_RDWR | O_CREATE, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
    defer close(handle);
    if open_error > 0 {
        log.errorf("open_error: %v", open_error);
        return;
    }

    data := make([]byte, int(len(arena.data)), allocator);
    defer delete(data);
    read(handle, data);
    offset := make([]byte, 8, allocator);
    read(handle, offset);
    defer delete(offset);
    peak_used := make([]byte, 8, allocator);
    read(handle, peak_used);
    defer delete(peak_used);
    temp_count := make([]byte, 8, allocator);
    read(handle, temp_count);
    defer delete(temp_count);

    // if data == nil {
    //     log.errorf("Error loading arena from file: empty");
    //     return;
    // }
    // if ok == false {
    //     log.errorf("Error loading arena from file: unknown");
    //     return;
    // }

    log.debugf("Loaded arena from file: %v", filepath);

    new_arena := mem.Arena {};
    new_arena.data = data;
    new_arena.offset = transmute(int) (^[8]byte)(raw_data(offset))^;
    new_arena.peak_used = transmute(int) (^[8]byte)(raw_data(peak_used))^;
    new_arena.temp_count = transmute(int) (^[8]byte)(raw_data(temp_count))^;
    log.debugf("arena.offset: %v", arena.offset);
    log.debugf("arena.peak_used: %v", arena.peak_used);
    log.debugf("arena.temp_count: %v", arena.temp_count);

    arena.data = new_arena.data;
    arena.offset = new_arena.offset;
    arena.peak_used = new_arena.peak_used;
    arena.temp_count = new_arena.temp_count;

    log.debugf("arena.offset: %v", arena.offset);
    log.debugf("arena.peak_used: %v", arena.peak_used);
    log.debugf("arena.temp_count: %v", arena.temp_count);
}
