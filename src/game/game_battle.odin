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
OFFSCREEN_POSITION :: Vector2i32 { 999, 999 }

BATTLE_LEVELS := [?]string {
    "Debug_0",
    "Level_0",
    "Level_1",
}

Game_Mode_Battle :: struct {
    entities:             [dynamic]Entity,
    level:                Level,
    current_unit:         int, // Index into _mem.game.units
    units:                [dynamic]int, // Index into _mem.game.units
    mode:                 Mode,
    next_tick:            time.Time,
    cursor_move_entity:   Entity,
    cursor_target_entity: Entity,
    cursor_unit_entity:   Entity,
    unit_preview_entity:  Entity,
    move_repeater:        engine.Input_Repeater,
    aim_repeater:         engine.Input_Repeater,
    turn:                 Turn,
    turn_count:           i32,
    turn_arena:           engine.Named_Virtual_Arena,
    plan_arena:           engine.Named_Virtual_Arena,
}

Battle_Mode :: enum {
    Ticking,
    Start_Turn,
    Select_Action,
    Target_Move,
    Perform_Move,
    Target_Ability,
    Perform_Ability,
    End_Turn,
    Victory,
    Defeat,
}

Cell_Highlight_Type :: enum { Move, Ability }
Cell_Highlight :: struct {
    position:               Vector2i32,
    type:                   Cell_Highlight_Type,
}

Turn :: struct {
    moved:                  bool,
    acted:                  bool,
    projectile:             Entity,
    animations:             ^queue.Queue(^engine.Animation),
    move_target:            Vector2i32,
    move_path:              []Vector2i32,
    move_valid_targets:     [dynamic]Vector2i32,
    ability_id:             Ability_Id,
    ability_target:         Vector2i32,
    ability_path:           []Vector2i32,
    ability_valid_targets:  [dynamic]Vector2i32,
    cursor_unit_animation:  ^engine.Animation, // TODO: Find a cleaner way to keep track of small animations like that
}

Menu_Action :: enum {
    None,
    Cancel,
    Confirm,
}
Battle_Action :: enum {
    None,
    Move,
    Throw,
    Wait,
}

Ability_Id :: distinct u32

game_mode_battle :: proc () {
    if game_mode_entering() {
        context.allocator = _mem.game.game_mode.arena.allocator
        _mem.game.battle_data = new(Game_Mode_Battle)
        engine.mem_make_named_arena(&_mem.game.battle_data.mode.arena, "battle_mode", mem.Megabyte)
        engine.mem_make_named_arena(&_mem.game.battle_data.turn_arena, "battle_turn", mem.Megabyte)
        engine.mem_make_named_arena(&_mem.game.battle_data.plan_arena, "battle_plan", mem.Megabyte)

        engine.asset_load(_mem.game.asset_image_battle_bg, engine.Image_Load_Options { engine.RENDERER_FILTER_NEAREST, engine.RENDERER_CLAMP_TO_EDGE })
        engine.asset_load(_mem.game.asset_map_areas)
        engine.asset_load(_mem.game.asset_music_battle, engine.Audio_Load_Options { .Music })

        music_asset := _mem.assets.assets[_mem.game.asset_music_battle]
        if music_asset.state == .Loaded {
            music_asset_info := music_asset.info.(engine.Asset_Info_Audio)
            engine.audio_play_music(music_asset_info.clip, -1)
        }

        if engine.renderer_is_enabled() {
            _mem.renderer.world_camera.position = { NATIVE_RESOLUTION.x / 2, NATIVE_RESOLUTION.y / 2, 0 }
        }
        _mem.game.battle_data.move_repeater = { threshold = 200 * time.Millisecond, rate = 100 * time.Millisecond }
        _mem.game.battle_data.aim_repeater = { threshold = 200 * time.Millisecond, rate = 100 * time.Millisecond }
        clear(&_mem.game.highlighted_cells)

        reset_turn(&_mem.game.battle_data.turn)

        {
            background_asset := &_mem.assets.assets[_mem.game.asset_image_battle_bg]
            asset_info, asset_ok := background_asset.info.(engine.Asset_Info_Image)
            if asset_ok {
                entity := engine.entity_create_entity("Background: Battle")
                engine.entity_set_component(entity, engine.Component_Transform {
                    position = { f32(asset_info.texture.width) / 4, f32(asset_info.texture.height) / 4 },
                    scale = { 1, 1 },
                })
                engine.entity_set_component(entity, engine.Component_Sprite {
                    texture_asset = _mem.game.asset_image_battle_bg,
                    texture_size = { asset_info.texture.width, asset_info.texture.height },
                    z_index = -99,
                    tint = { 1, 1, 1, 1 },
                })
                append(&_mem.game.battle_data.entities, entity)
            }
        }

        {
            entity := engine.entity_create_entity("Cursor: move")
            engine.entity_set_component(entity, engine.Component_Transform {
                position = grid_to_world_position_center(OFFSCREEN_POSITION),
                scale = { 1, 1 },
            })
            engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_spritesheet,
                texture_size = GRID_SIZE_V2,
                texture_position = grid_position(1, 12),
                texture_padding = 1,
                z_index = 9,
                tint = { 0, 0, 1, 1 },
            })
            append(&_mem.game.battle_data.entities, entity)
            _mem.game.battle_data.cursor_move_entity = entity
        }

        {
            entity := engine.entity_create_entity("Cursor: target")
            engine.entity_set_component(entity, engine.Component_Transform {
                position = grid_to_world_position_center(OFFSCREEN_POSITION),
                scale = { 1, 1 },
            })
            engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_spritesheet,
                texture_size = GRID_SIZE_V2,
                texture_position = grid_position(1, 12),
                texture_padding = 1,
                z_index = 10,
                tint = { 0, 1, 0, 1 },
            })
            append(&_mem.game.battle_data.entities, entity)
            _mem.game.battle_data.cursor_target_entity = entity
        }

        {
            entity := engine.entity_create_entity("Cursor: unit")
            component_transform, _ := engine.entity_set_component(entity, engine.Component_Transform {
                position = grid_to_world_position_center({ 5, 5 }),
                scale = { 1, 1 },
            })
            append(&_mem.game.battle_data.entities, entity)
            _mem.game.battle_data.cursor_unit_entity = entity

            anim_entity := engine.entity_create_entity("Cursor: unit (animation)")
            engine.entity_set_component(anim_entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_spritesheet,
                texture_size = GRID_SIZE_V2,
                texture_position = grid_position(6, 6),
                texture_padding = 1,
                z_index = 11,
                tint = { 1, 1, 1, 1 },
            })
            anim_component_transform, ok := engine.entity_set_component(anim_entity, engine.Component_Transform {
                parent = entity,
                position = Vector2f32 { 0, -1 } * f32(GRID_SIZE),
                scale = { 1, 1 },
            })
            append(&_mem.game.battle_data.entities, anim_entity)

            animation := engine.animation_create_animation(1.5)
            animation.loop = true
            animation.active = true
            engine.animation_add_curve(animation, engine.Animation_Curve_Position {
                target = &anim_component_transform.position,
                timestamps = { 0, 0.5, 1 },
                frames = { anim_component_transform.position, anim_component_transform.position + { 0, -0.5 } * f32(GRID_SIZE), anim_component_transform.position },
            })
            engine.entity_set_component(anim_entity, engine.Component_Animation { animation })
        }

        {
            entity := engine.entity_create_entity("Unit preview")
            engine.entity_set_component(entity, engine.Component_Transform {
                position = grid_to_world_position_center(OFFSCREEN_POSITION),
                scale = { 1, 1 },
            })
            engine.entity_set_component(entity, engine.Component_Sprite {
                texture_asset = _mem.game.asset_image_spritesheet,
                texture_size = GRID_SIZE_V2,
                texture_position = grid_position(3, 12),
                texture_padding = 1,
                z_index = 1,
                tint = { 1, 1, 1, 0.5 },
            })
            append(&_mem.game.battle_data.entities, entity)
            _mem.game.battle_data.unit_preview_entity = entity
        }

        {
            areas_asset := &_mem.assets.assets[_mem.game.asset_map_areas]
            asset_info, asset_ok := areas_asset.info.(engine.Asset_Info_Map)
            level_index : int = 0
            for level, i in asset_info.ldtk.levels {
                if level.identifier == BATTLE_LEVELS[_mem.game.battle_index - 1] {
                    level_index = i
                    break
                }
            }
            _mem.game.level_assets = load_level_assets(asset_info)
            _mem.game.battle_data.level = make_level(asset_info.ldtk, level_index, _mem.game.level_assets, &_mem.game.battle_data.entities, _mem.game.game_mode.arena.allocator)
        }

        spawners_ally := [dynamic]Entity {}
        spawners_foe := [dynamic]Entity {}
        for entity in _mem.game.battle_data.entities {
            component_meta, err_meta := engine.entity_get_component(entity, engine.Component_Tile_Meta)
            if err_meta != .None {
                continue
            }

            ldtk_entity := _mem.game.ldtk_entity_defs[component_meta.entity_uid]
            if ldtk_entity.identifier == LDTK_ID_SPAWNER_ALLY {
                append(&spawners_ally, entity)
            }
            if ldtk_entity.identifier == LDTK_ID_SPAWNER_FOE {
                append(&spawners_foe, entity)
            }
        }

        if len(spawners_ally) == 0 {
            fmt.panicf("Can't have a battle with 0 allies.")
        }
        if len(spawners_foe) == 0 {
            fmt.panicf("Can't have a battle with 0 foes.")
        }
        spawn_units(spawners_ally, _mem.game.party, Directions.Right, .Ally)
        spawn_units(spawners_foe, _mem.game.foes, Directions.Left, .Foe)

        for unit_index in _mem.game.battle_data.units {
            unit := &_mem.game.units[unit_index]
            unit.stat_ctr = 0
            unit.stat_health = unit.stat_health_max
        }

        log.infof("Battle:           %v", BATTLE_LEVELS[_mem.game.battle_index - 1])
    }

    if game_mode_running() {
        shader_info_default, shader_default_err := engine.asset_get_asset_info_shader(_mem.game.asset_shader_sprite)
        shader_info_line, shader_line_err := engine.asset_get_asset_info_shader(_mem.game.asset_shader_line)

        current_unit := &_mem.game.units[_mem.game.battle_data.current_unit]
        unit_transform, unit_transform_ok := engine.entity_get_component(current_unit.entity, engine.Component_Transform)
        assert(unit_transform_ok == .None)
        unit_rendering, unit_rendering_ok := engine.entity_get_component(current_unit.entity, engine.Component_Sprite)
        assert(unit_rendering_ok == .None)
        cursor_move := _mem.game.battle_data.cursor_move_entity
        assert(cursor_move != engine.ENTITY_INVALID)
        cursor_unit := _mem.game.battle_data.cursor_unit_entity
        assert(cursor_unit != engine.ENTITY_INVALID)
        cursor_target := _mem.game.battle_data.cursor_target_entity
        assert(cursor_unit != engine.ENTITY_INVALID)
        unit_preview := _mem.game.battle_data.unit_preview_entity
        assert(unit_preview != engine.ENTITY_INVALID)
        unit_preview_rendering, unit_preview_rendering_ok := engine.entity_get_component(unit_preview, engine.Component_Sprite)
        assert(unit_preview_rendering_ok == .None)

        engine.platform_process_repeater(&_mem.game.battle_data.move_repeater, _mem.game.player_inputs.move)
        engine.platform_process_repeater(&_mem.game.battle_data.aim_repeater, _mem.game.player_inputs.aim)

        {
            defer battle_mode_check_exit()
            battle_mode: switch Battle_Mode(_mem.game.battle_data.mode.current) {
                case .Ticking: {
                    engine.profiler_zone(".Ticking")
                    if battle_mode_running() {
                        for time.diff(_mem.game.battle_data.next_tick, time.now()) >= 0 {
                            for unit_index in _mem.game.battle_data.units {
                                unit := &_mem.game.units[unit_index]
                                unit.stat_ctr += unit.stat_speed
                            }

                            sorted_units := slice.clone(_mem.game.battle_data.units[:], context.temp_allocator)
                            sort.heap_sort_proc(sorted_units, sort_units_by_ctr)

                            for unit_index in sorted_units {
                                unit := &_mem.game.units[unit_index]
                                if unit_can_take_turn(unit) {
                                    _mem.game.battle_data.current_unit = unit_index
                                    current_unit = &_mem.game.units[_mem.game.battle_data.current_unit]
                                    battle_mode_transition(.Start_Turn)
                                    break battle_mode
                                }
                            }

                            _mem.game.battle_data.next_tick = { time.now()._nsec + TICK_DURATION }
                        }
                    }
                }

                case .Start_Turn: {
                    engine.profiler_zone(".Start_Turn")
                    if battle_mode_entering() {
                        reset_turn(&_mem.game.battle_data.turn)
                        battle_mode_transition(.Select_Action)
                    }
                }

                case .Select_Action: {
                    engine.profiler_zone(".Select_Action")
                    if battle_mode_entering() {
                        log.infof("Turn %v | Select_Action: %v | HP: %v", _mem.game.battle_data.turn_count, current_unit.name, current_unit.stat_health)
                        free_all(_mem.game.battle_data.plan_arena.allocator)
                        _mem.game.battle_data.turn.move_target = OFFSCREEN_POSITION
                        _mem.game.battle_data.turn.move_path = {}
                        _mem.game.battle_data.turn.ability_target = OFFSCREEN_POSITION
                        _mem.game.battle_data.turn.ability_path = {}
                        entity_move_grid(cursor_move, OFFSCREEN_POSITION)
                        entity_move_grid(cursor_target, OFFSCREEN_POSITION)
                        entity_move_grid(cursor_unit, current_unit.grid_position)

                        update_grid_flags(&_mem.game.battle_data.level)
                        if unit_can_take_turn(current_unit) == false || _mem.game.battle_data.turn.moved && _mem.game.battle_data.turn.acted {
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
                        action := Battle_Action.None

                        switch current_unit.controlled_by {
                            case .CPU: {
                                action = cpu_choose_action(current_unit)
                            }

                            case .Player: {
                                if _mem.game.player_inputs.cancel.released {
                                    action = .Wait
                                }

                                if game_ui_window(fmt.tprintf("%v's turn", current_unit.name), nil, .NoResize | .NoMove | .NoCollapse) {
                                    engine.ui_set_window_size_vec2({ 300, 200 }, .Always)
                                    engine.ui_set_window_pos_vec2({ f32(_mem.platform.window_size.x - 300) / 2, f32(_mem.platform.window_size.y - 150) / 2 }, .Always)

                                    health_progress := f32(current_unit.stat_health) / f32(current_unit.stat_health_max)
                                    engine.ui_progress_bar_label(health_progress, fmt.tprintf("HP: %v/%v", current_unit.stat_health, current_unit.stat_health_max))

                                    if game_ui_button("Move", _mem.game.battle_data.turn.moved && _mem.game.cheat_move_repeatedly == false) {
                                        action = .Move
                                    }
                                    if game_ui_button("Throw", _mem.game.battle_data.turn.acted && _mem.game.cheat_act_repeatedly == false) {
                                        action = .Throw
                                    }
                                    if game_ui_button("Wait") {
                                        action = .Wait
                                    }
                                }
                            }
                        }

                        switch action {
                            case .None: { }
                            case .Move: {
                                _mem.game.battle_data.turn.ability_target = OFFSCREEN_POSITION
                                _mem.game.battle_data.turn.move_target = current_unit.grid_position
                                _mem.game.battle_data.turn.move_valid_targets = flood_fill_search(_mem.game.battle_data.level.size, _mem.game.battle_data.level.grid, current_unit.grid_position, current_unit.stat_move, search_filter_move_target, EIGHT_DIRECTIONS, _mem.game.battle_data.plan_arena.allocator)
                                exclude_cells_with_units(&_mem.game.battle_data.turn.move_valid_targets)
                                if current_unit.controlled_by == .Player {
                                    _mem.game.highlighted_cells = create_cell_highlight(_mem.game.battle_data.turn.move_valid_targets, .Move, _mem.game.battle_data.plan_arena.allocator)
                                }
                                battle_mode_transition(.Target_Move)
                            }
                            case .Throw: {
                                _mem.game.battle_data.turn.move_target = OFFSCREEN_POSITION
                                _mem.game.battle_data.turn.ability_id = 1
                                _mem.game.battle_data.turn.ability_target = current_unit.grid_position
                                _mem.game.battle_data.turn.ability_valid_targets = flood_fill_search(_mem.game.battle_data.level.size, _mem.game.battle_data.level.grid, current_unit.grid_position, current_unit.stat_range, search_filter_ability_target, CARDINAL_DIRECTIONS, _mem.game.battle_data.plan_arena.allocator)
                                if current_unit.controlled_by == .Player {
                                    _mem.game.highlighted_cells = create_cell_highlight(_mem.game.battle_data.turn.ability_valid_targets, .Ability, _mem.game.battle_data.plan_arena.allocator)
                                }
                                battle_mode_transition(.Target_Ability)
                            }
                            case .Wait: {
                                battle_mode_transition(.End_Turn)
                            }
                        }
                    }

                    if battle_mode_exiting() {
                        if _mem.game.battle_data.turn.cursor_unit_animation != nil {
                            engine.animation_delete_animation(_mem.game.battle_data.turn.cursor_unit_animation)
                        }
                        entity_move_grid(cursor_move, OFFSCREEN_POSITION)
                        entity_move_grid(cursor_unit, OFFSCREEN_POSITION)
                        entity_move_grid(cursor_target, OFFSCREEN_POSITION)
                    }
                }

                case .Target_Move: {
                    engine.profiler_zone(".Target_Move")

                    if battle_mode_entering() {
                        entity_move_grid(cursor_unit, _mem.game.battle_data.turn.move_target)
                    }

                    if battle_mode_running() {
                        entity_move_grid(cursor_move, _mem.game.battle_data.turn.move_target)
                        action := Menu_Action.None

                        switch current_unit.controlled_by {
                            case .CPU: {
                                cpu_choose_move_target(current_unit)
                                action = .Confirm
                            }

                            case .Player: {
                                if _mem.game.player_inputs.cancel.released {
                                    action = .Cancel
                                }
                                if _mem.game.player_inputs.confirm.released || _mem.game.player_inputs.mouse_left.released{
                                    action = .Confirm
                                }
                                if _mem.platform.mouse_moved || _mem.game.player_inputs.mouse_left.released {
                                    _mem.game.battle_data.turn.move_target = _mem.game.mouse_grid_position
                                }
                                if _mem.game.battle_data.aim_repeater.value != { 0, 0 } {
                                    _mem.game.battle_data.turn.move_target = _mem.game.battle_data.turn.move_target + _mem.game.battle_data.aim_repeater.value
                                }
                                if _mem.game.battle_data.move_repeater.value != { 0, 0 } {
                                    _mem.game.battle_data.turn.move_target = _mem.game.battle_data.turn.move_target + _mem.game.battle_data.move_repeater.value
                                }

                                // TODO: instead of recreating this path every frame in temp_allocator, store it inside a scratch allocator (that we can free)
                                path, path_ok := find_path(_mem.game.battle_data.level.grid, _mem.game.battle_data.level.size, current_unit.grid_position, _mem.game.battle_data.turn.move_target, allocator = context.temp_allocator)
                                _mem.game.battle_data.turn.move_path = path
                            }
                        }

                        switch action {
                            case .None: { }

                            case .Cancel: {
                                if current_unit.controlled_by == .Player {
                                    engine.audio_play_sound(_mem.game.asset_sound_cancel)
                                }
                                battle_mode_transition(.Select_Action)
                            }

                            case .Confirm: {
                                is_valid_target := slice.contains(_mem.game.battle_data.turn.move_valid_targets[:], _mem.game.battle_data.turn.move_target)
                                path, path_ok := find_path(_mem.game.battle_data.level.grid, _mem.game.battle_data.level.size, current_unit.grid_position, _mem.game.battle_data.turn.move_target, allocator = _mem.game.battle_data.turn_arena.allocator)
                                if is_valid_target && path_ok {
                                    _mem.game.battle_data.turn.move_path = path
                                    if current_unit.controlled_by == .Player {
                                        engine.audio_play_sound(_mem.game.asset_sound_confirm)
                                    }
                                    clear(&_mem.game.highlighted_cells)
                                    battle_mode_transition(.Perform_Move)
                                } else {
                                    if _mem.game.cheat_move_anywhere {
                                        log.infof("[CHEAT] Moved to: %v", _mem.game.battle_data.turn.move_target)
                                        cheat_path := make([]Vector2i32, 2, _mem.game.battle_data.turn_arena.allocator)
                                        cheat_path[0] = current_unit.grid_position
                                        cheat_path[1] = _mem.game.battle_data.turn.move_target
                                        _mem.game.battle_data.turn.move_path = cheat_path
                                        battle_mode_transition(.Perform_Move)
                                    } else {
                                        if current_unit.controlled_by == .Player {
                                            engine.audio_play_sound(_mem.game.asset_sound_invalid)
                                        }
                                        log.warnf("       Invalid target!")
                                    }
                                }
                            }
                        }
                    }

                    if battle_mode_exiting() {
                        clear(&_mem.game.highlighted_cells)
                    }
                }

                case .Perform_Move: {
                    engine.profiler_zone(".Perform_Move")
                    if battle_mode_entering() {
                        entity_move_grid(cursor_move, OFFSCREEN_POSITION)
                        entity_move_grid(cursor_unit, OFFSCREEN_POSITION)
                        path := _mem.game.battle_data.turn.move_path
                        _mem.game.battle_data.turn.move_path = {}

                        direction := current_unit.direction
                        for point, i in path {
                            if i < len(path) - 1 {
                                new_direction := direction
                                if point.x != path[i+1].x {
                                    new_direction = get_direction_from_points(point.x, path[i+1].x)
                                }

                                if direction != new_direction {
                                    queue.push_back(_mem.game.battle_data.turn.animations, create_animation_unit_flip(current_unit, new_direction))
                                    direction = new_direction
                                }

                                queue.push_back(_mem.game.battle_data.turn.animations, create_animation_unit_move(current_unit, new_direction, point, path[i+1]))
                            }
                        }

                        current_unit.grid_position = _mem.game.battle_data.turn.move_target
                        current_unit.direction = direction
                        _mem.game.battle_data.turn.moved = true
                    }

                    if battle_mode_running() {
                        if engine.animation_queue_is_done(_mem.game.battle_data.turn.animations) {
                            battle_mode_transition(.Select_Action)
                        }
                    }

                    if battle_mode_exiting() {
                        _mem.game.battle_data.turn.move_path = {}
                    }
                }

                case .Target_Ability: {
                    engine.profiler_zone(".Target_Ability")

                    if battle_mode_entering() {
                        entity_move_grid(cursor_unit, _mem.game.battle_data.turn.move_target)
                    }

                    if battle_mode_running() {
                        entity_move_grid(cursor_target, _mem.game.battle_data.turn.ability_target)
                        action := Menu_Action.None

                        switch current_unit.controlled_by {
                            case .CPU: {
                                cpu_choose_ability_target(current_unit)
                                action = .Confirm
                            }

                            case .Player: {
                                if _mem.game.player_inputs.cancel.released {
                                    action = .Cancel
                                }
                                if _mem.game.player_inputs.confirm.released || _mem.game.player_inputs.mouse_left.released {
                                    action = .Confirm
                                }
                                if _mem.platform.mouse_moved || _mem.game.player_inputs.mouse_left.released {
                                    _mem.game.battle_data.turn.ability_target = _mem.game.mouse_grid_position
                                }
                                if _mem.game.battle_data.aim_repeater.value != { 0, 0 } {
                                    _mem.game.battle_data.turn.ability_target = _mem.game.battle_data.turn.ability_target + _mem.game.battle_data.aim_repeater.value
                                }
                                if _mem.game.battle_data.move_repeater.value != { 0, 0 } {
                                    _mem.game.battle_data.turn.ability_target = _mem.game.battle_data.turn.ability_target + _mem.game.battle_data.move_repeater.value
                                }

                                if _mem.game.battle_data.turn.ability_target != OFFSCREEN_POSITION {
                                    _mem.game.battle_data.turn.ability_path = { current_unit.grid_position, _mem.game.battle_data.turn.ability_target }
                                }
                            }
                        }

                        switch action {
                            case .None: { }

                            case .Cancel: {
                                if current_unit.controlled_by == .Player {
                                    engine.audio_play_sound(_mem.game.asset_sound_cancel)
                                }
                                battle_mode_transition(.Select_Action)
                            }

                            case .Confirm: {
                                is_valid_target := slice.contains(_mem.game.battle_data.turn.ability_valid_targets[:], _mem.game.battle_data.turn.ability_target)
                                if is_valid_target || _mem.game.cheat_act_anywhere {
                                    if current_unit.controlled_by == .Player {
                                        engine.audio_play_sound(_mem.game.asset_sound_confirm)
                                    }
                                    battle_mode_transition(.Perform_Ability)
                                } else {
                                    if current_unit.controlled_by == .Player {
                                        engine.audio_play_sound(_mem.game.asset_sound_invalid)
                                    }
                                    log.warnf("       Invalid target!")
                                }
                            }
                        }
                    }

                    if battle_mode_exiting() {
                        clear(&_mem.game.highlighted_cells)
                    }
                }

                case .Perform_Ability: {
                    engine.profiler_zone(".Perform_Ability")
                    if battle_mode_entering() {
                        entity_move_grid(cursor_target, OFFSCREEN_POSITION)

                        direction := get_direction_from_points(current_unit.grid_position, _mem.game.battle_data.turn.ability_target)
                        if current_unit.direction != direction {
                            queue.push_back(_mem.game.battle_data.turn.animations, create_animation_unit_flip(current_unit, direction))
                            current_unit.direction = direction
                        }
                        _mem.game.battle_data.turn.projectile = engine.entity_create_entity("Projectile")
                        engine.entity_set_component(_mem.game.battle_data.turn.projectile, engine.Component_Transform {
                            position = grid_to_world_position_center(current_unit.grid_position),
                        })
                        engine.entity_set_component(_mem.game.battle_data.turn.projectile, engine.Component_Sprite {
                            texture_asset = _mem.game.asset_image_spritesheet,
                            texture_size = GRID_SIZE_V2,
                            texture_position = GRID_SIZE_V2 * { 0, 7 },
                            texture_padding = 1,
                            z_index = 3,
                            tint = { 1, 1, 1, 1 },
                        })

                        queue.push_back(_mem.game.battle_data.turn.animations, create_animation_unit_throw(current_unit, _mem.game.battle_data.turn.ability_target, _mem.game.battle_data.turn.projectile))

                        _mem.game.battle_data.turn.acted = true
                    }

                    if battle_mode_running() {
                        if engine.animation_queue_is_done(_mem.game.battle_data.turn.animations) {
                            battle_mode_transition(.Select_Action)
                        }
                    }

                    if battle_mode_exiting() {
                        engine.entity_delete_entity(_mem.game.battle_data.turn.projectile)
                        _mem.game.battle_data.turn.projectile = engine.ENTITY_INVALID
                    }
                }

                case .End_Turn: {
                    engine.profiler_zone(".End_Turn")
                    if battle_mode_entering() {
                        turn_cost := TURN_COST
                        if _mem.game.battle_data.turn.moved {
                            turn_cost += MOVE_COST
                        }
                        if _mem.game.battle_data.turn.acted {
                            turn_cost += ACT_COST
                        }
                        current_unit.stat_ctr -= turn_cost

                        _mem.game.battle_data.turn_count += 1

                        clear(&_mem.game.highlighted_cells)
                        free_all(_mem.game.battle_data.turn_arena.allocator)
                        battle_mode_transition(.Ticking)
                    }
                }

                case .Victory: {
                    engine.profiler_zone(".Victory")
                    if battle_mode_entering() {
                        engine.profiler_message("victory")
                        log.warnf("Victory")
                        game_mode_transition(.Debug)
                    }
                }

                case .Defeat: {
                    engine.profiler_zone(".Defeat")
                    if battle_mode_entering() {
                        engine.profiler_message("defeat")
                        log.warnf("Game over")
                        game_mode_transition(.Debug)
                    }
                }
            }
        }

        unit_preview_rendering.texture_position = unit_rendering.texture_position

        game_ui_window_battle(&_mem.game.debug_ui_window_battle)

        if _mem.game.battle_data != nil && len(_mem.game.battle_data.turn.move_path) > 0 {
            points := make([]Vector2f32, len(_mem.game.battle_data.turn.move_path), context.temp_allocator)
            for point, i in _mem.game.battle_data.turn.move_path {
                points[i] = grid_to_world_position_center(point)
            }

            engine.renderer_push_line(points, shader_info_line.shader, COLOR_IN_RANGE)
        }
        if _mem.game.battle_data != nil && len(_mem.game.battle_data.turn.ability_path) > 0 {
            points := make([]Vector2f32, len(_mem.game.battle_data.turn.ability_path), context.temp_allocator)
            for point, i in _mem.game.battle_data.turn.ability_path {
                points[i] = grid_to_world_position_center(point)
            }
            last_point := _mem.game.battle_data.turn.ability_path[len(_mem.game.battle_data.turn.ability_path) - 1]

            color := COLOR_IN_RANGE
            if slice.contains(_mem.game.battle_data.turn.ability_valid_targets[:], last_point) == false {
                color = COLOR_OUT_OF_RANGE
            }
            engine.renderer_push_line(points, shader_info_line.shader, color)
        }

        if _mem.game.debug_draw_grid {
            engine.profiler_zone("debug_draw_grid", PROFILER_COLOR_RENDER)

            asset_image_spritesheet, asset_image_spritesheet_ok := engine.asset_get(_mem.game.asset_image_spritesheet)
            if asset_image_spritesheet_ok && asset_image_spritesheet.state == .Loaded {
                image_info_debug, asset_ok := asset_image_spritesheet.info.(engine.Asset_Info_Image)
                texture_position, texture_size, pixel_size := texture_position_and_size(image_info_debug.texture, { 40, 40 }, { 8, 8 })
                grid_width :: 40
                grid_height :: 23
                for grid_value, grid_index in _mem.game.battle_data.level.grid {
                    grid_position := engine.grid_index_to_position(grid_index, _mem.game.battle_data.level.size)
                    color := engine.Color { 0, 0, 0, 0 }
                    if .None      not_in grid_value { color.a = 1 }
                    if .Climb     in grid_value     { color.g = 1 }
                    if .Fall      in grid_value     { color.r = 1 }
                    if .Move      in grid_value     { color.b = 1 }
                    if .Grounded  in grid_value     { color.g = 1 }
                    engine.renderer_push_quad(
                        Vector2f32 { f32(grid_position.x), f32(grid_position.y) } * engine.vector_i32_to_f32(GRID_SIZE_V2) + engine.vector_i32_to_f32(GRID_SIZE_V2) / 2,
                        engine.vector_i32_to_f32(GRID_SIZE_V2),
                        color,
                        image_info_debug.texture,
                        texture_position, texture_size,
                        0,
                        shader_info_default.shader,
                    )
                }
            }
        }
    }

    if game_mode_exiting() {
        engine.entity_reset_memory()
        engine.asset_unload(_mem.game.asset_image_battle_bg)
        engine.asset_unload(_mem.game.asset_map_areas)
        _mem.game.battle_data = nil
    }
}

spawn_units :: proc(spawners: [dynamic]Entity, units: [dynamic]int, direction: Directions, alliance: Unit_Alliances) {
    for spawner, i in spawners {
        if i >= len(units) {
            break
        }

        unit := &_mem.game.units[units[i]]
        component_transform, _ := engine.entity_get_component(spawner, engine.Component_Transform)
        unit.grid_position = world_to_grid_position(component_transform.position)
        unit.direction = direction
        unit.alliance = alliance

        entity := unit_create_entity(unit)
        append(&_mem.game.battle_data.units, units[i])

        unit.entity = entity
    }
}

sort_units_by_ctr :: proc(a, b: int) -> int {
    return int(_mem.game.units[a].stat_ctr - _mem.game.units[b].stat_ctr)
}

create_cell_highlight :: proc(positions: [dynamic]Vector2i32, type: Cell_Highlight_Type, allocator := context.allocator) -> [dynamic]Cell_Highlight {
    context.allocator = allocator
    result := [dynamic]Cell_Highlight {}
    for position in positions {
        append(&result, Cell_Highlight { position, type })
    }
    return result
}

is_valid_move_destination :: proc(cell: Grid_Cell) -> bool { return cell >= { .Move, .Grounded } }
is_valid_ability_destination :: proc(cell: Grid_Cell) -> bool { return cell >= { .Move } }

search_filter_move_target : Search_Filter_Proc : proc(cell_position: Vector2i32, grid_size: Vector2i32, grid: []Grid_Cell) -> bool {
    grid_index := engine.grid_position_to_index(cell_position, grid_size.x)
    cell := grid[grid_index]
    return is_valid_move_destination(cell)
}

// TODO: Check range and FOV
search_filter_ability_target : Search_Filter_Proc : proc(cell_position: Vector2i32, grid_size: Vector2i32, grid: []Grid_Cell) -> bool {
    grid_index := engine.grid_position_to_index(cell_position, grid_size.x)
    cell := grid[grid_index]
    return is_valid_ability_destination(cell)
}

create_animation_unit_throw :: proc(actor: ^Unit, target: Vector2i32, projectile: Entity) -> ^engine.Animation {
    context.allocator = _mem.game.battle_data.mode.arena.allocator

    distance := Vector2f32(array_cast(target, f32) - array_cast(actor.grid_position, f32))
    aim_direction := linalg.vector_normalize(distance)

    animation := engine.animation_create_animation(2)
    component_limbs, has_limbs := engine.entity_get_component(actor.entity, Component_Limbs)
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
    user_data := new(Throw_Event_Data)
    user_data^ = { actor, target, projectile }
    engine.animation_add_curve(animation, engine.Animation_Curve_Event {
        timestamps = { 0.5 },
        frames = { { procedure = throw_event, user_data = user_data } },
    })

    return animation

    Throw_Event_Data :: struct {
        actor:      ^Unit,
        target:     Vector2i32,
        projectile: Entity,
    }
    throw_event :: proc(user_data: rawptr) {
        data := cast(^Throw_Event_Data) user_data
        using data;

        queue.push_back(_mem.game.battle_data.turn.animations, create_animation_projectile(actor, target, projectile))
    }
}

create_animation_projectile :: proc(actor: ^Unit, target: Vector2i32, projectile: Entity) -> ^engine.Animation {
    context.allocator = _mem.game.battle_data.mode.arena.allocator

    distance := Vector2f32(array_cast(target, f32) - array_cast(actor.grid_position, f32))
    animation := engine.animation_create_animation(20 / linalg.length(distance))
    animation.active = true // Important or the animation will be queue after the throw animation
    animation.parallel = true
    component_transform, err_transform := engine.entity_get_component(projectile, engine.Component_Transform)
    engine.animation_add_curve(animation, engine.Animation_Curve_Scale {
        target = &component_transform.scale,
        timestamps = { 0.0, 0.05, 0.95, 1.0 },
        frames = { { 0, 0 }, { 1, 1 }, { 1, 1 }, { 0, 0 } },
    })
    engine.animation_add_curve(animation, engine.Animation_Curve_Position {
        target = &component_transform.position,
        timestamps = { 0.0, 1.0 },
        frames = { component_transform.position, grid_to_world_position_center(target) },
    })
    user_data := new(Hit_Event_Data)
    user_data^ = { actor }
    engine.animation_add_curve(animation, engine.Animation_Curve_Event {
        timestamps = { 0.9 },
        frames = { { procedure = hit_event, user_data = user_data } },
    })

    return animation

    Hit_Event_Data :: struct {
        actor:      ^Unit,
    }
    hit_event :: proc(user_data: rawptr) {
        data := cast(^Hit_Event_Data) user_data
        using data;

        target_unit := find_unit_at_position(_mem.game.battle_data.turn.ability_target)
        if target_unit != nil {
            damage_taken := ability_apply_damage(_mem.game.battle_data.turn.ability_id, actor, target_unit)
            log.infof("damage_taken: %v", damage_taken)

            direction := get_direction_from_points(actor.grid_position, _mem.game.battle_data.turn.ability_target)
            if target_unit.stat_health == 0 {
                queue.push_back(_mem.game.battle_data.turn.animations, create_animation_unit_death(target_unit, direction))
            } else {
                queue.push_back(_mem.game.battle_data.turn.animations, create_animation_unit_hit(target_unit, direction))
            }
        }
    }
}

create_animation_unit_flip :: proc(unit: ^Unit, direction: Directions) -> ^engine.Animation {
    context.allocator = _mem.game.battle_data.mode.arena.allocator

    animation := engine.animation_create_animation(5)
    component_transform, err_transform := engine.entity_get_component(unit.entity, engine.Component_Transform)
    engine.animation_add_curve(animation, engine.Animation_Curve_Scale {
        target = &component_transform.scale,
        timestamps = { 0.0, 1.0 },
        frames = { { -f32(direction), 1 }, { f32(direction), 1 } },
    })
    return animation
}

create_animation_unit_hit :: proc(unit: ^Unit, direction: Directions) -> ^engine.Animation {
    context.allocator = _mem.game.battle_data.mode.arena.allocator

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

    hit_event :: proc(user_data: rawptr) {
        engine.audio_play_sound(_mem.game.asset_sound_hit)
    }
    return animation
}

create_animation_unit_death :: proc(unit: ^Unit, direction: Directions) -> ^engine.Animation {
    context.allocator = _mem.game.battle_data.mode.arena.allocator

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

    hit_event :: proc(user_data: rawptr) {
        engine.audio_play_sound(_mem.game.asset_sound_hit)
    }
    return animation
}

create_animation_unit_move :: proc(unit: ^Unit, direction: Directions, start_position, end_position: Vector2i32) -> ^engine.Animation {
    context.allocator = _mem.game.battle_data.mode.arena.allocator

    s := grid_to_world_position_center(start_position)
    e := grid_to_world_position_center(end_position)
    animation := engine.animation_create_animation(5)
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
    for unit_index in _mem.game.battle_data.units {
        unit := &_mem.game.units[unit_index]
        if unit.grid_position == position {
            return unit
        }
    }
    return nil
}

reset_turn :: proc(turn: ^Turn) {
    turn^ = {}
    turn.move_target = OFFSCREEN_POSITION
    turn.move_path = {}
    clear(&turn.move_valid_targets)
    turn.ability_target = OFFSCREEN_POSITION
    turn.ability_path = {}
    clear(&turn.ability_valid_targets)
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

    hand_left := engine.entity_create_entity(fmt.aprintf("%s: Hand (left)", unit.name, allocator = _mem.game.game_mode.arena.allocator))
    hand_left_transform, _ := engine.entity_set_component(hand_left, engine.Component_Transform {
        scale = { 1, 1 },
        parent = entity,
    })
    engine.entity_set_component(hand_left, engine.Component_Sprite {
        texture_asset = _mem.game.asset_image_units,
        texture_size = SPRITE_SIZE,
        texture_position = GRID_SIZE_V2 * { 5, 1 },
        texture_padding = 1,
        z_index = 3,
        tint = { 1, 1, 1, 1 },
        palette = palette,
    })

    hand_right := engine.entity_create_entity(fmt.aprintf("%s: Hand (right)", unit.name, allocator = _mem.game.game_mode.arena.allocator))
    hand_right_transform, _ := engine.entity_set_component(hand_right, engine.Component_Transform {
        scale = { 1, 1 },
        parent = entity,
    })
    engine.entity_set_component(hand_right, engine.Component_Sprite {
        texture_asset = _mem.game.asset_image_units,
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
        texture_asset = _mem.game.asset_image_units,
        texture_size = SPRITE_SIZE,
        texture_position = unit.sprite_position * GRID_SIZE_V2,
        texture_padding = 1,
        z_index = 2,
        tint = { 1, 1, 1, 1 },
        palette = palette,
    })
    engine.entity_set_component(entity, Component_Flag { { .Unit } })
    engine.entity_set_component(entity, Component_Limbs { hand_left = hand_left, hand_right = hand_right })

    append(&_mem.game.battle_data.entities, entity)
    append(&_mem.game.battle_data.entities, hand_left)
    append(&_mem.game.battle_data.entities, hand_right)

    return entity
}

entity_move_grid :: proc(entity: Entity, grid_position: Vector2i32, loc := #caller_location) {
    assert(entity != engine.ENTITY_INVALID, "Can't move invalid entity", loc)
    component_transform, component_transform_ok := engine.entity_get_component(entity, engine.Component_Transform)
    assert(component_transform_ok != .Entity_Not_Found, "Can't move entity with no Component_Transform", loc)
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

ability_is_valid_target :: proc(ability: Ability_Id, actor, target: ^Unit) -> bool {
    return unit_is_alive(target) && target != actor && target.alliance != actor.alliance
}

ability_apply_damage :: proc(ability: Ability_Id, actor, target: ^Unit) -> (damage_taken: i32) {
    damage_taken = 99
    target.stat_health = math.max(target.stat_health - damage_taken, 0)
    return damage_taken
}

win_condition_reached :: proc() -> bool {
    units_count := 0
    for unit_index in _mem.game.battle_data.units {
        unit := &_mem.game.units[unit_index]
        if unit.alliance == .Foe && unit_is_alive(unit) {
            units_count += 1
        }
    }
    return units_count == 0
}
lose_condition_reached :: proc() -> bool {
    units_count := 0
    for unit_index in _mem.game.battle_data.units {
        unit := &_mem.game.units[unit_index]
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
            engine.ui_text("Battle index: %v", _mem.game.battle_index)
            if engine.ui_button("World map") {
                _mem.game.battle_index = 0
                game_mode_transition(.WorldMap)
            }
            if engine.ui_button("Victory") {
                battle_mode_transition(.Victory)
            }
            engine.ui_same_line()
            if engine.ui_button("Defeat") {
                battle_mode_transition(.Defeat)
            }

            engine.ui_text("mode:               %v", Battle_Mode(_mem.game.battle_data.mode.current))
            engine.ui_text("current_unit:       %v", _mem.game.units[_mem.game.battle_data.current_unit].name)
            if engine.ui_tree_node("Mouse cursor") {
                engine.ui_text("mouse_grid_pos:     %v", _mem.game.mouse_grid_position)
                mouse_cell, mouse_cell_found := get_cell_at_position(&_mem.game.battle_data.level, _mem.game.mouse_grid_position)
                if mouse_cell_found {
                    engine.ui_text("  - Climb:    %v", .Climb in mouse_cell ? "x" : "")
                    engine.ui_text("  - Fall:     %v", .Fall in mouse_cell ? "x" : "")
                    engine.ui_text("  - Move:     %v", .Move in mouse_cell ? "x" : "")
                    engine.ui_text("  - Grounded: %v", .Grounded in mouse_cell ? "x" : "")
                }
            }
            if engine.ui_tree_node("Turn") {
                engine.ui_text("  move:    %v", _mem.game.battle_data.turn.move_target)
                engine.ui_text("  target:  %v", _mem.game.battle_data.turn.ability_target)
                engine.ui_text("  ability: %v", _mem.game.battle_data.turn.ability_id)
            }

            if engine.ui_tree_node("level", { .DefaultOpen }) {
                engine.ui_text("len(grid): %v", len(_mem.game.battle_data.level.grid))
                engine.ui_text("size:      %v", _mem.game.battle_data.level.size)
            }
        }

        engine.ui_same_line()
        if engine.ui_child("middle", { region.x * 0.5, region.y }, false, .NoBackground) {
            columns := []string { "index", "name", "pos", "ctr", "hp", "actions" }
            if engine.ui_table(columns) {
                for i := 0; i < len(_mem.game.units); i += 1 {
                    engine.ui_table_next_row()
                    unit := &_mem.game.units[i]
                    for column, column_index in columns {
                        engine.ui_table_set_column_index(i32(column_index))
                        switch column {
                            case "index": engine.ui_text("%v", i)
                            case "name": {
                                if unit.alliance == .Foe { engine.ui_push_style_color(.Text, { 1, 0.4, 0.4, 1 }) }
                                engine.ui_text("%v (%v)", unit.name, unit.alliance)
                                if unit.alliance == .Foe { engine.ui_pop_style_color(1) }
                            }
                            case "pos": engine.ui_text("%v", unit.grid_position)
                            case "ctr": {
                                progress := f32(unit.stat_ctr) / 100
                                engine.ui_progress_bar(progress, { -1, 20 }, fmt.tprintf("CTR: %v", unit.stat_ctr))
                            }
                            case "hp": {
                                progress := f32(unit.stat_health) / f32(unit.stat_health_max)
                                engine.ui_progress_bar(progress, { -1, 20 }, fmt.tprintf("HP: %v/%v", unit.stat_health, unit.stat_health_max))
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
                                    _mem.game.battle_data.current_unit = i
                                }
                                engine.ui_same_line()
                                if engine.ui_button("Kill") {
                                    unit.stat_health = 0
                                }
                                engine.ui_pop_id()
                            }
                            case: engine.ui_text("x")
                        }
                    }
                }
            }
            engine.ui_text("Actions for all units:")
            if engine.ui_button("Player") {
                for _, i in _mem.game.units {
                    unit := &_mem.game.units[i]
                    unit.controlled_by = .Player
                }
            }
            engine.ui_same_line()
            if engine.ui_button("CPU") {
                for _, i in _mem.game.units {
                    unit := &_mem.game.units[i]
                    unit.controlled_by = .CPU
                }
            }
            engine.ui_same_line()
            if engine.ui_button("Set active") {
                for _, i in _mem.game.units {
                    unit := &_mem.game.units[i]
                    _mem.game.battle_data.current_unit = i
                }
            }
            engine.ui_same_line()
            if engine.ui_button("Kill") {
                for _, i in _mem.game.units {
                    unit := &_mem.game.units[i]
                    unit.stat_health = 0
                }
            }
        }

        engine.ui_same_line()
        if engine.ui_child("right", { region.x * 0.25, region.y }, false, .NoBackground) {
            unit := &_mem.game.units[_mem.game.battle_data.current_unit]
            engine.ui_text("name:          %v", unit.name)
            engine.ui_text("grid_position: %v", unit.grid_position)
            engine.ui_text("direction:     %v", unit.direction)
            engine.ui_text("controlled_by: %v", unit.controlled_by)
            engine.ui_push_item_width(100)
            engine.ui_input_int("stat_ctr", &unit.stat_ctr)
            engine.ui_input_int("stat_health", &unit.stat_health)
            engine.ui_input_int("stat_health_max", &unit.stat_health_max)
            engine.ui_input_int("stat_move", &unit.stat_move)
            engine.ui_input_int("stat_speed", &unit.stat_speed)
            engine.ui_input_int("stat_range", &unit.stat_range)
            {
                progress := f32(unit.stat_ctr) / 100
                engine.ui_progress_bar_label(progress, fmt.tprintf("CTR: %v", unit.stat_ctr))
            }
            {
                progress := f32(unit.stat_health) / f32(unit.stat_health_max)
                engine.ui_progress_bar_label(progress, fmt.tprintf("HP: %v/%v", unit.stat_health, unit.stat_health_max))
            }
        }
    }
}

// FIXME: Don't do this on the main thread or at least don't block while doing it, because this can be slow later down the line
cpu_choose_action :: proc(current_unit: ^Unit) -> Battle_Action {
    engine.profiler_zone("cpu_choose_action")

    if _mem.game.battle_data.turn.moved == false {
        return .Move
    }

    if _mem.game.battle_data.turn.acted == false {
        return .Throw
    }

    // TODO: wait if no valid action
    return .Wait
}

cpu_choose_move_target :: proc(current_unit: ^Unit) {
    engine.profiler_zone("cpu_choose_move_target")

    valid_targets := _mem.game.battle_data.turn.move_valid_targets
    best_target := OFFSCREEN_POSITION
    if len(valid_targets) == 0 {
        log.errorf("[CPU] No valid targets to move?!")
        return
    }

    random_cell_index := rand.int_max(len(valid_targets) - 1, &_mem.game.rand)
    best_target = valid_targets[random_cell_index]

    log.infof("[CPU] Move target: %v", best_target)
    _mem.game.battle_data.turn.move_target = best_target
}

cpu_choose_ability_target :: proc(current_unit: ^Unit) {
    engine.profiler_zone("cpu_choose_move_target")

    valid_targets := _mem.game.battle_data.turn.ability_valid_targets
    if len(valid_targets) == 0 {
        log.errorf("[CPU] No valid targets to ability?!")
        return
    }

    best_target := OFFSCREEN_POSITION
    for target_position in valid_targets {
        target_unit := find_unit_at_position(target_position)

        // TODO: check if the target is better than the previous
        best_target = target_position

        if ability_is_valid_target(_mem.game.battle_data.turn.ability_id, current_unit, target_unit) {
            break
        }
    }

    log.infof("[CPU] Ability target: %v", best_target)
    _mem.game.battle_data.turn.ability_target = best_target
}

exclude_cells_with_units :: proc(cell_positions: ^[dynamic]Vector2i32) {
    cells: for cell_position, cell_index in cell_positions {
        for unit_index in _mem.game.battle_data.units {
            unit := &_mem.game.units[unit_index]
            if cell_position == unit.grid_position {
                unordered_remove(cell_positions, cell_index)
                continue cells
            }
        }
    }
}
