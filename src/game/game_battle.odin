package game

import "core:log"
import "core:fmt"

import "../engine"

Game_Mode_Battle :: struct {
    entities:             [dynamic]Entity,
    level:                Level,
}

game_mode_update_battle :: proc () {
    if game_mode_enter() {
        context.allocator = _game.game_mode.allocator
        _game.battle_data = new(Game_Mode_Battle)
        // _game.background_asset = _game.asset_battle_background

        {
            background_asset := &_game._engine.assets.assets[_game.asset_battle_background]
            asset_info, asset_ok := background_asset.info.(engine.Asset_Info_Image)

            entity := entity_make("Background: Battle")
            entity_add_transform(entity, { 0, 0 }, Vector2f32(array_cast(asset_info.size, f32)))
            entity_add_sprite(entity, _game.asset_battle_background, { 0, 0 }, asset_info.size)
            _game.entities.components_z_index[entity] = Component_Z_Index { -1 }
        }

        {
            areas_asset := &_game._engine.assets.assets[_game.asset_areas]
            asset_info, asset_ok := areas_asset.info.(engine.Asset_Info_Map)
            assert(asset_ok)
            _game.battle_data.level, _game.battle_data.entities = make_level(asset_info.ldtk, _game.battle_index, _game.tileset_assets, _game.game_allocator)
        }

        log.debugf("Battle:           %v", _game.battle_index)
        // log.debugf("_game.battle_data: %v | %v", _game.battle_data.level, _game.battle_data.entities)
    }

    if game_mode_running() {
        // if engine.ui_window("Battle", { 400, 400, 200, 100 }, { .NO_CLOSE, .NO_RESIZE }) {
        //     engine.ui_layout_row({ -1 }, 0)
        //     engine.ui_label(fmt.tprintf("Battle index: %v", _game.battle_index))
        //     if .SUBMIT in engine.ui_button("Back to world map") {
        //         game_mode_transition(.WorldMap)
        //     }
        // }

        return
    }

    log.debug("Battle exit")
    for entity in _game.battle_data.entities {
        entity_delete(entity, &_game.entities)
    }
    // _game.background_asset = 0

    game_mode_end()
}
