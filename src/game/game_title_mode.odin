package game

import "core:os"
import "core:slice"

import platform "../engine/platform"
import renderer "../engine/renderer"

Game_Mode_Title :: struct {
    initialized:        bool,
    some_stuff:         []u8,
}

title_mode_update :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    delta_time: f64,
) {
    title_data := cast(^Game_Mode_Title)game_state.game_mode_data;
    start_selected := false;

    if title_data.initialized == false {
        title_data.initialized = true;
        title_data.some_stuff = make([]u8, 100, game_state.game_mode_allocator);

        if slice.contains(os.args, "skip-title") {
            start_selected = true;
        }
    }

    if ui_window("Title", { 600, 400, 320, 320 }, { .NO_CLOSE, .NO_RESIZE }) {
        if .SUBMIT in ui_button("Start") {
            start_selected = true;
        }
        if .SUBMIT in ui_button("Quit") {
            game_state.quit = true;
        }
    }
    if platform_state.keys[.SPACE].released {
        start_selected = true;
    }

    if start_selected {
        start_last_save(game_state);
    }
}
