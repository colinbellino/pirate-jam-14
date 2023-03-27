package engine

import "core:c"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
when ODIN_OS == .Windows {
    import win32 "core:sys/windows"
}
// import "vendor:sdl2"

foreign import libc "System.framework"
foreign libc {
    @(link_name="mmap")             _mmap               :: proc(addr: rawptr, len: c.size_t, prot: c.int, flags: c.int, fd: c.int, offset: int) -> rawptr ---
    @(link_name="mprotect")         _mprotect           :: proc(addr: rawptr, len: c.size_t, prot: c.int) -> c.int ---
}

PROT_NONE  :: 0x0; /* [MC2] no permissions */
PROT_READ  :: 0x1; /* [MC2] pages can be read */
PROT_WRITE :: 0x2; /* [MC2] pages can be written */
PROT_EXEC  :: 0x4; /* [MC2] pages can be executed */

// Sharing options
MAP_SHARED    :: 0x1; /* [MF|SHM] share changes */
MAP_PRIVATE   :: 0x2; /* [MF|SHM] changes are private */

// Other flags
MAP_FIXED        :: 0x0010; /* [MF|SHM] interpret addr exactly */
MAP_RENAME       :: 0x0020; /* Sun: rename private pages to file */
MAP_NORESERVE    :: 0x0040; /* Sun: don't reserve needed swap area */
MAP_RESERVED0080 :: 0x0080; /* previously unimplemented MAP_INHERIT */
MAP_NOEXTEND     :: 0x0100; /* for MAP_FILE, don't change file size */
MAP_HASSEMAPHORE :: 0x0200; /* region may contain semaphores */
MAP_NOCACHE      :: 0x0400; /* don't cache pages for this mapping */
MAP_JIT          :: 0x0800; /* Allocate a region that will be used for JIT purposes */

// Mapping type
MAP_FILE         :: 0x0000;  /* map from file (default) */
MAP_ANONYMOUS    :: 0x1000;  /* allocated from memory, swap space */

// Allocation failure result
MAP_FAILED : rawptr = rawptr(~uintptr(0));

Arena_Name :: enum u8 {
    Unnamed,
    App,
    Platform,
    Renderer,
    Logger,
    Debug,
    Temp,
    Game,
    GameMode,
    WorldMode,
}

@(private="file") _temp_allocator: runtime.Allocator;
@(private="file") _allocator: runtime.Allocator;
@(private="file") _temp_allocs: i32;

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

set_memory_functions_temp :: proc(location := #caller_location) {
    // memory_error := sdl2.SetMemoryFunctions(
    //     sdl2.malloc_func(sdl_malloc_temp),   sdl2.calloc_func(sdl_calloc_temp),
    //     sdl2.realloc_func(sdl_realloc_temp), sdl2.free_func(sdl_free_temp),
    // );
    // if memory_error > 0 {
    //     log.errorf("SetMemoryFunctions error: %v", memory_error);
    // }
}

@(private="file")
sdl_malloc_temp   :: proc(size: c.size_t)              -> rawptr {
    _temp_allocs += 1;

    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_malloc_temp:  %v\n", size);
    }
    return mem.alloc(int(size), mem.DEFAULT_ALIGNMENT, _temp_allocator);

}

@(private="file")
sdl_calloc_temp   :: proc(nmemb, size: c.size_t)       -> rawptr {
    _temp_allocs += 1;

    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_calloc_temp:  %v * %v\n", nmemb, size);
    }
    len := int(nmemb * size);
    ptr := mem.alloc(len, mem.DEFAULT_ALIGNMENT, _temp_allocator);
    return mem.zero(ptr, len);

}

@(private="file")
sdl_realloc_temp  :: proc(_mem: rawptr, size: c.size_t) -> rawptr {
    _temp_allocs += 1;

    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_realloc_temp: %v | %v\n", _mem, size);
    }
    return mem.resize(_mem, int(size), int(size), mem.DEFAULT_ALIGNMENT, _temp_allocator);

}

@(private="file")
sdl_free_temp     :: proc(_mem: rawptr) {
    _temp_allocs += 1;

    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_free_temp:    %v\n", _mem);
    }
    mem.free(_mem, _temp_allocator);
}

@(private="file")
sdl_malloc   :: proc(size: c.size_t)              -> rawptr {
    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_malloc:  %v\n", size);
    }
    return mem.alloc(int(size), mem.DEFAULT_ALIGNMENT, _allocator);
}

@(private="file")
sdl_calloc   :: proc(nmemb, size: c.size_t)       -> rawptr {
    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_calloc:  %v * %v\n", nmemb, size);
    }
    len := int(nmemb * size);
    ptr := mem.alloc(len, mem.DEFAULT_ALIGNMENT, _allocator);
    return mem.zero(ptr, len);
}

@(private="file")
sdl_realloc  :: proc(_mem: rawptr, size: c.size_t) -> rawptr {
    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_realloc: %v | %v\n", _mem, size);
    }
    return mem.resize(_mem, int(size), int(size), mem.DEFAULT_ALIGNMENT, _allocator);
}

@(private="file")
sdl_free     :: proc(_mem: rawptr) {
    if contains_os_args("log-alloc-sdl") {
        fmt.printf("sdl_free:    %v\n", _mem);
    }
    mem.free(_mem, _allocator);
}

when ODIN_OS == .Darwin {

    reserve_darwin :: proc "contextless" (size: uint, base_address: rawptr = nil) -> (data: []byte, err: runtime.Allocator_Error) {
        result := _mmap(base_address, size, PROT_NONE, MAP_ANONYMOUS | MAP_SHARED | MAP_FIXED, -1, 0);
        if result == MAP_FAILED {
            return nil, .Out_Of_Memory;
        }
        return ([^]byte)(uintptr(result))[:size], nil;
    }

    commit_darwin :: proc "contextless" (data: rawptr, size: uint) -> runtime.Allocator_Error {
        result := _mprotect(data, size, PROT_READ | PROT_WRITE);
        if result != 0 {
            return .Out_Of_Memory;
        }
        return nil;
    }
}

reserve_and_commit :: proc "contextless" (size: uint, base_address: rawptr = nil) -> (data: []byte, err: runtime.Allocator_Error) {
    when ODIN_OS == .Windows {
        using win32;

        result := VirtualAlloc(
            base_address, SIZE_T(size),
            MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE,
        );

        if result == nil {
            switch err := GetLastError(); err {
                case 0:
                    return nil, .Invalid_Argument;
                // case ERROR_INVALID_ADDRESS, ERROR_COMMITMENT_LIMIT:
                //     return nil, .Out_Of_Memory
            }
            return nil, .Out_Of_Memory;
        }

        data = ([^]byte)(result)[:size];
    } else when ODIN_OS == .Darwin {
        data = reserve_darwin(size, base_address) or_return;
        commit_darwin(raw_data(data), size) or_return;
    } else {
        fmt.eprintf("OS not supported: %v.\b", ODIN_OS);
        os.exit(1);
    }
    return
}

default_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    fmt.printf("DEFAULT_ALLOCATOR: %v %v at ", mode, size);
    runtime.print_caller_location(location);
    runtime.print_byte('\n');
    data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    if error != .None {
        fmt.eprintf("DEFAULT_ALLOCATOR ERROR: %v\n", error);
    }

    return;
}

default_temp_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    fmt.printf("DEFAULT_TEMP_ALLOCATOR: %v %v at ", mode, size);
    runtime.print_caller_location(location);
    runtime.print_byte('\n');
    data, error = runtime.default_temp_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    if error != .None && error != .Mode_Not_Implemented && mode != .Free {
        fmt.eprintf("DEFAULT_TEMP_ALLOCATOR ERROR: %v | %v at ", mode, error);
        runtime.print_caller_location(location);
        runtime.print_byte('\n');
    }

    return;
}

make_arena_allocator :: proc(name: Arena_Name, size: int, arena: ^mem.Arena, allocator: mem.Allocator = context.allocator, location := #caller_location) -> mem.Allocator {
    buffer, error := make([]u8, size, allocator);
    if error != .None {
        log.errorf("Buffer alloc error: %v", error);
    }
    log.debugf("[%v] Arena created with size: %v", name, size);
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
    result, error = named_arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    arena := cast(^mem.Arena)allocator_data;
    arena_name: Arena_Name;
    if len(arena.data) > 0 {
        arena_name = cast(Arena_Name)arena.data[0];
    }

    arena_formatted_name := fmt.tprintf("%v", arena_name);fmt.tprintf("%v", arena_name)

    if contains_os_args("log-alloc") {
        ptr := mode == .Free ? old_memory : rawptr(&result);
        fmt.printf("[%v] %v %v byte (%p) at ", arena_formatted_name, mode, size, ptr);
        runtime.print_caller_location(location);
        runtime.print_byte('\n');
    }

    if error != .None && error != .Mode_Not_Implemented {
        fmt.eprintf("[%v] ERROR %v: %v byte at ", arena_formatted_name, error, size);
        runtime.print_caller_location(location);
        runtime.print_byte('\n');
        os.exit(0);
    }

    return;
}

@(private="file")
named_arena_allocator_proc :: proc(
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
