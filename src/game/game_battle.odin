package game

import "core:container/queue"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:sort"
import "core:time"

import "../engine"

TAKE_TURN              :: i32(100)
TURN_COST              :: i32(60)
ACT_COST               :: i32(20)
MOVE_COST              :: i32(20)
TICK_DURATION          :: i64(0)
BATTLE_TURN_ARENA_SIZE :: 16 * mem.Kilobyte

BATTLE_LEVELS := [?]string {
    "Debug_0",
    "Level_0",
    "Level_1",
}
OFFSCREEN_POSITION :: Vector2i32 { 999, 999 }

Game_Mode_Battle :: struct {
    entities:             [dynamic]Entity,
    level:                Level,
    current_unit:         int, // Index into _game.units
    units:                [dynamic]int, // Index into _game.units
    mode:                 Mode,
    next_tick:            time.Time,
    cursor_move_entity:   Entity,
    cursor_target_entity: Entity,
    cursor_unit_entity:   Entity,
    unit_preview_entity:  Entity,
    move_repeater:        engine.Input_Repeater,
    aim_repeater:         engine.Input_Repeater,
    turn:                 Turn,
    turn_allocator:       runtime.Allocator,
    turn_arena:           mem.Arena,
}

Battle_Mode :: enum {
    Ticking,
    Start_Turn,
    Select_Action,
    Target_Move,
    Execute_Move,
    Target_Ability,
    Execute_Ability,
    End_Turn,
    Victory,
    Defeat,
}

Cell_Highlight_Type :: enum { Move, Ability }
Cell_Highlight :: struct {
    grid_index: int,
    type:       Cell_Highlight_Type,
}

Turn :: struct {
    move:                  Vector2i32,
    target:                Vector2i32,
    ability:               Ability,
    moved:                 bool,
    acted:                 bool,
    projectile:            Entity,
    animations:            ^queue.Queue(^engine.Animation),
    move_path:             []Vector2i32,
    cursor_unit_animation: ^engine.Animation, // TODO: Find a cleaner way to keep track of small animations like that
}

Battle_Action :: enum {
    None,
    Move,
    Throw,
    Wait,
}

Ability :: distinct u32

game_mode_battle :: proc () {
    if game_mode_entering() {
        context.allocator = _game.game_mode.allocator
        _game.battle_data = new(Game_Mode_Battle)
        _game.battle_data.turn_allocator = engine.platform_make_arena_allocator("turn", BATTLE_TURN_ARENA_SIZE, &_game.battle_data.turn_arena)

        engine.asset_load(_game.asset_image_battle_bg, engine.Image_Load_Options { engine.RENDERER_FILTER_NEAREST, engine.RENDERER_CLAMP_TO_EDGE })
        engine.asset_load(_game.asset_map_areas)
        engine.asset_load(_game.asset_music_battle, engine.Audio_Load_Options { .Music })

        music_asset := _engine.assets.assets[_game.asset_music_battle]
        music_asset_info := music_asset.info.(engine.Asset_Info_Audio)
        engine.audio_play_music(music_asset_info.clip, -1)

        _engine.renderer.world_camera.position = { NATIVE_RESOLUTION.x / 2, NATIVE_RESOLUTION.y / 2, 0 }
        _game.battle_data.move_repeater = { threshold = 200 * time.Millisecond, rate = 100 * time.Millisecond }
        _game.battle_data.aim_repeater = { threshold = 200 * time.Millisecond, rate = 100 * time.Millisecond }
        clear(&_game.highlighted_cells)

        reset_turn(&_game.battle_data.turn)

        {
            background_asset := &_engine.assets.assets[_game.asset_image_battle_bg]
            asset_info, asset_ok := background_asset.info.(engine.Asset_Info_Image)
            if asset_ok {
                entity := engine.entity_create_entity("Background: Battle")
                engine.entity_set_component(entity, engine.Component_Transform {
                    position = { f32(asset_info.texture.width) / 4, f32(asset_info.texture.height) / 4 },
                    scale = { 1, 1 },
                })
                engine.entity_set_component(entity, engine.Component_Sprite {
                    texture_asset = _game.asset_image_battle_bg,
                    texture_size = { asset_info.texture.width, asset_info.texture.height },
                    z_index = -1,
                    tint = { 1, 1, 1, 1 },
                })
                append(&_game.battle_data.entities, entity)
            }
        }

        {
            cursor_asset := &_engine.assets.assets[_game.asset_image_debug]
            asset_info, asset_ok := cursor_asset.info.(engine.Asset_Info_Image)
            entity := engine.entity_create_entity("Cursor: move")
            engine.entity_set_component(entity, engine.Component_Transform {
                position = grid_to_world_position_center(OFFSCREEN_POSITION),
                scale = { 1, 1 },
            })
            engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _game.asset_image_debug,
                texture_size = GRID_SIZE_V2,
                texture_position = grid_position(1, 12),
                texture_padding = 1,
                z_index = 9,
                tint = { 0, 0, 1, 1 },
            })
            append(&_game.battle_data.entities, entity)
            _game.battle_data.cursor_move_entity = entity
        }

        {
            cursor_asset := &_engine.assets.assets[_game.asset_image_debug]
            asset_info, asset_ok := cursor_asset.info.(engine.Asset_Info_Image)
            entity := engine.entity_create_entity("Cursor: target")
            engine.entity_set_component(entity, engine.Component_Transform {
                position = grid_to_world_position_center(OFFSCREEN_POSITION),
                scale = { 1, 1 },
            })
            engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _game.asset_image_debug,
                texture_size = GRID_SIZE_V2,
                texture_position = grid_position(1, 12),
                texture_padding = 1,
                z_index = 10,
                tint = { 0, 1, 0, 1 },
            })
            append(&_game.battle_data.entities, entity)
            _game.battle_data.cursor_target_entity = entity
        }

        {
            cursor_asset := &_engine.assets.assets[_game.asset_image_debug]
            asset_info, asset_ok := cursor_asset.info.(engine.Asset_Info_Image)
            entity := engine.entity_create_entity("Cursor: unit")
            component_transform, _ := engine.entity_set_component(entity, engine.Component_Transform {
                position = grid_to_world_position_center(OFFSCREEN_POSITION),
                scale = { 1, 1 },
            })
            engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _game.asset_image_debug,
                texture_size = GRID_SIZE_V2,
                texture_position = grid_position(6, 6),
                texture_padding = 1,
                z_index = 11,
                tint = { 1, 1, 1, 1 },
            })
            append(&_game.battle_data.entities, entity)
            _game.battle_data.cursor_unit_entity = entity
        }

        {
            unit_preview_asset := &_engine.assets.assets[_game.asset_image_debug]
            asset_info, asset_ok := unit_preview_asset.info.(engine.Asset_Info_Image)
            entity := engine.entity_create_entity("Unit preview")
            engine.entity_set_component(entity, engine.Component_Transform {
                position = grid_to_world_position_center(OFFSCREEN_POSITION),
                scale = { 1, 1 },
            })
            engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _game.asset_image_debug,
                texture_size = GRID_SIZE_V2,
                texture_position = grid_position(3, 12),
                texture_padding = 1,
                z_index = 1,
                tint = { 1, 1, 1, 0.5 },
            })
            append(&_game.battle_data.entities, entity)
            _game.battle_data.unit_preview_entity = entity
        }

        {
            areas_asset := &_engine.assets.assets[_game.asset_map_areas]
            asset_info, asset_ok := areas_asset.info.(engine.Asset_Info_Map)
            level_index : int = 0
            for level, i in asset_info.ldtk.levels {
                if level.identifier == BATTLE_LEVELS[_game.battle_index - 1] {
                    level_index = i
                    break
                }
            }
            _game.tileset_assets = load_level_assets(asset_info, _engine.assets)
            _game.battle_data.level = make_level(asset_info.ldtk, level_index, _game.tileset_assets, &_game.battle_data.entities, _game.allocator)
        }

        spawners_ally := [dynamic]Entity {}
        spawners_foe := [dynamic]Entity {}
        for entity in _game.battle_data.entities {
            component_meta, err_meta := engine.entity_get_component(entity, engine.Component_Tile_Meta)
            if err_meta != .None {
                continue
            }

            component_transform, _ := engine.entity_get_component(entity, engine.Component_Transform)
            ldtk_entity := _game.ldtk_entity_defs[component_meta.entity_uid]
            if ldtk_entity.identifier == "Spawner_Ally" {
                append(&spawners_ally, entity)
            }
            if ldtk_entity.identifier == "Spawner_Foe" {
                append(&spawners_foe, entity)
            }
        }

        spawn_units(spawners_ally, _game.party, Directions.Right, .Ally)
        spawn_units(spawners_foe, _game.foes, Directions.Left, .Foe)

        for unit_index in _game.battle_data.units {
            unit := &_game.units[unit_index]
            unit.stat_ctr = 0
            unit.stat_health = unit.stat_health_max
        }

        log.debugf("Battle:           %v", BATTLE_LEVELS[_game.battle_index - 1])
    }

    if game_mode_running() {
        current_unit := &_game.units[_game.battle_data.current_unit]
        unit_transform, _ := engine.entity_get_component(current_unit.entity, engine.Component_Transform)
        unit_rendering, _ := engine.entity_get_component(current_unit.entity, engine.Component_Sprite)
        cursor_move := _game.battle_data.cursor_move_entity
        cursor_unit := _game.battle_data.cursor_unit_entity
        cursor_unit_transform, _ := engine.entity_get_component(cursor_unit, engine.Component_Transform)
        cursor_target := _game.battle_data.cursor_target_entity
        unit_preview := _game.battle_data.unit_preview_entity
        unit_preview_rendering, _ := engine.entity_get_component(unit_preview, engine.Component_Sprite)

        engine.platform_process_repeater(&_game.battle_data.move_repeater, _game.player_inputs.move)
        engine.platform_process_repeater(&_game.battle_data.aim_repeater, _game.player_inputs.aim)

        {
            defer battle_mode_check_exit()
            battle_mode: switch Battle_Mode(_game.battle_data.mode.current) {
                case .Ticking: {
                    engine.profiler_zone(".Ticking")
                    if battle_mode_running() {
                        for time.diff(_game.battle_data.next_tick, time.now()) >= 0 {
                            for unit_index in _game.battle_data.units {
                                unit := &_game.units[unit_index]
                                unit.stat_ctr += unit.stat_speed
                            }

                            sorted_units := slice.clone(_game.battle_data.units[:], context.temp_allocator)
                            sort.heap_sort_proc(sorted_units, sort_units_by_ctr)

                            for unit_index in sorted_units {
                                unit := &_game.units[unit_index]
                                if unit_can_take_turn(unit) {
                                    _game.battle_data.current_unit = unit_index
                                    current_unit = &_game.units[_game.battle_data.current_unit]
                                    battle_mode_transition(.Start_Turn)
                                    break battle_mode
                                }
                            }

                            _game.battle_data.next_tick = { time.now()._nsec + TICK_DURATION }
                        }
                    }
                }

                case .Start_Turn: {
                    engine.profiler_zone(".Start_Turn")
                    if battle_mode_entering() {
                        reset_turn(&_game.battle_data.turn)
                        battle_mode_transition(.Select_Action)
                    }
                }

                case .Select_Action: {
                    engine.profiler_zone(".Select_Action")
                    if battle_mode_entering() {
                        _game.battle_data.turn.move = OFFSCREEN_POSITION
                        _game.battle_data.turn.target = OFFSCREEN_POSITION
                        entity_move_grid(cursor_move, OFFSCREEN_POSITION)
                        entity_move_grid(cursor_target, OFFSCREEN_POSITION)
                        entity_move_grid(cursor_unit, current_unit.grid_position + { 0, -1 })
                        _game.battle_data.turn.cursor_unit_animation = engine.animation_create_animation(1.5)
                        _game.battle_data.turn.cursor_unit_animation.loop = true
                        _game.battle_data.turn.cursor_unit_animation.active = true
                        engine.animation_add_curve(_game.battle_data.turn.cursor_unit_animation, engine.Animation_Curve_Position {
                            target = &cursor_unit_transform.position,
                            timestamps = { 0, 0.5, 1 },
                            frames = { cursor_unit_transform.position, cursor_unit_transform.position + { 0, -0.75 }, cursor_unit_transform.position },
                        })

                        update_grid_flags(&_game.battle_data.level)
                        if unit_can_take_turn(current_unit) == false || _game.battle_data.turn.moved && _game.battle_data.turn.acted {
                            battle_mode_transition(.End_Turn)
                        }

                        if win_condition_reached() {
                            battle_mode_transition(.Victory)
                        }
                        if lose_condition_reached() {
                            battle_mode_transition(.Defeat)
                        }
                    }

                    if battle_mode_running() {
                        if current_unit.controlled_by == .CPU {
                            cpu_plan_turn(current_unit)
                        } else {
                            action := Battle_Action.None

                            if _game.player_inputs.cancel.released {
                                action = .Wait
                            }

                            if action == .None {
                                if game_ui_window(fmt.tprintf("%v's turn", current_unit.name), nil, .NoResize | .NoMove | .NoCollapse) {
                                    engine.ui_set_window_size_vec2({ 300, 200 }, .Always)
                                    engine.ui_set_window_pos_vec2({ f32(_engine.platform.window_size.x - 300) / 2, f32(_engine.platform.window_size.y - 150) / 2 }, .Always)

                                    health_progress := f32(current_unit.stat_health) / f32(current_unit.stat_health_max)
                                    engine.ui_progress_bar(health_progress, { -1, 20 }, fmt.tprintf("HP: %v/%v", current_unit.stat_health, current_unit.stat_health_max))

                                    if game_ui_button("Move", _game.battle_data.turn.moved) {
                                        action = .Move
                                    }
                                    if game_ui_button("Throw", _game.battle_data.turn.acted) {
                                        action = .Throw
                                    }
                                    if game_ui_button("Wait") {
                                        action = .Wait
                                    }
                                }
                            }

                            switch action {
                                case .Move: {
                                    _game.battle_data.turn.target = OFFSCREEN_POSITION
                                    _game.battle_data.turn.move = current_unit.grid_position
                                    _game.highlighted_cells = create_cell_highlight(.Move, is_valid_move_destination_and_in_range)
                                    battle_mode_transition(.Target_Move)
                                }
                                case .Throw: {
                                    _game.battle_data.turn.ability = 1
                                    _game.battle_data.turn.target = current_unit.grid_position
                                    _game.battle_data.turn.move = OFFSCREEN_POSITION
                                    _game.highlighted_cells = create_cell_highlight(.Ability, is_valid_ability_destination)
                                    battle_mode_transition(.Target_Ability)
                                }
                                case .Wait: {
                                    battle_mode_transition(.End_Turn)
                                }
                                case .None: {

                                }
                            }
                        }
                    }

                    if battle_mode_exiting() {
                        if _game.battle_data.turn.cursor_unit_animation != nil {
                            engine.animation_delete_animation(_game.battle_data.turn.cursor_unit_animation)
                        }
                        entity_move_grid(cursor_move, OFFSCREEN_POSITION)
                        entity_move_grid(cursor_unit, OFFSCREEN_POSITION)
                        entity_move_grid(cursor_target, OFFSCREEN_POSITION)
                    }
                }

                case .Target_Move: {
                    engine.profiler_zone(".Target_Move")
                    if battle_mode_running() {
                        entity_move_grid(cursor_move, _game.battle_data.turn.move)

                        if _game.player_inputs.cancel.released {
                            engine.audio_play_sound(_game.asset_sound_cancel)
                            clear(&_game.highlighted_cells)
                            battle_mode_transition(.Select_Action)
                        }

                        if _engine.platform.mouse_moved {
                            _game.battle_data.turn.move = _game.mouse_grid_position
                        }
                        if engine.vector_not_equal(_game.battle_data.aim_repeater.value, 0) {
                            _game.battle_data.turn.move = _game.battle_data.turn.move + _game.battle_data.aim_repeater.value
                        }
                        if engine.vector_not_equal(_game.battle_data.move_repeater.value, 0) {
                            _game.battle_data.turn.move = _game.battle_data.turn.move + _game.battle_data.move_repeater.value
                        }

                        if _game.player_inputs.confirm.released || _game.player_inputs.mouse_left.released {
                            path, path_ok := find_path(_game.battle_data.level.grid, _game.battle_data.level.size, current_unit.grid_position, _game.battle_data.turn.move)
                            if path_ok {
                                _game.battle_data.turn.move_path = path
                                engine.audio_play_sound(_game.asset_sound_confirm)
                                clear(&_game.highlighted_cells)
                                battle_mode_transition(.Execute_Move)
                            } else {
                                engine.audio_play_sound(_game.asset_sound_invalid)
                                log.warnf("       Invalid target!")
                            }
                        }
                    }
                }

                case .Execute_Move: {
                    engine.profiler_zone(".Execute_Move")
                    if battle_mode_entering() {
                        direction := current_unit.direction
                        path := _game.battle_data.turn.move_path
                        for point, i in path {
                            if i < len(path) - 1 {
                                new_direction := direction
                                if point.x != path[i+1].x {
                                    new_direction = get_direction_from_points(point.x, path[i+1].x)
                                }

                                if direction != new_direction {
                                    animation := create_unit_flip_animation(current_unit, new_direction)
                                    queue.push_back(_game.battle_data.turn.animations, animation)
                                    direction = new_direction
                                }

                                animation := create_unit_move_animation(current_unit, new_direction, point, path[i+1])
                                queue.push_back(_game.battle_data.turn.animations, animation)
                            }
                        }

                        current_unit.grid_position = _game.battle_data.turn.move
                        current_unit.direction = direction
                        _game.battle_data.turn.moved = true
                    }

                    if battle_mode_running() {
                        if engine.animation_queue_is_done(_game.battle_data.turn.animations) {
                            battle_mode_transition(.Select_Action)
                        }
                    }
                }

                case .Target_Ability: {
                    engine.profiler_zone(".Target_Ability")
                    if battle_mode_entering() {
                        entity_move_grid(cursor_move, OFFSCREEN_POSITION)
                    }

                    if battle_mode_running() {
                        entity_move_grid(cursor_target, _game.battle_data.turn.target)

                        if _game.player_inputs.cancel.released {
                            engine.audio_play_sound(_game.asset_sound_cancel)
                            clear(&_game.highlighted_cells)
                            battle_mode_transition(.Select_Action)
                        }

                        if _engine.platform.mouse_moved {
                            _game.battle_data.turn.target = _game.mouse_grid_position
                        }
                        if engine.vector_not_equal(_game.battle_data.aim_repeater.value, 0) {
                            _game.battle_data.turn.target = _game.battle_data.turn.target + _game.battle_data.aim_repeater.value
                        }
                        if engine.vector_not_equal(_game.battle_data.move_repeater.value, 0) {
                            _game.battle_data.turn.target = _game.battle_data.turn.target + _game.battle_data.move_repeater.value
                        }

                        if _game.player_inputs.confirm.released || _game.player_inputs.mouse_left.released {
                            grid_index := int(engine.grid_position_to_index(_game.battle_data.turn.target, _game.battle_data.level.size.x))
                            is_valid_target := slice.contains(_game.highlighted_cells[:], Cell_Highlight { grid_index, .Ability })
                            if is_valid_target || _game.cheat_act_anywhere {
                                engine.audio_play_sound(_game.asset_sound_confirm)
                                clear(&_game.highlighted_cells)
                                battle_mode_transition(.Execute_Ability)
                            } else {
                                engine.audio_play_sound(_game.asset_sound_invalid)
                                log.warnf("       Invalid target!")
                            }
                        }
                    }
                }

                case .Execute_Ability: {
                    engine.profiler_zone(".Execute_Ability")
                    if battle_mode_entering() {
                        entity_move_grid(cursor_target, OFFSCREEN_POSITION)

                        direction := get_direction_from_points(current_unit.grid_position, _game.battle_data.turn.target)
                        if current_unit.direction != direction {
                            animation := create_unit_flip_animation(current_unit, direction)
                            queue.push_back(_game.battle_data.turn.animations, animation)
                            current_unit.direction = direction
                        }
                        _game.battle_data.turn.projectile = engine.entity_create_entity("Projectile")
                        engine.entity_set_component(_game.battle_data.turn.projectile, engine.Component_Transform {
                            position = grid_to_world_position_center(current_unit.grid_position),
                        })
                        engine.entity_set_component(_game.battle_data.turn.projectile, engine.Component_Sprite {
                            texture_asset = _game.asset_image_spritesheet,
                            texture_size = GRID_SIZE_V2,
                            texture_position = GRID_SIZE_V2 * { 0, 7 },
                            texture_padding = 1,
                            z_index = 3,
                            tint = { 1, 1, 1, 1 },
                        })
                        {
                            animation := create_unit_throw_animation(current_unit, _game.battle_data.turn.target, _game.battle_data.turn.projectile)
                            queue.push_back(_game.battle_data.turn.animations, animation)
                        }

                        target_unit := find_unit_at_position(_game.battle_data.turn.target)
                        if target_unit != nil {
                            damage_taken := ability_apply_damage(_game.battle_data.turn.ability, current_unit, target_unit)
                            if target_unit.stat_health == 0 {
                                animation := create_unit_death_animation(target_unit, direction)
                                queue.push_back(_game.battle_data.turn.animations, animation)
                            } else {
                                animation := create_unit_hit_animation(target_unit, direction)
                                queue.push_back(_game.battle_data.turn.animations, animation)
                            }
                        }
                        _game.battle_data.turn.acted = true
                    }

                    if battle_mode_running() {
                        if engine.animation_queue_is_done(_game.battle_data.turn.animations) {
                            battle_mode_transition(.Select_Action)
                        }
                    }

                    if battle_mode_exiting() {
                        engine.entity_delete_entity(_game.battle_data.turn.projectile)
                        _game.battle_data.turn.projectile = engine.ENTITY_INVALID
                    }
                }

                case .End_Turn: {
                    engine.profiler_zone(".End_Turn")
                    if battle_mode_entering() {
                        turn_cost := TURN_COST
                        if _game.battle_data.turn.moved {
                            turn_cost += MOVE_COST
                        }
                        if _game.battle_data.turn.acted {
                            turn_cost += ACT_COST
                        }
                        current_unit.stat_ctr -= turn_cost

                        clear(&_game.highlighted_cells)
                        free_all(_game.battle_data.turn_allocator)
                        battle_mode_transition(.Ticking)
                    }
                }

                case .Victory: {
                    engine.profiler_zone(".Victory")
                    if battle_mode_entering() {
                        log.warnf("Victory")
                        game_mode_transition(.Debug)
                    }
                }

                case .Defeat: {
                    engine.profiler_zone(".Defeat")
                    if battle_mode_entering() {
                        log.warnf("Game over")
                        game_mode_transition(.Debug)
                    }
                }
            }
        }

        unit_preview_rendering.texture_position = unit_rendering.texture_position

        game_ui_window_battle(&_game.debug_ui_window_battle)
    }

    if game_mode_exiting() {
        log.debugf("Battle exit | entities: %v", len(_game.battle_data.entities))
        for entity in _game.battle_data.entities {
            engine.entity_delete_entity(entity)
        }
        if _game.battle_data.turn.projectile != engine.ENTITY_INVALID {
            engine.entity_delete_entity(_game.battle_data.turn.projectile)
        }
        engine.asset_unload(_game.asset_image_battle_bg)
        engine.asset_unload(_game.asset_map_areas)
    }
}

spawn_units :: proc(spawners: [dynamic]Entity, units: [dynamic]int, direction: Directions, alliance: Unit_Alliances) {
    for spawner, i in spawners {
        if i >= len(units) {
            break
        }

        unit := &_game.units[units[i]]
        component_transform, _ := engine.entity_get_component(spawner, engine.Component_Transform)
        unit.grid_position = world_to_grid_position(component_transform.position)
        unit.direction = direction
        unit.alliance = alliance

        entity := unit_create_entity(unit)
        append(&_game.battle_data.units, units[i])

        unit.entity = entity
    }
}

sort_units_by_ctr :: proc(a, b: int) -> int {
    return int(_game.units[a].stat_ctr - _game.units[b].stat_ctr)
}

create_cell_highlight :: proc(type: Cell_Highlight_Type, search_filter_proc: Search_Filter_Proc, allocator := context.allocator) -> [dynamic]Cell_Highlight {
    context.allocator = allocator
    result := [dynamic]Cell_Highlight {}
    search_result := grid_search(_game.battle_data.level.size, _game.battle_data.level.grid, search_filter_proc)
    for grid_index in search_result {
        append(&result, Cell_Highlight { grid_index, type })
    }
    return result
}

Search_Filter_Proc :: #type proc(grid_index: int, grid_size: Vector2i32, grid: []Grid_Cell) -> bool

grid_search :: proc(grid_size: Vector2i32, grid: []Grid_Cell, search_filter_proc: Search_Filter_Proc) -> [dynamic]int {
    result := [dynamic]int {}

    for grid_value, grid_index in grid {
        if search_filter_proc(grid_index, grid_size, grid) {
            append(&result, grid_index)
        }
    }

    return result
}

// TODO: Check range and path finding
is_valid_move_destination_and_in_range : Search_Filter_Proc : proc(grid_index: int, grid_size: Vector2i32, grid: []Grid_Cell) -> bool {
    cell := grid[grid_index]
    position := engine.grid_index_to_position(grid_index, grid_size.x)

    unit := _game.units[_game.battle_data.current_unit]
    unit_transform, _ := engine.entity_get_component(unit.entity, engine.Component_Transform)
    if engine.manhathan_distance(unit.grid_position, position) > unit.stat_move {
        return false
    }

    return is_valid_move_destination(cell)
}

is_valid_move_destination :: proc(cell: Grid_Cell) -> bool { return cell >= { .Move, .Grounded } }

// TODO: Check range and FOV
is_valid_ability_destination : Search_Filter_Proc : proc(grid_index: int, grid_size: Vector2i32, grid: []Grid_Cell) -> bool {
    grid_value := grid[grid_index]
    position := engine.grid_index_to_position(grid_index, grid_size.x)

    unit := _game.units[_game.battle_data.current_unit]
    unit_transform, _ := engine.entity_get_component(unit.entity, engine.Component_Transform)
    MAX_RANGE :: 10
    if engine.manhathan_distance(unit.grid_position, position) > MAX_RANGE {
        return false
    }

    return grid_value >= { .Move }
}

create_unit_throw_animation :: proc(unit: ^Unit, target: Vector2i32, projectile: Entity) -> ^engine.Animation {
    aim_direction := Vector2f32(linalg.vector_normalize(array_cast(target, f32) - array_cast(unit.grid_position, f32)))

    animation := engine.animation_create_animation(2)
    component_limbs, has_limbs := engine.entity_get_component(unit.entity, Component_Limbs)
    {
        component_transform, _ := engine.entity_get_component(component_limbs.hand_left, engine.Component_Transform)
        engine.animation_add_curve(animation, engine.Animation_Curve_Position {
            target = &component_transform.position,
            timestamps = {
                0.00,
                0.10,
                0.50,
                1.00,
            },
            frames = {
                component_transform.position,
                component_transform.position + aim_direction * -2,
                component_transform.position + aim_direction * +2,
                component_transform.position,
            },
        })
    }
    {
        component_transform, _ := engine.entity_get_component(component_limbs.hand_right, engine.Component_Transform)
        engine.animation_add_curve(animation, engine.Animation_Curve_Position {
            target = &component_transform.position,
            timestamps = {
                0.00,
                0.10,
                0.50,
                1.00,
            },
            frames = {
                component_transform.position,
                component_transform.position + aim_direction * 0.5,
                component_transform.position + aim_direction * 0.5,
                component_transform.position,
            },
        })
    }
    {
        component_transform, err_transform := engine.entity_get_component(projectile, engine.Component_Transform)
        engine.animation_add_curve(animation, engine.Animation_Curve_Scale {
            target = &component_transform.scale,
            timestamps = { 0.0, 0.55, 0.7, 0.95, 1.0 },
            frames = { { 0, 0 }, { 0, 0 }, { 1, 1 }, { 1, 1 }, { 0, 0 } },
        })
        engine.animation_add_curve(animation, engine.Animation_Curve_Position {
            target = &component_transform.position,
            timestamps = { 0.0, 0.6, 1.0 },
            frames = { component_transform.position, component_transform.position, grid_to_world_position_center(target) },
        })
    }
    return animation
}

create_unit_flip_animation :: proc(unit: ^Unit, direction: Directions) -> ^engine.Animation {
    animation := engine.animation_create_animation(3)
    component_transform, err_transform := engine.entity_get_component(unit.entity, engine.Component_Transform)
    engine.animation_add_curve(animation, engine.Animation_Curve_Scale {
        target = &component_transform.scale,
        timestamps = { 0.0, 1.0 },
        frames = { { -f32(direction), 1 }, { f32(direction), 1 } },
    })
    return animation
}

create_unit_hit_animation :: proc(unit: ^Unit, direction: Directions) -> ^engine.Animation {
    animation := engine.animation_create_animation(5)
    component_transform, err_transform := engine.entity_get_component(unit.entity, engine.Component_Transform)
    engine.animation_add_curve(animation, engine.Animation_Curve_Scale {
        target = &component_transform.scale,
        timestamps = { 0.0, 0.5, 1.0 },
        frames = { { 1 * f32(unit.direction), 1 }, { 0.8 * f32(unit.direction), 1.2 }, { 1 * f32(unit.direction), 1 } },
    })
    engine.animation_add_curve(animation, engine.Animation_Curve_Event {
        timestamps = { 0.0 },
        frames = { { procedure = hit_event } },
    })

    hit_event :: proc() {
        engine.audio_play_sound(_game.asset_sound_hit)
    }
    return animation
}

create_unit_death_animation :: proc(unit: ^Unit, direction: Directions) -> ^engine.Animation {
    animation := engine.animation_create_animation(5)
    component_transform, err_transform := engine.entity_get_component(unit.entity, engine.Component_Transform)
    engine.animation_add_curve(animation, engine.Animation_Curve_Scale {
        target = &component_transform.scale,
        timestamps = { 0.0, 1.0 },
        frames = { component_transform.scale, { 0, 0 } },
    })
    engine.animation_add_curve(animation, engine.Animation_Curve_Event {
        timestamps = { 0.0 },
        frames = { { procedure = hit_event } },
    })

    hit_event :: proc() {
        engine.audio_play_sound(_game.asset_sound_hit)
    }
    return animation
}

create_unit_move_animation :: proc(unit: ^Unit, direction: Directions, start_position, end_position: Vector2i32) -> ^engine.Animation {
    context.allocator = _game.battle_data.turn_allocator
    s := grid_to_world_position_center(start_position)
    e := grid_to_world_position_center(end_position)
    animation := engine.animation_create_animation(3)
    component_transform, _ := engine.entity_get_component(unit.entity, engine.Component_Transform)
    engine.animation_add_curve(animation, engine.Animation_Curve_Position {
        target = &(component_transform.position),
        timestamps = { 0.0, 1.0 },
        frames = {
            grid_to_world_position_center(start_position),
            grid_to_world_position_center(end_position),
        },
    })
    engine.animation_add_curve(animation, engine.Animation_Curve_Scale {
        target = &component_transform.scale,
        timestamps = {
            0.00,
            0.25,
            0.50,
            0.75,
            1.00,
        },
        frames = {
            { f32(direction) * 1.0, 1.0 },
            { f32(direction) * 0.9, 1.1 },
            { f32(direction) * 1.0, 1.0 },
            { f32(direction) * 0.9, 1.1 },
            { f32(direction) * 1.0, 1.0 },
        },
    })

    component_limbs, err_limbs := engine.entity_get_component(unit.entity, Component_Limbs)
    compnent_hand_left_component_transform, _ := engine.entity_get_component(component_limbs.hand_left, engine.Component_Transform)
    engine.animation_add_curve(animation, engine.Animation_Curve_Position {
        target = &compnent_hand_left_component_transform.position,
        timestamps = {
            0.00,
            0.25,
            0.50,
            0.75,
            1.00,
        },
        frames = {
            { 0.0, 0.0 },
            { 1.0, 1.0 },
            { 0.0, 0.0 },
            { -1.0, -1.0 },
            { 0.0, 0.0 },
        },
    })
    compnent_hand_right_component_transform, _ := engine.entity_get_component(component_limbs.hand_right, engine.Component_Transform)
    engine.animation_add_curve(animation, engine.Animation_Curve_Position {
        target = &compnent_hand_right_component_transform.position,
        timestamps = {
            0.00,
            0.25,
            0.50,
            0.75,
            1.00,
        },
        frames = {
            { 0.0, 0.0 },
            { -1.0, -1.0 },
            { 0.0, 0.0 },
            { 1.0, 1.0 },
            { 0.0, 0.0 },
        },
    })

    return animation
}

get_direction_from_points :: proc(a, b: Vector2i32) -> Directions {
    return (a.x - b.x) > 0 ? .Left : .Right
}

find_unit_at_position :: proc(position: Vector2i32) -> ^Unit {
    for unit_index in _game.battle_data.units {
        unit := &_game.units[unit_index]
        if unit.grid_position == position {
            return unit
        }
    }
    return nil
}

reset_turn :: proc(turn: ^Turn) {
    turn^ = {}
    turn.move = OFFSCREEN_POSITION
    turn.target = OFFSCREEN_POSITION
    animation_ok: bool
    turn.animations, animation_ok = engine.animation_make_queue()
    assert(animation_ok)
    assert(turn.animations != nil)
}

unit_move :: proc(unit: ^Unit, grid_position: Vector2i32) {
    component_transform, _ := engine.entity_get_component(unit.entity, engine.Component_Transform)
    component_transform.position = grid_to_world_position_center(grid_position, GRID_SIZE)
}

unit_create_entity :: proc(unit: ^Unit) -> Entity {
    SPRITE_SIZE :: Vector2i32 { 8, 8 }
    palette : i32 = 1
    if unit.alliance == .Foe {
        palette = 2
    }

    entity := engine.entity_create_entity(unit.name)

    hand_left := engine.entity_create_entity(fmt.tprintf("%s: Hand (left)", unit.name))
    hand_left_transform, _ := engine.entity_set_component(hand_left, engine.Component_Transform {
        scale = { 1, 1 },
        parent = entity,
    })
    engine.entity_set_component(hand_left, engine.Component_Sprite {
        texture_asset = _game.asset_image_units,
        texture_size = SPRITE_SIZE,
        texture_position = GRID_SIZE_V2 * { 5, 1 },
        texture_padding = 1,
        z_index = 3,
        tint = { 1, 1, 1, 1 },
        palette = palette,
    })

    hand_right := engine.entity_create_entity(fmt.tprintf("%s: Hand (right)", unit.name))
    hand_right_transform, _ := engine.entity_set_component(hand_right, engine.Component_Transform {
        scale = { 1, 1 },
        parent = entity,
    })
    engine.entity_set_component(hand_right, engine.Component_Sprite {
        texture_asset = _game.asset_image_units,
        texture_size = SPRITE_SIZE,
        texture_position = GRID_SIZE_V2 * { 6, 1 },
        texture_padding = 1,
        z_index = 1,
        tint = { 1, 1, 1, 1 },
        palette = palette,
    })

    entity_transform, _ := engine.entity_set_component(entity, engine.Component_Transform {
        scale = { f32(unit.direction), 1 },
        position = grid_to_world_position_center(unit.grid_position),
    })
    entity_rendering, _ := engine.entity_set_component(entity, engine.Component_Sprite {
        texture_asset = _game.asset_image_units,
        texture_size = SPRITE_SIZE,
        texture_position = unit.sprite_position * GRID_SIZE_V2,
        texture_padding = 1,
        z_index = 2,
        tint = { 1, 1, 1, 1 },
        palette = palette,
    })
    engine.entity_set_component(entity, Component_Flag { { .Unit } })
    engine.entity_set_component(entity, Component_Limbs { hand_left = hand_left, hand_right = hand_right })

    append(&_game.battle_data.entities, entity)
    append(&_game.battle_data.entities, hand_left)
    append(&_game.battle_data.entities, hand_right)

    return entity
}

entity_move_grid :: proc(entity: Entity, grid_position: Vector2i32) {
    component_transform, _ := engine.entity_get_component(entity, engine.Component_Transform)
    component_transform.position = grid_to_world_position_center(grid_position)
}

unit_can_take_turn :: proc(unit: ^Unit) -> bool {
    if unit == nil { return false }
    return unit.stat_ctr >= TAKE_TURN && unit_is_alive(unit)
}

unit_is_alive :: proc(unit: ^Unit) -> bool {
    if unit == nil { return false }
    return unit.stat_health > 0
}

ability_is_valid_target :: proc(ability: Ability, actor, target: ^Unit) -> bool {
    return unit_is_alive(target) && target != actor && target.alliance != actor.alliance
}

ability_apply_damage :: proc(ability: Ability, actor, target: ^Unit) -> (damage_taken: i32) {
    damage_taken = 99
    target.stat_health = math.max(target.stat_health - damage_taken, 0)
    return damage_taken
}

win_condition_reached :: proc() -> bool {
    units_count := 0
    for unit_index in _game.battle_data.units {
        unit := &_game.units[unit_index]
        if unit.alliance == .Foe && unit_is_alive(unit) {
            units_count += 1
        }
    }
    return units_count == 0
}
lose_condition_reached :: proc() -> bool {
    units_count := 0
    for unit_index in _game.battle_data.units {
        unit := &_game.units[unit_index]
        if unit.alliance == .Ally && unit_is_alive(unit) {
            units_count += 1
        }
    }
    return units_count == 0
}

game_ui_window_battle :: proc(open: ^bool) {
    if open^ == false {
        return
    }

    if engine.ui_window("Debug: Battle", nil) {
        engine.ui_set_window_pos_vec2({ 100, 300 }, .FirstUseEver)
        engine.ui_set_window_size_vec2({ 800, 300 }, .FirstUseEver)

        region := engine.ui_get_content_region_avail()

        if engine.ui_child("left", { region.x * 0.25, region.y }, false) {
            engine.ui_text("Battle index: %v", _game.battle_index)
            if engine.ui_button("World map") {
                _game.battle_index = 0
                game_mode_transition(.WorldMap)
            }
            if engine.ui_button("Victory") {
                battle_mode_transition(.Victory)
            }
            engine.ui_same_line()
            if engine.ui_button("Defeat") {
                battle_mode_transition(.Defeat)
            }

            engine.ui_text("mode:               %v", Battle_Mode(_game.battle_data.mode.current))
            engine.ui_text("current_unit:       %v", _game.units[_game.battle_data.current_unit].name)
            if engine.ui_tree_node("Mouse cursor") {
                engine.ui_text("mouse_grid_pos:     %v", _game.mouse_grid_position)
                mouse_cell, mouse_cell_found := get_cell_at_position(&_game.battle_data.level, _game.mouse_grid_position)
                if mouse_cell_found {
                    engine.ui_text("  - Climb:    %v", .Climb in mouse_cell ? "x" : "")
                    engine.ui_text("  - Fall:     %v", .Fall in mouse_cell ? "x" : "")
                    engine.ui_text("  - Move:     %v", .Move in mouse_cell ? "x" : "")
                    engine.ui_text("  - Grounded: %v", .Grounded in mouse_cell ? "x" : "")
                }
            }
            if engine.ui_tree_node("Turn") {
                engine.ui_text("  move:    %v", _game.battle_data.turn.move)
                engine.ui_text("  target:  %v", _game.battle_data.turn.target)
                engine.ui_text("  ability: %v", _game.battle_data.turn.ability)
            }
        }

        engine.ui_same_line()
        if engine.ui_child("middle", { region.x * 0.5, region.y }, false, {}) {
            columns := []string { "index", "name", "pos", "ctr", "hp", "actions" }
            if engine.ui_table(columns) {
                for i := 0; i < len(_game.units); i += 1 {
                    engine.ui_table_next_row()
                    unit := &_game.units[i]
                    for column, column_index in columns {
                        engine.ui_table_set_column_index(i32(column_index))
                        switch column {
                            case "index": engine.ui_text("%v", i)
                            case "name": {
                                if unit.alliance == .Foe { engine.ui_push_style_color(.Text, { 1, 0.2, 0.2, 1 }) }
                                engine.ui_text("%v (%v)", unit.name, unit.alliance)
                                if unit.alliance == .Foe { engine.ui_pop_style_color(1) }
                            }
                            case "pos": engine.ui_text("%v", unit.grid_position)
                            case "ctr": {
                                progress := f32(unit.stat_ctr) / 100
                                engine.ui_progress_bar(progress, { -1, 20 }, fmt.tprintf("CTR %v", unit.stat_ctr))
                            }
                            case "hp": {
                                progress := f32(unit.stat_health) / f32(unit.stat_health_max)
                                engine.ui_progress_bar(progress, { -1, 20 }, fmt.tprintf("HP %v/%v", unit.stat_health, unit.stat_health_max))
                            }
                            case "actions": {
                                engine.ui_push_id(i32(i))
                                if engine.ui_button_disabled("Player", unit.controlled_by == .Player) {
                                    unit.controlled_by = .Player
                                }
                                engine.ui_same_line()
                                if engine.ui_button_disabled("CPU", unit.controlled_by == .CPU) {
                                    unit.controlled_by = .CPU
                                }
                                engine.ui_same_line()
                                if engine.ui_button("Set active") {
                                    _game.battle_data.current_unit = i
                                }
                                engine.ui_pop_id()
                            }
                            case: engine.ui_text("x")
                        }
                    }
                }
            }
        }

        engine.ui_same_line()
        if engine.ui_child("right", { region.x * 0.25, region.y }, false) {
            unit := &_game.units[_game.battle_data.current_unit]
            engine.ui_text("name:          %v", unit.name)
            engine.ui_text("grid_position: %v", unit.grid_position)
            engine.ui_text("direction:     %v", unit.direction)
            engine.ui_text("controlled_by: %v", unit.controlled_by)
            engine.ui_push_item_width(100)
            engine.ui_input_int("stat_speed", &unit.stat_speed)
            engine.ui_input_int("stat_move", &unit.stat_move)
            {
                progress := f32(unit.stat_ctr) / 100
                engine.ui_progress_bar(progress, { 100, 20 }, fmt.tprintf("CTR %v", unit.stat_ctr))
            }
            {
                progress := f32(unit.stat_health) / f32(unit.stat_health_max)
                engine.ui_progress_bar(progress, { 100, 20 }, fmt.tprintf("HP %v/%v", unit.stat_health, unit.stat_health_max))
            }
        }
    }
}

// FIXME: Don't do this on the main thread or at least don't block while doing it, because this can be slow later down the line
cpu_plan_turn :: proc(current_unit: ^Unit) {
    engine.profiler_zone("cpu_plan_turn")

    if _game.battle_data.turn.moved == false {
        highlighted_cells := create_cell_highlight(.Move, is_valid_move_destination_and_in_range, context.temp_allocator)
        random_cell_index := rand.int_max(len(highlighted_cells) - 1)
        _game.battle_data.turn.move = engine.grid_index_to_position(highlighted_cells[random_cell_index].grid_index, _game.battle_data.level.size.x)
        path, path_ok := find_path(_game.battle_data.level.grid, _game.battle_data.level.size, current_unit.grid_position, _game.battle_data.turn.move)
        if path_ok {
            _game.battle_data.turn.move_path = path
            battle_mode_transition(.Execute_Move)
        }
    }
    if _game.battle_data.turn.acted == false {
        TRIES :: 20
        highlighted_cells := create_cell_highlight(.Move, is_valid_ability_destination, context.temp_allocator)
        tries: for try := 0; try < TRIES; try += 1 {
            random_cell_index := rand.int_max(len(highlighted_cells) - 1)
            target_position := engine.grid_index_to_position(highlighted_cells[random_cell_index].grid_index, _game.battle_data.level.size.x)
            target_unit := find_unit_at_position(target_position)
            if ability_is_valid_target(_game.battle_data.turn.ability, current_unit, target_unit) {
                _game.battle_data.turn.target = target_position
                break tries
            }

            if try == TRIES - 1 {
                _game.battle_data.turn.target = target_position
            }
        }

        battle_mode_transition(.Execute_Ability)
    }
    // TODO: wait if no valid action
}
