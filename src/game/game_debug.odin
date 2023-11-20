package game

import "core:log"
import "../engine"

game_mode_debug :: proc() {
    if game_mode_entering() {
        log.debug("DEBUG enter")
    }

    engine.renderer_clear({ 0.5, 0.2, 0.2, 1 })
    game_mode_transition(.Battle)

    if game_mode_exiting() {
        log.debug("DEBUG exit")
    }
}
