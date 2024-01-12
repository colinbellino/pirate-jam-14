package game

import "core:fmt"
import "core:log"
import "core:math/rand"
import "../engine"

Title_Action :: enum {
    None,
    Start,
    Continue,
    Quit,
 }

game_mode_title :: proc() {
    if game_mode_entering() {

    }

    if game_mode_running() {
        action := Title_Action.None
        when SKIP_TITLE { action = .Continue }

        if game_ui_window("Title", nil, .NoResize | .NoCollapse) {
            game_ui_window_center({ 200, 150 })

            if game_ui_button("Start", true) {
                action = .Start
            }
            if game_ui_button("Continue") {
                action = .Continue
            }
            if game_ui_button("Quit") {
                action = .Quit
            }
        }

        switch action {
            case .None: { }
            case .Start: { }
            case .Continue: {
                // TODO: screen transition
                save_slot := 0
                load_ok := load_save_slot(save_slot)
                if load_ok {
                    // log.debugf("FIXME: start game")
                } else {
                    log.errorf("Couldn't load save_slot: %v", save_slot)
                }
            }
            case .Quit: {
                _mem.game.quit_requested = true
            }
        }
    }

}

load_save_slot :: proc(slot: int) -> (ok: bool) {
    _mem.game.rand = rand.create(12)
    return true
}
