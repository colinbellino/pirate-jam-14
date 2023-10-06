package simple

import "core:fmt"
import "core:log"
import "core:time"
import "core:runtime"
import "core:os"
import game "game2"

main :: proc() {
    // TODO: tracked allocator
    // TODO: sdl custom allocators
    // TODO: use paged memory
    context.allocator = os.heap_allocator()
    context.temp_allocator = context.temp_allocator
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })

    game.game_init()

    quit := false
    for quit == false {
        quit = game.game_update()
        free_all(context.temp_allocator)
    }

    log.warn("Quitting...")
}
