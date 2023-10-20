package main

import "core:log"
import "core:fmt"
import "core:mem"
import "core:runtime"
import "app_loader"
import "tools"
import "game"

main :: proc() {
    context.allocator.procedure = tools.log_allocator_proc
    context.temp_allocator.procedure = tools.temp_allocator_proc
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })

    game_api := app_loader.API {
        app_init = auto_cast(game.app_init),
        app_update = auto_cast(game.app_update),
        app_quit = auto_cast(game.app_quit),
    }

    game_memory := game_api.app_init()

    quit := false
    for quit == false {
        quit, _ = game_api.app_update(game_memory)
    }

    log.warn("Quitting...")
}
