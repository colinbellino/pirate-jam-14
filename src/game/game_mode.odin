package game

import "core:runtime"
import "core:log"

Mode :: struct {
    entered:    bool,
    exiting:    bool,
    current:    int,
    next:       int,
    allocator:  runtime.Allocator,
}

mode_transition :: proc(mode: ^Mode, next: int) {
    mode.exiting = true // TODO: do this in game_mode_transition(.Worldmap)
    mode.next = next
}
mode_end :: proc(mode: ^Mode, loc := #caller_location) {
    assert(mode.current != mode.next, "Ended mode without transitioning first!", loc)
    mode.entered = false
    mode.exiting = false
    mode.current = mode.next
    if mode.allocator.procedure != nil {
        arena_allocator_free_all_and_zero(mode.allocator)
    }
}

@(deferred_in=_mode_enter_end)
mode_enter :: proc(mode: ^Mode) -> bool {
    return mode.entered == false
}
@(private="file")_mode_enter_end :: proc(mode: ^Mode) {
    mode.entered = true
}

@(deferred_in=_mode_running_end)
mode_running :: proc(mode: ^Mode) -> bool {
    return mode.exiting == false
}
@(private="file")_mode_running_end :: proc(mode: ^Mode) {
    // mode.exiting = true
}

game_mode_transition :: proc(next: Game_Mode) {
    mode_transition(&_game.game_mode, int(next))
    log.debugf("[GAME_MODE_TRANSITION] %v -> %v", Game_Mode(_game.game_mode.current), Game_Mode(_game.game_mode.next))
}
game_mode_end :: proc(loc := #caller_location) {
    log.debugf("[GAME_MODE_END] %v -> %v", Game_Mode(_game.game_mode.current), Game_Mode(_game.game_mode.next))
    mode_end(&_game.game_mode, loc)
}
game_mode_enter :: proc() -> bool {
    return mode_enter(&_game.game_mode)
}
game_mode_running :: proc() -> bool {
    return mode_running(&_game.game_mode)
}

battle_mode_transition :: proc(next: Battle_Mode) {
    mode_transition(&_game.battle_data.mode, int(next))
    log.debugf("[BATTLE_MODE_TRANSITION] %v -> %v", Battle_Mode(_game.battle_data.mode.current), Battle_Mode(_game.battle_data.mode.next))
}
battle_mode_end :: proc(loc := #caller_location) {
    log.debugf("[BATTLE_MODE_END] %v -> %v", Battle_Mode(_game.battle_data.mode.current), Battle_Mode(_game.battle_data.mode.next))
    mode_end(&_game.battle_data.mode, loc)
}
battle_mode_enter :: proc() -> bool {
    return mode_enter(&_game.battle_data.mode)
}
battle_mode_running :: proc() -> bool {
    return mode_running(&_game.battle_data.mode)
}
