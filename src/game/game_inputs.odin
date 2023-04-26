package game

import "core:math/linalg"

import "../engine"

Player_Inputs :: struct {
    move:    Vector2f32,
    confirm: engine.Key_State,
    cancel:  engine.Key_State,
    back:    engine.Key_State,
    start:   engine.Key_State,
    debug_0: engine.Key_State,
    debug_1: engine.Key_State,
    debug_2: engine.Key_State,
    debug_3: engine.Key_State,
    debug_4: engine.Key_State,
    debug_5: engine.Key_State,
    debug_6: engine.Key_State,
    debug_7: engine.Key_State,
    debug_8: engine.Key_State,
    debug_9: engine.Key_State,
    debug_10: engine.Key_State,
    debug_11: engine.Key_State,
    debug_12: engine.Key_State,
}

update_player_inputs :: proc(platform: ^engine.Platform_State, game: ^Game_State) {
    keyboard_was_used := false;
    for key in platform.keys {
        if platform.keys[key].down || platform.keys[key].released {
            keyboard_was_used = true;
            break;
        }
    }

    for player_index := 0; player_index < PLAYER_MAX; player_index += 1 {
        player_inputs := &game.player_inputs[player_index];
        player_inputs^ = {};

        if keyboard_was_used {
            // Right now, the keyboard can only control the first player.
            if player_index > 0 {
                continue;
            }

            if (platform.keys[.UP].down) {
                player_inputs.move.y -= 1;
            } else if (platform.keys[.DOWN].down) {
                player_inputs.move.y += 1;
            }
            if (platform.keys[.LEFT].down) {
                player_inputs.move.x -= 1;
            } else if (platform.keys[.RIGHT].down) {
                player_inputs.move.x += 1;
            }

            player_inputs.back = platform.keys[.BACKSPACE];
            player_inputs.start = platform.keys[.RETURN];
            player_inputs.confirm = platform.keys[.SPACE];
            player_inputs.cancel = platform.keys[.ESCAPE];
            player_inputs.debug_0 = platform.keys[.GRAVE];
            player_inputs.debug_1 = platform.keys[.F1];
            player_inputs.debug_2 = platform.keys[.F2];
            player_inputs.debug_3 = platform.keys[.F3];
            player_inputs.debug_4 = platform.keys[.F4];
            player_inputs.debug_5 = platform.keys[.F5];
            player_inputs.debug_6 = platform.keys[.F6];
            player_inputs.debug_7 = platform.keys[.F7];
            player_inputs.debug_8 = platform.keys[.F8];
            player_inputs.debug_9 = platform.keys[.F9];
            player_inputs.debug_10 = platform.keys[.F10];
            player_inputs.debug_11 = platform.keys[.F11];
            player_inputs.debug_12 = platform.keys[.F12];
        } else {
            controller_state, controller_found := engine.get_controller_from_player_index(platform, player_index);
            if controller_found {
                if (controller_state.buttons[.DPAD_UP].down) {
                    player_inputs.move.y -= 1;
                } else if (controller_state.buttons[.DPAD_DOWN].down) {
                    player_inputs.move.y += 1;
                }
                if (controller_state.buttons[.DPAD_LEFT].down) {
                    player_inputs.move.x -= 1;
                } else if (controller_state.buttons[.DPAD_RIGHT].down) {
                    player_inputs.move.x += 1;
                }
                if (controller_state.buttons[.DPAD_UP].down) {
                    player_inputs.move.y -= 1;
                }

                // If we use the analog sticks, we ignore the DPad inputs
                if controller_state.axes[.LEFTX].value < -CONTROLLER_DEADZONE || controller_state.axes[.LEFTX].value > CONTROLLER_DEADZONE {
                    player_inputs.move.x = f32(controller_state.axes[.LEFTX].value) / f32(size_of(controller_state.axes[.LEFTX].value));
                }
                if controller_state.axes[.LEFTY].value < -CONTROLLER_DEADZONE || controller_state.axes[.LEFTY].value > CONTROLLER_DEADZONE {
                    player_inputs.move.y = f32(controller_state.axes[.LEFTY].value) / f32(size_of(controller_state.axes[.LEFTY].value));
                }

                player_inputs.back = controller_state.buttons[.BACK];
                player_inputs.start = controller_state.buttons[.START];
                player_inputs.confirm = controller_state.buttons[.A];
                player_inputs.cancel = controller_state.buttons[.B];
            }
        }

        if player_inputs.move.x != 0 || player_inputs.move.y != 0 {
            player_inputs.move = linalg.vector_normalize(player_inputs.move);
        }
    }
}
