package engine_platform

import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:slice"
when ODIN_OS == .Windows {
    import win32 "core:sys/windows"
}

import sdl "vendor:sdl2"

set_memory_functions_default :: proc() {
    memory_error := sdl.SetMemoryFunctions(
        sdl.malloc_func(sdl_malloc),   sdl.calloc_func(sdl_calloc),
        sdl.realloc_func(sdl_realloc), sdl.free_func(sdl_free),
    );
    if memory_error > 0 {
        log.errorf("SetMemoryFunctions error: %v", memory_error);
    }
}

sdl_malloc   :: proc(size: c.size_t)              -> rawptr {
    if slice.contains(os.args, "show-alloc-sdl") {
        fmt.printf("sdl_malloc:  %v\n", size);
    }
    return mem.alloc(int(size), mem.DEFAULT_ALIGNMENT, _allocator);
}
sdl_calloc   :: proc(nmemb, size: c.size_t)       -> rawptr {
    if slice.contains(os.args, "show-alloc-sdl") {
        fmt.printf("sdl_calloc:  %v * %v\n", nmemb, size);
    }
    len := int(nmemb * size);
    ptr := mem.alloc(len, mem.DEFAULT_ALIGNMENT, _allocator);
    return mem.zero(ptr, len);
}
sdl_realloc  :: proc(_mem: rawptr, size: c.size_t) -> rawptr {
    if slice.contains(os.args, "show-alloc-sdl") {
        fmt.printf("sdl_realloc: %v | %v\n", _mem, size);
    }
    return mem.resize(_mem, int(size), int(size), mem.DEFAULT_ALIGNMENT, _allocator);
}
sdl_free     :: proc(_mem: rawptr) {
    if slice.contains(os.args, "show-alloc-sdl") {
        fmt.printf("sdl_free:    %v\n", _mem);
    }
    mem.free(_mem, _allocator);
}

set_memory_functions_temp :: proc() {
    memory_error := sdl.SetMemoryFunctions(
        sdl.malloc_func(sdl_malloc_temp),   sdl.calloc_func(sdl_calloc_temp),
        sdl.realloc_func(sdl_realloc_temp), sdl.free_func(sdl_free_temp),
    );
    if memory_error > 0 {
        log.errorf("SetMemoryFunctions error: %v", memory_error);
    }
}

sdl_malloc_temp   :: proc(size: c.size_t)              -> rawptr {
    if slice.contains(os.args, "show-alloc-sdl") {
        fmt.printf("sdl_malloc_temp:  %v\n", size);
    }
    return mem.alloc(int(size), mem.DEFAULT_ALIGNMENT, _temp_allocator);
}
sdl_calloc_temp   :: proc(nmemb, size: c.size_t)       -> rawptr {
    if slice.contains(os.args, "show-alloc-sdl") {
        fmt.printf("sdl_calloc_temp:  %v * %v\n", nmemb, size);
    }
    len := int(nmemb * size);
    ptr := mem.alloc(len, mem.DEFAULT_ALIGNMENT, _temp_allocator);
    return mem.zero(ptr, len);
}
sdl_realloc_temp  :: proc(_mem: rawptr, size: c.size_t) -> rawptr {
    if slice.contains(os.args, "show-alloc-sdl") {
        fmt.printf("sdl_realloc_temp: %v | %v\n", _mem, size);
    }
    return mem.resize(_mem, int(size), int(size), mem.DEFAULT_ALIGNMENT, _temp_allocator);
}
sdl_free_temp     :: proc(_mem: rawptr) {
    if slice.contains(os.args, "show-alloc-sdl") {
        fmt.printf("sdl_free_temp:    %v\n", _mem);
    }
    mem.free(_mem, _temp_allocator);
}

Arena_Name :: enum {
    None,
    App,
    Platform,
    Renderer,
    Game,
    GameMode,
    WorldMode,
}

make_arena_allocator :: proc(name: Arena_Name, size: int, arena: ^mem.Arena, allocator: mem.Allocator, location := #caller_location) -> mem.Allocator {
    log.debugf("make_arena_allocator: %v (%v) -> %v", name, size, location);
    buffer := make([]u8, size, allocator);
    mem.arena_init(arena, buffer);
    new_allocator := mem.Allocator { arena_allocator_proc, arena };
    arena_name := new(Arena_Name, new_allocator);
    arena_name^ = name;
    return new_allocator;
}

arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    result, error = mem.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    arena := cast(^mem.Arena)allocator_data;
    name : Arena_Name;
    if len(arena.data) > 0 {
        name = cast(Arena_Name)arena.data[0];
    }

    if slice.contains(os.args, "show-alloc") {
        if size > 1_000 {
            fmt.printf("[%v] %v %v byte at %v\n", name, mode, size, location);
        }
    }

    if error != .None && error != .Mode_Not_Implemented {
        fmt.eprintf("[%v] ERROR: %v %v byte at %v -> %v\n", name, mode, size, location, error);
        os.exit(0);
    }

    return;
}

allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    when ODIN_OS == .Windows {
        result, error = win32_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    } else {
        result, error = runtime.default_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    }

    if slice.contains(os.args, "show-alloc") {
        fmt.printf("[Default] %v %v byte at %v\n", mode, size, location);
    }

    if error != .None {
        fmt.eprintf("[Default] ERROR: %v %v byte at %v -> %v\n", mode, size, location, error);
        os.exit(0);
    }
    return;
}

when ODIN_OS == .Windows {
    win32_allocator_proc :: proc(
        allocator_data: rawptr, mode: mem.Allocator_Mode,
        size, alignment: int,
        old_memory: rawptr, old_size: int, loc := #caller_location) -> (data: []byte, err: mem.Allocator_Error,
    ) {
        using runtime;
        using win32;

        // TODO: Test this out properly
        switch mode {
            case .Alloc, .Alloc_Non_Zeroed:
                // data, err = _windows_default_alloc(size, alignment, mode == .Alloc);
                data := VirtualAlloc(
                    rawptr(uintptr(APP_BASE_ADDRESS)), win32.SIZE_T(APP_ARENA_SIZE),
                    MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE,
                );
                // TODO: handle alloc errors
                return mem.byte_slice(data, size), .None;
                // err = .None;

            case .Free:
                return nil, .Mode_Not_Implemented;
                // _windows_default_free(old_memory);

            case .Free_All:
                return nil, .Mode_Not_Implemented;

            case .Resize:
                return nil, .Mode_Not_Implemented;
                // data, err = _windows_default_resize(old_memory, old_size, size, alignment);

            case .Query_Features:
                set := (^Allocator_Mode_Set)(old_memory);
                if set != nil {
                    set^ = {.Alloc, .Alloc_Non_Zeroed, .Free, .Resize, .Query_Features};
                }

            case .Query_Info:
                return nil, .Mode_Not_Implemented;
        }

        return;
    }
}
