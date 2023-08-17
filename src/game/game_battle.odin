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

        engine.asset_load(_game.asset_battle_background, engine.Image_Load_Options { engine.RENDERER_LINEAR, engine.RENDERER_CLAMP_TO_EDGE })
        engine.asset_load(_game.asset_areas)

        {
            areas_asset := &_game._engine.assets.assets[_game.asset_areas]
            asset_info, asset_ok := areas_asset.info.(engine.Asset_Info_Map)
            _game.tileset_assets = load_level_assets(asset_info, _game._engine.assets)
            _game.battle_data.level = make_level(asset_info.ldtk, _game.battle_index - 1, _game.tileset_assets, &_game.battle_data.entities, _game.game_allocator)
        }

        {
            background_asset := &_game._engine.assets.assets[_game.asset_battle_background]
            asset_info, asset_ok := background_asset.info.(engine.Asset_Info_Image)
            entity := entity_make("Background: Battle")
            entity_add_transform(entity, { f32(asset_info.texture.width) / 2, f32(asset_info.texture.height) / 2 }, { f32(asset_info.texture.width), f32(asset_info.texture.height) })
            entity_add_sprite(entity, _game.asset_battle_background, { 0, 0 }, { asset_info.texture.width, asset_info.texture.height }, -1)
            append(&_game.battle_data.entities, entity)
        }

        // {
        //     entity := entity_make("Unit: 1")
        //     entity_add_transform(entity, { 0, 0 }, { 32, 32 })
        //     entity_add_sprite(entity, 4, { 2, 2 }, { 8, 8 })
        //     // _game.entities.components_z_index[entity] = Component_Z_Index { 1 }
        //     append(&_game.battle_data.entities, entity)
        // }

        log.debugf("Battle:           %v", _game.battle_index)
        // log.debugf("_game.battle_data: %v | %v", _game.battle_data.level, _game.battle_data.entities)
    }

    if game_mode_running() {
        if game_ui_window("Battle", nil, .NoResize) {
            engine.ui_set_window_size_vec2({ 400, 100 })
            engine.ui_set_window_pos_vec2({ 400, 200 }, .FirstUseEver)

            engine.ui_text(fmt.tprintf("Battle index: %v", _game.battle_index))
            if engine.ui_button("Back to world map") {
                _game.battle_index = 0
                game_mode_transition(.WorldMap)
            }
        }

        return
    }

    log.debugf("Battle exit | entities: %v", len(_game.battle_data.entities))
    for entity in _game.battle_data.entities {
        entity_delete(entity, &_game.entities)
    }
    engine.asset_unload(_game.asset_battle_background)
    engine.asset_unload(_game.asset_areas)

    game_mode_end()
}

