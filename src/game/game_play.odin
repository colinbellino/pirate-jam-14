package game

import "core:time"
import "core:mem"
import "core:math/rand"
import "core:log"
import "core:fmt"
import "../engine"

game_mode_play :: proc() {
    @(static) entered_at: time.Time

    if game_mode_entering() {
        entered_at = time.now()
        log.debugf("[PLAY] entered at %v", entered_at)
    }

    if game_mode_running() {

    }

    if game_mode_exiting() {
        log.debug("[PLAY] exit")
    }
}
