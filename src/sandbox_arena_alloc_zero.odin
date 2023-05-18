package main

import "core:fmt"
import "core:mem"
import "core:runtime"

@(deferred_out=mem.end_arena_temp_memory)
arena_temp_block :: proc(arena: ^mem.Arena) -> mem.Arena_Temp_Memory {
    return mem.begin_arena_temp_memory(arena);
}

main :: proc() {
    context.allocator = arena_allocator_make(6);
    arena := cast(^mem.Arena) context.allocator.data;
    fmt.printf("arena: %v\n", arena);

    d := make([]u8, 3);
    d[0] = 1;
    d[1] = 1;
    d[2] = 1;
    fmt.printf("arena: %v\n", arena);

    {
        arena_temp_block(arena);
        d := make([]u8, 3);
        d[0] = 2;
        d[1] = 2;
        d[2] = 2;
    }
    fmt.printf("arena: %v\n", arena);

    e := make([]u8, 3);
    e[0] = 3;
    e[1] = 3;
    e[2] = 3;
    fmt.printf("arena: %v\n", arena);

    arena_allocator_free_all_and_zero();
    fmt.printf("arena: %v\n", arena);
}

arena_allocator_make :: proc(size: int) -> runtime.Allocator {
    arena := new(mem.Arena);
    arena_backing_buffer := make([]u8, size);
    mem.arena_init(arena, arena_backing_buffer);
    return mem.arena_allocator(arena);
}

arena_allocator_free_all_and_zero :: proc(allocator: runtime.Allocator = context.allocator) {
    arena := cast(^mem.Arena) allocator.data;
    mem.zero_slice(arena.data);
    free_all(allocator);
}
