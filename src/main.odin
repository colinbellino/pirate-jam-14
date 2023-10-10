package main

import "core:log"
import "core:fmt"
import "core:mem"
import "core:runtime"
import "app_loader"

main :: proc() {
    context.allocator.procedure = log_allocator_proc
    context.temp_allocator.procedure = log_temp_allocator_proc
    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color })

    game_api, game_api_ok := app_loader.load(0)
    assert(game_api_ok == true, "game_api couldn't be loaded.")

    game_memory := game_api.app_init()

    quit := false
    reload := false
    for quit == false {
        quit, reload = game_api.app_update(game_memory)

        if app_loader.should_reload(&game_api) {
            reload = true
        }

        if reload {
            new_game_api, new_game_api_ok := app_loader.load(game_api.version + 1)
            if new_game_api_ok {
                log.debug("Game reloaded!")
                // game_api.game_quit(game_memory)
                // unload_game_api(&game_api)
                game_api = new_game_api
                game_api.app_reload(game_memory)
            }
        }
    }

    log.warn("Quitting...")
}

log_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, loc := #caller_location,
)-> (data: []byte, err: mem.Allocator_Error) {
    data, err = runtime.default_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, loc)
    fmt.printf("allocator_proc: %v %v -> %v\n", mode, size, loc)
    if err != .None {
        fmt.eprintf("error: %v\n", err)
    }
    return
}
log_temp_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, loc := #caller_location,
)-> (data: []byte, err: mem.Allocator_Error) {
    data, err = runtime.default_temp_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, loc)
    // fmt.printf("temp_allocator_proc: %v %v -> %v\n", mode, size, loc)
    if err != .None {
        fmt.eprintf("error: %v\n", err)
    }
    return
}
