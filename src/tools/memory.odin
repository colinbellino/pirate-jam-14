package tools

import "core:fmt"
import "core:log"
import "core:mem"
import "core:runtime"

mem_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, loc := #caller_location,
)-> (data: []byte, err: mem.Allocator_Error) {
    data, err = runtime.default_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, loc)
    fmt.printf("%-16s | old_memory: %14v | size: %10d | %v\n", mode, old_memory, size, loc)
    return
}

mem_get_diff :: proc() -> (string, bool) #optional_ok {
    current, previous := mem_get_usage()
    str := fmt.tprintf("MEM              | %v - %v = %v", current, previous, current - previous)
    changed := current != previous
    return str, changed
}

panic_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, loc := #caller_location)-> (data: []byte, err: mem.Allocator_Error) {
    fmt.panicf("allocator_panic: %v %v -> %v\n", mode, size, loc)
}

log_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, loc := #caller_location,
)-> (data: []byte, err: mem.Allocator_Error) {
    data, err = runtime.default_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, loc)
    fmt.printf("allocator_proc: %v %v -> %v\n", mode, size, loc)
    if err != .None {
        fmt.eprintf("allocator_proc error: %v (%v) <- %v\n", err, mode, loc)
    }
    return
}

log_temp_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, loc := #caller_location,
)-> (data: []byte, err: mem.Allocator_Error) {
    data, err = runtime.default_temp_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, loc)
    fmt.printf("temp_allocator_proc: %v %v -> %v\n", mode, size, loc)
    if err != .None && mode != .Free {
        fmt.eprintf("temp_allocator_proc error: %v (%v) <- %v\n", err, mode, loc)
    }
    return
}

temp_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, loc := #caller_location,
)-> (data: []byte, err: mem.Allocator_Error) {
    data, err = runtime.default_temp_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, loc)
    if err != .None && mode != .Free {
        fmt.eprintf("temp_allocator_proc error: %v (%v) <- %v\n", err, mode, loc)
    }
    return
}
