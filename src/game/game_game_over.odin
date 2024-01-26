package game

import "core:fmt"
import "core:log"
import "core:math/rand"
import "../engine"

Menu_Action :: enum {
    None,
    Start,
    Quit,
 }

game_mode_game_over :: proc() {
    game_is_over := _mem.game.current_level >= len(levels)
    if game_mode_entering() {
        if game_is_over {
            log.debugf("Last level reached, game is over")
        }
    }

    if game_mode_running() {
        // @(static) transition: i32
        // if transition == 0 && scene_transition_is_done() {
        //     transition = 1
        //     scene_transition_start(.Unswipe_Left_To_Right)
        //     return
        // }

        // if scene_transition_is_done() == false {
        //     return
        // }

        action := Menu_Action.None

        if _mem.game.player_inputs.cancel.released {
            action = .Quit
        } else if _mem.game.player_inputs.confirm.released || _mem.game.player_inputs.back.released {
            action = .Start
        }

        if game_is_over {
            game_ui_game_over()
        } else {
            game_ui_next_level()
        }

        switch action {
            case .None: { }
            case .Start: {
                if game_is_over {
                    game_mode_transition(.Title)
                } else {
                    // TODO: screen transition
                    game_mode_transition(.Play)
                }
            }
            case .Quit: {
                _mem.game.quit_requested = true
            }
        }
    }

    if game_mode_exiting() {
        log.debugf("Game over exit")
    }
}
