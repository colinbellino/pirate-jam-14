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

Named_Virtual_Arena :: struct {
    allocator:         mem.Allocator,
    backing_allocator: mem.Allocator,
    name:              string,
    arena:             virtual.Arena,
}
mem_named_arena_virtual_bootstrap_new_by_offset :: proc($T: typeid, offset_to_field: uintptr, reserved: uint, arena_name: string) -> (ptr: ^T, err: mem.Allocator_Error) {
    bootstrap: virtual.Arena
    bootstrap.kind = .Static
    bootstrap.minimum_block_size = reserved
    data := virtual.arena_alloc(&bootstrap, size_of(T), align_of(T)) or_return
    ptr = (^T)(raw_data(data))

    offset_to_arena := offset_of_by_string(Named_Virtual_Arena, "arena")
    named_arena := cast(^Named_Virtual_Arena) (uintptr(ptr) + offset_to_field)
    named_arena.backing_allocator = mem.Allocator {
        procedure = virtual.arena_allocator_proc,
        data      = &named_arena.arena,
    }
    named_arena.allocator = mem.Allocator {
        procedure = named_virtual_arena_allocator_proc,
        data      = named_arena,
    }
    named_arena.name = arena_name
    // when TRACY_ENABLE {
    //     data := new(ProfiledAllocatorDataNamed, result.allocator)
    //     data.name = strings.clone_to_cstring(field_name, result.allocator)
    //     result.allocator = profiler_make_profiled_allocator_named(data, backing_allocator = result.allocator)
    // }

    (^virtual.Arena)(uintptr(ptr) + offset_to_field + offset_to_arena)^ = bootstrap

    return
}

mem_zero_named_arena :: proc(named_arena: ^Named_Virtual_Arena) {
    arena := cast(^virtual.Arena) named_arena.backing_allocator.data
    block := arena.curr_block
    for block != nil {
        mem.zero(block.base, int(block.used))
        block = block.prev
    }
}

mem_make_named_arena :: proc(named_arena: ^Named_Virtual_Arena, arena_name: string, reserved: uint) -> mem.Allocator_Error {
    named_arena.backing_allocator = mem.Allocator {
        procedure = virtual.arena_allocator_proc,
        data      = &named_arena.arena,
    }
    named_arena.allocator = mem.Allocator {
        procedure = named_virtual_arena_allocator_proc,
        data      = named_arena,
    }
    named_arena.name = arena_name
    err := virtual.arena_init_static(&named_arena.arena, reserved)
    if err != .None {
        log.errorf("Allocation error when creating named arena: %v", err)
    }
    return err
}

@(private="package")
named_virtual_arena_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> ([]byte, mem.Allocator_Error) {
    named_arena := cast(^Named_Virtual_Arena) allocator_data
    arena := cast(^virtual.Arena) named_arena.backing_allocator.data
    data, error := named_arena.backing_allocator.procedure(arena, mode, size, alignment, old_memory, old_size, location)

    when ODIN_DEBUG {
        when LOG_ALLOC {
            log.debugf("(%v | %v) %v %v %v byte %v %v %v %v", named_arena.name, format_arena_usage_virtual(arena), allocator_data, mode, size, alignment, old_memory, old_size, location)
        }
        if error != .None {
            if error == .Mode_Not_Implemented {
                when LOG_ALLOC {
                    log.warnf("(%v) %v %v: %v byte at %v", named_arena.name, mode, error, size, location)
                }
            } else {
                log.errorf("(%v) %v %v: %v byte at %v", named_arena.name, mode, error, size, location)
                os.exit(0)
            }
        }
    }

    return data, error
}

mem_named_arena_virtual_bootstrap_new_by_name :: proc($T: typeid, $field_name: string, reserved: uint, arena_name: string) -> (ptr: ^T, err: mem.Allocator_Error) {
    return mem_named_arena_virtual_bootstrap_new_by_offset(T, offset_of_by_string(T, field_name), reserved, arena_name)
}
mem_named_arena_virtual_bootstrap_new_or_panic :: proc($T: typeid, $field_name: string, reserved: uint, arena_name: string) -> ^T {
    ptr, err := mem_named_arena_virtual_bootstrap_new_by_name(T, field_name, reserved, arena_name)
    if err != .None {
        fmt.panicf("Couldn't create arena: %v", err)
    }
    return ptr
}

format_arena_usage :: proc {
    format_arena_usage_data,
    format_arena_usage_static,
    format_arena_usage_virtual,
    format_arena_usage_named_virtual,
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
format_arena_usage_named_virtual :: proc(named_arena: ^Named_Virtual_Arena) -> string {
    arena := cast(^virtual.Arena) named_arena.backing_allocator.data
    return format_arena_usage_virtual(arena)
}

format_bytes_size :: proc(size_in_bytes: int, allocator := context.temp_allocator) -> string {
    UNITS := [?]string { "B", "kB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB" }
    i := 0
    size := f32(size_in_bytes)
    for size > 1024 {
        size /= 1024
        i += 1
    }
    return fmt.aprintf("%f %v", size, UNITS[i], allocator = allocator)
}
