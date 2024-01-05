package game

import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:mem"
import "core:runtime"
import engine "../engine_v2"

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
                _mem.game.quit_requested = true
            }
        }
    }

}

load_save_slot :: proc(slot: int) -> (ok: bool) {
    _mem.game.battle_index = 1
    _mem.game.rand = rand.create(12)
    _mem.game.party = {
        append_unit_from_asset_name("unit_ramza"),
        append_unit_from_asset_name("unit_delita"),
        append_unit_from_asset_name("unit_alma"),
    }
    _mem.game.foes = {
        append_unit_from_asset_name("unit_agrias"),
        append_unit_from_asset_name("unit_mustadio"),
        append_unit_from_asset_name("unit_boco"),
        append_unit_from_asset_name("unit_rapha"),
        append_unit_from_asset_name("unit_wiegraf"),
        append_unit_from_asset_name("unit_belias"),
        append_unit_from_asset_name("unit_gaffgarion"),
        append_unit_from_asset_name("unit_lavian"),
        append_unit_from_asset_name("unit_alicia"),
        append_unit_from_asset_name("unit_ladd"),
        append_unit_from_asset_name("unit_cidolfus"),
    }
    return true
}

append_unit_from_asset_name :: proc(asset_name: string) -> int {
    asset, asset_found := engine.asset_get_by_file_name(fmt.tprintf("media/units/%v.json", asset_name))
    assert(asset_found, fmt.tprintf("Couldn't find asset with name: %v", asset_name))

    asset_info, asset_info_ok := engine.asset_get_asset_info_external(asset.id, Asset_Unit)
    assert(asset_info_ok, fmt.tprintf("Couldn't find loaded asset unit with name: %v", asset_name))

    unit_index := len(_mem.game.units)
    append(&_mem.game.units, create_unit_from_asset(asset.id, asset_info))
    return unit_index
}
