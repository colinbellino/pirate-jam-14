package main

import "core:fmt"
import "core:log"
import "core:time"
import "tools"
import "engine"
import "game"

main :: proc() {
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color/*, .Short_File_Path, .Line , .Procedure */ })

    e := engine.engine_init(context.allocator)
    g := cast(^game.Game_State) game.game_init()

    quit := false
    for quit == false {
        quit, _ = game.game_update(g)

        free_all(context.temp_allocator)
    }

    fmt.println("Quitting...")
}
