package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:mem/virtual"
import "core:runtime"
import "core:slice"
import "core:sort"
import "core:strings"
import "core:time"
import "../tools"
import "../engine"

Game_State :: struct {
    arena:                      engine.Named_Virtual_Arena,

    game_mode:                  Mode,
    player_inputs:              Player_Inputs,

    volume_main:                f32,
    volume_music:               f32,
    volume_sound:               f32,

    asset_map_world:            Asset_Id,
    asset_map_areas:            Asset_Id,

    asset_image_spritesheet:    Asset_Id,
    asset_image_battle_bg:      Asset_Id,
    asset_image_nyan:           Asset_Id,
    asset_image_units:          Asset_Id,

    asset_shader_sprite:        Asset_Id,
    asset_shader_sprite_aa:     Asset_Id,
    asset_shader_line:          Asset_Id,
    asset_shader_grid:          Asset_Id,
    asset_shader_swipe:         Asset_Id,
    asset_shader_test:          Asset_Id,

    asset_music_worldmap:       Asset_Id,
    asset_music_battle:         Asset_Id,

    asset_sound_cancel:         Asset_Id,
    asset_sound_confirm:        Asset_Id,
    asset_sound_invalid:        Asset_Id,
    asset_sound_hit:            Asset_Id,

    rand:                       rand.Rand,

    last_frame_camera:          engine.Camera_Orthographic,

    units:                      [dynamic]Unit,
    party:                      [dynamic]int,
    foes:                       [dynamic]int,

    mouse_world_position:       Vector2f32,
    mouse_grid_position:        Vector2i32,

    highlighted_cells:          [dynamic]Cell_Highlight,
    level_assets:               map[engine.LDTK_Tileset_Uid]Asset_Id,

    scene_transition:           Scene_Transition,

    battle_index:               int,
    world_data:                 ^Game_Mode_Worldmap,
    battle_data:                ^Game_Mode_Battle,
    background_asset:           Asset_Id,
    ldtk_entity_defs:           map[engine.LDTK_Entity_Uid]engine.LDTK_Entity,

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

    cheat_act_anywhere:         bool,
    cheat_act_repeatedly:       bool,
    cheat_move_anywhere:        bool,
    cheat_move_repeatedly:      bool,
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
    zoom:       f32,
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
    stat_range:         i32,
    direction:          Directions,
    entity:             Entity,
    controlled_by:      Unit_Controllers,
    alliance:           Unit_Alliances,
}
Unit_Controllers :: enum { CPU = 0, Player = 1 }
Unit_Alliances :: enum { Neutral = 0, Ally = 1, Foe = 2 }

Directions :: enum { Left = -1, Right = 1 }

GAME_VOLUME_MAIN        :: #config(GAME_VOLUME_MAIN, 0.0)

Vector2i32              :: engine.Vector2i32
Vector2f32              :: engine.Vector2f32
Vector3f32              :: engine.Vector3f32
Vector4f32              :: engine.Vector4f32
Matrix4x4f32            :: engine.Matrix4x4f32
Entity                  :: engine.Entity
Asset_Id                :: engine.Asset_Id
Color                   :: engine.Color

NATIVE_RESOLUTION       :: Vector2f32 { 240, 135 }
CONTROLLER_DEADZONE     :: 15_000
PROFILER_COLOR_RENDER   :: 0x550000
CLEAR_COLOR             :: Color { 1, 0, 1, 1 } // This is supposed to never show up, so it's a super flashy color. If you see it, something is broken.
VOID_COLOR              :: Color { 0.4, 0.4, 0.4, 1 }
WINDOW_BORDER_COLOR     :: Color { 0, 0, 0, 1 }
GRID_SIZE               :: 8
GRID_SIZE_V2            :: Vector2i32 { GRID_SIZE, GRID_SIZE }

COLOR_MOVE         :: Color { 0, 0, 0.75, 0.5 }
COLOR_IN_RANGE     :: Color { 1, 1, 0, 1 }
COLOR_OUT_OF_RANGE :: Color { 1, 0, 0, 1 }

game_update :: proc(app_memory: ^App_Memory) -> (quit: bool, reload: bool) {
    engine.profiler_zone("game_update")
    context.allocator = _mem.game.arena.allocator

    engine.platform_set_window_title(get_window_title())
    engine.platform_frame()

    ui_push_theme_debug()
    defer ui_pop_theme_debug()

    game_ui_debug()

    camera := &_mem.renderer.world_camera
    shader_info_default, shader_default_err := engine.asset_get_asset_info_shader(_mem.game.asset_shader_sprite)
    shader_info_line, shader_line_err := engine.asset_get_asset_info_shader(_mem.game.asset_shader_line)
    camera_bounds := get_world_camera_bounds()
    level_bounds := get_level_bounds()
    camera_move := Vector3f32 {}
    camera_zoom : f32 = 0

    { engine.profiler_zone("inputs")
        update_player_inputs()

        _mem.game.mouse_world_position = window_to_world_position(_mem.platform.mouse_position)
        _mem.game.mouse_grid_position = world_to_grid_position(_mem.game.mouse_world_position)

        // TODO: do this inside battle only
        {
            if _mem.game.player_inputs.aim != {} {
                camera_move.xy = cast([2]f32) _mem.game.player_inputs.aim
            }
            if _mem.game.player_inputs.zoom != 0 && engine.ui_is_any_window_hovered() == false{
                camera_zoom = _mem.game.player_inputs.zoom
            }
        }

        { // Debug inputs
            if _mem.game.player_inputs.modifier == {} {
                if _mem.game.player_inputs.debug_0.released {
                    _mem.game.debug_ui_window_console = !_mem.game.debug_ui_window_console
                }
                if _mem.game.player_inputs.debug_1.released {
                    _mem.game.debug_ui_window_debug = !_mem.game.debug_ui_window_debug
                }
                if _mem.game.player_inputs.debug_2.released {
                    _mem.game.debug_ui_window_entities = !_mem.game.debug_ui_window_entities
                }
                if _mem.game.player_inputs.debug_3.released {
                    _mem.game.debug_ui_window_assets = !_mem.game.debug_ui_window_assets
                }
                if _mem.game.player_inputs.debug_4.released {
                    _mem.game.debug_ui_window_anim = !_mem.game.debug_ui_window_anim
                }
                if _mem.game.player_inputs.debug_5.released {
                    _mem.game.debug_ui_window_battle = !_mem.game.debug_ui_window_battle
                }
                if _mem.game.player_inputs.debug_6.released {
                    _mem.game.debug_ui_window_shader = !_mem.game.debug_ui_window_shader
                }
                if _mem.game.player_inputs.debug_12.released {
                    engine.debug_reload_shaders()
                }
            }

            if .Mod_1 in _mem.game.player_inputs.modifier {
                if _mem.game.player_inputs.debug_1.released {
                    _mem.game.debug_draw_grid = !_mem.game.debug_draw_grid
                }
                if _mem.game.player_inputs.debug_2.released {
                    _mem.game.debug_draw_tiles = !_mem.game.debug_draw_tiles
                }
                if _mem.game.player_inputs.debug_3.released {

                }
                if _mem.game.player_inputs.debug_4.released {
                    _mem.game.debug_show_bounding_boxes = !_mem.game.debug_show_bounding_boxes
                }
                if _mem.game.player_inputs.debug_7.released {
                }

                if _mem.platform.keys[.Q].down {
                    camera.rotation += _mem.platform.delta_time / 1000
                }
                if _mem.platform.keys[.E].down {
                    camera.rotation -= _mem.platform.delta_time / 1000
                }

                if .Mod_2 in _mem.game.player_inputs.modifier {
                    if _mem.platform.keys[.LEFT].down {
                        _mem.game.debug_ui_entity -= 1
                    }
                    if _mem.platform.keys[.RIGHT].down {
                        _mem.game.debug_ui_entity += 1
                    }
                } else {
                    if _mem.platform.keys[.LEFT].released {
                        _mem.game.debug_ui_entity -= 1
                    }
                    if _mem.platform.keys[.RIGHT].released {
                        _mem.game.debug_ui_entity += 1
                    }
                }
            }
        }
    }

    { engine.profiler_zone("game_mode")
        defer game_mode_check_exit()
        switch Game_Mode(_mem.game.game_mode.current) {
            case .Init: game_mode_init()
            case .Title: game_mode_title()
            case .WorldMap: game_mode_worldmap()
            case .Battle: game_mode_battle()
            case .Debug: game_mode_debug()
        }
    }

    if _mem.platform.quit_requested {
        quit = true
        return
    }

    if camera_zoom != 0 {
        max_zoom := engine.vector_i32_to_f32(_mem.platform.window_size) / level_bounds.zx / 2
        next_camera_zoom := math.clamp(camera.zoom + (camera_zoom * _mem.platform.delta_time / 35), max(max_zoom.x, max_zoom.y), 16)

        next_camera_position := camera.position
        next_camera_bounds := get_camera_bounds(engine.vector_i32_to_f32(_mem.platform.window_size), next_camera_position.xy, next_camera_zoom)

        if engine.aabb_collides_x(level_bounds, next_camera_bounds) == false {
            min_x := (level_bounds.x - level_bounds.z) + next_camera_bounds.z
            max_x := (level_bounds.x + level_bounds.z) - next_camera_bounds.z
            next_camera_position.x = math.clamp(next_camera_position.x, min_x, max_x)
        }
        if engine.aabb_collides_y(level_bounds, next_camera_bounds) == false {
            min_y := (level_bounds.y - level_bounds.w) + next_camera_bounds.w
            max_y := (level_bounds.y + level_bounds.w) - next_camera_bounds.w
            next_camera_position.y = math.clamp(next_camera_position.y, min_y, max_y)
        }

        camera.position = next_camera_position
        camera.zoom = next_camera_zoom
    }
    if camera_move != {} {
        next_camera_bounds := get_camera_bounds(engine.vector_i32_to_f32(_mem.platform.window_size), (camera.position + camera_move).xy, camera.zoom)

        if engine.aabb_collides_x(level_bounds, next_camera_bounds) == false {
            camera_move.x = 0
        }
        if engine.aabb_collides_y(level_bounds, next_camera_bounds) == false {
            camera_move.y = 0
        }
        camera_move = linalg.vector_normalize(camera_move)

        if camera_move != {} {
            camera.position = camera.position + (camera_move * _mem.platform.delta_time / 10)
        }
    }
    if _mem.game.last_frame_camera != camera^ {
        engine.renderer_update_camera_projection_matrix()
        engine.renderer_update_camera_view_projection_matrix()
    }
    if _mem.platform.window_resized {
        engine.platform_resize_window()
        engine.renderer_update_camera_projection_matrix()
        engine.renderer_update_camera_view_projection_matrix()
    }

    engine.animation_update()

    if engine.renderer_is_enabled() {
        engine.profiler_zone("render")

        engine.renderer_clear({ 0.1, 0.1, 0.1, 1 })

        engine.renderer_change_camera_begin(&_mem.renderer.world_camera)

        if _mem.game.debug_draw_entities {
            sorted_entities: []Entity

            { engine.profiler_zone("sort_entities", PROFILER_COLOR_RENDER)
                sprite_components, entity_indices, sprite_components_err := engine.entity_get_components(engine.Component_Sprite)
                assert(sprite_components_err == .None)

                z_indices_by_entity := make([]i32, len(_mem.entity.entities), context.temp_allocator)
                for entity, component_index in entity_indices {
                    z_indices_by_entity[entity] = sprite_components[component_index].z_index
                }

                sorted_entities_err: runtime.Allocator_Error
                sorted_entities, sorted_entities_err = slice.map_keys(entity_indices, context.temp_allocator)
                assert(sorted_entities_err == .None)
                assert(len(sorted_entities) == len(sprite_components), "oh no")

                {
                    engine.profiler_zone("quick_sort_proc", PROFILER_COLOR_RENDER)
                    context.user_ptr = &z_indices_by_entity
                    sort_entities_by_z_index :: proc(a, b: Entity) -> int {
                        z_indices_by_entity := cast(^[]i32) context.user_ptr
                        return int(z_indices_by_entity[a] - z_indices_by_entity[b])
                    }
                    sort.quick_sort_proc(sorted_entities, sort_entities_by_z_index)
                }
            }

            // TODO: rewrite this entire loop, this was the first thing i wrote, even before having entities and tiles, it could be WAAAAY faster.
            { engine.profiler_zone(fmt.tprintf("draw_entities (%v)", len(sorted_entities)), PROFILER_COLOR_RENDER)
                // engine.profiler_zone_temp_begin("entity_get_components_by_entity")
                transform_components_by_entity := engine.entity_get_components_by_entity(engine.Component_Transform)
                sprite_components_by_entity := engine.entity_get_components_by_entity(engine.Component_Sprite)
                flag_components_by_entity := engine.entity_get_components_by_entity(Component_Flag)
                // engine.profiler_zone_temp_end()

                for entity in sorted_entities {
                    // engine.profiler_zone(fmt.tprintf("entity: %v", entity))

                    component_sprite := sprite_components_by_entity[entity]
                    if component_sprite.hidden {
                        continue
                    }

                    // engine.profiler_zone_temp_begin("asset_get texture_asset")
                    texture_asset, texture_asset_ok := engine.asset_get(component_sprite.texture_asset)
                    // engine.profiler_zone_temp_end()
                    if texture_asset_ok == false || texture_asset.state != .Loaded {
                        continue
                    }
                    texture_asset_info, texture_asset_info_ok := texture_asset.info.(engine.Asset_Info_Image)
                    if texture_asset_info_ok == false {
                        continue
                    }

                    // engine.profiler_zone_temp_begin("entity_get_absolute_transform")
                    component_transform := transform_components_by_entity[entity]
                    position, scale := entity_get_absolute_transform(&component_transform)
                    // engine.profiler_zone_temp_end()

                    component_flag := flag_components_by_entity[entity]
                    if .Tile in component_flag.value {
                        // engine.profiler_zone_temp_begin("skip tile")
                        // defer engine.profiler_zone_temp_end()
                        if _mem.game.debug_draw_tiles == false {
                            continue
                        }

                        camera_bounds_padded := camera_bounds
                        camera_bounds_padded.zw *= 1.2
                        sprite_bounds := entity_get_sprite_bounds(&component_sprite, position, scale)
                        if engine.aabb_collides(camera_bounds_padded, sprite_bounds) == false {
                            continue
                        }
                    }

                    // engine.profiler_zone_temp_begin("skip tile")
                    shader: ^engine.Shader
                    if component_sprite.shader_asset == Asset_Id(0) {
                        log.warnf("Missing shader_asset for entity: %v", entity)
                    }
                    shader_asset_info, shader_asset_info_ok := engine.asset_get_asset_info_shader(component_sprite.shader_asset)
                    if shader_asset_info_ok {
                        shader = shader_asset_info.shader
                    }
                    // engine.profiler_zone_temp_end()

                    // engine.profiler_zone_temp_begin("texture_position_and_size")
                    texture_position, texture_size, _pixel_size := texture_position_and_size(texture_asset_info.texture, component_sprite.texture_position, component_sprite.texture_size, component_sprite.texture_padding)
                    rotation : f32 = 0
                    // engine.profiler_zone_temp_end()

                    // engine.profiler_zone_temp_begin("push_quad")
                    engine.renderer_push_quad(
                        position,
                        engine.vector_i32_to_f32(component_sprite.texture_size) * scale,
                        component_sprite.tint,
                        texture_asset_info.texture,
                        texture_position, texture_size,
                        rotation, shader, component_sprite.palette,
                        flip = component_sprite.flip,
                    )
                    // engine.profiler_zone_temp_end()
                }
            }
        }

        { engine.profiler_zone("draw_highlighted_cells", PROFILER_COLOR_RENDER)
            asset_image_spritesheet, asset_image_spritesheet_ok := engine.asset_get(_mem.game.asset_image_spritesheet)
            if asset_image_spritesheet_ok && asset_image_spritesheet.state == .Loaded {
                image_info_debug, asset_ok := asset_image_spritesheet.info.(engine.Asset_Info_Image)

                texture_position, texture_size, pixel_size := texture_position_and_size(image_info_debug.texture, { 40, 40 }, { 8, 8 })
                for cell in _mem.game.highlighted_cells {
                    color := engine.Color { 1, 1, 1, 1 }
                    switch cell.type {
                        case .Move: color = COLOR_MOVE
                        case .Ability: color = COLOR_MOVE
                    }
                    engine.renderer_push_quad(
                        Vector2f32 { f32(cell.position.x), f32(cell.position.y) } * engine.vector_i32_to_f32(GRID_SIZE_V2) + engine.vector_i32_to_f32(GRID_SIZE_V2) / 2,
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

        if _mem.game.debug_show_bounding_boxes {
            engine.profiler_zone("draw_debug_bounds", PROFILER_COLOR_RENDER)
            if _mem.game.debug_ui_entity != engine.ENTITY_INVALID {
                component_transform, err_transform := engine.entity_get_component(_mem.game.debug_ui_entity, engine.Component_Transform)
                component_sprite, err_sprite := engine.entity_get_component(_mem.game.debug_ui_entity, engine.Component_Sprite)
                if err_transform == .None && err_sprite == .None {
                    position, scale := entity_get_absolute_transform(component_transform)
                    sprite_bounds := entity_get_sprite_bounds(component_sprite, position, scale)
                    engine.renderer_push_quad(
                        sprite_bounds.xy,
                        sprite_bounds.zw * 2,
                        { 1, 0, 0, 0.3 },
                        shader = shader_info_default.shader,
                    )
                }
            }

            engine.renderer_push_quad(
                camera_bounds.xy,
                camera_bounds.zw * 2,
                { 0, 1, 0, 0.2 },
                shader = shader_info_default.shader,
            )

            engine.renderer_push_quad(
                level_bounds.xy,
                level_bounds.zw * 2,
                { 0, 0, 1, 0.2 },
                shader = shader_info_default.shader,
            )
        }

        if _mem.game.debug_draw_grid {
            shader_asset, shader_asset_ok := engine.asset_get_by_asset_id(_mem.game.asset_shader_grid)
            assert(shader_asset_ok)
            if shader_asset_ok && shader_asset.state == .Loaded {
                shader := shader_asset.info.(engine.Asset_Info_Shader).shader
                engine.renderer_push_quad(
                    { 0, 0 },
                    engine.vector_i32_to_f32(_mem.platform.window_size),
                    { 1, 0, 0, 0.2 },
                    shader = shader,
                )
            }
        }

        { // Mouse cursor
            engine.renderer_push_quad(
                _mem.game.mouse_world_position,
                { 1, 1 },
                { 1, 0, 0, 1 },
                nil, 0, 0, 0, shader_info_default.shader,
            )
        }

        if scene_transition_is_done() == false {
            shader_asset, shader_asset_ok := engine.asset_get_by_asset_id(_mem.game.asset_shader_swipe)
            assert(shader_asset_ok)
            if shader_asset_ok && shader_asset.state == .Loaded {
                shader := shader_asset.info.(engine.Asset_Info_Shader).shader
                progress := scene_transition_calculate_progress()
                type := _mem.game.scene_transition.type
                switch type {
                    case .Swipe_Left_To_Right:
                        engine.renderer_set_uniform_NEW_1f_to_shader(shader, "u_progress", progress)
                    case .Unswipe_Left_To_Right:
                        engine.renderer_set_uniform_NEW_1f_to_shader(shader, "u_progress", 1 - progress)
                }
                engine.renderer_push_quad(
                    { 0, 0 },
                    { f32(_mem.platform.window_size.x), f32(_mem.platform.window_size.y) },
                    { 0, 0, 0, 1 },
                    nil, 0, 0, 0, shader,
                )
            }
        }
    }

    _mem.game.last_frame_camera = camera^

    return
}

get_window_title :: proc() -> string {
    builder := strings.builder_make(context.temp_allocator)
    strings.write_string(&builder, fmt.tprintf("Snowball"))
    strings.write_string(&builder, fmt.tprintf(" | Renderer: %v", engine.RENDERER))
    if engine.renderer_is_enabled() {
        strings.write_string(&builder, fmt.tprintf(" | Refresh rate: %3.0fHz", f32(_mem.renderer.refresh_rate)))
        strings.write_string(&builder, fmt.tprintf(" | Stats: %v", _mem.renderer.stats))
        strings.write_string(&builder, fmt.tprintf(" | Stats: %v", _mem.renderer.stats))
    }
    strings.write_string(&builder, fmt.tprintf(" | FPS: %5.0f / %5.0f", f32(_mem.platform.locked_fps), f32(_mem.platform.actual_fps)))
    strings.write_string(&builder, fmt.tprintf(" | Memory usage: %v/%v", tools.mem_get_usage()))

    when engine.RENDERER == .None {
        strings.write_string(&builder, fmt.tprintf(" | platform %v ", engine.format_arena_usage(&_mem.platform.arena)))
        strings.write_string(&builder, fmt.tprintf(" | assets %v ", engine.format_arena_usage(&_mem.assets.arena)))
        strings.write_string(&builder, fmt.tprintf(" | entity %v ", engine.format_arena_usage(&_mem.entity.arena)))
        strings.write_string(&builder, fmt.tprintf(" | logger %v ", engine.format_arena_usage(&_mem.logger.arena)))
        strings.write_string(&builder, fmt.tprintf(" | game %v ", engine.format_arena_usage(&_mem.game.arena.arena)))
        strings.write_string(&builder, fmt.tprintf(" | game_mode %v ", engine.format_arena_usage(&_mem.game.game_mode.arena)))
        strings.write_string(&builder, fmt.tprintf(" | battle_mode %v ", _mem.game.battle_data != nil ? engine.format_arena_usage(&_mem.game.battle_data.mode.arena) : ""))
        strings.write_string(&builder, fmt.tprintf(" | battle_turn %v ", _mem.game.battle_data != nil ? engine.format_arena_usage(&_mem.game.battle_data.turn_arena) : ""))
        strings.write_string(&builder, fmt.tprintf(" | battle_plan %v ", _mem.game.battle_data != nil ? engine.format_arena_usage(&_mem.game.battle_data.plan_arena) : ""))
    }

    title := strings.to_string(builder)
    return title
}

update_player_inputs :: proc() {
    keyboard_was_used := false
    for key in _mem.platform.keys {
        if _mem.platform.keys[key].down || _mem.platform.keys[key].released {
            keyboard_was_used = true
            break
        }
    }

    {
        player_inputs := &_mem.game.player_inputs
        player_inputs^ = {}

        player_inputs.mouse_left = _mem.platform.mouse_keys[engine.BUTTON_LEFT]
        player_inputs.zoom = f32(_mem.platform.mouse_wheel.y)

        if keyboard_was_used {
            if _mem.platform.keys[.A].down {
                player_inputs.aim.x -= 1
            } else if _mem.platform.keys[.D].down {
                player_inputs.aim.x += 1
            }
            if _mem.platform.keys[.W].down {
                player_inputs.aim.y -= 1
            } else if _mem.platform.keys[.S].down {
                player_inputs.aim.y += 1
            }

            if _mem.platform.keys[.LEFT].down {
                player_inputs.move.x -= 1
            } else if _mem.platform.keys[.RIGHT].down {
                player_inputs.move.x += 1
            }
            if _mem.platform.keys[.UP].down {
                player_inputs.move.y -= 1
            } else if _mem.platform.keys[.DOWN].down {
                player_inputs.move.y += 1
            }

            if _mem.platform.keys[.LSHIFT].down {
                player_inputs.modifier |= { .Mod_1 }
            }
            if _mem.platform.keys[.LCTRL].down {
                player_inputs.modifier |= { .Mod_2 }
            }
            if _mem.platform.keys[.LALT].down {
                player_inputs.modifier |= { .Mod_3 }
            }

            player_inputs.back = _mem.platform.keys[.BACKSPACE]
            player_inputs.start = _mem.platform.keys[.DELETE]
            player_inputs.confirm = _mem.platform.keys[.RETURN]
            player_inputs.cancel = _mem.platform.keys[.ESCAPE]
            player_inputs.debug_0 = _mem.platform.keys[.GRAVE]
            player_inputs.debug_1 = _mem.platform.keys[.F1]
            player_inputs.debug_2 = _mem.platform.keys[.F2]
            player_inputs.debug_3 = _mem.platform.keys[.F3]
            player_inputs.debug_4 = _mem.platform.keys[.F4]
            player_inputs.debug_5 = _mem.platform.keys[.F5]
            player_inputs.debug_6 = _mem.platform.keys[.F6]
            player_inputs.debug_7 = _mem.platform.keys[.F7]
            player_inputs.debug_8 = _mem.platform.keys[.F8]
            player_inputs.debug_9 = _mem.platform.keys[.F9]
            player_inputs.debug_10 = _mem.platform.keys[.F10]
            player_inputs.debug_11 = _mem.platform.keys[.F11]
            player_inputs.debug_12 = _mem.platform.keys[.F12]
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

                if controller_state.axes[.TRIGGERLEFT].value < -CONTROLLER_DEADZONE || controller_state.axes[.TRIGGERLEFT].value > CONTROLLER_DEADZONE {
                    player_inputs.zoom = -1
                } else if controller_state.axes[.TRIGGERRIGHT].value < -CONTROLLER_DEADZONE || controller_state.axes[.TRIGGERRIGHT].value > CONTROLLER_DEADZONE {
                    player_inputs.zoom = +1
                }
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

window_to_world_position :: proc(window_position: Vector2i32) -> (result: Vector2f32) {
    if engine.renderer_is_enabled() == false { return }

    window_position_f32 := engine.vector_i32_to_f32(window_position)
    window_size_f32 := engine.vector_i32_to_f32(_mem.platform.window_size)
    pixel_density := _mem.renderer.pixel_density
    camera_position_f32 := Vector2f32 { _mem.renderer.world_camera.position.x, _mem.renderer.world_camera.position.y }
    zoom := _mem.renderer.world_camera.zoom
    ratio := window_size_f32 / _mem.renderer.game_view_size

    // engine.ui_input_float2("game_view_position", cast(^[2]f32) &_mem.renderer.game_view_position)
    // engine.ui_input_float2("game_view_size", cast(^[2]f32) &_mem.renderer.game_view_size)
    // engine.ui_input_float2("window_size", cast(^[2]f32) &_mem.platform.window_size)
    // engine.ui_text("window_position:      %v", window_position_f32)
    // engine.ui_text("mouse_position grid:  %v", _mem.game.mouse_grid_position)
    // engine.ui_text("mouse_position world: %v", _mem.game.mouse_world_position)
    // engine.ui_text("ratio:                %v", ratio)
    // engine.ui_text("ideal_scale:          %v", _mem.renderer.ideal_scale)

    result = (((window_position_f32 - window_size_f32 / 2 - _mem.renderer.game_view_position)) / zoom * pixel_density + camera_position_f32) * ratio * pixel_density
    // engine.ui_text("result:               %v", result)

    return result
}

entity_get_absolute_transform :: proc(component_transform: ^engine.Component_Transform) -> (position: Vector2f32, scale: Vector2f32) {
    current_transform := component_transform
    position = current_transform.position
    scale = current_transform.scale
    for current_transform.parent != engine.ENTITY_INVALID {
        // assert(current_transform.parent != entity, "entity shouldn't be their own parent!")
        parent_transform, parent_transform_err := engine.entity_get_component(current_transform.parent, engine.Component_Transform)
        assert(parent_transform_err == .None, "entity parent doesn't have a transform component.")

        current_transform = parent_transform
        position += current_transform.position
        scale *= current_transform.scale
    }
    return
}

entity_get_sprite_bounds :: proc(component_sprite: ^engine.Component_Sprite, position, scale: Vector2f32) -> Vector4f32 {
    radius := engine.vector_i32_to_f32(component_sprite.texture_size) * scale / 2
    return {
        position.x, position.y,
        radius.x, radius.y,
    }
}

get_world_camera_bounds :: proc() -> Vector4f32 {
    camera := _mem.renderer.world_camera
    size := engine.vector_i32_to_f32(_mem.platform.window_size) / camera.zoom
    return {
        camera.position.x, camera.position.y,
        size.x / 2, size.y / 2,
    }
}
get_camera_bounds :: proc(camera_size, position, zoom: Vector2f32) -> Vector4f32 {
    size := camera_size / zoom
    return {
        position.x, position.y,
        size.x / 2, size.y / 2,
    }
}
get_level_bounds :: proc() -> Vector4f32 {
    if _mem.game.battle_data == nil {
        return {}
    }
    size := engine.vector_i32_to_f32(_mem.game.battle_data.level.size * GRID_SIZE)
    return {
        size.x / 2, size.y / 2,
        size.x / 2, size.y / 2,
    }
}
