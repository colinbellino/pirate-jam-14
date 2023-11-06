package game

import "core:log"

game_mode_debug :: proc() {
    if game_mode_entering() {
        log.debug("DEBUG enter")
    }

    if game_mode_exiting() {
        log.debug("DEBUG exit")
    }
}
