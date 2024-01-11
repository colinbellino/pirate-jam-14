package main

import "core:log"
import "app_loader"
import "tools"

HOT_RELOAD_CODE :: #config(HOT_RELOAD_CODE, ODIN_DEBUG)

main :: proc() {
    context.allocator.procedure = tools.panic_allocator_proc
    context.temp_allocator.procedure = tools.temp_allocator_proc

    game_api, game_api_ok := app_loader.load(0)
    assert(game_api_ok == true, "game_api couldn't be loaded.")

    game_memory := game_api.app_init()

    quit := false
    reload := false
    for quit == false {
        quit, reload = game_api.app_update(game_memory)

        when HOT_RELOAD_CODE {
            if app_loader.should_reload(&game_api) {
                reload = true
            }

            if reload {
                new_game_api, new_game_api_ok := app_loader.load(game_api.version + 1)
                if new_game_api_ok {
                    // game_api.app_quit(game_memory)
                    game_api = new_game_api
                    game_api.app_reload(game_memory)
                }
            }
        }
    }

    game_api.app_quit(game_memory)
    log.warn("Quitting...")
}
