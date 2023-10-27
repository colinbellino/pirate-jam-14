package game

import "core:fmt"
import "core:log"
import "core:slice"
import "core:sort"
import "core:time"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:container/queue"

import "../engine"

TAKE_TURN     : i32 : 100
TURN_COST     : i32 : 60
ACT_COST      : i32 : 20
MOVE_COST     : i32 : 20
TICK_DURATION :: i64(0)

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
    projectile: Entity,
    animations: ^queue.Queue(^engine.Animation),
    move_path:  []Vector2i32,
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
            background_asset := &_engine.assets.assets[_game.asset_battle_background]
            asset_info, asset_ok := background_asset.info.(engine.Asset_Info_Image)
            if asset_ok {
                entity := engine.entity_make("Background: Battle")
                engine.entity_add_transform(entity, { f32(asset_info.texture.width) / 4, f32(asset_info.texture.height) / 4 })
                engine.entity_add_sprite(entity, _game.asset_battle_background, texture_size = { asset_info.texture.width, asset_info.texture.height }, z_index = -1)
                append(&_game.battle_data.entities, entity)
            }
        }

        {
            cursor_asset := &_engine.assets.assets[_game.asset_debug_image]
            asset_info, asset_ok := cursor_asset.info.(engine.Asset_Info_Image)
            entity := engine.entity_make("Cursor: move")
            engine.entity_add_transform(entity, grid_to_world_position_center(OFFSCREEN_POSITION))
            engine.entity_add_sprite(entity, _game.asset_debug_image, grid_position(1, 12), texture_padding = 1, z_index = 9, color = { 0, 0, 1, 1 }, texture_size = GRID_SIZE_V2)
            append(&_game.battle_data.entities, entity)
            _game.battle_data.cursor_move_entity = entity
        }

        {
            cursor_asset := &_engine.assets.assets[_game.asset_debug_image]
            asset_info, asset_ok := cursor_asset.info.(engine.Asset_Info_Image)
            entity := engine.entity_make("Cursor: target")
            engine.entity_add_transform(entity, grid_to_world_position_center(OFFSCREEN_POSITION))
            engine.entity_add_sprite(entity, _game.asset_debug_image, grid_position(1, 12), texture_padding = 1, z_index = 10, color = { 0, 1, 0, 1 }, texture_size = GRID_SIZE_V2)
            append(&_game.battle_data.entities, entity)
            _game.battle_data.cursor_target_entity = entity
        }

        {
            unit_preview_asset := &_engine.assets.assets[_game.asset_debug_image]
            asset_info, asset_ok := unit_preview_asset.info.(engine.Asset_Info_Image)
            entity := engine.entity_make("Unit preview")
            engine.entity_add_transform(entity, grid_to_world_position_center(OFFSCREEN_POSITION))
            engine.entity_add_sprite(entity, _game.asset_debug_image, grid_position(3, 12), texture_padding = 1, z_index = 1, color = { 1, 1, 1, 0.5 }, texture_size = GRID_SIZE_V2)
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
            component_meta, has_meta := engine.entity_get_component_meta(entity)
            if has_meta == false {
                continue
            }

            component_transform, has_transform := engine.entity_get_component_transform(entity)
            ldtk_entity := _game.ldtk_entity_defs[component_meta.entity_uid]
            if ldtk_entity.identifier == "Spawner_Ally" {
                append(&spawners_ally, entity)
            }
            if ldtk_entity.identifier == "Spawner_Foe" {
                append(&spawners_foe, entity)
            }
        }

        spawn_units(spawners_ally, _game.party, Directions.Right)
        spawn_units(spawners_foe, _game.foes, Directions.Left)

        for unit_index in _game.battle_data.units {
            unit := &_game.units[unit_index]
            unit.stat_ctr = 0
        }

        log.debugf("Battle:           %v", BATTLE_LEVELS[_game.battle_index - 1])
        // log.debugf("_game.battle_data: %v | %v", _game.battle_data.level, _game.battle_data.entities)
    }

    if game_mode_running() {
        current_unit := &_game.units[_game.battle_data.current_unit]
        unit_transform := engine.entity_get_component_transform(current_unit.entity)
        unit_rendering := engine.entity_get_component_rendering(current_unit.entity)
        cursor_move := _game.battle_data.cursor_move_entity
        cursor_target := _game.battle_data.cursor_target_entity
        unit_preview := _game.battle_data.unit_preview_entity
        unit_preview_rendering := engine.entity_get_component_rendering(unit_preview)

        engine.platform_process_repeater(&_game.battle_data.move_repeater, _game.player_inputs.move)
        engine.platform_process_repeater(&_game.battle_data.aim_repeater, _game.player_inputs.aim)

        {
            defer battle_mode_check_exit()
            battle_mode: switch Battle_Mode(_game.battle_data.mode.current) {
                case .Ticking: {
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
                                if unit.stat_ctr >= TAKE_TURN {
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
                    if battle_mode_entering() {
                        reset_turn(&_game.battle_data.turn)
                        entity_move_grid(unit_preview, _game.battle_data.turn.move)
                        entity_move_grid(cursor_move, current_unit.grid_position)
                        entity_move_grid(cursor_target, _game.battle_data.turn.target)
                        log.debugf("[TURN] %v (CTR: %v)", current_unit.name, current_unit.stat_ctr)
                        battle_mode_transition(.Select_Action)

                        break battle_mode
                    }

                    battle_mode_exiting()
                }

                case .Select_Action: {
                    if battle_mode_entering() {
                        _game.battle_data.turn.move = OFFSCREEN_POSITION
                        _game.battle_data.turn.target = OFFSCREEN_POSITION
                        entity_move_grid(cursor_move, current_unit.grid_position)
                        entity_move_grid(cursor_target, _game.battle_data.turn.target)

                        update_grid_flags(&_game.battle_data.level)
                    }

                    if battle_mode_running() {
                        if _game.battle_data.turn.moved && _game.battle_data.turn.acted {
                            battle_mode_transition(.End_Turn)
                            break battle_mode
                        }

                        if current_unit.controlled_by == .CPU {
                            if _game.battle_data.turn.moved == false {
                                highlighted_cells := create_cell_highlight(.Move, is_valid_move_destination_and_in_range, context.temp_allocator)
                                random_cell_index := rand.int_max(len(highlighted_cells) - 1)
                                _game.battle_data.turn.move = engine.grid_index_to_position(highlighted_cells[random_cell_index].grid_index, _game.battle_data.level.size.x)
                                path, path_ok := find_path(_game.battle_data.level.grid, _game.battle_data.level.size, current_unit.grid_position, _game.battle_data.turn.move)
                                if path_ok {
                                    _game.battle_data.turn.move_path = path
                                    battle_mode_transition(.Execute_Move)
                                    break battle_mode
                                }
                            }
                            if _game.battle_data.turn.acted == false {
                                highlighted_cells := create_cell_highlight(.Move, is_valid_ability_destination, context.temp_allocator)
                                random_cell_index := rand.int_max(len(highlighted_cells) - 1)
                                _game.battle_data.turn.target = engine.grid_index_to_position(highlighted_cells[random_cell_index].grid_index, _game.battle_data.level.size.x)
                                if true { // TODO: check if target is valid
                                    battle_mode_transition(.Execute_Ability)
                                    break battle_mode
                                }
                            }
                            // TODO: wait if no valid action
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
                }

                case .Target_Move: {
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

                        break battle_mode
                    }
                }

                case .Execute_Move: {
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

                    if battle_mode_exiting() {
                        log.debugf("       Moved: %v", _game.battle_data.turn.move)
                    }
                }

                case .Target_Ability: {
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

                        break battle_mode
                    }
                }

                case .Execute_Ability: {
                    if battle_mode_entering() {
                        entity_move_grid(cursor_target, OFFSCREEN_POSITION)

                        direction := get_direction_from_points(current_unit.grid_position, _game.battle_data.turn.target)
                        if current_unit.direction != direction {
                            animation := create_unit_flip_animation(current_unit, direction)
                            queue.push_back(_game.battle_data.turn.animations, animation)
                            current_unit.direction = direction
                        }
                        _game.battle_data.turn.projectile = engine.entity_make("Projectile")
                        engine.entity_add_transform(_game.battle_data.turn.projectile, grid_to_world_position_center(current_unit.grid_position), { 0, 0 })
                        engine.entity_add_sprite(_game.battle_data.turn.projectile, 3, { 0, 7 } * GRID_SIZE_V2, GRID_SIZE_V2, 1, z_index = 3)
                        {
                            animation := create_unit_throw_animation(current_unit, _game.battle_data.turn.target, _game.battle_data.turn.projectile)
                            queue.push_back(_game.battle_data.turn.animations, animation)
                        }

                        target_unit := find_unit_at_position(_game.battle_data.turn.target)
                        if target_unit != nil {
                            animation := create_unit_hit_animation(target_unit, direction)
                            queue.push_back(_game.battle_data.turn.animations, animation)
                        }
                        _game.battle_data.turn.acted = true
                    }

                    if battle_mode_running() {
                        if engine.animation_queue_is_done(_game.battle_data.turn.animations) {
                            battle_mode_transition(.Select_Action)
                        }
                    }

                    if battle_mode_exiting() {
                        engine.entity_delete(_game.battle_data.turn.projectile)
                        log.debugf("       Ability: %v", _game.battle_data.turn.target)
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

        unit_preview_rendering.texture_position = unit_rendering.texture_position

        if _game.debug_window_battle {
            if engine.ui_window("Debug: Battle", nil) {
                engine.ui_set_window_pos_vec2({ 100, 300 }, .FirstUseEver)
                engine.ui_set_window_size_vec2({ 800, 300 }, .FirstUseEver)

                region := engine.ui_get_content_region_avail()

                if engine.ui_child("left", { region.x * 0.25, region.y }, false) {
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

        return
    }

    if game_mode_exiting() {
        log.debugf("Battle exit | entities: %v", len(_game.battle_data.entities))
        for entity in _game.battle_data.entities {
            engine.entity_delete(entity)
        }
        engine.asset_unload(_game.asset_battle_background)
        engine.asset_unload(_game.asset_areas)
    }
}

spawn_units :: proc(spawners: [dynamic]Entity, units: [dynamic]int, direction: Directions) {
    for spawner, i in spawners {
        if i >= len(units) {
            break
        }

        unit := &_game.units[units[i]]
        component_transform := engine.entity_get_component_transform(spawner)
        unit.grid_position = world_to_grid_position(component_transform.position)
        unit.direction = direction

        entity := unit_create_entity(unit)
        append(&_game.battle_data.entities, entity)
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
    unit_transform := engine.entity_get_component_transform(unit.entity)
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
    unit_transform := engine.entity_get_component_transform(unit.entity)
    MAX_RANGE :: 5
    if engine.manhathan_distance(unit.grid_position, position) > MAX_RANGE {
        return false
    }

    return grid_value >= { .Move }
}

create_unit_throw_animation :: proc(unit: ^Unit, target: Vector2i32, projectile: Entity) -> ^engine.Animation {
    aim_direction := Vector2f32(linalg.vector_normalize(array_cast(target, f32) - array_cast(unit.grid_position, f32)))

    // log.debugf("ANIM: throw: %v", direction)
    animation := engine.animation_create_animation(2)
    component_limbs, has_limbs := engine.entity_get_component_limbs(unit.entity)
    {
        origin := engine.entity_get_component_transform(component_limbs.hand_left).position
        engine.animation_add_curve(animation, engine.Animation_Curve_Position {
            target = &(engine.entity_get_component_transform(component_limbs.hand_left)).position,
            timestamps = {
                0.00,
                0.10,
                0.50,
                1.00,
            },
            frames = {
                origin,
                origin + aim_direction * -2,
                origin + aim_direction * +2,
                origin,
            },
        })
    }
    {
        origin := engine.entity_get_component_transform(component_limbs.hand_right).position
        engine.animation_add_curve(animation, engine.Animation_Curve_Position {
            target = &(engine.entity_get_component_transform(component_limbs.hand_right)).position,
            timestamps = {
                0.00,
                0.10,
                0.50,
                1.00,
            },
            frames = {
                origin,
                origin + aim_direction * 0.5,
                origin + aim_direction * 0.5,
                origin,
            },
        })
    }
    {
        component_transform, has_transform := engine.entity_get_component_transform(projectile)
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
    // log.debugf("ANIM: flip: %v", direction)
    animation := engine.animation_create_animation(3)
    engine.animation_add_curve(animation, engine.Animation_Curve_Scale {
        target = &(engine.entity_get_component_transform(unit.entity)).scale,
        timestamps = { 0.0, 1.0 },
        frames = { { -f32(direction), 1 }, { f32(direction), 1 } },
    })
    return animation
}

create_unit_hit_animation :: proc(unit: ^Unit, direction: Directions) -> ^engine.Animation {
    // log.debugf("ANIM: hit: %v", direction)
    animation := engine.animation_create_animation(5)
    engine.animation_add_curve(animation, engine.Animation_Curve_Scale {
        target = &(engine.entity_get_component_transform(unit.entity)).scale,
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

create_unit_move_animation :: proc(unit: ^Unit, direction: Directions, start_position, end_position: Vector2i32) -> ^engine.Animation {
    // log.debugf("ANIM: move: %v", direction)
    animation := engine.animation_create_animation(3)
    engine.animation_add_curve(animation, engine.Animation_Curve_Position {
        target = &(engine.entity_get_component_transform(unit.entity)).position,
        timestamps = { 0.0, 1.0 },
        frames = {
            grid_to_world_position_center(start_position),
            grid_to_world_position_center(end_position),
        },
    })
    engine.animation_add_curve(animation, engine.Animation_Curve_Scale {
        target = &(engine.entity_get_component_transform(unit.entity)).scale,
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

    component_limbs, has_limbs := engine.entity_get_component_limbs(unit.entity)
    engine.animation_add_curve(animation, engine.Animation_Curve_Position {
        target = &(engine.entity_get_component_transform(component_limbs.hand_left)).position,
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
        target = &(engine.entity_get_component_transform(component_limbs.hand_right)).position,
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
    component_transform := engine.entity_get_component_transform(unit.entity)
    component_transform.position = grid_to_world_position_center(grid_position, GRID_SIZE)
}

unit_create_entity :: proc(unit: ^Unit) -> Entity {
    SPRITE_SIZE :: Vector2i32 { 8, 8 }

    entity := engine.entity_make(unit.name)

    hand_left := engine.entity_make(fmt.tprintf("%s: Hand (left)", unit.name))
    hand_left_transform := engine.entity_add_transform(hand_left, { 0, 0 })
    hand_left_transform.parent = entity
    engine.entity_add_sprite(hand_left, 3, { 5, 15 } * GRID_SIZE_V2, SPRITE_SIZE, 1, z_index = 3)

    hand_right := engine.entity_make(fmt.tprintf("%s: Hand (right)", unit.name))
    hand_right_transform := engine.entity_add_transform(hand_right, { 0, 0 })
    hand_right_transform.parent = entity
    engine.entity_add_sprite(hand_right, 3, { 6, 15 } * GRID_SIZE_V2, SPRITE_SIZE, 1, z_index = 1)

    entity_transform := engine.entity_add_transform(entity, grid_to_world_position_center(unit.grid_position))
    entity_transform.scale.x *= f32(unit.direction)
    engine.entity_add_sprite(entity, 3, unit.sprite_position * GRID_SIZE_V2, SPRITE_SIZE, 1, z_index = 2)
    engine.entity_set_component_flag(entity, { { .Unit } })
    engine.entity_set_component_limbs(entity, { hand_left = hand_left, hand_right = hand_right })

    return entity
}

entity_move_grid :: proc(entity: Entity, grid_position: Vector2i32) {
    component_transform := engine.entity_get_component_transform(entity)
    component_transform.position = grid_to_world_position_center(grid_position)
}
