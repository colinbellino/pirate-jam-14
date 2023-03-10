package engine_platform

import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "vendor:sdl2"

_temp_allocator: runtime.Allocator;
_allocator: runtime.Allocator;
_temp_allocs: i32;

set_memory_functions_default :: proc(location := #caller_location) {
    // if contains_os_args("log-alloc-sdl") && _temp_allocs == 0 {
    //     log.warnf("Switch to temp allocator but no alloc was done at %v", location);
    // }
    _temp_allocs = 0;

    // memory_error := sdl2.SetMemoryFunctions(
    //     sdl2.malloc_func(sdl_malloc),   sdl2.calloc_func(sdl_calloc),
    //     sdl2.realloc_func(sdl_realloc), sdl2.free_func(sdl_free),
    // );
    // if memory_error > 0 {
    //     log.errorf("SetMemoryFunctions error: %v", memory_error);
    // }
}

sdl_malloc   :: proc(size: c.size_t)              -> rawptr {
    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_malloc:  %v\n", size);
    }
    return mem.alloc(int(size), mem.DEFAULT_ALIGNMENT, _allocator);
}
sdl_calloc   :: proc(nmemb, size: c.size_t)       -> rawptr {
    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_calloc:  %v * %v\n", nmemb, size);
    }
    len := int(nmemb * size);
    ptr := mem.alloc(len, mem.DEFAULT_ALIGNMENT, _allocator);
    return mem.zero(ptr, len);
}
sdl_realloc  :: proc(_mem: rawptr, size: c.size_t) -> rawptr {
    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_realloc: %v | %v\n", _mem, size);
    }
    return mem.resize(_mem, int(size), int(size), mem.DEFAULT_ALIGNMENT, _allocator);
}
sdl_free     :: proc(_mem: rawptr) {
    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_free:    %v\n", _mem);
    }
    mem.free(_mem, _allocator);
}

set_memory_functions_temp :: proc(location := #caller_location) {
    // memory_error := sdl2.SetMemoryFunctions(
    //     sdl2.malloc_func(sdl_malloc_temp),   sdl2.calloc_func(sdl_calloc_temp),
    //     sdl2.realloc_func(sdl_realloc_temp), sdl2.free_func(sdl_free_temp),
    // );
    // if memory_error > 0 {
    //     log.errorf("SetMemoryFunctions error: %v", memory_error);
    // }
}

sdl_malloc_temp   :: proc(size: c.size_t)              -> rawptr {
    _temp_allocs += 1;

    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_malloc_temp:  %v\n", size);
    }
    return mem.alloc(int(size), mem.DEFAULT_ALIGNMENT, _temp_allocator);
}
sdl_calloc_temp   :: proc(nmemb, size: c.size_t)       -> rawptr {
    _temp_allocs += 1;

    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_calloc_temp:  %v * %v\n", nmemb, size);
    }
    len := int(nmemb * size);
    ptr := mem.alloc(len, mem.DEFAULT_ALIGNMENT, _temp_allocator);
    return mem.zero(ptr, len);
}
sdl_realloc_temp  :: proc(_mem: rawptr, size: c.size_t) -> rawptr {
    _temp_allocs += 1;

    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_realloc_temp: %v | %v\n", _mem, size);
    }
    return mem.resize(_mem, int(size), int(size), mem.DEFAULT_ALIGNMENT, _temp_allocator);
}
sdl_free_temp     :: proc(_mem: rawptr) {
    _temp_allocs += 1;

    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_free_temp:    %v\n", _mem);
    }
    mem.free(_mem, _temp_allocator);
}

Arena_Name :: enum {
    Unnamed,
    Temp,
    App,
    Platform,
    Renderer,
    Game,
    GameMode,
    WorldMode,
}

make_arena_allocator :: proc(name: Arena_Name, size: int, arena: ^mem.Arena, allocator: mem.Allocator = context.allocator, location := #caller_location) -> mem.Allocator {
    buffer, error := make([]u8, size, allocator);
    if error != .None {
        fmt.eprintf("Buffer alloc error: %v\n", error);
    }
    mem.arena_init(arena, buffer);
    new_allocator := mem.Allocator { arena_allocator_proc, arena };
    arena_name := new(Arena_Name, new_allocator);
    arena_name^ = name;
    return new_allocator;
}

scratch_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    result, error = mem.scratch_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    if contains_os_args("log-alloc-scratch") {
        ptr := mode == .Free ? old_memory : rawptr(&result);
        fmt.printf("[Scratch] %v %v byte (%p) at %v\n", mode, size, ptr, location);
        // s := (^mem.Scratch_Allocator)(allocator_data);
        // fmt.printf("bla: curr %v, prev %v, leak %v\n", s.curr_offset, s.prev_allocation, len(s.leaked_allocations));
    }

    if error != .None {
        fmt.eprintf("[Scratch] ERROR %v: %v byte at %v\n", error, size, location);
        os.exit(0);
    }

    return;
}


arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    result, error = custom_arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    arena := cast(^mem.Arena)allocator_data;
    arena_name: Arena_Name;
    if len(arena.data) > 0 {
        arena_name = cast(Arena_Name)arena.data[0];
    }

    if contains_os_args("log-alloc") {
        ptr := mode == .Free ? old_memory : rawptr(&result);
        fmt.printf("[%v] %v %v byte (%p) at %v\n", arena_name, mode, size, ptr, location);
    }

    if error != .None && error != .Mode_Not_Implemented {
        fmt.eprintf("[%v] ERROR %v: %v byte at %v\n", arena_name, error, size, location);
        os.exit(0);
    }

    return;
}

@(private)
custom_arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> ([]byte, mem.Allocator_Error)  {
    arena := cast(^mem.Arena)allocator_data;

    switch mode {
        case .Alloc, .Alloc_Non_Zeroed:
            #no_bounds_check end := &arena.data[arena.offset];

            ptr := mem.align_forward(end, uintptr(alignment));

            total_size := size + mem.ptr_sub((^byte)(ptr), (^byte)(end));

            if arena.offset + total_size > len(arena.data) {
                return nil, .Out_Of_Memory;
            }

            arena.offset += total_size;
            arena.peak_used = max(arena.peak_used, arena.offset);
            if mode != .Alloc_Non_Zeroed {
                mem.zero(ptr, size);
            }
            return mem.byte_slice(ptr, size), nil;

        case .Free:
            return nil, .Mode_Not_Implemented;

        case .Free_All:
            arena.offset = size_of(Arena_Name); // Important: we want to keep the arena name which is always first

        case .Resize:
            return mem.default_resize_bytes_align(mem.byte_slice(old_memory, old_size), size, alignment, mem.arena_allocator(arena));

        case .Query_Features:
            set := (^mem.Allocator_Mode_Set)(old_memory);
            if set != nil {
                set^ = {.Alloc, .Alloc_Non_Zeroed, .Free_All, .Resize, .Query_Features};
            }
            return nil, nil;

        case .Query_Info:
            return nil, .Mode_Not_Implemented;
        }

    return nil, nil;
}

allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    result, error = runtime.default_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    if contains_os_args("log-alloc") {
        ptr := mode == .Free ? old_memory : rawptr(&result);
        fmt.printf("[Default] %v %v byte (%p) at %v\n", mode, size, ptr, location);
    }

    if error != .None {
        fmt.eprintf("[Default] ERROR %v: %v %v byte at %v\n", error, mode, size, location);
        os.exit(0);
    }
    return;
}
