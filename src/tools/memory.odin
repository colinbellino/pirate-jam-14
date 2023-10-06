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
    log.debugf("%-16s | old_memory: %14v | size: %10d | %v", mode, old_memory, size, loc)
    mem_print_diff()
    return
}

mem_print_diff :: proc() {
    current, previous := mem_get_usage()
    diff := current - previous
    log.debugf("MEM              | %v - %v = %v", current, previous, diff)
}
