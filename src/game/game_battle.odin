package game

import "core:log"
import "core:fmt"

import "../engine"

BATTLE_LEVELS := [?]string {
    "Debug_0",
    "Level_0",
    "Level_1",
}

Game_Mode_Battle :: struct {
    entities:             [dynamic]Entity,
    level:                Level,
}

game_mode_update_battle :: proc () {
    if game_mode_enter() {
        context.allocator = _game.game_mode.allocator
        _game.battle_data = new(Game_Mode_Battle)

        engine.asset_load(_game.asset_battle_background, engine.Image_Load_Options { engine.RENDERER_NEAREST, engine.RENDERER_CLAMP_TO_EDGE })
        engine.asset_load(_game.asset_areas)

        _game._engine.renderer.world_camera.position = { NATIVE_RESOLUTION.x / 2, NATIVE_RESOLUTION.y / 2, 0 }

        {
            background_asset := &_game._engine.assets.assets[_game.asset_battle_background]
            asset_info, asset_ok := background_asset.info.(engine.Asset_Info_Image)
            entity := entity_make("Background: Battle")
            entity_add_transform(entity, { f32(asset_info.texture.width) / 4, f32(asset_info.texture.height) / 4 }, { f32(asset_info.texture.width), f32(asset_info.texture.height) })
            entity_add_sprite(entity, _game.asset_battle_background, { 0, 0 }, { asset_info.texture.width, asset_info.texture.height }, 0, -1)
            append(&_game.battle_data.entities, entity)
        }

        {
            areas_asset := &_game._engine.assets.assets[_game.asset_areas]
            asset_info, asset_ok := areas_asset.info.(engine.Asset_Info_Map)
            level_index : int = 0
            for level, i in asset_info.ldtk.levels {
                if level.identifier == BATTLE_LEVELS[_game.battle_index - 1] {
                    level_index = i
                    break
                }
            }
            _game.tileset_assets = load_level_assets(asset_info, _game._engine.assets)
            _game.battle_data.level = make_level(asset_info.ldtk, level_index, _game.tileset_assets, &_game.battle_data.entities, _game.game_allocator)
        }

        party := [dynamic]Unit {
            Unit { 1, "Ramza", { 4, 15 }, 0 },
            Unit { 2, "Delita", { 3, 15 }, 0 },
            Unit { 3, "Alma", { 2, 15 }, 0 },
        }
        foes := [dynamic]Unit {
            Unit { 1, "Wiegraf", { 1, 15 }, 0 },
            Unit { 2, "Belias", { 0, 14 }, 0 },
            Unit { 3, "Gaffgarion", { 1, 15 }, 0 },
        }

        spawners_ally := [dynamic]Entity {}
        spawners_foe := [dynamic]Entity {}
        for entity in _game.battle_data.entities {
            component_meta, has_meta := _game.entities.components_meta[entity]
            if has_meta == false {
                continue
            }

            component_transform, has_transform := _game.entities.components_transform[entity]
            ldtk_entity := _game.ldtk_entity_defs[component_meta.entity_uid]
            if ldtk_entity.identifier == "Spawner_Ally" {
                append(&spawners_ally, entity)
            }
            if ldtk_entity.identifier == "Spawner_Foe" {
                append(&spawners_foe, entity)
            }
        }

        spawn_units(spawners_ally, party)
        spawn_units(spawners_foe, foes)

        log.debugf("Battle:           %v", BATTLE_LEVELS[_game.battle_index - 1])
        // log.debugf("_game.battle_data: %v | %v", _game.battle_data.level, _game.battle_data.entities)
    }

    if game_mode_running() {
        if game_ui_window("Battle", nil, .NoResize | .NoCollapse) {
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

spawn_units :: proc(spawners: [dynamic]Entity, units: [dynamic]Unit) {
    for spawner, i in spawners {
        if i >= len(units) {
            break
        }

        unit := &units[i]
        component_transform := _game.entities.components_transform[spawner]

        entity := entity_create_unit(unit, component_transform.grid_position)
        append(&_game.battle_data.entities, entity)
        unit.entity = entity
    }
}
