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

TAKE_TURN               :: i32(100)
TURN_COST               :: i32(60)
ACT_COST                :: i32(20)
MOVE_COST               :: i32(20)
TICK_DURATION           :: i64(0)
OFFSCREEN_POSITION      :: Vector2i32 { 999, 999 }
GRAVITY_DIRECTION       :: Vector2i32 { 0, 1 }
FALL_DAMAGE_THRESHOLD   :: 4

BATTLE_LEVELS := [?]string {
    // "Debug_99",
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
    exits:                [dynamic]Vector2i32, // TODO: make this a slice
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

Turn :: struct {
    moved:                  bool,
    acted:                  bool,
    projectile:             Entity,
    animations:             ^queue.Queue(^engine.Animation),
    move_target:            Vector2i32,
    move_path:              []Vector2i32,
    move_path_valid:        bool,
    move_valid_targets:     [dynamic]Vector2i32,
    ability_id:             Ability_Id,
    ability_target:         Vector2i32,
    ability_path:           []Vector2i32,
    ability_path_valid:     bool,
    ability_valid_targets:  [dynamic]Vector2i32,
    cursor_unit_animation:  ^engine.Animation, // TODO: Find a cleaner way to keep track of small animations like that
    cpu_delay:              time.Duration,
    cpu_retries:            i32,
}

Menu_Action :: enum {
    None,
    Cancel,
    Confirm,
}
Battle_Action :: enum {
    None,
    Move,
    Ability,
    Wait,
}

Ability_Id :: distinct int

game_mode_battle :: proc () {
    if game_mode_entering() {
        context.allocator = _mem.game.game_mode.arena.allocator
        _mem.game.battle_data = new(Game_Mode_Battle)
        engine.mem_make_named_arena(&_mem.game.battle_data.mode.arena, "battle_mode", mem.Megabyte)
        engine.mem_make_named_arena(&_mem.game.battle_data.turn_arena, "battle_turn", mem.Megabyte)
        engine.mem_make_named_arena(&_mem.game.battle_data.plan_arena, "battle_plan", mem.Megabyte)

        engine.asset_load(_mem.game.asset_map_areas)
        engine.asset_load(_mem.game.asset_music_battle, engine.Asset_Load_Options_Audio { .Music })
        engine.asset_load(_mem.game.asset_image_battle_bg, engine.Asset_Load_Options_Image { engine.RENDERER_FILTER_NEAREST, engine.RENDERER_WRAP_REPEAT })

        music_asset := _mem.assets.assets[_mem.game.asset_music_battle]
        if music_asset.state == .Loaded {
            music_asset_info := music_asset.info.(engine.Asset_Info_Audio)
            engine.audio_play_music(music_asset_info, -1)
        }

        if engine.renderer_is_enabled() {
            // FIXME: handle non 16x9 resolutions better
            _mem.renderer.world_camera.position = { NATIVE_RESOLUTION.x / 2, NATIVE_RESOLUTION.y / 2, 0 }
            _mem.renderer.world_camera.zoom = f32(_mem.platform.window_size.y) / NATIVE_RESOLUTION.y * _mem.renderer.pixel_density
        }
        _mem.game.battle_data.move_repeater = { threshold = 200 * time.Millisecond, rate = 100 * time.Millisecond }
        _mem.game.battle_data.aim_repeater = { threshold = 200 * time.Millisecond, rate = 100 * time.Millisecond }
        clear(&_mem.game.highlighted_cells)

        reset_turn(&_mem.game.battle_data.turn)

        current_level: engine.LDTK_Level
        {
            areas_asset := &_mem.assets.assets[_mem.game.asset_map_areas]
            asset_info, asset_ok := areas_asset.info.(engine.Asset_Info_Map)
            level_index : int = -1
            for level, i in asset_info.levels {
                if level.identifier == BATTLE_LEVELS[_mem.game.battle_index - 1] {
                    level_index = i
                    break
                }
            }
            assert(level_index > -1, "Invalid level")
            current_level = asset_info.levels[level_index]
            _mem.game.level_assets = load_level_assets(asset_info)
            _mem.game.battle_data.level = make_level(asset_info, level_index, _mem.game.level_assets, &_mem.game.battle_data.entities, 1, _mem.game.asset_shader_sprite, _mem.game.game_mode.arena.allocator)
            update_grid_flags(&_mem.game.battle_data.level)
        }

        {
            background_asset, background_found := get_asset_from_ldtk_rel_path(current_level.bgRelPath)
            assert(background_found, "battle background asset not found")

            asset_info, asset_ok := background_asset.info.(engine.Asset_Info_Image)
            if asset_ok {
                entity := engine.entity_create_entity("Background: Battle")
                engine.entity_set_component(entity, engine.Component_Transform {
                    position = { 0, GRID_SIZE / 2 },
                    scale = { 1, 1 },
                })
                engine.entity_set_component(entity, engine.Component_Sprite {
                    texture_asset = background_asset.id,
                    texture_size = _mem.platform.window_size,
                    z_index = -99,
                    tint = { 1, 1, 1, 1 },
                    shader_asset = _mem.game.asset_shader_sprite,
                })
                append(&_mem.game.battle_data.entities, entity)
            }
        }

        // TODO: Merge cursor_move_entity and cursor_target_entity, no need to have multiple cursors since we never use them at the same time
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
                tint = { 1, 1, 1, 1 },
                shader_asset = _mem.game.asset_shader_sprite,
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
                tint = { 1, 1, 1, 1 },
                shader_asset = _mem.game.asset_shader_sprite,
            })
            append(&_mem.game.battle_data.entities, entity)
            _mem.game.battle_data.cursor_target_entity = entity
        }

        {
            entity := engine.entity_create_entity("Cursor: unit")
            component_transform, _ := engine.entity_set_component(entity, engine.Component_Transform {
                position = grid_to_world_position_center(OFFSCREEN_POSITION),
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
                shader_asset = _mem.game.asset_shader_sprite,
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
                shader_asset = _mem.game.asset_shader_sprite,
            })
            append(&_mem.game.battle_data.entities, entity)
            _mem.game.battle_data.unit_preview_entity = entity
        }

        spawners_ally := [dynamic]Entity {}
        spawners_foe := [dynamic]Entity {}
        {
            metas := engine.entity_get_components_by_entity(engine.Component_Tile_Meta)
            for meta, entity in metas {
                if meta.entity_uid == LDTK_ENTITY_ID_SPAWNER_ALLY {
                    append(&spawners_ally, Entity(entity))
                }
                if meta.entity_uid == LDTK_ENTITY_ID_SPAWNER_FOE {
                    append(&spawners_foe, Entity(entity))
                }
                if meta.entity_uid == LDTK_ENTITY_ID_EXIT {
                    component_transform, _ := engine.entity_get_component(Entity(entity), engine.Component_Transform)
                    append(&_mem.game.battle_data.exits, world_to_grid_position(component_transform.position))
                }
                if meta.entity_uid == LDTK_ENTITY_ID_SNOWPAL {
                    component_transform, component_transform_err := engine.entity_get_component(Entity(entity), engine.Component_Transform)
                    assert(component_transform_err == .None)

                    unit_index := append_unit_from_asset_name("unit_snowpal")
                    unit := spawn_unit(unit_index, world_to_grid_position(component_transform.position), .Left)
                    unit.hide_in_turn_order = true
                }
                if meta.entity_uid == LDTK_ENTITY_ID_STALACTITE {
                    component_transform, component_transform_err := engine.entity_get_component(Entity(entity), engine.Component_Transform)
                    assert(component_transform_err == .None)

                    unit_index := append_unit_from_asset_name("unit_stalactite")
                    unit := spawn_unit(unit_index, world_to_grid_position(component_transform.position), .Left)
                    unit.hide_in_turn_order = true
                }
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

        _mem.game.fog_cells = make([]Cell_Fog, len(_mem.game.battle_data.level.grid), _mem.game.game_mode.arena.allocator)
        for i := 0; i < len(_mem.game.battle_data.level.grid); i += 1 {
            _mem.game.fog_cells[i] = Cell_Fog { engine.grid_index_to_position(i, _mem.game.battle_data.level.size), true }
        }

        for unit_index in _mem.game.battle_data.units {
            unit := &_mem.game.units[unit_index]
            unit.stat_ctr = 0
            unit.stat_health = unit.stat_health_max

            unit.in_battle = unit.alliance == .Ally
            if unit.alliance == .Ally {
                visible_units := fog_remove_unit_vision(unit.grid_position, unit.stat_vision)
                activate_units(visible_units)
                unit.controlled_by = AUTO_PLAY ? .CPU : .Player
            }
        }
        log.infof("Battle:           %v", BATTLE_LEVELS[_mem.game.battle_index - 1])

        scene_transition_start(.Unswipe_Left_To_Right)
    }

    if game_mode_running() {
        if scene_transition_is_done() == false {
            return
        }

        shader_default, shader_default_err := engine.asset_get_asset_info_shader(_mem.game.asset_shader_sprite)
        shader_line, shader_line_err := engine.asset_get_asset_info_shader(_mem.game.asset_shader_line)

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
                                if unit.in_battle {
                                    if unit_can_gain_ctr(unit) {
                                        unit.stat_ctr += unit.stat_speed
                                    }
                                }
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

                        if current_unit.alliance == .Ally {
                            fog_remove_unit_vision(current_unit.grid_position, current_unit.stat_vision)
                        }

                        update_grid_flags(&_mem.game.battle_data.level)
                        if unit_can_take_turn(current_unit) == false || _mem.game.battle_data.turn.moved && _mem.game.battle_data.turn.acted {
                            if _mem.game.cheat_act_repeatedly == false {
                                battle_mode_transition(.End_Turn)
                            }
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
                        ability_id := Ability_Id(0)

                        switch current_unit.controlled_by {
                            case .CPU: {
                                action, ability_id = cpu_choose_action(current_unit)
                            }

                            case .Player: {
                                if _mem.game.player_inputs.cancel.pressed {
                                    action = .Wait
                                }

                                if game_ui_window(fmt.tprintf("%v's turn", current_unit.name), nil, .NoResize | .NoMove | .NoCollapse) {
                                    engine.ui_set_window_size_vec2({ 300, 200 }, .Always)
                                    engine.ui_set_window_pos_vec2({ f32(_mem.platform.window_size.x - 350), f32(_mem.platform.window_size.y - 300) }, .Always)

                                    health_progress := f32(current_unit.stat_health) / f32(current_unit.stat_health_max)
                                    engine.ui_progress_bar_label(health_progress, fmt.tprintf("HP: %v/%v", current_unit.stat_health, current_unit.stat_health_max))

                                    if game_ui_button("Move", _mem.game.battle_data.turn.moved && _mem.game.cheat_move_repeatedly == false) {
                                        action = .Move
                                    }
                                    if game_ui_button("Snowball", _mem.game.battle_data.turn.acted && _mem.game.cheat_act_repeatedly == false) {
                                        action = .Ability
                                        ability_id = 0
                                    }
                                    if game_ui_button("Push", _mem.game.battle_data.turn.acted && _mem.game.cheat_act_repeatedly == false) {
                                        action = .Ability
                                        ability_id = 1
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
                                if current_unit.controlled_by == .Player && _mem.game.cheat_move_anywhere {
                                    _mem.game.battle_data.turn.move_valid_targets = flood_search(_mem.game.battle_data.level.size, _mem.game.battle_data.level.grid, current_unit.grid_position, 999, search_filter_teleport_target, CARDINAL_DIRECTIONS, _mem.game.battle_data.plan_arena.allocator)
                                } else {
                                    _mem.game.battle_data.turn.move_valid_targets = flood_search(_mem.game.battle_data.level.size, _mem.game.battle_data.level.grid, current_unit.grid_position, current_unit.stat_move, search_filter_move_target, EIGHT_DIRECTIONS, _mem.game.battle_data.plan_arena.allocator)
                                }
                                exclude_cells_with_units(&_mem.game.battle_data.turn.move_valid_targets)
                                append_to_highlighted_cells(_mem.game.battle_data.turn.move_valid_targets, current_unit.alliance == .Ally ? .Ally : .Foe, _mem.game.battle_data.plan_arena.allocator)
                                battle_mode_transition(.Target_Move)
                            }
                            case .Ability: {
                                _mem.game.battle_data.turn.move_target = OFFSCREEN_POSITION
                                _mem.game.battle_data.turn.ability_id = ability_id
                                _mem.game.battle_data.turn.ability_target = current_unit.grid_position
                                ability := &_mem.game.abilities[_mem.game.battle_data.turn.ability_id]
                                if current_unit.controlled_by == .Player && _mem.game.cheat_act_anywhere {
                                    _mem.game.battle_data.turn.ability_valid_targets = flood_search(_mem.game.battle_data.level.size, _mem.game.battle_data.level.grid, current_unit.grid_position, 999, search_filter_ability_target, CARDINAL_DIRECTIONS, _mem.game.battle_data.plan_arena.allocator)
                                } else {
                                    _mem.game.battle_data.turn.ability_valid_targets = line_of_sight_search(current_unit.grid_position, ability.range, _mem.game.battle_data.plan_arena.allocator)
                                }
                                append_to_highlighted_cells(_mem.game.battle_data.turn.ability_valid_targets, current_unit.alliance == .Ally ? .Ally : .Foe, _mem.game.battle_data.plan_arena.allocator)
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
                        if current_unit.controlled_by == .CPU {
                            cpu_choose_move_target(current_unit)
                            _mem.game.battle_data.turn.cpu_delay = 300 * time.Millisecond
                        }
                    }

                    if battle_mode_running() {
                        entity_move_grid(cursor_move, _mem.game.battle_data.turn.move_target)
                        action := Menu_Action.None

                        switch current_unit.controlled_by {
                            case .CPU: {
                                if timer_done(&_mem.game.battle_data.turn.cpu_delay) {
                                    action = .Confirm
                                }
                            }

                            case .Player: {
                                if _mem.game.player_inputs.cancel.pressed {
                                    action = .Cancel
                                }
                                if _mem.game.player_inputs.confirm.pressed || _mem.game.player_inputs.mouse_left.pressed {
                                    action = .Confirm
                                }
                                if _mem.platform.mouse_moved || _mem.game.player_inputs.mouse_left.pressed {
                                    _mem.game.battle_data.turn.move_target = _mem.game.mouse_grid_position
                                }
                                if _mem.game.battle_data.aim_repeater.value != { 0, 0 } {
                                    _mem.game.battle_data.turn.move_target = _mem.game.battle_data.turn.move_target + _mem.game.battle_data.aim_repeater.value
                                }
                                if _mem.game.battle_data.move_repeater.value != { 0, 0 } {
                                    _mem.game.battle_data.turn.move_target = _mem.game.battle_data.turn.move_target + _mem.game.battle_data.move_repeater.value
                                }

                                // FIXME: instead of recreating this path every frame in temp_allocator, store it inside a scratch allocator (that we can free)
                                path, path_ok := find_path(_mem.game.battle_data.level.grid, _mem.game.battle_data.level.size, current_unit.grid_position, _mem.game.battle_data.turn.move_target, valid_cells = _mem.game.battle_data.turn.move_valid_targets[:], allocator = context.temp_allocator)
                                _mem.game.battle_data.turn.move_path = path
                            }
                        }

                        {
                            _mem.game.battle_data.turn.move_path_valid = len(_mem.game.battle_data.turn.move_path) > 0 && slice.contains(_mem.game.battle_data.turn.move_valid_targets[:], slice.last(_mem.game.battle_data.turn.move_path))
                            component_sprite, component_sprite_err := engine.entity_get_component(_mem.game.battle_data.cursor_move_entity, engine.Component_Sprite)
                            assert(component_sprite_err == .None)
                            component_sprite.tint = _mem.game.battle_data.turn.move_path_valid ? COLOR_IN_RANGE : COLOR_OUT_OF_RANGE
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
                                path, path_ok := find_path(_mem.game.battle_data.level.grid, _mem.game.battle_data.level.size, current_unit.grid_position, _mem.game.battle_data.turn.move_target, valid_cells = _mem.game.battle_data.turn.move_valid_targets[:], allocator = _mem.game.battle_data.turn_arena.allocator)
                                if is_valid_target && path_ok {
                                    _mem.game.battle_data.turn.move_path = path
                                    if current_unit.controlled_by == .Player {
                                        engine.audio_play_sound(_mem.game.asset_sound_confirm)
                                    }
                                    clear(&_mem.game.highlighted_cells)
                                    battle_mode_transition(.Perform_Move)
                                } else {
                                    log.warnf("       Invalid target!")
                                    if current_unit.controlled_by == .Player {
                                        engine.audio_play_sound(_mem.game.asset_sound_invalid)
                                    } else {
                                        battle_mode_transition(.Select_Action)
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
                                    assert(direction != .Invalid)
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
                        if current_unit.controlled_by == .CPU {
                            ability := &_mem.game.abilities[_mem.game.battle_data.turn.ability_id]
                            cpu_choose_ability_target(ability, current_unit)
                            _mem.game.battle_data.turn.cpu_delay = 300 * time.Millisecond
                        }
                    }

                    if battle_mode_running() {
                        entity_move_grid(cursor_target, _mem.game.battle_data.turn.ability_target)
                        action := Menu_Action.None

                        switch current_unit.controlled_by {
                            case .CPU: {
                                if timer_done(&_mem.game.battle_data.turn.cpu_delay) {
                                    action = .Confirm
                                }
                            }

                            case .Player: {
                                if _mem.game.player_inputs.cancel.pressed {
                                    action = .Cancel
                                }
                                if _mem.game.player_inputs.confirm.pressed || _mem.game.player_inputs.mouse_left.pressed {
                                    action = .Confirm
                                }
                                if _mem.platform.mouse_moved || _mem.game.player_inputs.mouse_left.pressed {
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

                        {
                            _mem.game.battle_data.turn.ability_path_valid = len(_mem.game.battle_data.turn.ability_path) > 0 && slice.contains(_mem.game.battle_data.turn.ability_valid_targets[:], slice.last(_mem.game.battle_data.turn.ability_path))
                            component_sprite, component_sprite_err := engine.entity_get_component(_mem.game.battle_data.cursor_target_entity, engine.Component_Sprite)
                            assert(component_sprite_err == .None)
                            component_sprite.tint = _mem.game.battle_data.turn.ability_path_valid ? COLOR_IN_RANGE : COLOR_OUT_OF_RANGE
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
                                if is_valid_target {
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

                        _mem.game.battle_data.turn.ability_path = {}
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
                            shader_asset = _mem.game.asset_shader_sprite,
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
                        scene_transition_start(.Swipe_Left_To_Right)
                    }

                    if battle_mode_running() {
                        if scene_transition_is_done() {
                            game_mode_transition(.WorldMap)
                        }
                    }
                }

                case .Defeat: {
                    engine.profiler_zone(".Defeat")
                    if battle_mode_entering() {
                        engine.profiler_message("defeat")
                        log.warnf("Game over")
                        scene_transition_start(.Swipe_Left_To_Right)
                    }

                    if battle_mode_running() {
                        if scene_transition_is_done() {
                            game_mode_transition(.WorldMap)
                        }
                    }
                }
            }
        }

        unit_preview_rendering.texture_position = unit_rendering.texture_position

        when ODIN_DEBUG {
            game_ui_window_battle(&_mem.game.debug_ui_window_battle)
        }
        @(static) active_units_count: int
        if game_ui_window(fmt.tprintf("Turn order (%v)", active_units_count), nil, .AlwaysAutoResize | .NoDocking | .NoResize | .NoMove | .NoCollapse) {
            engine.ui_set_window_pos_vec2({ f32(_mem.platform.window_size.x - 200 - 30), 30 }, .Always)

            sorted_units := slice.clone(_mem.game.battle_data.units[:], context.temp_allocator)
            sort.heap_sort_proc(sorted_units, sort_units_by_ctr)

            active_units_count = 0
            for unit_index in sorted_units {
                unit := &_mem.game.units[unit_index]
                if unit.in_battle == false || unit_is_alive(unit) == false || unit.hide_in_turn_order {
                    continue
                }

                if engine.ui_draw_sprite_component(unit.entity) {
                    engine.ui_same_line()
                }

                color := engine.Vec4 { 0.2, 0.2, 0.2, 1}
                if unit.alliance == .Foe {
                    color = { 1, 0.4, 0.4, 1 }
                }
                if unit.alliance == .Ally {
                    color = { 0.4, 0.4, 1, 1 }
                }
                engine.ui_push_style_color(.Text, color)
                defer engine.ui_pop_style_color(1)

                label := fmt.tprintf("%v (CTR: %v) ###%v", unit.name, unit.stat_ctr, unit_index)
                disabled := unit_index != _mem.game.battle_data.current_unit
                game_ui_button(label, disabled)
                active_units_count += 1
            }
        }

        if _mem.game.battle_data != nil && len(_mem.game.battle_data.turn.move_path) > 0 {
            color := _mem.game.battle_data.turn.move_path_valid ? COLOR_IN_RANGE : COLOR_OUT_OF_RANGE
            points := make([]Vector2f32, len(_mem.game.battle_data.turn.move_path), context.temp_allocator)
            for point, i in _mem.game.battle_data.turn.move_path {
                points[i] = grid_to_world_position_center(point)
            }
            engine.renderer_push_line(points, shader_line, color)
        }

        if _mem.game.battle_data != nil && len(_mem.game.battle_data.turn.ability_path) > 0 {
            color := _mem.game.battle_data.turn.ability_path_valid ? COLOR_IN_RANGE : COLOR_OUT_OF_RANGE
            points := make([]Vector2f32, len(_mem.game.battle_data.turn.ability_path), context.temp_allocator)
            for point, i in _mem.game.battle_data.turn.ability_path {
                points[i] = grid_to_world_position_center(point)
            }
            engine.renderer_push_line(points, shader_line, color)
        }

        if _mem.game.debug_draw_grid {
            engine.profiler_zone("debug_draw_grid", PROFILER_COLOR_RENDER)

            asset_image_spritesheet, asset_image_spritesheet_ok := engine.asset_get(_mem.game.asset_image_spritesheet)
            if asset_image_spritesheet_ok && asset_image_spritesheet.state == .Loaded {
                image_info_debug, asset_ok := asset_image_spritesheet.info.(engine.Asset_Info_Image)
                texture_position, texture_size, pixel_size := engine.texture_position_and_size(image_info_debug, { 40, 40 }, { 8, 8 })
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
                        image_info_debug,
                        texture_position, texture_size,
                        0,
                        shader_default,
                    )
                }
            }
        }
    }

    if game_mode_exiting() {
        engine.entity_reset_memory()
        engine.asset_unload(_mem.game.asset_map_areas)
        _mem.game.battle_data = nil
    }
}

spawn_units :: proc(spawners: [dynamic]Entity, units: [dynamic]int, direction: Directions, alliance: Unit_Alliances) {
    for spawner, i in spawners {
        if i >= len(units) {
            break
        }

        component_transform, component_transform_err := engine.entity_get_component(spawner, engine.Component_Transform)
        assert(component_transform_err == .None)

        unit := spawn_unit(units[i], world_to_grid_position(component_transform.position), direction)
        unit.alliance = alliance
    }
}

spawn_unit :: proc(unit_index: int, grid_position: Vector2i32, direction: Directions) -> ^Unit {
    unit := &_mem.game.units[unit_index]
    unit.grid_position = grid_position
    unit.direction = direction
    unit.entity = unit_create_entity(unit, has_limbs = false)
    append(&_mem.game.battle_data.units, unit_index)
    return unit
}

sort_units_by_ctr :: proc(a, b: int) -> int {
    return int(_mem.game.units[b].stat_ctr - _mem.game.units[a].stat_ctr)
}

create_cell_highlight :: proc(positions: [dynamic]Vector2i32, type: Cell_Highlight_Type, allocator := context.allocator) -> [dynamic]Cell_Highlight {
    context.allocator = allocator
    result := [dynamic]Cell_Highlight {}
    for position in positions {
        append(&result, Cell_Highlight { position, type })
    }
    return result
}

is_valid_teleport_destination :: proc(cell: Grid_Cell) -> bool { return cell >= { .Move } }
is_valid_move_destination :: proc(cell: Grid_Cell) -> bool { return cell >= { .Move, .Grounded } }
is_valid_ability_destination :: proc(cell: Grid_Cell) -> bool { return cell >= { .Move } }
is_see_through :: proc(cell: Grid_Cell) -> bool { return cell >= { .See } }

search_filter_teleport_target : Flood_Search_Filter_Proc : proc(cell_position: Vector2i32, grid_size: Vector2i32, grid: []Grid_Cell) -> u8 {
    grid_index := engine.grid_position_to_index(cell_position, grid_size.x)
    cell := grid[grid_index]
    return is_valid_teleport_destination(cell) ? 2 : 0
}
search_filter_move_target : Flood_Search_Filter_Proc : proc(cell_position: Vector2i32, grid_size: Vector2i32, grid: []Grid_Cell) -> u8 {
    grid_index := engine.grid_position_to_index(cell_position, grid_size.x)
    cell := grid[grid_index]
    return is_valid_move_destination(cell) ? 2 : 0
}

// TODO: Check range and FOV
search_filter_ability_target : Flood_Search_Filter_Proc : proc(cell_position: Vector2i32, grid_size: Vector2i32, grid: []Grid_Cell) -> u8 {
    grid_index := engine.grid_position_to_index(cell_position, grid_size.x)
    cell := grid[grid_index]
    return is_valid_ability_destination(cell) ? 2 : 0
}

create_animation_unit_throw :: proc(actor: ^Unit, target: Vector2i32, projectile: Entity) -> ^engine.Animation {
    context.allocator = _mem.game.battle_data.turn_arena.allocator

    distance := Vector2f32(linalg.array_cast(target, f32) - linalg.array_cast(actor.grid_position, f32))
    aim_direction := linalg.vector_normalize(distance)

    animation := engine.animation_create_animation(2)
    component_limbs, component_limbs_err := engine.entity_get_component(actor.entity, Component_Limbs)
    if component_limbs_err == .None {
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
    }

    engine.animation_make_event(animation, 0.5, auto_cast(event_proc), Event_Data { actor, target, projectile })
    Event_Data :: struct {
        actor:      ^Unit,
        target:     Vector2i32,
        projectile: Entity,
    }
    event_proc :: proc(user_data: ^Event_Data) {
        queue.push_back(_mem.game.battle_data.turn.animations, create_animation_projectile(user_data.actor, user_data.target, user_data.projectile))
    }

    return animation

}

create_animation_projectile :: proc(actor: ^Unit, target: Vector2i32, projectile: Entity) -> ^engine.Animation {
    context.allocator = _mem.game.battle_data.turn_arena.allocator

    distance := Vector2f32(linalg.array_cast(target, f32) - linalg.array_cast(actor.grid_position, f32))
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

    engine.animation_make_event(animation, 0.9, auto_cast(event_proc), Event_Data { actor })
    Event_Data :: struct {
        actor:         ^Unit,
    }
    event_proc :: proc(user_data: ^Event_Data) {
        actor := user_data.actor
        target := find_unit_at_position(_mem.game.battle_data.turn.ability_target)
        if target != nil {
            ability := &_mem.game.abilities[_mem.game.battle_data.turn.ability_id]
            ability_damage := ability_calculate_damage(ability, actor, target)
            unit_apply_damage(target, ability_damage, ability.damage_type)
            path := ability_apply_push(ability, actor, target)
            if len(path) > 0 {
                last_valid_index := 0
                for i := 1; i < len(path); i += 1 {
                    if find_unit_at_position(path[i]) != nil {
                        break
                    }
                    last_valid_index = i
                }

                if last_valid_index == len(path) - 1 {
                    fall_height : i32 = 0
                    for i := 1; i < len(path); i += 1 {
                        // TODO: different animations for push and fall
                        queue.push_back(_mem.game.battle_data.turn.animations, create_animation_unit_fall(target, target.direction, path[i-1], path[i]))
                        fall_height += path[i-1].y - path[i].y
                    }
                    target.grid_position = slice.last(path)

                    // TODO: do this inside the fall animation (event)?
                    if abs(fall_height) > FALL_DAMAGE_THRESHOLD {
                        fall_damage := -1 + i32(abs(fall_height) / 2)
                        unit_apply_damage(target, ability_damage, Damage_Types.Fall)
                    }
                } else {
                    log.warnf("%v would have been pushed on an occupied cell (%v), aborting", target.name, path[last_valid_index])
                }
            }

            direction := get_direction_from_points(actor.grid_position, _mem.game.battle_data.turn.ability_target)
            if target.stat_health == 0 {
                queue.push_back(_mem.game.battle_data.turn.animations, create_animation_unit_death(target, direction))
            } else {
                queue.push_back(_mem.game.battle_data.turn.animations, create_animation_unit_hit(target, direction))
            }
        }
    }

    return animation

}

create_animation_unit_flip :: proc(unit: ^Unit, direction: Directions) -> ^engine.Animation {
    assert(direction != .Invalid)
    context.allocator = _mem.game.battle_data.turn_arena.allocator

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
    context.allocator = _mem.game.battle_data.turn_arena.allocator

    animation := engine.animation_create_animation(5)
    component_transform, err_transform := engine.entity_get_component(unit.entity, engine.Component_Transform)
    engine.animation_add_curve(animation, engine.Animation_Curve_Scale {
        target = &component_transform.scale,
        timestamps = { 0.0, 0.5, 1.0 },
        frames = { { 1 * f32(unit.direction), 1 }, { 0.8 * f32(unit.direction), 1.2 }, { 1 * f32(unit.direction), 1 } },
    })
    engine.animation_make_event(animation, 0, event_proc)
    event_proc :: proc(user_data: rawptr) {
        engine.audio_play_sound(_mem.game.asset_sound_hit)
    }
    return animation
}

create_animation_unit_death :: proc(unit: ^Unit, direction: Directions) -> ^engine.Animation {
    context.allocator = _mem.game.battle_data.turn_arena.allocator

    animation := engine.animation_create_animation(5)
    component_transform, err_transform := engine.entity_get_component(unit.entity, engine.Component_Transform)
    engine.animation_add_curve(animation, engine.Animation_Curve_Scale {
        target = &component_transform.scale,
        timestamps = { 0.0, 1.0 },
        frames = { component_transform.scale, { 0, 0 } },
    })
    // TODO: animate limbs
    engine.animation_make_event(animation, 0, event_proc)
    event_proc :: proc(user_data: rawptr) {
        engine.audio_play_sound(_mem.game.asset_sound_hit) // TODO: use death sfx
    }
    return animation
}

create_animation_unit_move :: proc(unit: ^Unit, direction: Directions, start_position, end_position: Vector2i32) -> ^engine.Animation {
    context.allocator = _mem.game.battle_data.turn_arena.allocator

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
    if err_limbs == .None {
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
    }
    make_unit_moved_event(animation, unit, end_position)

    return animation
}
create_animation_unit_fall :: proc(unit: ^Unit, direction: Directions, start_position, end_position: Vector2i32) -> ^engine.Animation {
    context.allocator = _mem.game.battle_data.turn_arena.allocator

    s := grid_to_world_position_center(start_position)
    e := grid_to_world_position_center(end_position)
    animation := engine.animation_create_animation(20)
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
            0.50,
            1.00,
        },
        frames = {
            { f32(direction) * 1.0, 1.0 },
            { f32(direction) * 0.9, 1.1 },
            { f32(direction) * 1.0, 1.0 },
        },
    })
    make_unit_moved_event(animation, unit, end_position)

    return animation
}

make_unit_moved_event :: proc(animation: ^engine.Animation, unit: ^Unit, end_position: Vector2i32) {
    engine.animation_make_event(animation, 1, auto_cast(event_proc), Event_Data { unit, end_position })
    Event_Data :: struct {
        actor:        ^Unit,
        end_position: Vector2i32,
    }
    event_proc :: proc(user_data: ^Event_Data) {
        if user_data.actor.alliance == .Ally {
            visible_units := fog_remove_unit_vision(user_data.end_position, user_data.actor.stat_vision)
            activate_units(visible_units)
        }
    }
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
    context.allocator = _mem.game.battle_data.turn_arena.allocator
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

unit_create_entity :: proc(unit: ^Unit, has_limbs: bool = true) -> Entity {
    SPRITE_SIZE :: Vector2i32 { 8, 8 }
    palette : i32 = 1
    if unit.alliance == .Foe {
        palette = 2
    }

    entity := engine.entity_create_entity(unit.name)
    engine.entity_set_component(entity, Component_Flag { { .Unit } })

    assert(unit.direction != .Invalid)
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
        shader_asset = _mem.game.asset_shader_sprite,
    })

    append(&_mem.game.battle_data.entities, entity)

    if has_limbs {
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
            shader_asset = _mem.game.asset_shader_sprite,
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
            shader_asset = _mem.game.asset_shader_sprite,
        })
        engine.entity_set_component(entity, Component_Limbs { hand_left = hand_left, hand_right = hand_right })
        append(&_mem.game.battle_data.entities, hand_left)
        append(&_mem.game.battle_data.entities, hand_right)
    }

    return entity
}

entity_move_grid :: proc(entity: Entity, grid_position: Vector2i32, loc := #caller_location) {
    assert(entity != engine.ENTITY_INVALID, "Can't move invalid entity", loc)
    component_transform, component_transform_ok := engine.entity_get_component(entity, engine.Component_Transform)
    assert(component_transform_ok != .Entity_Not_Found, "Can't move entity with no Component_Transform", loc)
    component_transform.position = grid_to_world_position_center(grid_position)
}

unit_can_take_turn :: proc(unit: ^Unit, loc := #caller_location) -> bool {
    assert(unit != nil, "invalid unit", loc)
    return unit.stat_ctr >= TAKE_TURN && unit_is_alive(unit)
}

unit_can_gain_ctr :: proc(unit: ^Unit, loc := #caller_location) -> bool {
    assert(unit != nil, "invalid unit", loc)
    return unit_is_alive(unit)
}

unit_is_alive :: proc(unit: ^Unit, loc := #caller_location) -> bool {
    assert(unit != nil, "invalid unit", loc)
    return unit.stat_health > 0
}

ability_is_valid_target :: proc(ability: ^Ability, actor, target: ^Unit) -> bool {
    return target != nil && unit_is_alive(target) && target != actor && target.alliance != actor.alliance
}

ability_calculate_damage :: proc(ability: ^Ability, actor, target: ^Unit) -> (damage_taken: i32) {
    // TODO: use stats like defense/resistance/etc
    return ability.damage
}
ability_apply_push :: proc(ability: ^Ability, actor, target: ^Unit) -> (path: []Vector2i32) {
    context.allocator = _mem.game.battle_data.turn_arena.allocator

    if ability.push == 0 {
        return {}
    }

    level := &_mem.game.battle_data.level
    current_position := target.grid_position
    path_dynamic := make([dynamic]Vector2i32)
    append(&path_dynamic, current_position)

    {
        diff := target.grid_position - actor.grid_position
        direction_x : i32 = diff.x > 0 ? 1 : -1
        direction := Vector2i32 { direction_x, 0 }
        cell_in_direction, cell_in_direction_found := get_cell_at_position(level, current_position + direction)
        if cell_in_direction_found && (.Move in cell_in_direction) {
            current_position += direction
            append(&path_dynamic, current_position)
        }
    }
    {
        cell_below, cell_below_found := get_cell_at_position(level, current_position + GRAVITY_DIRECTION)
        for cell_below_found && (.Fall in cell_below) {
            current_position += GRAVITY_DIRECTION
            append(&path_dynamic, current_position)
            cell_below, cell_below_found = get_cell_at_position(level, current_position + GRAVITY_DIRECTION)
        }
    }

    path = path_dynamic[:]
    return
}

win_condition_reached :: proc() -> bool {
    for unit_index in _mem.game.party {
        unit := _mem.game.units[unit_index]
        for exit_position in _mem.game.battle_data.exits {
            if unit.grid_position == exit_position {
                log.debugf("%v reached exit point: %v", unit.name, )
                return true
            }
        }
    }
    return false
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

        if engine.ui_child("left", { 250, region.y }, false) {
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
            if engine.ui_tree_node("Mouse cursor", { .DefaultOpen }) {
                engine.ui_text("mouse_grid_pos:     %v", _mem.game.mouse_grid_position)
                mouse_cell, mouse_cell_found := get_cell_at_position(&_mem.game.battle_data.level, _mem.game.mouse_grid_position)
                if mouse_cell_found {
                    engine.ui_text(" - Climb:    %v", .Climb in mouse_cell ? "x" : "")
                    engine.ui_text(" - Fall:     %v", .Fall in mouse_cell ? "x" : "")
                    engine.ui_text(" - Move:     %v", .Move in mouse_cell ? "x" : "")
                    engine.ui_text(" - Grounded: %v", .Grounded in mouse_cell ? "x" : "")
                    engine.ui_text(" - See:      %v", .See in mouse_cell ? "x" : "")
                    engine.ui_text(" - Fog_Half: %v", .Fog_Half in mouse_cell ? "x" : "")
                    engine.ui_text(" ------------ ")
                    engine.ui_text(" %#v", _mem.game.fog_cells[engine.grid_position_to_index(_mem.game.mouse_grid_position, _mem.game.battle_data.level.size.x)])
                }
            }
            if engine.ui_tree_node("Turn") {
                engine.ui_text("  move:               %v", _mem.game.battle_data.turn.move_target)
                engine.ui_text("  move_path_valid:    %v", _mem.game.battle_data.turn.move_path_valid)
                engine.ui_text("  target:             %v", _mem.game.battle_data.turn.ability_target)
                engine.ui_text("  ability_path_valid: %v", _mem.game.battle_data.turn.ability_path_valid)
                engine.ui_text("  ability:            %v", _mem.game.battle_data.turn.ability_id)
                engine.ui_text("  acted:              %v", _mem.game.battle_data.turn.acted)
                engine.ui_text("  moved:              %v", _mem.game.battle_data.turn.moved)
            }

            if engine.ui_tree_node("level", { .DefaultOpen }) {
                engine.ui_text("len(grid): %v", len(_mem.game.battle_data.level.grid))
                engine.ui_text("size:      %v", _mem.game.battle_data.level.size)
            }
        }

        engine.ui_same_line()
        if engine.ui_child("middle", { region.x - 500, region.y }, false, .NoBackground) {
            columns := []string { "unit_index", "name", "pos", "ctr", "hp", "actions" }
            if engine.ui_table(columns) {
                for unit_index in _mem.game.battle_data.units {
                    engine.ui_table_next_row()
                    unit := &_mem.game.units[unit_index]
                    for column, column_index in columns {
                        engine.ui_table_set_column_index(i32(column_index))
                        switch column {
                            case "unit_index": engine.ui_text("%v", unit_index)
                            case "name": {
                                color := engine.Vec4 { 1, 1, 1, 1}
                                if unit.alliance == .Foe {
                                    color = { 1, 0.4, 0.4, 1 }
                                }
                                if unit.in_battle == false {
                                    color = { 0.7, 0.7, 0.7, 1 }
                                }
                                if unit == &_mem.game.units[_mem.game.battle_data.current_unit] {
                                    color = { 0.7, 0.7, 0, 1 }
                                }
                                engine.ui_push_style_color(.Text, color)
                                engine.ui_text("%v (%v)", unit.name, unit.alliance)
                                engine.ui_pop_style_color(1)
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
                                engine.ui_push_id(i32(unit_index))
                                if engine.ui_button_disabled("Player", unit.controlled_by == .Player) {
                                    unit.controlled_by = .Player
                                }
                                engine.ui_same_line()
                                if engine.ui_button_disabled("CPU", unit.controlled_by == .CPU) {
                                    unit.controlled_by = .CPU
                                }
                                engine.ui_same_line()
                                if engine.ui_button("Turn") {
                                    _mem.game.battle_data.current_unit = unit_index
                                }
                                engine.ui_same_line()
                                if engine.ui_button("Kill") {
                                    unit.stat_health = 0
                                }
                                engine.ui_same_line()
                                if engine.ui_button(fmt.tprintf("%v", unit.in_battle ? "Remove from battle" : "Add to battle")) {
                                    unit.in_battle = !unit.in_battle
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
            if engine.ui_button("Turn") {
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
        if engine.ui_child("right", { 250, region.y }, false, .NoBackground) {
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
            engine.ui_input_int("stat_vision", &unit.stat_vision)
            {
                progress := f32(unit.stat_ctr) / 100
                engine.ui_progress_bar_label(progress, fmt.tprintf("CTR: %v", unit.stat_ctr))
            }
            {
                progress := f32(unit.stat_health) / f32(unit.stat_health_max)
                engine.ui_progress_bar_label(progress, fmt.tprintf("HP: %v/%v", unit.stat_health, unit.stat_health_max))
            }
            if engine.ui_tree_node("unit") {
                engine.ui_text("%#v", unit)
            }
        }
    }
}

// FIXME: Don't do this on the main thread or at least don't block while doing it, because this can be slow later down the line
cpu_choose_action :: proc(current_unit: ^Unit) -> (Battle_Action, Ability_Id) {
    engine.profiler_zone("cpu_choose_action")

    if _mem.game.battle_data.turn.moved == false && _mem.game.battle_data.turn.cpu_retries < 5 {
        _mem.game.battle_data.turn.cpu_retries += 1
        return .Move, 0
    }

    if _mem.game.battle_data.turn.acted == false && _mem.game.battle_data.turn.cpu_retries < 5 {
        random_ability_index := rand.int31_max(i32(len(_mem.game.abilities)), &_mem.game.rand)
        return .Ability, Ability_Id(random_ability_index)
    }

    return .Wait, 0
}

cpu_choose_move_target :: proc(current_unit: ^Unit) {
    engine.profiler_zone("cpu_choose_move_target")

    valid_targets := _mem.game.battle_data.turn.move_valid_targets
    best_target := OFFSCREEN_POSITION
    if len(valid_targets) == 0 {
        log.errorf("[CPU] No valid targets to move?!")
        return
    }

    random_cell_index := rand.int_max(len(valid_targets), &_mem.game.rand)
    best_target = valid_targets[random_cell_index]

    log.infof("[CPU] Move target: %v", best_target)
    _mem.game.battle_data.turn.move_target = best_target
}

cpu_choose_ability_target :: proc(ability: ^Ability, current_unit: ^Unit) {
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

        ability := &_mem.game.abilities[_mem.game.battle_data.turn.ability_id]
        if ability_is_valid_target(ability, current_unit, target_unit) {
            break
        }
    }

    log.infof("[CPU] Ability (%v) target: %v", ability.name, best_target)
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


fog_remove_unit_vision :: proc(grid_position: Vector2i32, distance: i32) -> []^Unit {
    cell_to_remove := line_of_sight_search(grid_position, distance, context.temp_allocator)
    units_found := make([dynamic]^Unit, context.temp_allocator)

    grid := _mem.game.battle_data.level.grid
    grid_size := _mem.game.battle_data.level.size
    for cell_position in cell_to_remove {
        for fog_cell, grid_index in _mem.game.fog_cells {
            if fog_cell.position == cell_position {
                grid_cell := _mem.game.battle_data.level.grid[grid_index]
                if is_see_through(grid_cell) {
                    _mem.game.fog_cells[grid_index].active = false
                } else {
                    _mem.game.fog_cells[grid_index].active = .Fog_Half not_in grid_cell
                }

                for unit_index in _mem.game.battle_data.units {
                    unit := &_mem.game.units[unit_index]
                    if unit.grid_position == cell_position {
                        append(&units_found, unit)
                    }
                }
            }
        }
    }

    return units_found[:]
}

append_to_highlighted_cells :: proc(cells: [dynamic]Vector2i32, type: Cell_Highlight_Type, allocator := context.allocator) {
    for cell_highlight in create_cell_highlight(cells, type, allocator) {
        append(&_mem.game.highlighted_cells, cell_highlight)
    }
}

unit_apply_damage :: proc(target: ^Unit, damage: i32, damage_type: Damage_Types, location := #caller_location) {
    if damage == 0 {
        return
    }
    target.stat_health = math.max(target.stat_health - damage, 0)
    log.debugf("%v received %v damage (%v) <- %v", target.name, damage, damage_type, location)
}

timer_done :: proc(timer: ^time.Duration) -> bool {
    timer^ -= time.Duration(f32(time.Millisecond) * _mem.platform.delta_time * _mem.core.time_scale)
    return timer^ <= 0
}

activate_units :: proc(units_to_activate: []^Unit) {
    for &unit in units_to_activate {
        if unit.in_battle == false {
            unit.in_battle = true
            log.debugf("%v entered battle!", unit.name)
        }
    }
}
