package game

import "core:fmt"
import "core:log"
import "core:slice"
import "core:sort"
import "core:time"
import "core:math"
import "core:container/queue"

import "../engine"

TAKE_TURN     : i32 : 100
TURN_COST     : i32 : 60
ACT_COST      : i32 : 20
MOVE_COST     : i32 : 20
TICK_DURATION :: i64(time.Millisecond * 1)

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
    turn:                 Turn,
    next_tick:            time.Time,
    tick_duration:        i64,
    cursor_move_entity:   Entity,
    cursor_target_entity: Entity,
    unit_preview_entity:  Entity,
    move_repeater:        engine.Input_Repeater,
    aim_repeater:         engine.Input_Repeater,
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
}

Cell_Highlight_Type :: enum { Move, Ability }
Cell_Highlight :: struct {
    grid_index: int,
    type:       Cell_Highlight_Type,
}

Turn :: struct {
    move:       Vector2i32,
    target:     Vector2i32,
    ability:    Ability,
    moved:      bool,
    acted:      bool,
    animations: queue.Queue(^engine.Animation),
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

        engine.asset_load(_game.asset_battle_background, engine.Image_Load_Options { engine.RENDERER_FILTER_NEAREST, engine.RENDERER_CLAMP_TO_EDGE })
        engine.asset_load(_game.asset_areas)

        _engine.renderer.world_camera.position = { NATIVE_RESOLUTION.x / 2, NATIVE_RESOLUTION.y / 2, 0 }
        _game.battle_data.tick_duration = TICK_DURATION
        _game.battle_data.move_repeater = { threshold = 200 * time.Millisecond, rate = 100 * time.Millisecond }
        _game.battle_data.aim_repeater = { threshold = 200 * time.Millisecond, rate = 100 * time.Millisecond }
        clear(&_game.highlighted_cells)

        _game.battle_data.turn = { }
        _game.battle_data.turn.move = OFFSCREEN_POSITION
        _game.battle_data.turn.target = OFFSCREEN_POSITION

        {
            background_asset := &_engine.assets.assets[_game.asset_battle_background]
            asset_info, asset_ok := background_asset.info.(engine.Asset_Info_Image)
            if asset_ok {
                entity := entity_make("Background: Battle")
                entity_add_transform(entity, { f32(asset_info.texture.width) / 4, f32(asset_info.texture.height) / 4 })
                entity_add_sprite(entity, _game.asset_battle_background, texture_size = { asset_info.texture.width, asset_info.texture.height }, z_index = -1)
                append(&_game.battle_data.entities, entity)
            }
        }

        {
            cursor_asset := &_engine.assets.assets[_game.asset_debug_image]
            asset_info, asset_ok := cursor_asset.info.(engine.Asset_Info_Image)
            entity := entity_make("Cursor: move")
            entity_add_transform_grid(entity, OFFSCREEN_POSITION)
            entity_add_sprite(entity, _game.asset_debug_image, grid_position(1, 12), texture_padding = 1, z_index = 9, color = { 0, 0, 1, 1 })
            append(&_game.battle_data.entities, entity)
            _game.battle_data.cursor_move_entity = entity
        }

        {
            cursor_asset := &_engine.assets.assets[_game.asset_debug_image]
            asset_info, asset_ok := cursor_asset.info.(engine.Asset_Info_Image)
            entity := entity_make("Cursor: target")
            entity_add_transform_grid(entity, OFFSCREEN_POSITION)
            entity_add_sprite(entity, _game.asset_debug_image, grid_position(1, 12), texture_padding = 1, z_index = 10, color = { 0, 1, 0, 1 })
            append(&_game.battle_data.entities, entity)
            _game.battle_data.cursor_target_entity = entity
        }

        {
            unit_preview_asset := &_engine.assets.assets[_game.asset_debug_image]
            asset_info, asset_ok := unit_preview_asset.info.(engine.Asset_Info_Image)
            entity := entity_make("Unit preview")
            entity_add_transform_grid(entity, OFFSCREEN_POSITION)
            entity_add_sprite(entity, _game.asset_debug_image, grid_position(3, 12), texture_padding = 1, z_index = 1, color = { 1, 1, 1, 0.5 })
            append(&_game.battle_data.entities, entity)
            _game.battle_data.unit_preview_entity = entity
        }

        {
            areas_asset := &_engine.assets.assets[_game.asset_areas]
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

        for unit_index in _game.battle_data.units {
            unit := &_game.units[unit_index]
            unit.stat_ctr = 0
        }

        log.debugf("Battle:           %v", BATTLE_LEVELS[_game.battle_index - 1])
        // log.debugf("_game.battle_data: %v | %v", _game.battle_data.level, _game.battle_data.entities)
    }

    if game_mode_running() {
        current_unit := &_game.units[_game.battle_data.current_unit]
        unit_transform := &_game.entities.components_transform[current_unit.entity]
        cursor_move := _game.battle_data.cursor_move_entity
        cursor_target := _game.battle_data.cursor_target_entity
        unit_preview := _game.battle_data.unit_preview_entity

        engine.platform_process_repeater(&_game.battle_data.move_repeater, _game.player_inputs.move)
        engine.platform_process_repeater(&_game.battle_data.aim_repeater, _game.player_inputs.aim)

        {
            defer battle_mode_check_exit()
            switch Battle_Mode(_game.battle_data.mode.current) {
                case .Ticking: {
                    if battle_mode_running() {
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
                                if unit.stat_ctr >= TAKE_TURN {
                                    _game.battle_data.current_unit = unit_index
                                    current_unit = &_game.units[_game.battle_data.current_unit]
                                    battle_mode_transition(.Start_Turn)
                                    break
                                }
                            }

                            _game.battle_data.next_tick = { time.now()._nsec + _game.battle_data.tick_duration }
                        }

                        break
                    }

                    battle_mode_exiting()
                }

                case .Start_Turn: {
                    if battle_mode_entering() {
                        _game.battle_data.turn = { }
                        _game.battle_data.turn.move = OFFSCREEN_POSITION
                        _game.battle_data.turn.target = OFFSCREEN_POSITION
                        entity_move_grid(cursor_move, current_unit.grid_position)
                        entity_move_grid(unit_preview, _game.battle_data.turn.move)
                        entity_move_grid(cursor_target, _game.battle_data.turn.target)
                        log.debugf("[TURN] %v (CTR: %v)", current_unit.name, current_unit.stat_ctr)
                        battle_mode_transition(.Select_Action)

                        break
                    }

                    battle_mode_exiting()
                }

                case .Select_Action: {
                    if battle_mode_running() {
                        update_grid_flags(&_game.battle_data.level)
                        _game.battle_data.turn.move = OFFSCREEN_POSITION
                        _game.battle_data.turn.target = OFFSCREEN_POSITION

                        action := Battle_Action.None
                        if _game.battle_data.turn.moved && _game.battle_data.turn.acted {
                            action = .Wait
                        }

                        if _game.player_inputs.cancel.released {
                            action = .Wait
                        }

                        if action == .None {
                            if game_ui_window(fmt.tprintf("%v's turn", current_unit.name), nil, .NoResize | .NoMove | .NoCollapse) {
                                engine.ui_set_window_size_vec2({ 300, 200 }, .Always)
                                engine.ui_set_window_pos_vec2({ f32(_engine.platform.window_size.x - 300) / 2, f32(_engine.platform.window_size.y - 150) / 2 }, .Always)

                                health_progress := f32(current_unit.stat_health) / f32(current_unit.stat_health_max)
                                engine.ui_progress_bar(health_progress, { -1, 20 }, fmt.tprintf("HP: %v/%v", current_unit.stat_health, current_unit.stat_health_max))

                                if engine.ui_button_disabled("Move", _game.battle_data.turn.moved) {
                                    action = .Move
                                }
                                if engine.ui_button_disabled("Throw", _game.battle_data.turn.acted) {
                                    action = .Throw
                                }
                                if engine.ui_button("Wait") {
                                    action = .Wait
                                }
                            }
                        }

                        switch action {
                            case .Move: {
                                _game.battle_data.turn.target = OFFSCREEN_POSITION
                                _game.battle_data.turn.move = current_unit.grid_position
                                _game.highlighted_cells = create_cell_highlight(.Move, is_valid_move_destination)
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

                        break
                    }

                    battle_mode_exiting()
                }

                case .Target_Move: {
                    if battle_mode_running() {
                        entity_move_grid(cursor_move, _game.battle_data.turn.move)

                        if _game.player_inputs.cancel.released {
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
                            grid_index := int(engine.grid_position_to_index(_game.battle_data.turn.move, _game.battle_data.level.size.x))
                            is_valid_target := slice.contains(_game.highlighted_cells[:], Cell_Highlight { grid_index, .Move })
                            if is_valid_target || _game.cheat_move_anywhere {
                                clear(&_game.highlighted_cells)
                                battle_mode_transition(.Execute_Move)
                            } else {
                                // TODO: handle invalid target
                                log.warnf("       Invalid target!")
                            }
                        }

                        break
                    }

                    battle_mode_exiting()
                }

                case .Execute_Move: {
                    if battle_mode_entering() {
                        path := generate_path(current_unit.grid_position, _game.battle_data.turn.move)

                        // FIXME: this is debug code for the animation, implement real path finding later.
                        generate_path :: proc(start_position, end_position: Vector2i32) -> (points: [dynamic]Vector2i32) {
                            append(&points, start_position)

                            x_sign : i32 = 1
                            if start_position.x > end_position.x {
                                x_sign = -1
                            }
                            y_sign : i32 = 1
                            if start_position.y > end_position.y {
                                y_sign = -1
                            }
                            current := start_position
                            for current.y != end_position.y {
                                current.y += 1 * y_sign
                                append(&points, current)
                                log.debugf("current: %v", current)
                            }
                            for current.x != end_position.x {
                                current.x += 1 * x_sign
                                append(&points, current)
                                log.debugf("current: %v", current)
                            }
                            return points

                            // return {
                            //     { 30, 21 },
                            //     { 31, 21 },
                            //     { 32, 21 },
                            // }
                        }

                        for point, i in path {
                            if i < len(path) - 1 {
                                animation := create_unit_move_animation(current_unit, point, path[i+1])
                                queue.push_back(&_game.battle_data.turn.animations, animation)
                            }
                        }

                        current_unit.grid_position = _game.battle_data.turn.move
                        _game.battle_data.turn.moved = true
                    }

                    if battle_mode_running() {
                        if engine.animation_advance_queue(&_game.battle_data.turn.animations) {
                            battle_mode_transition(.Select_Action)
                        }
                    }

                    if battle_mode_exiting() {
                        log.debugf("       Moved: %v", _game.battle_data.turn.move)
                    }
                }

                case .Target_Ability: {
                    if battle_mode_running() {
                        if _game.player_inputs.cancel.released {
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
                                clear(&_game.highlighted_cells)
                                battle_mode_transition(.Execute_Ability)
                            } else {
                                // TODO: handle invalid target
                                log.warnf("       Invalid target!")
                            }
                        }

                        break
                    }
                }

                case .Execute_Ability: {
                    if battle_mode_entering() {
                        log.debugf("       Ability: %v", _game.battle_data.turn.target)
                        _game.battle_data.turn.acted = true
                        battle_mode_transition(.Select_Action)
                    }
                }

                case .End_Turn: {
                    if battle_mode_entering() {
                        log.debugf("       Turn over!")

                        turn_cost := TURN_COST
                        if _game.battle_data.turn.moved {
                            turn_cost += MOVE_COST
                        }
                        if _game.battle_data.turn.acted {
                            turn_cost += ACT_COST
                        }
                        current_unit.stat_ctr -= turn_cost

                        log.debugf("       CTR cost: %v", turn_cost)
                        log.debugf("       CTR: %v | SPD: %v", current_unit.stat_ctr, current_unit.stat_speed)
                        clear(&_game.highlighted_cells)
                        battle_mode_transition(.Ticking)
                    }
                }
            }
        }

        // entity_move_grid(cursor_move, _game.battle_data.turn.move)
        // entity_move_grid(unit_preview, _game.battle_data.turn.move)
        (&_game.entities.components_rendering[unit_preview]).texture_position = _game.entities.components_rendering[current_unit.entity].texture_position
        entity_move_grid(cursor_target, _game.battle_data.turn.target)

        if engine.ui_window("Battle Debug", nil) {
            engine.ui_set_window_pos_vec2({ 100, 300 }, .FirstUseEver)
            engine.ui_set_window_size_vec2({ 800, 300 }, {})

            region := engine.ui_get_content_region_avail()

            if engine.ui_child("left", { region.x * 0.7, region.y }, false, {}) {
                engine.ui_input_int("tick_duration", cast(^i32)&_game.battle_data.tick_duration)
                progress := math.clamp(1 - f32(_game.battle_data.next_tick._nsec - time.now()._nsec) / f32(_game.battle_data.tick_duration), 0, 1)
                engine.ui_progress_bar(progress, { -1, 20 }, fmt.tprintf("Tick %v", progress))

                columns := [?]string { "index", "name", "pos", "ctr", "hp", "actions" }
                if engine.ui_begin_table("table1", len(columns), engine.TableFlags_RowBg | engine.TableFlags_SizingStretchSame | engine.TableFlags_Resizable) {
                    engine.ui_table_next_row()
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
                                    if engine.ui_button("Set current") {
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

            if engine.ui_child("right", { region.x * 0.3, region.y }, false) {
                engine.ui_text("Battle index: %v", _game.battle_index)
                if engine.ui_button("Back to world map") {
                    _game.battle_index = 0
                    game_mode_transition(.WorldMap)
                }
                engine.ui_text("mode:               %v", Battle_Mode(_game.battle_data.mode.current))
                engine.ui_text("current_unit:       %v", _game.units[_game.battle_data.current_unit].name)
                engine.ui_text("mouse_grid_pos:     %v", _game.mouse_grid_position)
                mouse_cell, mouse_cell_found := get_cell_at_position(&_game.battle_data.level, _game.mouse_grid_position)
                if mouse_cell_found {
                    engine.ui_text("  - Climb:    %v", .Climb in mouse_cell ? "x" : "")
                    engine.ui_text("  - Fall:     %v", .Fall in mouse_cell ? "x" : "")
                    engine.ui_text("  - Move:     %v", .Move in mouse_cell ? "x" : "")
                    engine.ui_text("  - Grounded: %v", .Grounded in mouse_cell ? "x" : "")
                }
                engine.ui_text("turn:")
                engine.ui_text("  move:    %v", _game.battle_data.turn.move)
                engine.ui_text("  target:  %v", _game.battle_data.turn.target)
                engine.ui_text("  ability: %v", _game.battle_data.turn.ability)
            }
        }

        return
    }

    if game_mode_exiting() {
        log.debugf("Battle exit | entities: %v", len(_game.battle_data.entities))
        for entity in _game.battle_data.entities {
            entity_delete(entity, &_game.entities)
        }
        engine.asset_unload(_game.asset_battle_background)
        engine.asset_unload(_game.asset_areas)
    }
}

spawn_units :: proc(spawners: [dynamic]Entity, units: [dynamic]int) {
    for spawner, i in spawners {
        if i >= len(units) {
            break
        }

        unit := &_game.units[units[i]]
        component_transform := _game.entities.components_transform[spawner]
        unit.grid_position = world_to_grid_position(component_transform.position)

        entity := entity_create_unit(unit)
        append(&_game.battle_data.entities, entity)
        append(&_game.battle_data.units, units[i])

        unit.entity = entity
    }
}

sort_units_by_ctr :: proc(a, b: int) -> int {
    return int(_game.units[a].stat_ctr - _game.units[b].stat_ctr)
}

create_cell_highlight :: proc(type: Cell_Highlight_Type, search_filter_proc: Search_Filter_Proc) -> [dynamic]Cell_Highlight {
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
is_valid_move_destination : Search_Filter_Proc : proc(grid_index: int, grid_size: Vector2i32, grid: []Grid_Cell) -> bool {
    grid_value := grid[grid_index]
    position := engine.grid_index_to_position(grid_index, grid_size.x)

    unit := _game.units[_game.battle_data.current_unit]
    unit_transform := _game.entities.components_transform[unit.entity]
    if engine.manhathan_distance(unit.grid_position, position) > unit.stat_move {
        return false
    }

    return grid_value >= { .Move, .Grounded }
}

// TODO: Check range and FOV
is_valid_ability_destination : Search_Filter_Proc : proc(grid_index: int, grid_size: Vector2i32, grid: []Grid_Cell) -> bool {
    grid_value := grid[grid_index]
    position := engine.grid_index_to_position(grid_index, grid_size.x)

    unit := _game.units[_game.battle_data.current_unit]
    unit_transform := _game.entities.components_transform[unit.entity]
    MAX_RANGE :: 8
    if engine.manhathan_distance(unit.grid_position, position) > MAX_RANGE {
        return false
    }

    return grid_value >= { .Move }
}

create_unit_move_animation :: proc(unit: ^Unit, start_position, end_position: Vector2i32) -> ^engine.Animation {
    animation := engine.animation_create_animation(3)
    engine.animation_add_curve(animation, engine.Animation_Curve_Position {
        entity = unit.entity,
        timestamps = { 0.0, 1.0 },
        frames = {
            grid_to_world_position_center(start_position),
            grid_to_world_position_center(end_position),
        },
    })
    engine.animation_add_curve(animation, engine.Animation_Curve_Scale {
        entity = unit.entity,
        timestamps = {
            0.00,
            0.25,
            0.50,
            0.75,
            1.00,
        },
        frames = {
            { 1.0, 1.0 },
            { 0.9, 1.1 },
            { 1.0, 1.0 },
            { 0.9, 1.1 },
            { 1.0, 1.0 },
        },
    })

    // TODO: flip those when changing direction
    component_limbs, has_limbs := &_game.entities.components_limbs[unit.entity]
    engine.animation_add_curve(animation, engine.Animation_Curve_Position {
        entity = component_limbs.hand_left,
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
    engine.animation_add_curve(animation, engine.Animation_Curve_Position {
        entity = component_limbs.hand_right,
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
