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
    mode.exiting = true
    mode.next = next
}
mode_check_exit :: proc(mode: ^Mode, loc := #caller_location) {
    // assert(mode.current != mode.next, "Ended mode without transitioning first!", loc)
    if mode_exiting(mode) {
        mode.entered = false
        mode.exiting = false
        mode.current = mode.next
        if mode.allocator.procedure != nil {
            arena_allocator_free_all_and_zero(mode.allocator)
        }
    }
}
mode_entering :: proc(mode: ^Mode) -> bool {
    result := mode.entered == false
    if result {
        mode.entered = true
    }
    return result
}
mode_running :: proc(mode: ^Mode) -> bool {
    return mode.exiting == false
}
mode_exiting :: proc(mode: ^Mode) -> bool {
    return mode.current != mode.next
}

game_mode_transition :: proc(next: Game_Mode) { mode_transition(&_game.game_mode, int(next)) }
game_mode_check_exit :: proc() { mode_check_exit(&_game.game_mode) }
game_mode_entering   :: proc() -> bool { return mode_entering(&_game.game_mode) }
game_mode_running    :: proc() -> bool { return mode_running(&_game.game_mode) }
game_mode_exiting    :: proc() -> bool { return mode_exiting(&_game.game_mode) }

battle_mode_transition :: proc(next: Battle_Mode) { mode_transition(&_game.battle_data.mode, int(next)) }
battle_mode_check_exit :: proc() { mode_check_exit(&_game.battle_data.mode) }
battle_mode_entering   :: proc() -> bool { return mode_entering(&_game.battle_data.mode) }
battle_mode_running    :: proc() -> bool { return mode_running(&_game.battle_data.mode) }
battle_mode_exiting    :: proc() -> bool { return mode_exiting(&_game.battle_data.mode) }
