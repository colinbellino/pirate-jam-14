package game

import "core:log"
import "core:strings"

import "../engine"

game_mode_init :: proc() {
    // TODO: generate the asset list in the build process
    _game.asset_worldmap          = engine.asset_add("media/levels/worldmap.ldtk", .Map)
    _game.asset_areas             = engine.asset_add("media/levels/areas.ldtk", .Map)
    _game.asset_tilemap           = engine.asset_add("media/art/spritesheet.png", .Image)
    _game.asset_battle_background = engine.asset_add("media/art/battle_background_xl.png", .Image)

    _game.draw_hud = false
    _game.debug_draw_tiles = true
    _game.debug_draw_entities = true
    _game.debug_render_z_index_0 = true
    _game.debug_render_z_index_1 = true

    _game.debug_window_anim = false

    _game.battle_index = 1 // Skip worldmap

    engine.renderer_scene_init()

    game_mode_transition(.Title)
    game_mode_end()
}
