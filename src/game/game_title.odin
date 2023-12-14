package game

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
    _mem.game.units = [dynamic]Unit {
        Unit { name = "Ramza", sprite_position = { 0, 0 }, stat_health = 10, stat_health_max = 10, stat_speed = 9, stat_move = 40, stat_range = 40, controlled_by = .Player },
        Unit { name = "Delita", sprite_position = { 1, 0 }, stat_health = 20, stat_health_max = 20, stat_speed = 3, stat_move = 40, stat_range = 15, controlled_by = .Player },
        Unit { name = "Alma", sprite_position = { 2, 0 }, stat_health = 30, stat_health_max = 30, stat_speed = 6, stat_move = 40, stat_range = 15, controlled_by = .Player },
        Unit { name = "Agrias", sprite_position = { 3, 0 }, stat_health = 30, stat_health_max = 30, stat_speed = 6, stat_move = 40, stat_range = 15, controlled_by = .Player },
        Unit { name = "Mustadio", sprite_position = { 4, 0 }, stat_health = 30, stat_health_max = 30, stat_speed = 6, stat_move = 40, stat_range = 15, controlled_by = .Player },
        Unit { name = "Boco", sprite_position = { 5, 0 }, stat_health = 30, stat_health_max = 30, stat_speed = 6, stat_move = 40, stat_range = 15, controlled_by = .Player },
        Unit { name = "Rapha", sprite_position = { 6, 0 }, stat_health = 30, stat_health_max = 30, stat_speed = 6, stat_move = 40, stat_range = 15, controlled_by = .Player },
        Unit { name = "Wiegraf", sprite_position = { 0, 1 }, stat_health = 10, stat_health_max = 10, stat_speed = 8, stat_move = 8, stat_range = 15, controlled_by = .CPU },
        Unit { name = "Belias", sprite_position = { 1, 1 }, stat_health = 20, stat_health_max = 20, stat_speed = 5, stat_move = 8, stat_range = 15, controlled_by = .CPU },
        Unit { name = "Gaffgarion", sprite_position = { 2, 1 }, stat_health = 30, stat_health_max = 30, stat_speed = 4, stat_move = 8, stat_range = 15, controlled_by = .CPU },
        Unit { name = "Lavian", sprite_position = { 3, 1 }, stat_health = 30, stat_health_max = 30, stat_speed = 4, stat_move = 8, stat_range = 15, controlled_by = .CPU },
        Unit { name = "Alicia", sprite_position = { 0, 1 }, stat_health = 30, stat_health_max = 30, stat_speed = 4, stat_move = 8, stat_range = 15, controlled_by = .CPU },
        Unit { name = "Ladd", sprite_position = { 1, 0 }, stat_health = 30, stat_health_max = 30, stat_speed = 4, stat_move = 8, stat_range = 15, controlled_by = .CPU },
        Unit { name = "Cidolfus", sprite_position = { 2, 0 }, stat_health = 30, stat_health_max = 30, stat_speed = 4, stat_move = 8, stat_range = 15, controlled_by = .CPU },
    }
    _mem.game.party = { 0, 1, 2 }
    _mem.game.foes = { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
    _mem.game.rand = rand.create(12)
    return true
}
