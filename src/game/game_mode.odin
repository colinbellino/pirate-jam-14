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
mode_end :: proc(mode: ^Mode) {
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
}
game_mode_end :: proc() {
    // log.debugf("[GAME_MODE_TRANSITION] %v -> %v", Game_Mode(_game.game_mode.current), Game_Mode(_game.game_mode.next))
    mode_end(&_game.game_mode)
}
game_mode_enter :: proc() -> bool {
    return mode_enter(&_game.game_mode)
}
game_mode_running :: proc() -> bool {
    return mode_running(&_game.game_mode)
}
