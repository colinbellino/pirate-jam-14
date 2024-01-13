package game

import "core:time"
import "core:mem"
import "core:math/rand"
import "core:log"
import "core:fmt"
import "../engine"

game_mode_debug :: proc() {
    if game_mode_entering() {
        log.debug("[DEBUG] enter")

        _mem.game.render_command_clear.pass_action.colors[0].clear_value = { 0.5, 0, 0, 1 }
    }

    if game_mode_running() {

    }

    if game_mode_exiting() {
        log.debug("[DEBUG] exit")
    }
}
