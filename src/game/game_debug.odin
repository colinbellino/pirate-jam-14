package game

import "core:log"
import "core:time"
import "../engine"

game_mode_debug :: proc() {
    @(static) entered_at: time.Time

    if game_mode_entering() {
        log.debug("[DEBUG] enter")
        entered_at = time.now()
        // engine.asset_load(_mem.game.asset_image_spritesheet, engine.Image_Load_Options { engine.RENDERER_FILTER_NEAREST, engine.RENDERER_CLAMP_TO_EDGE })
    }

    if game_mode_running() {
        engine.renderer_clear({ 0.5, 0.2, 0.2, 1 })

        if time.diff(time.time_add(entered_at, time.Second), time.now()) > 0 {
            log.debugf("DEBUG -> BATTLE")
            game_mode_transition(.Battle)
        }
    }

    if game_mode_exiting() {
        log.debug("[DEBUG] exit")
    }
}
