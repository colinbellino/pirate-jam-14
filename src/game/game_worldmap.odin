package game

import "core:fmt"
import "core:log"
import "core:strings"
import "core:time"
import engine "../engine_v2"

Game_Mode_Worldmap :: struct {
    entities:             [dynamic]Entity,
    level:                Level,
    starting_level:       bool,
}

game_mode_worldmap :: proc() {
    if game_mode_entering() {
        context.allocator = _mem.game.game_mode.arena.allocator
        _mem.game.battle_index = 0
        _mem.game.world_data = new(Game_Mode_Worldmap)

        engine.asset_load(_mem.game.asset_map_world)
        engine.asset_load(_mem.game.asset_shader_sprite)

        world_asset := engine.asset_get(_mem.game.asset_map_world)
        asset_info := world_asset.info.(engine.Asset_Info_Map)
        log.infof("Level %v loaded: %s (%s)", world_asset.file_name, asset_info.iid, asset_info.jsonVersion)
        _mem.game.level_assets = load_level_assets(asset_info)
        _mem.game.world_data.level = make_level(asset_info, 0, _mem.game.level_assets, &_mem.game.world_data.entities, 1, _mem.game.asset_shader_sprite, _mem.game.game_mode.arena.allocator)
        // _mem.renderer.world_camera.position = { 128, 72, 0 }

        scene_transition_start(.Unswipe_Left_To_Right)
    }

    if game_mode_running() {
        if _mem.game.world_data.starting_level && scene_transition_is_done() {
            game_mode_transition(.Battle)
        } else {
            if scene_transition_is_done() == false {
                return
            }

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
                    if engine.ui_button(fmt.tprintf("%v", battle_id)) {
                        _mem.game.battle_index = i + 1
                    }
                }
            }

            if _mem.game.battle_index != 0 && _mem.game.world_data.starting_level == false {
                _mem.game.world_data.starting_level = true
                scene_transition_start(.Swipe_Left_To_Right)
            }
        }
    }

    if game_mode_exiting() {
        log.debugf("Worldmap exit | entities: %v ", len(_mem.game.world_data.entities))
        // for entity in _mem.game.world_data.entities {
        //     engine.entity_delete_entity(entity)
        // }
        engine.entity_reset_memory()
        engine.asset_unload(_mem.game.asset_map_world)
        _mem.game.world_data = nil
    }
}
