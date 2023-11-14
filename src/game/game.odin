package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/ease"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:sort"
import "core:time"
import "../tools"
import "../engine"

GAME_VOLUME_MAIN        :: #config(GAME_VOLUME_MAIN, 0.0)

Vector2i32              :: engine.Vector2i32
Vector2f32              :: engine.Vector2f32
Vector3f32              :: engine.Vector3f32
Vector4f32              :: engine.Vector4f32
Matrix4x4f32            :: engine.Matrix4x4f32
Entity                  :: engine.Entity
Asset_Id                :: engine.Asset_Id
Color                   :: engine.Color
array_cast              :: linalg.array_cast

MEM_GAME_SIZE           :: 10 * mem.Megabyte
MEM_ENGINE_SIZE         :: 24 * mem.Megabyte
NATIVE_RESOLUTION       :: Vector2f32 { 320, 180 }
CONTROLLER_DEADZONE     :: 15_000
PROFILER_COLOR_RENDER   :: 0x550000
CLEAR_COLOR             :: Color { 1, 0, 1, 1 } // This is supposed to never show up, so it's a super flashy color. If you see it, something is broken.
VOID_COLOR              :: Color { 0.4, 0.4, 0.4, 1 }
WINDOW_BORDER_COLOR     :: Color { 0, 0, 0, 1 }
GRID_SIZE               :: 8
GRID_SIZE_V2            :: Vector2i32 { GRID_SIZE, GRID_SIZE }

COLOR_MOVE    :: Color { 1, 1, 0, 0.7 }
COLOR_ABILITY :: Color { 0, 1, 0, 0.7 }

App_Memory :: struct {
    game:   ^Game_State,
    engine: ^engine.Engine_State,
}

Game_State :: struct {
    allocator:                  runtime.Allocator,
    arena:                      virtual.Arena,

    game_mode:                  Mode,
    player_inputs:              Player_Inputs,

    volume_main:                f32,
    volume_music:               f32,
    volume_sound:               f32,

    asset_map_world:            Asset_Id,
    asset_map_areas:            Asset_Id,

    asset_image_debug:          Asset_Id,
    asset_image_spritesheet:    Asset_Id,
    asset_image_battle_bg:      Asset_Id,
    asset_image_nyan:           Asset_Id,
    asset_image_units:          Asset_Id,

    asset_shader_sprite:        Asset_Id,
    asset_shader_sprite_aa:     Asset_Id,
    asset_shader_line:          Asset_Id,
    asset_shader_test:          Asset_Id,

    asset_music_worldmap:       Asset_Id,
    asset_music_battle:         Asset_Id,

    asset_sound_cancel:         Asset_Id,
    asset_sound_confirm:        Asset_Id,
    asset_sound_invalid:        Asset_Id,
    asset_sound_hit:            Asset_Id,

    units:                      [dynamic]Unit,
    party:                      [dynamic]int,
    foes:                       [dynamic]int,

    mouse_world_position:       Vector2f32,
    mouse_grid_position:        Vector2i32,

    highlighted_cells:          [dynamic]Cell_Highlight,

    battle_index:               int,
    world_data:                 ^Game_Mode_Worldmap,
    battle_data:                ^Game_Mode_Battle,
    tileset_assets:             map[engine.LDTK_Tileset_Uid]Asset_Id,
    background_asset:           Asset_Id,
    ldtk_entity_defs:           map[engine.LDTK_Entity_Uid]engine.LDTK_Entity,

    debug_render_z_index_0:     bool,
    debug_render_z_index_1:     bool,

    debug_ui_window_game:       bool,
    debug_ui_window_console:    bool,
    debug_ui_window_debug:      bool,
    debug_ui_window_entities:   bool,
    debug_ui_window_assets:     bool,
    debug_ui_window_anim:       bool,
    debug_ui_window_battle:     bool,
    debug_ui_window_shader:     bool,
    debug_ui_window_demo:       bool,
    debug_ui_entity:            Entity,
    debug_ui_entity_highlight:  bool,
    debug_ui_entity_all:        bool,
    debug_ui_entity_tiles:      bool,
    debug_ui_entity_units:      bool,
    debug_ui_entity_children:   bool,
    debug_ui_shader_asset_id:   Asset_Id,
    debug_draw_tiles:           bool,
    debug_show_bounding_boxes:  bool,
    debug_entity_under_mouse:   Entity,
    debug_draw_entities:        bool,
    debug_draw_grid:            bool,

    cheat_move_anywhere:        bool,
    cheat_act_anywhere:         bool,
}

Game_Mode :: enum { Init, Title, WorldMap, Battle, Debug }

Key_Modifier :: enum {
    None  = 0,
    Mod_1 = 1,
    Mod_2 = 2,
    Mod_3 = 4,
}

Key_Modifier_BitSet :: bit_set[Key_Modifier]

Player_Inputs :: struct {
    modifier:   Key_Modifier_BitSet,
    mouse_left: engine.Key_State,
    move:       Vector2f32,
    aim:        Vector2f32,
    confirm:    engine.Key_State,
    cancel:     engine.Key_State,
    back:       engine.Key_State,
    start:      engine.Key_State,
    debug_0:    engine.Key_State,
    debug_1:    engine.Key_State,
    debug_2:    engine.Key_State,
    debug_3:    engine.Key_State,
    debug_4:    engine.Key_State,
    debug_5:    engine.Key_State,
    debug_6:    engine.Key_State,
    debug_7:    engine.Key_State,
    debug_8:    engine.Key_State,
    debug_9:    engine.Key_State,
    debug_10:   engine.Key_State,
    debug_11:   engine.Key_State,
    debug_12:   engine.Key_State,
}

Unit :: struct {
    name:               string,
    sprite_position:    Vector2i32,
    grid_position:      Vector2i32,
    stat_health:        i32,
    stat_health_max:    i32,
    stat_ctr:           i32,
    stat_speed:         i32,
    stat_move:          i32,
    direction:          Directions,
    entity:             Entity,
    controlled_by:      Unit_Controllers,
    alliance:           Unit_Alliances,
}
Unit_Controllers :: enum { CPU = 0, Player = 1 }
Unit_Alliances :: enum { Neutral = 0, Ally = 1, Foe = 2 }

Directions :: enum { Left = -1, Right = 1 }

@(private="file") _mem: ^App_Memory
@(private="package") _game: ^Game_State
@(private="package") _engine: ^engine.Engine_State

@(export) app_init :: proc() -> rawptr {
    _engine = engine.engine_init({ 1920, 1080 }, NATIVE_RESOLUTION, MEM_ENGINE_SIZE)
    context.logger = _engine.logger.logger

    err: mem.Allocator_Error
    _game, err = engine.platform_make_virtual_arena("game_arena", Game_State, MEM_GAME_SIZE)
    if err != .None {
        fmt.eprintf("Couldn't allocate game arena: %v\n", err)
        os.exit(1)
    }
    _game.game_mode.allocator = arena_allocator_make(1000 * mem.Kilobyte, _game.allocator)

    _mem = new(App_Memory, _engine.allocator)
    _mem.game = _game
    _mem.engine = _engine

    return _mem
}

// FIXME: free game state memory (in arena) when changing state
@(export) app_update :: proc(app_memory: ^App_Memory) -> (quit: bool, reload: bool) {
    context.logger = _engine.logger.logger

    // log.infof("frame ----------------------------------------------------------------")
    engine.platform_frame()
    engine.profiler_zone("app_update")
    ui_push_theme_debug()
    defer ui_pop_theme_debug()

    context.allocator = _game.allocator

    game_ui_debug()

    camera := &_engine.renderer.world_camera
    shader_info_default, shader_default_err := engine.asset_get_asset_info_shader(_game.asset_shader_sprite)
    shader_info_line, shader_line_err := engine.asset_get_asset_info_shader(_game.asset_shader_line)

    _game.mouse_world_position = window_to_world_position(_engine.platform.mouse_position)
    _game.mouse_grid_position = world_to_grid_position(_game.mouse_world_position)

    engine.debug_update()

    { engine.profiler_zone("inputs")
        update_player_inputs()

        { // Debug inputs
            if _game.player_inputs.modifier == {} {
                if _game.player_inputs.debug_0.released {
                    _game.debug_ui_window_console = !_game.debug_ui_window_console
                }
                if _game.player_inputs.debug_1.released {
                    _game.debug_ui_window_debug = !_game.debug_ui_window_debug
                }
                if _game.player_inputs.debug_2.released {
                    _game.debug_ui_window_entities = !_game.debug_ui_window_entities
                }
                if _game.player_inputs.debug_3.released {
                    _game.debug_ui_window_assets = !_game.debug_ui_window_assets
                }
                if _game.player_inputs.debug_4.released {
                    _game.debug_ui_window_anim = !_game.debug_ui_window_anim
                }
                if _game.player_inputs.debug_5.released {
                    _game.debug_ui_window_battle = !_game.debug_ui_window_battle
                }
                if _game.player_inputs.debug_6.released {
                    _game.debug_ui_window_shader = !_game.debug_ui_window_shader
                }
                if _game.player_inputs.debug_12.released {
                    engine.debug_reload_shaders()
                }
            }

            if .Mod_1 in _game.player_inputs.modifier {
                if _game.player_inputs.debug_1.released {
                    _game.debug_render_z_index_0 = !_game.debug_render_z_index_0
                }
                if _game.player_inputs.debug_2.released {
                    _game.debug_render_z_index_1 = !_game.debug_render_z_index_1
                }
                if _game.player_inputs.debug_3.released {
                    _game.debug_draw_grid = !_game.debug_draw_grid
                }
                if _game.player_inputs.debug_4.released {
                    _game.debug_draw_tiles = !_game.debug_draw_tiles
                }
                if _game.player_inputs.debug_7.released {
                    _game.debug_show_bounding_boxes = !_game.debug_show_bounding_boxes
                }

                if _engine.platform.keys[.A].down {
                    camera.position.x -= _engine.platform.delta_time / 10
                }
                if _engine.platform.keys[.D].down {
                    camera.position.x += _engine.platform.delta_time / 10
                }
                if _engine.platform.keys[.W].down {
                    camera.position.y -= _engine.platform.delta_time / 10
                }
                if _engine.platform.keys[.S].down {
                    camera.position.y += _engine.platform.delta_time / 10
                }
                if _engine.platform.keys[.Q].down {
                    camera.rotation += _engine.platform.delta_time / 1000
                }
                if _engine.platform.keys[.E].down {
                    camera.rotation -= _engine.platform.delta_time / 1000
                }
                if _engine.platform.mouse_wheel.y != 0 {
                    camera.zoom = math.clamp(camera.zoom + f32(_engine.platform.mouse_wheel.y) * _engine.platform.delta_time / 50, 0.2, 40)
                }
                if .Mod_2 in _game.player_inputs.modifier {
                    if _engine.platform.keys[.LEFT].down {
                        _game.debug_ui_entity -= 1
                    }
                    if _engine.platform.keys[.RIGHT].down {
                        _game.debug_ui_entity += 1
                    }
                } else {
                    if _engine.platform.keys[.LEFT].released {
                        _game.debug_ui_entity -= 1
                    }
                    if _engine.platform.keys[.RIGHT].released {
                        _game.debug_ui_entity += 1
                    }
                }
            }
        }
    }

    engine.renderer_clear(VOID_COLOR)

    { engine.profiler_zone("game_mode")
        defer game_mode_check_exit()
        switch Game_Mode(_game.game_mode.current) {
            case .Init: game_mode_init()
            case .Title: game_mode_title()
            case .WorldMap: game_mode_worldmap()
            case .Battle: game_mode_battle()
            case .Debug: game_mode_debug()
        }
    }

    if _engine.platform.quit_requested {
        quit = true
        return
    }

    if _engine.platform.window_resized {
        engine.platform_resize_window()
    }
    if _engine.renderer.game_view_resized {
        _engine.renderer.world_camera.zoom = _engine.renderer.ideal_scale
    }

    { engine.profiler_zone("render")
        engine.renderer_update_camera_matrix()

        engine.renderer_change_camera_begin(&_engine.renderer.world_camera)

        if _game.debug_draw_entities {
            sorted_entities: []Entity
            { engine.profiler_zone("sort_entities", PROFILER_COLOR_RENDER)
                components_rendering := engine.entity_get_entities_with_components({ engine.Component_Sprite }, context.temp_allocator)
                alloc_err: runtime.Allocator_Error
                sorted_entities, alloc_err = slice.clone(components_rendering[:], context.temp_allocator)
                {
                    sort_entities_by_z_index :: proc(a, b: Entity) -> int {
                        component_rendering_a, _ := engine.entity_get_component(a, engine.Component_Sprite)
                        component_rendering_b, _ := engine.entity_get_component(b, engine.Component_Sprite)
                        return int(component_rendering_a.z_index - component_rendering_b.z_index)
                    }
                    sort.heap_sort_proc(sorted_entities, sort_entities_by_z_index)
                }
            }

            { // Animations
                engine.animation_update()
            }

            { engine.profiler_zone("draw_entities", PROFILER_COLOR_RENDER)
                for entity in sorted_entities {
                    component_transform, err_transform := engine.entity_get_component(entity, engine.Component_Transform)
                    component_rendering, err_rendering := engine.entity_get_component(entity, engine.Component_Sprite)
                    component_flag, err_flag := engine.entity_get_component(entity, Component_Flag)

                    if err_rendering == .None && component_rendering.hidden == false && err_transform == .None {
                        texture_asset, texture_asset_ok := engine.asset_get(component_rendering.texture_asset)
                        if texture_asset.state != .Loaded {
                            continue
                        }
                        texture_asset_info, texture_asset_info_ok := texture_asset.info.(engine.Asset_Info_Image)
                        if texture_asset_info_ok == false {
                            continue
                        }

                        if _game.debug_draw_tiles == false && err_flag == .None && .Tile in component_flag.value {
                            continue
                        }

                        current_transform := component_transform
                        position := current_transform.position
                        scale := current_transform.scale
                        for current_transform.parent != 0 {
                            parent_transform, parent_transform_err := engine.entity_get_component(current_transform.parent, engine.Component_Transform)
                            if parent_transform_err != .None {
                                break
                            }
                            current_transform = parent_transform
                            position += current_transform.position
                            scale *= current_transform.scale
                        }

                        shader: ^engine.Shader
                        shader_asset := _engine.assets.assets[_game.asset_shader_sprite]
                        shader_asset_info, shader_asset_ok := shader_asset.info.(engine.Asset_Info_Shader)
                        if shader_asset_ok {
                            shader = shader_asset_info.shader
                        }

                        texture_position, texture_size, _pixel_size := texture_position_and_size(texture_asset_info.texture, component_rendering.texture_position, component_rendering.texture_size, component_rendering.texture_padding)

                        rotation : f32 = 0
                        engine.renderer_push_quad(
                            position,
                            Vector2f32(array_cast(component_rendering.texture_size, f32)) * scale,
                            component_rendering.tint,
                            texture_asset_info.texture,
                            texture_position, texture_size,
                            rotation, shader, component_rendering.palette,
                        )
                    }
                }
            }
        }

        asset_image_debug, asset_image_debug_ok := engine.asset_get(_game.asset_image_debug)
        if asset_image_debug_ok && asset_image_debug.state == .Loaded {
            image_info_debug, asset_ok := asset_image_debug.info.(engine.Asset_Info_Image)

            texture_position, texture_size, pixel_size := texture_position_and_size(image_info_debug.texture, { 40, 40 }, { 8, 8 })
            for cell in _game.highlighted_cells {
                grid_position := engine.grid_index_to_position(cell.grid_index, _game.battle_data.level.size.x)
                color := engine.Color { 1, 1, 1, 1 }
                switch cell.type {
                    case .Move: color = COLOR_MOVE
                    case .Ability: color = COLOR_ABILITY
                }
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


        if false {
            points := []Vector2f32 {
                { 0, 0 },
                grid_to_world_position_center(_game.units[0].grid_position),
                grid_to_world_position_center(_game.units[1].grid_position),
                grid_to_world_position_center(_game.units[2].grid_position),
                grid_to_world_position_center(_game.units[3].grid_position),
                grid_to_world_position_center(_game.units[4].grid_position),
                grid_to_world_position_center(_game.units[5].grid_position),
            }
            // for point, i in points {
            //     engine.ui_slider_float2(fmt.tprintf("p_%v", i), transmute(^[2]f32) &points[i], 0, 1000)
            // }

            engine.renderer_push_line(points, shader_info_line.shader, Color { 1, 1, 0, 1 })
        } else {
            if _game.battle_data != nil && len(_game.battle_data.turn.move_path) > 0 {
                points_dynamic := [dynamic]Vector2f32 {}
                for point in _game.battle_data.turn.move_path {
                    append(&points_dynamic, grid_to_world_position_center(point))
                }

                engine.renderer_push_line(points_dynamic[:], shader_info_line.shader, COLOR_MOVE)
            }
        }

        { engine.profiler_zone("draw_debug_ui_entity_highlight", PROFILER_COLOR_RENDER)
            if _game.debug_ui_entity != 0 && _game.debug_ui_entity_highlight {
                component_transform, err_transform := engine.entity_get_component(_game.debug_ui_entity, engine.Component_Transform)
                if err_transform == .None {
                    engine.renderer_push_quad(
                        { component_transform.position.x, component_transform.position.y },
                        { component_transform.scale.x, component_transform.scale.y } * GRID_SIZE,
                        { 1, 0, 0, 0.3 },
                        nil, 0, 0, 0,
                        shader_info_default.shader,
                    )
                }
            }
        }

        { // Mouse cursor
            engine.renderer_push_quad(
                _game.mouse_world_position,
                { 1, 1 },
                { 1, 0, 0, 1 },
                nil, 0, 0, 0, shader_info_default.shader,
            )
        }
    }

    engine.platform_set_window_title(get_window_title()) // This needs to be done at the end of the frame since we use frame statistics

    return
}

@(export) app_quit :: proc(app_memory: ^App_Memory) {
    context.logger = _engine.logger.logger
    engine.engine_quit()
}

@(export) app_reload :: proc(app_memory: ^App_Memory) {
    _mem = app_memory
    _game = _mem.game
    _engine = _mem.engine
    context.logger = _engine.logger.logger
    engine.engine_reload(_mem.engine)
}

get_window_title :: proc() -> string {
    current, previous := tools.mem_get_usage()
    return fmt.tprintf("Snowball (Renderer: %v | Refresh rate: %3.0fHz | FPS: %5.0f / %5.0f | Stats: %v | Memory: %v)",
        engine.RENDERER, f32(_engine.renderer.refresh_rate),
        f32(_engine.platform.locked_fps), f32(_engine.platform.actual_fps), _engine.renderer.stats,
        current,
    )
}

update_player_inputs :: proc() {
    keyboard_was_used := false
    for key in _engine.platform.keys {
        if _engine.platform.keys[key].down || _engine.platform.keys[key].released {
            keyboard_was_used = true
            break
        }
    }

    {
        player_inputs := &_game.player_inputs
        player_inputs^ = {}

        player_inputs.mouse_left = _engine.platform.mouse_keys[engine.BUTTON_LEFT]

        if keyboard_was_used {
            if _engine.platform.keys[.A].down {
                player_inputs.move.x -= 1
            } else if _engine.platform.keys[.D].down {
                player_inputs.move.x += 1
            }
            if _engine.platform.keys[.W].down {
                player_inputs.move.y -= 1
            } else if _engine.platform.keys[.S].down {
                player_inputs.move.y += 1
            }

            if _engine.platform.keys[.LEFT].down {
                player_inputs.aim.x -= 1
            } else if _engine.platform.keys[.RIGHT].down {
                player_inputs.aim.x += 1
            }
            if _engine.platform.keys[.UP].down {
                player_inputs.aim.y -= 1
            } else if _engine.platform.keys[.DOWN].down {
                player_inputs.aim.y += 1
            }

            if _engine.platform.keys[.LSHIFT].down {
                player_inputs.modifier |= { .Mod_1 }
            }
            if _engine.platform.keys[.LCTRL].down {
                player_inputs.modifier |= { .Mod_2 }
            }
            if _engine.platform.keys[.LALT].down {
                player_inputs.modifier |= { .Mod_3 }
            }

            player_inputs.back = _engine.platform.keys[.BACKSPACE]
            player_inputs.start = _engine.platform.keys[.RETURN]
            player_inputs.confirm = _engine.platform.keys[.SPACE]
            player_inputs.cancel = _engine.platform.keys[.ESCAPE]
            player_inputs.debug_0 = _engine.platform.keys[.GRAVE]
            player_inputs.debug_1 = _engine.platform.keys[.F1]
            player_inputs.debug_2 = _engine.platform.keys[.F2]
            player_inputs.debug_3 = _engine.platform.keys[.F3]
            player_inputs.debug_4 = _engine.platform.keys[.F4]
            player_inputs.debug_5 = _engine.platform.keys[.F5]
            player_inputs.debug_6 = _engine.platform.keys[.F6]
            player_inputs.debug_7 = _engine.platform.keys[.F7]
            player_inputs.debug_8 = _engine.platform.keys[.F8]
            player_inputs.debug_9 = _engine.platform.keys[.F9]
            player_inputs.debug_10 = _engine.platform.keys[.F10]
            player_inputs.debug_11 = _engine.platform.keys[.F11]
            player_inputs.debug_12 = _engine.platform.keys[.F12]
        } else {
            controller_state, controller_found := engine.platform_get_controller_from_player_index(0)
            if controller_found {
                if (controller_state.buttons[.DPAD_UP].down) {
                    player_inputs.move.y -= 1
                } else if (controller_state.buttons[.DPAD_DOWN].down) {
                    player_inputs.move.y += 1
                }
                if (controller_state.buttons[.DPAD_LEFT].down) {
                    player_inputs.move.x -= 1
                } else if (controller_state.buttons[.DPAD_RIGHT].down) {
                    player_inputs.move.x += 1
                }
                if (controller_state.buttons[.DPAD_UP].down) {
                    player_inputs.move.y -= 1
                }

                // If we use the analog sticks, we ignore the DPad inputs
                if controller_state.axes[.LEFTX].value < -CONTROLLER_DEADZONE || controller_state.axes[.LEFTX].value > CONTROLLER_DEADZONE {
                    player_inputs.move.x = f32(controller_state.axes[.LEFTX].value) / f32(size_of(controller_state.axes[.LEFTX].value))
                }
                if controller_state.axes[.LEFTY].value < -CONTROLLER_DEADZONE || controller_state.axes[.LEFTY].value > CONTROLLER_DEADZONE {
                    player_inputs.move.y = f32(controller_state.axes[.LEFTY].value) / f32(size_of(controller_state.axes[.LEFTY].value))
                }

                if controller_state.axes[.RIGHTX].value < -CONTROLLER_DEADZONE || controller_state.axes[.RIGHTX].value > CONTROLLER_DEADZONE {
                    player_inputs.aim.x = f32(controller_state.axes[.RIGHTX].value) / f32(size_of(controller_state.axes[.RIGHTX].value))
                }
                if controller_state.axes[.RIGHTY].value < -CONTROLLER_DEADZONE || controller_state.axes[.RIGHTY].value > CONTROLLER_DEADZONE {
                    player_inputs.aim.y = f32(controller_state.axes[.RIGHTY].value) / f32(size_of(controller_state.axes[.RIGHTY].value))
                }

                player_inputs.back = controller_state.buttons[.BACK]
                player_inputs.start = controller_state.buttons[.START]
                player_inputs.confirm = controller_state.buttons[.A]
                player_inputs.cancel = controller_state.buttons[.B]
            }
        }

        if engine.vector_not_equal(player_inputs.move, 0) {
            player_inputs.move = linalg.vector_normalize(player_inputs.move)
        }
        if engine.vector_not_equal(player_inputs.aim, 0) {
            player_inputs.aim = linalg.vector_normalize(player_inputs.aim)
        }
    }
}

arena_allocator_make :: proc(size: int, allocator: mem.Allocator) -> runtime.Allocator {
    context.allocator = allocator
    arena := new(mem.Arena)
    arena_backing_buffer := make([]u8, size)
    mem.arena_init(arena, arena_backing_buffer)
    result := mem.arena_allocator(arena)
    result.procedure = arena_allocator_proc
    return result
}

arena_allocator_free_all_and_zero :: proc(allocator: runtime.Allocator = context.allocator) {
    arena := cast(^mem.Arena) allocator.data
    mem.zero_slice(arena.data)
    free_all(allocator)
}

@(deferred_out=mem.end_arena_temp_memory)
arena_temp_block :: proc(arena: ^mem.Arena) -> mem.Arena_Temp_Memory {
    return mem.begin_arena_temp_memory(arena)
}

arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (new_memory: []byte, error: mem.Allocator_Error) {
    new_memory, error = mem.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location)

    if error != .None {
        if error == .Mode_Not_Implemented {
            log.warnf("ARENA alloc (%v) %v: %v byte at %v", mode, error, size, location)
        } else {
            log.errorf("ARENA alloc (%v) %v: %v byte at %v", mode, error, size, location)
            os.exit(0)
        }
    }

    return
}

// FIXME: this is assuming a 1px padding between sprites
texture_position_and_size :: proc(texture: ^engine.Texture, texture_position, texture_size: Vector2i32, padding : i32 = 1, loc := #caller_location) ->
    (normalized_texture_position, normalized_texture_size, pixel_size: Vector2f32)
{
    assert(texture != nil, "Invalid texture.", loc)
    assert(texture.width > 0, "Invalid texture: texture.width must be greater than 0.", loc)
    assert(texture.height > 0, "Invalid texture: texture.height must be greater than 0.", loc)
    assert(texture_size.x > 0, "Texture size: size.x must be greater than 0.", loc)
    assert(texture_size.y > 0, "Texture size: size.y must be greater than 0. ", loc)
    pixel_size = Vector2f32 { 1 / f32(texture.width), 1 / f32(texture.height) }
    pos := Vector2f32 { f32(texture_position.x), f32(texture_position.y) }
    size := Vector2f32 { f32(texture_size.x), f32(texture_size.y) }
    normalized_texture_position = {
        (pixel_size.x * pos.x) + (f32(padding) * pixel_size.x) + (f32(padding) * 2 * pixel_size.x * pos.x / size.x),
        (pixel_size.y * pos.y) + (f32(padding) * pixel_size.y) + (f32(padding) * 2 * pixel_size.y * pos.y / size.y),
    }
    normalized_texture_size = {
        size.x * pixel_size.x,
        size.y * pixel_size.y,
    }
    return
}

window_to_world_position :: proc(window_position: Vector2i32) -> Vector2f32 {
    window_position_f32 := engine.vector_i32_to_f32(window_position)
    window_size_f32 := engine.vector_i32_to_f32(_engine.platform.window_size)
    pixel_density := _engine.renderer.pixel_density
    camera_position_f32 := Vector2f32 { _engine.renderer.world_camera.position.x, _engine.renderer.world_camera.position.y }
    zoom := _engine.renderer.world_camera.zoom
    ratio := window_size_f32 / _engine.renderer.game_view_size

    // engine.ui_input_float2("game_view_position", cast(^[2]f32) &_engine.renderer.game_view_position)
    // engine.ui_input_float2("game_view_size", cast(^[2]f32) &_engine.renderer.game_view_size)
    // engine.ui_input_float2("window_size", cast(^[2]f32) &_engine.platform.window_size)
    // engine.ui_text("window_position:      %v", window_position_f32)
    // engine.ui_text("mouse_position grid:  %v", _game.mouse_grid_position)
    // engine.ui_text("mouse_position world: %v", _game.mouse_world_position)
    // engine.ui_text("ratio:                %v", ratio)
    // engine.ui_text("ideal_scale:          %v", _engine.renderer.ideal_scale)

    result := (((window_position_f32 - window_size_f32 / 2 - _engine.renderer.game_view_position)) / zoom * pixel_density + camera_position_f32) * ratio * pixel_density
    // engine.ui_text("result:               %v", result)

    return result
}
