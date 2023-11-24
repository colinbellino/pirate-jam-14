package engine

import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"
import "core:slice"

platform_make_virtual_arena :: proc(name: cstring, $T: typeid, size: uint) -> (state: ^T, err: mem.Allocator_Error) {
    state, err = virtual.arena_static_bootstrap_new_by_name(T, "arena", size)
    if err != .None {
        return
    }
    state.allocator = virtual.arena_allocator(&state.arena)
    state.allocator.procedure = platform_virtual_arena_allocator_proc

    when TRACY_ENABLE {
        data := new(ProfiledAllocatorDataNamed, state.allocator)
        data.name = name
        state.allocator = profiler_make_profiled_allocator_named(data, backing_allocator = state.allocator)
    }

    return
}

Named_Arena_Allocator :: struct {
    backing_allocator: mem.Allocator,
    named_allocator:   mem.Allocator,
    name:              string,
}

platform_make_named_arena_allocator :: proc(arena_name: string, size: int, allocator := context.allocator, loc := #caller_location) -> mem.Allocator {
    context.allocator = allocator

    named_arena_allocator := new(Named_Arena_Allocator)
    named_arena_allocator.name = arena_name

    arena := new(mem.Arena)
    buffer, error := make([]u8, size)
    if error != .None {
        log.errorf("Buffer alloc error: %v.", error)
    }
    mem.arena_init(arena, buffer)
    named_arena_allocator.backing_allocator = mem.Allocator {
        procedure = mem.arena_allocator_proc,
        data      = arena,
    }
    named_arena_allocator.named_allocator = mem.Allocator {
        procedure = _named_arena_allocator_proc,
        data      = named_arena_allocator,
    }

    when LOG_ALLOC {
        log.infof("(%v) Arena created with size: %v (TRACY_ENABLE: %v).", arena_name, size, TRACY_ENABLE)
    }

    // when TRACY_ENABLE {
    //     data := new(ProfiledAllocatorDataNamed, arena_allocator)
    //     data.name = name
    //     arena_allocator = profiler_make_profiled_allocator_named(self = data, backing_allocator = arena_allocator)
    // }

    return named_arena_allocator.named_allocator
}

plateform_free_and_zero_named_arena :: proc(named_arena_allocator: ^Named_Arena_Allocator) {
    arena := cast(^mem.Arena) named_arena_allocator.backing_allocator.data
    mem.zero_slice(arena.data)
    free_all(named_arena_allocator.named_allocator)
}

@(private="file")
_named_arena_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> ([]byte, mem.Allocator_Error) {
    named_arena_allocator := cast(^Named_Arena_Allocator) allocator_data
    arena := cast(^mem.Arena) named_arena_allocator.backing_allocator.data

    data, error := named_arena_allocator.backing_allocator.procedure(arena, mode, size, alignment, old_memory, old_size, location)

    when ODIN_DEBUG {
        when LOG_ALLOC {
            fmt.printf("(%v | %v) %v %v %v byte %v %v %v %v\n", named_arena_allocator.name, format_arena_usage_static(arena), allocator_data, mode, size, alignment, old_memory, old_size, location)
        }
        if error != .None {
            if error == .Mode_Not_Implemented {
                log.warnf("(%v) %v %v: %v byte at %v", named_arena_allocator.name, mode, error, size, location)
            } else {
                log.errorf("(%v) %v %v: %v byte at %v", named_arena_allocator.name, mode, error, size, location)
                os.exit(0)
            }
        }
    }

    return data, error
}

platform_virtual_arena_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (new_memory: []byte, error: mem.Allocator_Error) {
    new_memory, error = virtual.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location)

    when ODIN_DEBUG {
        when LOG_ALLOC {
            fmt.printf("(VIRTUAL) %v %v %v byte %v %v %v %v\n", mode, allocator_data, size, alignment, old_memory, old_size, location)
        }
        if error != .None {
            if error == .Mode_Not_Implemented {
                when LOG_ALLOC {
                    fmt.printf("(VIRTUAL) %v %v: %v byte at %v\n", mode, error, size, location)
                }
            } else {
                fmt.panicf("(VIRTUAL) %v %v: %v byte at %v\n", mode, error, size, location)
            }
        }
    }

    return
}

format_arena_usage :: proc {
    format_arena_usage_static_data,
    format_arena_usage_static,
    format_arena_usage_virtual,
}
format_arena_usage_static_data :: proc(offset, data_length: int) -> string {
    return fmt.tprintf("%v Kb / %v Kb", f32(offset) / mem.Kilobyte, f32(data_length) / mem.Kilobyte)
}
format_arena_usage_static :: proc(arena: ^mem.Arena) -> string {
    return format_arena_usage_static_data(arena.offset, len(arena.data))
}
format_arena_usage_virtual :: proc(arena: ^virtual.Arena) -> string {
    return format_arena_usage_static_data(int(arena.total_used), int(arena.total_reserved))
}
