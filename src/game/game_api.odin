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

@(private)
_game: ^Game_State

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

    _game = new(Game_State, app.game_allocator);
    _game.game_allocator = app.game_allocator;
    _game.game_mode_allocator = arena_allocator_make(1000 * mem.Kilobyte);
    _game.debug_ui_no_tiles = true;
    // _game.debug_show_bounding_boxes = true;
    _game.app = app

    return &_game
}
@(export)
game_update :: proc(game_state: ^Game_State) -> (quit: bool, reload: bool) {
    engine.process_events()

    // FIXME: don't hardcode delta_time
    legacy_game_update(1.0)

    if _game.app.platform.keys[.F5].released {
        reload = true
    }
    if _game.app.platform.quit || _game.app.platform.keys[.ESCAPE].released {
        quit = true
    }

    // FIXME: don't hardcode delta_time
    legacy_game_render(1.0)

    engine.reset_inputs()
    engine.reset_events()

    engine.profiler_frame_mark()

    return
}
@(export)
game_quit :: proc(_game: rawptr) {

}
@(export)
window_open :: proc() {

}
@(export)
window_close :: proc(_game: rawptr) {

}
