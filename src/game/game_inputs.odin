package game

import "core:math/linalg"

import "../engine"

update_player_inputs :: proc(platform_state: ^engine.Platform_State, game_state: ^Game_State) {
    for player_index := 0; player_index < PLAYER_MAX; player_index += 1 {
            player_inputs := &game_state.player_inputs[player_index];
            player_inputs^ = {};

            controller_state, controller_found := engine.get_controller_from_player_index(platform_state, player_index);
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

                player_inputs.confirm = controller_state.buttons[.A];
                player_inputs.cancel = controller_state.buttons[.B];
            } else {
                // Right now, the keyboard can only control the first player.
                if player_index > 0 {
                    continue;
                }

                if (platform_state.keys[.UP].down) {
                    player_inputs.move.y -= 1;
                } else if (platform_state.keys[.DOWN].down) {
                    player_inputs.move.y += 1;
                }
                if (platform_state.keys[.LEFT].down) {
                    player_inputs.move.x -= 1;
                } else if (platform_state.keys[.RIGHT].down) {
                    player_inputs.move.x += 1;
                }

                player_inputs.confirm = platform_state.keys[.SPACE];
                player_inputs.cancel = platform_state.keys[.ESCAPE];
            }

            if player_inputs.move.x != 0 || player_inputs.move.y != 0 {
                player_inputs.move = linalg.vector_normalize(player_inputs.move);
            }
        }
}
