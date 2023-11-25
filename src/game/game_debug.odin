package game

import "core:log"
import "../engine"

game_mode_debug :: proc() {
    if game_mode_entering() {
        log.debug("[DEBUG] enter")
        // engine.asset_load(_mem.game.asset_image_spritesheet, engine.Image_Load_Options { engine.RENDERER_FILTER_NEAREST, engine.RENDERER_CLAMP_TO_EDGE })
        game_mode_transition(.Battle)
    }

    if game_mode_running() {
        engine.renderer_clear({ 0.5, 0.2, 0.2, 1 })
    }

    if game_mode_exiting() {
        log.debug("[DEBUG] exit")
    }
}
