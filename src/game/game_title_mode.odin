package game

import platform "../engine/platform"
import renderer "../engine/renderer"

title_mode_fixed_update :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    delta_time: f64,
) {
    title_data := cast(^Game_Mode_Title)game_state.game_mode_data;

    if title_data.initialized == false {
        title_data.initialized = true;
        title_data.some_stuff = make([]u8, 100, game_state.game_mode_allocator);
    }

    if platform_state.keys[.SPACE].released {
        start_game(game_state);
    }
}
