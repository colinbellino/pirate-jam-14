package simple

import "core:fmt"
import "core:log"
import "core:time"
import "core:runtime"
import "core:os"
import "core:mem"
import game "game2"
import "tools"

main :: proc() {
    // TODO: tracked allocator
    // TODO: sdl custom allocators
    // TODO: use paged memory
    tracking_allocator: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)
    defer {
        if len(tracking_allocator.allocation_map) > 0 {
            fmt.eprintf("=== %v allocations not freed: ===\n", len(tracking_allocator.allocation_map))
            for _, entry in tracking_allocator.allocation_map {
                fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
            }
        }
        if len(tracking_allocator.bad_free_array) > 0 {
            fmt.eprintf("=== %v incorrect frees: ===\n", len(tracking_allocator.bad_free_array))
            for entry in tracking_allocator.bad_free_array {
                fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
            }
        }
        mem.tracking_allocator_destroy(&tracking_allocator)
    }

    // context.allocator.procedure = tools.mem_allocator_proc
    // context.allocator = os.heap_allocator()
    // context.temp_allocator = context.temp_allocator
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })
    defer free(context.logger.data)

    game.game_init()

    quit := false
    for quit == false {
        quit = game.game_update()
        free_all(context.temp_allocator)
    }

    log.warn("Quitting...")

}
