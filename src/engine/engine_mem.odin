package engine

import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"

platform_make_virtual_arena :: proc(name: cstring, $T: typeid, size: uint) -> (state: ^T, err: mem.Allocator_Error) {
    state, err = virtual.arena_static_bootstrap_new_by_name(T, "arena", size)
    if err != .None {
        return
    }
    state.allocator = virtual.arena_allocator(&state.arena)

    when TRACY_ENABLE {
        data := new(ProfiledAllocatorDataNamed, state.allocator)
        data.name = name
        state.allocator = profiler_make_profiled_allocator_named(data, backing_allocator = state.allocator)
    }

    when LOG_ALLOC {
        state.allocator.procedure = platform_virtual_arena_allocator_proc
    }

    return
}

platform_make_arena_allocator :: proc(name: cstring, size: int, arena: ^mem.Arena, allocator := context.allocator, loc := #caller_location) -> mem.Allocator {
    buffer, error := make([]u8, size, allocator)
    if error != .None {
        log.errorf("Buffer alloc error: %v.", error)
    }

    when LOG_ALLOC {
        log.infof("[%v] Arena created with size: %v (TRACY_ENABLE: %v).", name, size, TRACY_ENABLE)
    }
    mem.arena_init(arena, buffer)
    arena_allocator := mem.arena_allocator(arena)
    arena_allocator.procedure = platform_arena_allocator_proc

    // when TRACY_ENABLE {
    //     data := new(ProfiledAllocatorDataNamed, arena_allocator)
    //     data.name = name
    //     arena_allocator = profiler_make_profiled_allocator_named(self = data, backing_allocator = arena_allocator)
    // }

    return arena_allocator
}

platform_virtual_arena_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location) -> ([]byte, mem.Allocator_Error)
{
    fmt.printf("platform_virtual_arena_allocator_proc %v %v %v %v %v %v %v\n", allocator_data, mode, size, alignment, old_memory, old_size, location)
    return virtual.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location)
}
platform_arena_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location) -> ([]byte, mem.Allocator_Error)
{
    data, error := mem.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location)

    when LOG_ALLOC {
        fmt.printf("platform_arena_allocator_proc %v %v %v %v %v %v %v\n", allocator_data, mode, size, alignment, old_memory, old_size, location)
    }

    when ODIN_DEBUG {
        if error != .None {
            if error == .Mode_Not_Implemented {
                log.warnf("ARENA alloc (%v) %v: %v byte at %v", mode, error, size, location)
            } else {
                log.errorf("ARENA alloc (%v) %v: %v byte at %v", mode, error, size, location)
                os.exit(0)
            }
        }
    }

    return data, error
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
