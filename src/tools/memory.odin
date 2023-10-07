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
