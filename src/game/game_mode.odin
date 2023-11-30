package game

import "core:runtime"
import "core:log"
import "../engine"

Mode :: struct {
    entered:    bool,
    exiting:    bool,
    current:    int,
    next:       int,
    arena:      engine.Named_Virtual_Arena,
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
        // log.debugf("zero aren    a: %v", mode.arena)
        engine.mem_zero_named_arena(&mode.arena)
        free_all(mode.arena.allocator)
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

game_mode_transition :: proc(next: Game_Mode) { mode_transition(&_mem.game.game_mode, int(next)) }
game_mode_check_exit :: proc() { mode_check_exit(&_mem.game.game_mode) }
game_mode_entering   :: proc() -> bool { return mode_entering(&_mem.game.game_mode) }
game_mode_running    :: proc() -> bool { return mode_running(&_mem.game.game_mode) }
game_mode_exiting    :: proc() -> bool { return mode_exiting(&_mem.game.game_mode) }

battle_mode_transition :: proc(next: Battle_Mode) { mode_transition(&_mem.game.battle_data.mode, int(next)) }
battle_mode_check_exit :: proc() { mode_check_exit(&_mem.game.battle_data.mode) }
battle_mode_entering   :: proc() -> bool { assert(_mem.game.battle_data != nil, "Battle not started, can't execute battle_mode_entering.");  return mode_entering(&_mem.game.battle_data.mode) }
battle_mode_running    :: proc() -> bool { assert(_mem.game.battle_data != nil, "Battle not started, can't execute battle_mode_running.");  return mode_running(&_mem.game.battle_data.mode) }
battle_mode_exiting    :: proc() -> bool { assert(_mem.game.battle_data != nil, "Battle not started, can't execute battle_mode_exiting.");  return mode_exiting(&_mem.game.battle_data.mode) }
