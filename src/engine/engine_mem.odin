package engine

import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:strings"

platform_make_virtual_arena :: proc($T: typeid, $field_name: string, reserved: uint) -> (result: ^T, err: mem.Allocator_Error) {
    result, err = virtual.arena_static_bootstrap_new_by_name(T, field_name, reserved)
    if err != .None {
        return
    }
    result.allocator = virtual.arena_allocator(&result.arena)
    result.allocator.procedure = platform_virtual_arena_allocator_proc

    when TRACY_ENABLE {
        data := new(ProfiledAllocatorDataNamed, result.allocator)
        data.name = strings.clone_to_cstring(field_name, result.allocator)
        result.allocator = profiler_make_profiled_allocator_named(data, backing_allocator = result.allocator)
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

    named_arena_allocator, named_arena_allocator_err := new(Named_Arena_Allocator)
    if named_arena_allocator_err != .None {
        fmt.panicf("(%v) Arena alloc error: %v", arena_name, named_arena_allocator_err)
    }
    named_arena_allocator.name = arena_name

    arena := new(mem.Arena)
    buffer, buffer_err := make([]u8, size)
    if buffer_err != .None {
        fmt.panicf("(%v) Arena alloc error: %v.", arena_name, buffer_err)
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
            log.debugf("(%v | %v) %v %v %v byte %v %v %v %v", named_arena_allocator.name, format_arena_usage_static(arena), allocator_data, mode, size, alignment, old_memory, old_size, location)
        }
        if error != .None {
            if error == .Mode_Not_Implemented {
                when LOG_ALLOC {
                    log.warnf("(%v) %v %v: %v byte at %v", named_arena_allocator.name, mode, error, size, location)
                }
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
    format_arena_usage_data,
    format_arena_usage_static,
    format_arena_usage_virtual,
}
format_arena_usage_data :: proc(offset, data_length: int) -> string {
    return fmt.tprintf("%s / %s", format_bytes_size(offset), format_bytes_size(data_length))
}
format_arena_usage_static :: proc(arena: ^mem.Arena) -> string {
    return format_arena_usage_data(arena.offset, len(arena.data))
}
format_arena_usage_virtual :: proc(arena: ^virtual.Arena) -> string {
    return format_arena_usage_data(int(arena.total_used), int(arena.total_reserved))
}

format_bytes_size :: proc(size_in_bytes: int, allocator := context.temp_allocator) -> string {
    UNITS := [?]string { "B", "kB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB" }
    i := 0
    size := f32(size_in_bytes)
    for size > 1024 {
        size /= 1024
        i += 1
    }
    return fmt.aprintf("%.3f %v", size, UNITS[i], allocator = allocator)
}
