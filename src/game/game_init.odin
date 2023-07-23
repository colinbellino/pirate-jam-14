package game

import "core:log"
import "core:strings"

import "../engine"

game_mode_init :: proc() {
    // engine.platform_resize_window()
    // update_rendering_offset()

    // _game.asset_tilemap = engine.asset_add("media/art/spritesheet.processed.png", .Image)
    _game.asset_battle_background = engine.asset_add("media/art/battle_background.png", .Image)
    _game.asset_worldmap = engine.asset_add("media/levels/worldmap.ldtk", .Map)
    _game.asset_areas = engine.asset_add("media/levels/areas.ldtk", .Map)

    _game.debug_ui_show_tiles = true
    _game.debug_show_anim_ui = true
    _game.draw_hud = true
    _game.debug_ui_entity = 1
    _game.debug_draw_entities = true
    _game.debug_render_z_index_0 = true
    _game.debug_render_z_index_1 = true

    engine.asset_load(_game.asset_tilemap)
    engine.asset_load(_game.asset_battle_background)
    engine.asset_load(_game.asset_worldmap)
    engine.asset_load(_game.asset_areas)

    world_asset := &_game._engine.assets.assets[_game.asset_worldmap]
    asset_info := world_asset.info.(engine.Asset_Info_Map)
    log.infof("Level %v loaded: %s (%s)", world_asset.file_name, asset_info.ldtk.iid, asset_info.ldtk.jsonVersion)

    for tileset in asset_info.ldtk.defs.tilesets {
        rel_path, value_ok := tileset.relPath.?
        if value_ok != true {
            continue
        }

        path, path_ok := strings.replace(rel_path, static_string("../art"), static_string("media/art"), 1)
        if path_ok != true {
            log.warnf("Invalid tileset: %s", rel_path)
            continue
        }

        asset, asset_found := engine.asset_get_by_file_name(_game._engine.assets, path)
        if asset_found == false {
            log.warnf("Tileset asset not found: %s", path)
            continue
        }

        _game.tileset_assets[tileset.uid] = asset.id
        engine.asset_load(asset.id)
    }

    game_mode_transition(.Title)
    game_mode_end()
}
