package game

import "core:log"
import "core:strings"

import "../engine"

Game_Mode_Worldmap :: struct {
    entities:             [dynamic]Entity,
    level:                Level,
}

game_mode_worldmap :: proc() {
    if game_mode_entering() {
        context.allocator = _game.game_mode.allocator
        _game.battle_index = 0
        _game.world_data = new(Game_Mode_Worldmap)

        engine.asset_load(_game.asset_worldmap)

        world_asset := &_engine.assets.assets[_game.asset_worldmap]
        asset_info := world_asset.info.(engine.Asset_Info_Map)
        log.infof("Level %v loaded: %s (%s)", world_asset.file_name, asset_info.ldtk.iid, asset_info.ldtk.jsonVersion)
        _game.tileset_assets = load_level_assets(asset_info, _engine.assets)
        _game.world_data.level = make_level(asset_info.ldtk, 0, _game.tileset_assets, &_game.world_data.entities,  _game.allocator)
        _engine.renderer.world_camera.position = { 128, 72, 0 }
    }

    if game_mode_running() {
        // if _game.player_inputs.mouse_left.released && _game.debug_entity_under_mouse != 0{
        //     entity := _game.debug_entity_under_mouse
        //     component_meta, has_meta := _game.entities.components_meta[_game.debug_entity_under_mouse]
        //     if has_meta {
        //         battle_index, battle_index_exists := component_meta.value["battle_index"]
        //         if battle_index_exists {
        //             _game.battle_index = int(battle_index.(json.Integer))
        //             game_mode_transition(.Battle)
        //         }
        //     }
        // }

        if _game.player_inputs.confirm.released {
            _game.battle_index = 1
        }

        if game_ui_window("Worldmap", nil, .NoResize | .NoCollapse) {
            engine.ui_set_window_size_vec2({ 400, 300 }, {})
            engine.ui_set_window_pos_vec2({ 400, 300 }, .FirstUseEver)
            for battle_id, i in BATTLE_LEVELS {
                if engine.ui_button(strings.clone_to_cstring(battle_id, context.temp_allocator)) {
                    _game.battle_index = i + 1
                }
            }
        }

        if _game.battle_index != 0 {
            game_mode_transition(.Battle)
        }
    }

    if game_mode_exiting() {
        log.debugf("Worldmap exit | entities: %v ", len(_game.world_data.entities))
        for entity in _game.world_data.entities {
            engine.entity_delete_entity(entity)
        }
        engine.asset_unload(_game.asset_worldmap)
    }
}
