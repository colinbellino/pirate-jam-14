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
        context.allocator = _mem.game.game_mode.allocator
        _mem.game.battle_index = 0
        _mem.game.world_data = new(Game_Mode_Worldmap)

        engine.asset_load(_mem.game.asset_map_world)

        world_asset := &_mem.assets.assets[_mem.game.asset_map_world]
        asset_info := world_asset.info.(engine.Asset_Info_Map)
        log.infof("Level %v loaded: %s (%s)", world_asset.file_name, asset_info.ldtk.iid, asset_info.ldtk.jsonVersion)
        _mem.game.level_assets = load_level_assets(asset_info)
        _mem.game.world_data.level = make_level(asset_info.ldtk, 0, _mem.game.level_assets, &_mem.game.world_data.entities,  _mem.game.allocator)
        _mem.engine.renderer.world_camera.position = { 128, 72, 0 }
    }

    if game_mode_running() {
        // if _mem.game.player_inputs.mouse_left.released && _mem.game.debug_entity_under_mouse != 0{
        //     entity := _mem.game.debug_entity_under_mouse
        //     component_meta, has_meta := _mem.game.entities.components_meta[_mem.game.debug_entity_under_mouse]
        //     if has_meta {
        //         battle_index, battle_index_exists := component_meta.value["battle_index"]
        //         if battle_index_exists {
        //             _mem.game.battle_index = int(battle_index.(json.Integer))
        //             game_mode_transition(.Battle)
        //         }
        //     }
        // }

        if _mem.game.player_inputs.confirm.released {
            _mem.game.battle_index = 1
        }

        if game_ui_window("Worldmap", nil, .NoResize | .NoCollapse) {
            engine.ui_set_window_size_vec2({ 400, 300 }, {})
            engine.ui_set_window_pos_vec2({ 400, 300 }, .FirstUseEver)
            for battle_id, i in BATTLE_LEVELS {
                if engine.ui_button(strings.clone_to_cstring(battle_id, context.temp_allocator)) {
                    _mem.game.battle_index = i + 1
                }
            }
        }

        if _mem.game.battle_index != 0 {
            game_mode_transition(.Battle)
        }
    }

    if game_mode_exiting() {
        log.debugf("Worldmap exit | entities: %v ", len(_mem.game.world_data.entities))
        for entity in _mem.game.world_data.entities {
            engine.entity_delete_entity(entity)
        }
        engine.asset_unload(_mem.game.asset_map_world)
    }
}
