package game

import "../engine"

Game_Mode_Title :: struct {
    initialized:        bool,
    some_stuff:         []u8,
}

title_mode_update :: proc(
    app: ^engine.App,
    delta_time: f64,
) {
    game_state := cast(^Game_State) app.game_state;
    platform_state := app.platform_state;
    renderer_state := app.renderer_state;
    player_inputs := &game_state.player_inputs[0];

    title_data := cast(^Game_Mode_Title)game_state.game_mode_data;
    start_selected := false;

    if title_data.initialized == false {
        title_data.initialized = true;
        title_data.some_stuff = make([]u8, 1_000, game_state.game_mode_allocator);

        if engine.contains_os_args("skip-title") {
            start_selected = true;
        }
    }

    if engine.ui_window(renderer_state, "Title", { 600, 400, 320, 320 }, { .NO_CLOSE, .NO_RESIZE }) {
        if .SUBMIT in engine.ui_button(renderer_state, "Start") {
            start_selected = true;
        }
        if .SUBMIT in engine.ui_button(renderer_state, "Quit") {
            platform_state.quit = true;
        }
    }
    if player_inputs.confirm.released {
        start_selected = true;
    }
    if app.debug_state.last_reload._nsec > 0 {
        start_selected = true;
    }

    if start_selected {
        start_last_save(game_state);
    }
}
