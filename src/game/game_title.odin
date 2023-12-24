package game

import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:mem"
import "core:runtime"
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
                    game_mode_transition(.Battle)
                } else {
                    log.errorf("Couldn't load save_slot: %v", save_slot)
                }
            }
            case .Quit: {
                _mem.platform.quit_requested = true
            }
        }
    }

}

load_save_slot :: proc(slot: int) -> (ok: bool) {
    _mem.game.battle_index = 1
    for i := 0; i < len(_mem.game.asset_units); i += 1 {
        asset_info, asset_ok := engine.asset_get_asset_info(_mem.game.asset_units[i])
        assert(asset_ok)
        append(&_mem.game.units, create_unit_from_asset(cast(^Asset_Unit) asset_info))
    }
    _mem.game.party = { 0, 1, 2 }
    _mem.game.foes = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
    _mem.game.rand = rand.create(12)
    return true
}
