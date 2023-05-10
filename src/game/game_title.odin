package game

import "core:log"

import "../engine"

Game_Mode_Title :: struct {
    initialized:        bool,
    some_stuff:         []u8,
}

title_mode_update :: proc(
    app: ^engine.App,
    delta_time: f64,
) {
    game := cast(^Game_State) app.game;
    player_inputs := &game.player_inputs[0];

    title_data := cast(^Game_Mode_Title)game.game_mode_data;
    start_selected := false;

    if title_data.initialized == false {
        title_data.initialized = true;
        title_data.some_stuff = make([]u8, 1_000, game.game_mode_allocator);

        /* if engine.contains_os_args("skip-title") */ {
            log.warn("Skipping title.");
            start_selected = true;
        }
    }

    if engine.ui_window(app.ui, "Title", { 600, 400, 320, 320 }, { .NO_CLOSE, .NO_RESIZE }) {
        if .SUBMIT in engine.ui_button(app.ui, "Start") {
            start_selected = true;
        }
        if .SUBMIT in engine.ui_button(app.ui, "Quit") {
            app.platform.quit = true;
        }
    }
    if player_inputs.confirm.released {
        start_selected = true;
    }

    if start_selected {
        log.debug("Starting game.");
        start_last_save(game);
    }
}
