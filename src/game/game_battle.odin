package game

import "core:fmt"
import "core:log"
import "core:slice"
import "core:sort"
import "core:time"

import "../engine"

TURN_COST     :: 100
TICK_DURATION :: i64(time.Second)

BATTLE_LEVELS := [?]string {
    "Debug_0",
    "Level_0",
    "Level_1",
}

Game_Mode_Battle :: struct {
    entities:             [dynamic]Entity,
    level:                Level,
    current_unit:         int, // Index into _game.units
    units:                [dynamic]int, // Index into _game.units
    action:               i32,
    next_tick:            time.Time,
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

        for unit_index in _game.battle_data.units {
            unit := &_game.units[unit_index]
            unit.stat_ctr = 0
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

        spawn_units(spawners_ally, _game.party)
        spawn_units(spawners_foe, _game.foes)

        log.debugf("Battle:           %v", BATTLE_LEVELS[_game.battle_index - 1])
        // log.debugf("_game.battle_data: %v | %v", _game.battle_data.level, _game.battle_data.entities)
    }

    if game_mode_running() {
        current_unit := _game.units[_game.battle_data.current_unit]

        tick := false
        if time.diff(_game.battle_data.next_tick, time.now()) >= 0 {
            tick = true
        }

        if tick {
            for unit_index in _game.battle_data.units {
                unit := &_game.units[unit_index]
                unit.stat_ctr += unit.stat_speed
            }

            sorted_units := slice.clone(_game.battle_data.units[:], context.temp_allocator)
            sort.heap_sort_proc(sorted_units, sort_units_by_ctr)

            for unit_index in sorted_units {
                unit := &_game.units[unit_index]
                if unit.stat_ctr >= TURN_COST {
                    log.debugf("%v's turn", unit.name)
                    unit.stat_ctr -= TURN_COST
                    break
                }
            }

            _game.battle_data.next_tick = { time.now()._nsec + TICK_DURATION }
        }

        if _game.battle_data.action == 1 {
            if _game.player_inputs.mouse_left.released {
                entity_move_grid(current_unit.entity, _game.mouse_grid_position)
                _game.battle_data.action = 0
            }
        }

        if game_ui_window("Battle", nil, .NoResize | .NoCollapse) {
            engine.ui_set_window_size_vec2({ 400, 100 })
            engine.ui_set_window_pos_vec2({ 400, 200 }, .FirstUseEver)

            engine.ui_text(fmt.tprintf("Battle index: %v", _game.battle_index))
            if engine.ui_button("Back to world map") {
                _game.battle_index = 0
                game_mode_transition(.WorldMap)
            }
        }

        if engine.ui_window("Battle Debug", nil) {
            engine.ui_set_window_pos_vec2({ 100, 300 }, .FirstUseEver)
            engine.ui_set_window_size_vec2({ 800, 300 })

            region: engine.UI_Vec2
            engine.ui_get_content_region_avail(&region)

            {
                progress : f32 = 1 - f32(_game.battle_data.next_tick._nsec - time.now()._nsec) / f32(TICK_DURATION)
                engine.ui_progress_bar(progress, { -1, 20 }, fmt.tprintf("Tick %v", progress))
            }

            if engine.ui_child("left", { region.x * 0.5, region.y }) {
                columns := [?]string { "index", "name", "ctr", "actions" }
                if engine.ui_begin_table("table1", len(columns), .RowBg | .SizingStretchSame | .Resizable) {
                    engine.ui_table_next_row(.Headers)
                    for column, i in columns {
                        engine.ui_table_set_column_index(i32(i))
                        engine.ui_text(column)
                    }

                    for i := 0; i < len(_game.units); i += 1 {
                        unit := &_game.units[i]
                        engine.ui_table_next_row()

                        for column, column_index in columns {
                            engine.ui_table_set_column_index(i32(column_index))
                            switch column {
                                case "index": engine.ui_text("%v", i)
                                case "name": engine.ui_text("%v", unit.name)
                                case "ctr": {
                                    progress := f32(unit.stat_ctr) / 100
                                    engine.ui_progress_bar(progress, { -1, 20 }, fmt.tprintf("CTR %v", unit.stat_ctr))
                                }
                                case "actions": {
                                    engine.ui_push_id(i32(i))
                                    if engine.ui_button("Inspect") {
                                        _game.battle_data.current_unit = i
                                    }
                                    engine.ui_pop_id()
                                }
                                case: engine.ui_text("x")
                            }
                        }
                    }

                    engine.ui_end_table()
                }
            }


            engine.ui_same_line()

            if engine.ui_child("right", { region.x * 0.5, region.y }) {
                engine.ui_text("action: %v", _game.battle_data.action)
                engine.ui_slider_int2("mouse_grid_position", transmute(^[2]i32)&_game.mouse_grid_position[0], 0, 40)
                if engine.ui_button("Move") {
                    _game.battle_data.action = 1
                    return
                }
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

spawn_units :: proc(spawners: [dynamic]Entity, units: [dynamic]int) {
    for spawner, i in spawners {
        if i >= len(units) {
            break
        }

        unit := &_game.units[units[i]]
        component_transform := _game.entities.components_transform[spawner]

        entity := entity_create_unit(unit, component_transform.grid_position)
        append(&_game.battle_data.entities, entity)
        append(&_game.battle_data.units, units[i])

        unit.entity = entity
    }
}

sort_units_by_ctr :: proc(a, b: int) -> int {
    return int(_game.units[a].stat_ctr - _game.units[b].stat_ctr)
}
