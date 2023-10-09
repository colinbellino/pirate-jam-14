package engine

import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"

Arena_Name :: enum u8 {
    Unnamed,
    App,
    Engine,
    Temp,
    Game,
    GameMode,
    WorldMode,
}

platform_make_arena_allocator :: proc(
    name: Arena_Name, size: int, arena: ^mem.Arena, allocator: mem.Allocator,
    location := #caller_location,
) -> mem.Allocator {
    buffer, error := make([]u8, size, allocator)
    if error != .None {
        log.errorf("Buffer alloc error: %v.", error)
    }

    log.debugf("[%v] Arena created with size: %v (profiled: %v).", name, size, PROFILER)
    mem.arena_init(arena, buffer)
    arena_allocator := mem.Allocator { platform_arena_allocator_proc, arena }
    arena_name := new(Arena_Name, arena_allocator)
    arena_name^ = name

    when PROFILER {
        data := new(ProfiledAllocatorData, arena_allocator)
        profiler_make_profiled_allocator(data, arena_allocator)
    }

    return arena_allocator
}

platform_arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (new_memory: []byte, error: mem.Allocator_Error) {
    new_memory, error = _named_arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location)

    arena := cast(^mem.Arena)allocator_data
    arena_name: Arena_Name
    if len(arena.data) > 0 {
        arena_name = cast(Arena_Name)arena.data[0]
    }

    arena_formatted_name := fmt.tprintf("%v", arena_name)

    if LOG_ALLOC {
        ptr := mode == .Free ? old_memory : rawptr(&new_memory)
        fmt.printf("[%v] %v %v byte (%p) at ", arena_formatted_name, mode, size, ptr)
        runtime.print_caller_location(location)
        runtime.print_byte('\n')
    }

    if error != .None && error != .Mode_Not_Implemented {
        fmt.eprintf("[%v] ERROR %v: %v byte at ", arena_formatted_name, error, size)
        runtime.print_caller_location(location)
        runtime.print_byte('\n')
        os.exit(0)
    }

    return
}

@(private="file")
_named_arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> ([]byte, mem.Allocator_Error)  {
    arena := cast(^mem.Arena)allocator_data

    switch mode {
        case .Alloc, .Alloc_Non_Zeroed:
            #no_bounds_check end := &arena.data[arena.offset]

            ptr := mem.align_forward(end, uintptr(alignment))

            total_size := size + mem.ptr_sub((^byte)(ptr), (^byte)(end))

            if arena.offset + total_size > len(arena.data) {
                return nil, .Out_Of_Memory
            }

            arena.offset += total_size
            arena.peak_used = max(arena.peak_used, arena.offset)
            if mode != .Alloc_Non_Zeroed {
                mem.zero(ptr, size)
            }
            return mem.byte_slice(ptr, size), nil

        case .Free:
            return nil, .Mode_Not_Implemented

        case .Free_All:
            arena.offset = size_of(Arena_Name) // Important: we want to keep the arena name which is always first

        case .Resize:
            return mem.default_resize_bytes_align(mem.byte_slice(old_memory, old_size), size, alignment, mem.arena_allocator(arena))

        case .Query_Features:
            set := (^mem.Allocator_Mode_Set)(old_memory)
            if set != nil {
                set^ = {.Alloc, .Alloc_Non_Zeroed, .Free_All, .Resize, .Query_Features}
            }
            return nil, nil

        case .Query_Info:
            return nil, .Mode_Not_Implemented
        }

    return nil, nil
}

format_arena_usage_static_data :: proc(offset: int, data_length: int) -> string {
    return fmt.tprintf("%v Kb / %v Kb",
        f32(offset) / mem.Kilobyte,
        f32(data_length) / mem.Kilobyte)
}

format_arena_usage_static :: proc(arena: ^mem.Arena) -> string {
    return fmt.tprintf("%v Kb / %v Kb",
        f32(arena.offset) / mem.Kilobyte,
        f32(len(arena.data)) / mem.Kilobyte)
}

format_arena_usage_virtual :: proc(arena: ^virtual.Arena) -> string {
    return fmt.tprintf("%v Kb / %v Kb",
        f32(arena.total_used) / mem.Kilobyte,
        f32(arena.total_reserved) / mem.Kilobyte)
}

format_arena_usage :: proc {
    format_arena_usage_static_data,
    format_arena_usage_static,
    format_arena_usage_virtual,
}
