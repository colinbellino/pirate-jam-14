package game

import "core:mem"
import "core:log"
import "core:os"

import "../engine"

// TODO: merge this file into game.odin

HOT_RELOAD_CODE :: #config(HOT_RELOAD_CODE, true)
HOT_RELOAD_ASSETS :: #config(HOT_RELOAD_ASSETS, true)
MEM_BASE_ADDRESS :: 2 * mem.Terabyte
MEM_ENGINE_SIZE :: 10 * mem.Megabyte
MEM_GAME_SIZE :: 10 * mem.Megabyte

Game_Memory :: struct {
    app:      ^engine.App,
}

game_memory: Game_Memory

@(export)
game_init :: proc() -> rawptr {
    log.debug("game -> game_init")

    config := engine.Config{}
    config.TRACY_ENABLE = #config(TRACY_ENABLE, true)
    config.ASSETS_PATH = #config(ASSETS_PATH, "../")
    config.HOT_RELOAD_CODE = HOT_RELOAD_CODE
    config.HOT_RELOAD_ASSETS = HOT_RELOAD_ASSETS
    config.os_args = os.args

    app, app_arena := engine.init_engine(
        {1920, 1080},
        "Snowball",
        config,
        MEM_BASE_ADDRESS,
        MEM_ENGINE_SIZE,
        MEM_GAME_SIZE,
    )

    game_memory = Game_Memory {}
    game_memory.app = app

    return &game_memory
}
@(export)
game_update :: proc(game_memory: ^Game_Memory) -> (quit: bool, reload: bool) {
    engine.process_events()

    // FIXME: don't hardcode delta_time
    legacy_game_update(1.0, game_memory.app)

    if game_memory.app.platform.keys[.F5].released {
        reload = true
    }
    if game_memory.app.platform.quit || game_memory.app.platform.keys[.ESCAPE].released {
        quit = true
    }

    // FIXME: don't hardcode delta_time
    legacy_game_render(1.0, game_memory.app)

    engine.reset_inputs()
    engine.reset_events()

    engine.profiler_frame_mark()

    return
}
@(export)
game_quit :: proc(game_memory: rawptr) {

}
@(export)
window_open :: proc() {

}
@(export)
window_close :: proc(game_memory: rawptr) {

}
