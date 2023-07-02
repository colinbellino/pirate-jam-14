package main

import "core:log"
import "core:fmt"
import "core:mem"
import "core:dynlib"
import "core:os"
import "core:time"
import "core:path/slashpath"

main :: proc() {
    tracking_allocator: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    main_allocator := mem.tracking_allocator(&tracking_allocator)
    context.allocator = main_allocator

    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color/*, .Short_File_Path, .Line , .Procedure */ })

    game_api, game_api_ok := load_game_api(0)
    assert(game_api_ok == true, "game_api couldn't be loaded.")

    game_memory := game_api.game_init()
    game_api.window_open()

    quit := false
    reload := false
    for quit == false {
        quit, reload = game_api.game_update(game_memory)

        if should_reload_game_api(&game_api) {
            reload = true
        }

        if reload {
            new_game_api, new_game_api_ok := load_game_api(game_api.version + 1)
            if new_game_api_ok {
                log.debug("Game reloaded!");
                // game_api.game_quit(game_memory)
                mem.tracking_allocator_clear(&tracking_allocator)
                unload_game_api(&game_api)
                game_api = new_game_api
                game_api.game_reload(game_memory)
            }
        }
    }

    log.warn("Quitting...")
}

Game_API :: struct {
    library:            dynlib.Library,
    game_init:          proc() -> rawptr,
    game_update:        proc(game_memory: rawptr) -> (quit: bool, reload: bool),
    game_quit:          proc(game_memory: rawptr),
    game_reload:        proc(game_memory: rawptr),
    window_open:        proc(),
    window_close:       proc(game_memory: rawptr),
    modification_time:  time.Time,
    version:            i32,
}
load_game_api :: proc(version: i32) -> (api: Game_API, ok: bool) {
    path := slashpath.join({ fmt.tprintf("game%i.bin", version) }, context.temp_allocator)
    load_library: bool
    api.library, load_library = dynlib.load_library(path)
    if load_library == false {
        log.errorf("load_library('%s') failed.", path)
        return
    }

    api.window_open = auto_cast(dynlib.symbol_address(api.library, "window_open"))
    if api.window_open == nil {
        log.error("symbol_address('window_open') failed.")
        return
    }
    api.window_close = auto_cast(dynlib.symbol_address(api.library, "window_close"))
    if api.window_close == nil {
        log.error("symbol_address('window_close') failed.")
        return
    }
    api.game_init = auto_cast(dynlib.symbol_address(api.library, "game_init"))
    if api.game_init == nil {
        log.error("symbol_address('game_init') failed.")
        return
    }
    api.game_update = auto_cast(dynlib.symbol_address(api.library, "game_update"))
    if api.game_update == nil {
        log.error("symbol_address('game_update') failed.")
        return
    }
    api.game_quit = auto_cast(dynlib.symbol_address(api.library, "game_quit"))
    if api.game_quit == nil {
        log.error("symbol_address('game_quit') failed.")
        return
    }
    api.game_reload = auto_cast(dynlib.symbol_address(api.library, "game_reload"))
    if api.game_reload == nil {
        log.error("symbol_address('game_reload') failed.")
        return
    }

    api.version = version
    api.modification_time = time.now()

    return api, true
}
unload_game_api :: proc(api: ^Game_API) {
    if api.library != nil {
        dynlib.unload_library(api.library)
    }
}
should_reload_game_api :: proc(api: ^Game_API) -> bool {
    path := slashpath.join({ fmt.tprintf("game%i.bin", api.version + 1) }, context.temp_allocator)
    return os.exists(path)
}
