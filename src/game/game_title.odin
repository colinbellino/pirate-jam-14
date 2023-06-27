package game

import "core:log"
import "core:os"
import "core:runtime"
import "core:mem"

import "../engine"

Data :: struct {
    thing_1: int,
    thing_2: int,
    thing_3: int,
}

data : ^Data

timer_tick :: proc(timer: ^int) -> bool {
    if timer^ >= 20 {
        return true
    }
    timer^ += 1
    log.debugf("timer %p: %v", timer, timer^);
    return false
}

game_mode_title :: proc() {
    if game_mode_enter() {
        log.debug("title -> enter")
        err: runtime.Allocator_Error
        data, err = new(Data, _game.game_mode.allocator)
        log.debugf("_game.game_mode.allocator: %v", _game.game_mode.allocator);
        log.debugf("  err:  %v", err)
        log.debugf("  data: %v", data)
    }

    if timer_tick(&data.thing_1) == false {
        return
    }
    if timer_tick(&data.thing_2) == false {
        return
    }

    if game_mode_running() {
        // log.debug("tick");
        if _game.player_inputs.confirm.pressed {
            log.debug("confirm pressed");
            game_mode_transition(.WorldMap)
        }

        return
    }

    if timer_tick(&data.thing_3) == false {
        return
    }

    game_mode_end()
}
