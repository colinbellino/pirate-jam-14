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
    if game_mode_entering() {

    }

    if game_mode_running() {
        action := Menu_Action.None

        if game_ui_window("Game Over", nil, .NoResize | .NoCollapse) {
            game_ui_window_center({ 200, 150 })

            engine.ui_text("Score: %v", _mem.game.score)

            if game_ui_button("Next level") {
                action = .Start
            }
            if game_ui_button("Quit") {
                action = .Quit
            }
        }

        switch action {
            case .None: { }
            case .Start: {
                // TODO: screen transition
                save_slot := 0
                load_ok := load_save_slot(save_slot)
                if load_ok {
                    game_mode_transition(.Play)
                } else {
                    log.errorf("Couldn't load save_slot: %v", save_slot)
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
