package game

import "core:time"
import "core:mem"
import "core:math/rand"
import "core:log"
import "core:fmt"
import "../engine"

game_mode_debug :: proc() {
    @(static) entered_at: time.Time

    if game_mode_entering() {
        log.debug("[DEBUG] enter")
        entered_at = time.now()
    }

    if game_mode_running() {
        start := false
        time_scale := engine.get_time_scale()
        if time_scale > 99 && time.diff(time.time_add(entered_at, time.Duration(f32(time.Second) / time_scale)), time.now()) > 0 {
            start = true
        }

        if start {
            log.debugf("Start clicked")
        }
    }

    if game_mode_exiting() {
        log.debug("[DEBUG] exit")
    }
}
