package pouet

import "core:fmt"
import "core:mem"
import "core:runtime"
import "core:slice"
import "core:log"

main :: proc() {
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })

    // track: mem.Tracking_Allocator
    // mem.tracking_allocator_init(&track, context.allocator)
    // context.allocator = mem.tracking_allocator(&track)
    // defer {
    //     for _, leak in track.allocation_map {
    //         fmt.eprintf("%v leaked %v bytes\n", leak.location, leak.size)
    //     }
    //     for bad_free in track.bad_free_array {
    //         fmt.eprintf("%v allocation %p was freed badly\n", bad_free.location, bad_free.memory)
    //     }
    //     fmt.println("Done")
    // }

    // arena: mem.Dynamic_Pool
    // mem.dynamic_pool_init(&arena)
    // context.allocator = mem.dynamic_pool_allocator(&arena)

    // x, err := make([]int, 5)
    // fmt.printf("err: %v\n", err)
    // x[0] = 1
    // x[1] = 2
    // x[2] = 3
    // fmt.printf("x: %v\n", x)

    // err = delete(x)
    // fmt.printf("err: %v\n", err)

    // err = delete(arena.unused_blocks)
    // fmt.printf("err: %v\n", err)
    // err = delete(arena.used_blocks)
    // fmt.printf("err: %v\n", err)
    // err = delete(arena.out_band_allocations)
    // fmt.printf("err: %v\n", err)
    // // Arenas make the tradeoff that it can do this very efficiently, in exchange for not being able to free individual things.

    // y := make([]int, 5)
    // y[0] = 10
    // y[1] = 20
    // y[2] = 30
    // fmt.printf("y: %p %v\n", &y, y)

    // fmt.printf("x: %p %v\n", &x, x)

    // off := (uintptr(&x) - uintptr(&y))
    // fmt.printf("off: %v\n", off)

    // mem.dynamic_pool_destroy(&arena)

    buffer, error := make([]u8, 50)
    if error != .None {
        fmt.panicf("Buffer alloc error: %v.\n", error)
    }
    arena := mem.Arena {}
    mem.arena_init(&arena, buffer)
    context.allocator = mem.Allocator {
		procedure = main_allocator_proc,
		data = &arena,
	}

    bla1 := new(i32)
    bla2 := new(i128)
    bla3 := new(i32)
    free(bla3)

    for alloc in s.allocs {
        if alloc.data != nil {
            log.debugf("alloc: %v", alloc)
        }
    }
    log.debugf("arena: %v/%v", arena.offset, len(arena.data))
}

State :: struct {
    allocs:      [dynamic]Alloc,
}

Alloc :: struct {
    data:       rawptr,
    size:       int,
    alignment:  int,
    location:   runtime.Source_Code_Location,
    mode:       runtime.Allocator_Mode,
}

s := State {}

main_allocator_proc : runtime.Allocator_Proc : proc(allocator_data: rawptr, mode: runtime.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location: runtime.Source_Code_Location = #caller_location) -> (data: []byte, error: runtime.Allocator_Error) {
    data, error = mem.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location)

    {
        context.allocator = runtime.default_allocator()
        if error != .None {
            fmt.eprintf("main_allocator_proc error: %v (%v) <- %v\n", error, mode, location)
            return
        }

        fmt.printf("main_allocator_proc: %v %v -> %v\n", mode, size, location)
        if mode == .Alloc || mode == .Alloc_Non_Zeroed {
            append(&s.allocs, Alloc { raw_data(data), size, alignment, location, mode })
        }
    }

    return
}
