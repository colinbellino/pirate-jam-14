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
    // TODO: sdl custom allocators
    // TODO: use paged memory

    game.game_start()

    quit := false
    for quit == false {
        quit = game.game_update()
        free_all(context.temp_allocator)
    }

    game.game_quit()

    log.warn("Quitting...")

}
