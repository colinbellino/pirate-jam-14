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
        append(&_mem.game.units, create_unit_from_asset_info(cast(^Asset_Unit) asset_info))
    }
    _mem.game.party = { 0, 1, 2 }
    _mem.game.foes = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
    _mem.game.rand = rand.create(12)
    return true
}

Asset_Unit :: struct {
    name:               string,
    sprite_position:    Vector2i32,
    stat_health_max:    i32,
    stat_speed:         i32,
    stat_move:          i32,
    stat_range:         i32,
    stat_vision:        i32,
}

create_unit_from_asset_info :: proc(asset_info: ^Asset_Unit) -> Unit {
    return Unit {
        name = asset_info.name,
        sprite_position = asset_info.sprite_position,
        stat_health = asset_info.stat_health_max,
        stat_health_max = asset_info.stat_health_max,
        stat_speed = asset_info.stat_speed,
        stat_move = asset_info.stat_move,
        stat_range = asset_info.stat_range,
        stat_vision = asset_info.stat_vision,
    }
}
create_unit_info :: proc "contextless" (full_path: string) -> (result: rawptr, ok: bool) {
    context = runtime.default_context()
    unit, err := new(Asset_Unit, _mem.game.arena.allocator)
    switch full_path {
        case "media/units/ramza.txt": { unit^ = { name = "Ramza", sprite_position = { 0, 0 }, stat_health_max = 10, stat_speed = 9, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case "media/units/delita.txt": { unit^ = { name = "Delita", sprite_position = { 1, 0 }, stat_health_max = 20, stat_speed = 3, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case "media/units/alma.txt": { unit^ = { name = "Alma", sprite_position = { 2, 0 }, stat_health_max = 30, stat_speed = 6, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case "media/units/agrias.txt": { unit^ = { name = "Agrias", sprite_position = { 3, 0 }, stat_health_max = 30, stat_speed = 6, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case "media/units/mustadio.txt": { unit^ = { name = "Mustadio", sprite_position = { 4, 0 }, stat_health_max = 30, stat_speed = 6, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case "media/units/boco.txt": { unit^ = { name = "Boco", sprite_position = { 5, 0 }, stat_health_max = 30, stat_speed = 6, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case "media/units/rapha.txt": { unit^ = { name = "Rapha", sprite_position = { 6, 0 }, stat_health_max = 30, stat_speed = 6, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case "media/units/wiegraf.txt": { unit^ = { name = "Wiegraf", sprite_position = { 0, 1 }, stat_health_max = 10, stat_speed = 8, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case "media/units/belias.txt": { unit^ = { name = "Belias", sprite_position = { 1, 1 }, stat_health_max = 20, stat_speed = 5, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case "media/units/gaffgarion.txt": { unit^ = { name = "Gaffgarion", sprite_position = { 2, 1 }, stat_health_max = 30, stat_speed = 4, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case "media/units/lavian.txt": { unit^ = { name = "Lavian", sprite_position = { 3, 1 }, stat_health_max = 30, stat_speed = 4, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case "media/units/alicia.txt": { unit^ = { name = "Alicia", sprite_position = { 0, 1 }, stat_health_max = 30, stat_speed = 4, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case "media/units/ladd.txt": { unit^ = { name = "Ladd", sprite_position = { 1, 0 }, stat_health_max = 30, stat_speed = 4, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case "media/units/cidolfus.txt": { unit^ = { name = "Cidolfus", sprite_position = { 2, 0 }, stat_health_max = 30, stat_speed = 4, stat_move = 8, stat_range = 10, stat_vision = 100 } }
        case: { unit^ = { name = "MissingNo" } }
    }
    return unit, true
}
print_unit_info :: proc "contextless" (data: rawptr) -> string {
    context = runtime.default_context()
    return fmt.tprintf("%v", transmute(^Asset_Unit) data)
}
