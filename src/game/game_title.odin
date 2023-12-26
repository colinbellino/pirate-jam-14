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
    _mem.game.rand = rand.create(12)

    // FIXME: OMG clean this up
    {
        asset_0, _ := engine.asset_get_by_file_name("media/units/unit_ramza.json")
        asset_1, _ := engine.asset_get_by_file_name("media/units/unit_delita.json")
        asset_2, _ := engine.asset_get_by_file_name("media/units/unit_alma.json")
        _mem.game.party = {
            append_unit_from_asset_id(asset_0.id),
            append_unit_from_asset_id(asset_1.id),
            append_unit_from_asset_id(asset_2.id),
        }
    }
    {
        asset_0, _ := engine.asset_get_by_file_name("media/units/unit_agrias.json")
        asset_1, _ := engine.asset_get_by_file_name("media/units/unit_mustadio.json")
        asset_2, _ := engine.asset_get_by_file_name("media/units/unit_boco.json")
        asset_3, _ := engine.asset_get_by_file_name("media/units/unit_rapha.json")
        asset_4, _ := engine.asset_get_by_file_name("media/units/unit_wiegraf.json")
        asset_5, _ := engine.asset_get_by_file_name("media/units/unit_belias.json")
        asset_6, _ := engine.asset_get_by_file_name("media/units/unit_gaffgarion.json")
        asset_7, _ := engine.asset_get_by_file_name("media/units/unit_lavian.json")
        asset_8, _ := engine.asset_get_by_file_name("media/units/unit_alicia.json")
        asset_9, _ := engine.asset_get_by_file_name("media/units/unit_ladd.json")
        asset_10, _ := engine.asset_get_by_file_name("media/units/unit_cidolfus.json")
        _mem.game.foes = {
            append_unit_from_asset_id(asset_0.id),
            append_unit_from_asset_id(asset_1.id),
            append_unit_from_asset_id(asset_2.id),
            append_unit_from_asset_id(asset_3.id),
            append_unit_from_asset_id(asset_4.id),
            append_unit_from_asset_id(asset_5.id),
            append_unit_from_asset_id(asset_6.id),
            append_unit_from_asset_id(asset_7.id),
            append_unit_from_asset_id(asset_8.id),
            append_unit_from_asset_id(asset_9.id),
            append_unit_from_asset_id(asset_10.id),
        }
    }
    return true
}

append_unit_from_asset_id :: proc(asset_id: engine.Asset_Id) -> int {
    asset_info, asset_ok := engine.asset_get_asset_info_external(asset_id, Asset_Unit)
    assert(asset_ok)
    unit := create_unit_from_asset(asset_id, asset_info)
    result := len(_mem.game.units)
    append(&_mem.game.units, unit)
    return result
}
