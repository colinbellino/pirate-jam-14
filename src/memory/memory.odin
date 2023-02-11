package game_memory

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
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

    if exists(filepath) {
        remove(filepath);
    }

    mode: int = 0;
    when ODIN_OS == .Linux || ODIN_OS == .Darwin {
        mode = S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH;
    }
    handle, open_error := open(filepath, O_WRONLY | O_CREATE, mode);
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
    using os;

    handle, open_error := open(filepath, O_RDONLY);
    defer close(handle);
    if open_error > 0 {
        log.errorf("open_error: %v", open_error);
        return;
    }

    // log.debugf("arena.data == nil: %v", arena.data == nil);
    // delete(arena.data);
    data_length := int(len(arena.data));

    data := make([]byte, data_length, context.temp_allocator);
    // defer delete(data);
    read(handle, data);
    offset := make([]byte, 8, context.temp_allocator);
    read(handle, offset);
    // defer delete(offset);
    peak_used := make([]byte, 8, context.temp_allocator);
    read(handle, peak_used);
    // defer delete(peak_used);
    temp_count := make([]byte, 8, context.temp_allocator);
    read(handle, temp_count);
    // defer delete(temp_count);

    log.debugf("Loaded arena from file: %v", filepath);

    log.debugf("&arena.data: %p | %p", &arena.data, arena.data);
    log.debugf("raw_data(arena.data): %p | %p", raw_data(arena.data));
    mem.copy(raw_data(arena.data), raw_data(data), data_length);
    // arena.data = transmute([]byte) (^[]byte)(raw_data(data[:data_length]))^;
    arena.offset = transmute(int) (^[8]byte)(raw_data(offset))^;
    arena.peak_used = transmute(int) (^[8]byte)(raw_data(peak_used))^;
    arena.temp_count = transmute(int) (^[8]byte)(raw_data(temp_count))^;
}

format_arena_usage_static :: proc(arena: ^mem.Arena) -> string {
    return fmt.tprintf("%v Kb / %v Kb",
        f32(arena.offset) / mem.Kilobyte,
        f32(len(arena.data)) / mem.Kilobyte);
}

format_arena_usage_virtual :: proc(arena: ^virtual.Arena) -> string {
    return fmt.tprintf("%v Kb / %v Kb",
        f32(arena.total_used) / mem.Kilobyte,
        f32(arena.total_reserved) / mem.Kilobyte);
}

format_arena_usage :: proc{
    format_arena_usage_static,
    format_arena_usage_virtual,
}
