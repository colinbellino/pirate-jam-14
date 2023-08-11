package game

import "core:log"
import "core:strings"

import "../engine"

game_mode_init :: proc() {
    // engine.platform_resize_window()
    // update_rendering_offset()

    // TODO: generate the asset list in the build process
    _game.asset_worldmap          = engine.asset_add("media/levels/worldmap.ldtk", .Map)
    _game.asset_areas             = engine.asset_add("media/levels/areas.ldtk", .Map)
    _game.asset_battle_background = engine.asset_add("media/art/battle_background.png", .Image)
    _game.asset_tilemap           = engine.asset_add("media/art/spritesheet.png", .Image)

    _game.debug_ui_show_tiles = true
    _game.debug_show_anim_ui = true
    _game.draw_hud = true
    _game.debug_draw_entities = true
    _game.debug_render_z_index_0 = true
    _game.debug_render_z_index_1 = true

    engine.renderer_scene_init()

    game_mode_transition(.Title)
    game_mode_end()
}
