package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/ease"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:math/rand"
import "core:mem"
import "core:mem/virtual"
import "core:runtime"
import "core:slice"
import "core:sort"
import "core:strings"
import "core:time"
import "../tools"
import engine "../engine_v2"

Game_State :: struct {
    arena:                      tools.Named_Virtual_Arena,

    quit_requested:             bool,
    game_mode:                  Mode,
    player_inputs:              Player_Inputs,

    world_camera:               engine.Camera_Orthographic,

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
    asset_shader_fog:           Asset_Id,
    asset_shader_test:          Asset_Id,

    asset_music_worldmap:       Asset_Id,
    asset_music_battle:         Asset_Id,

    asset_sound_cancel:         Asset_Id,
    asset_sound_confirm:        Asset_Id,
    asset_sound_invalid:        Asset_Id,
    asset_sound_hit:            Asset_Id,

    asset_units:                [dynamic]Asset_Id,
    asset_abilities:            [dynamic]Asset_Id,

    rand:                       rand.Rand,

    last_frame_camera:          engine.Camera_Orthographic,
    render_command_clear:       ^engine.Render_Command_Clear,
    render_command_sprites:     ^engine.Render_Command_Draw_Sprite,
    render_command_gl:          ^engine.Render_Command_Draw_GL,
    render_commands:            [dynamic]rawptr,
    palettes:                   [engine.PALETTE_MAX]engine.Color_Palette,
    loaded_textures:            [engine.SPRITE_TEXTURE_MAX]Asset_Id,

    units:                      [dynamic]Unit,
    abilities:                  [dynamic]Ability,

    party:                      [dynamic]int,
    foes:                       [dynamic]int,

    mouse_world_position:       Vector2f32,
    mouse_grid_position:        Vector2i32,

    highlighted_cells:          [dynamic]Cell_Highlight, // TODO: do we really need this to be dynamic? pretty sure this would be just a slice
    fog_cells:                  []Cell_Fog,
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
    debug_ui_entity_tiles:      bool,
    debug_ui_entity_units:      bool,
    debug_ui_entity_children:   bool,
    debug_ui_entity_other:      bool,
    debug_ui_shader_asset_id:   Asset_Id,
    debug_draw_tiles:           bool,
    debug_show_bounding_boxes:  bool,
    debug_entity_under_mouse:   Entity,
    debug_draw_entities:        bool,
    debug_draw_fog:             bool,

    cheat_act_anywhere:         bool,
    cheat_act_repeatedly:       bool,
    cheat_move_anywhere:        bool,
    cheat_move_repeatedly:      bool,
}

Game_Mode :: enum { Init, Title, WorldMap, Battle, Debug }

Cell_Highlight_Type :: enum { Move, Ability, Ally, Foe }
Cell_Highlight :: struct {
    position:               Vector2i32,
    type:                   Cell_Highlight_Type,
}
Cell_Fog :: struct {
    position:               Vector2i32,
    active:                 bool,
}

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

// Instance of a unit.
Unit :: struct {
    asset:              engine.Asset_Id,
    grid_position:      Vector2i32,
    in_battle:          bool,
    hide_in_turn_order: bool,
    direction:          Directions,
    entity:             Entity,
    controlled_by:      Unit_Controllers,
    alliance:           Unit_Alliances,
    // Data below is copied directly from Asset_Unit when creating an instance of a unit, see: `create_unit_from_asset`
    name:               string,
    sprite_position:    Vector2i32,
    stat_health:        i32,
    stat_health_max:    i32,
    stat_ctr:           i32,
    stat_speed:         i32,
    stat_move:          i32,
    stat_vision:        i32,
}
Unit_Controllers :: enum { CPU = 0, Player = 1 }
Unit_Alliances :: enum { Neutral = 0, Ally = 1, Foe = 2 }

Directions :: enum { Left = 0, Right = 1 }

// Instance of a ability.
Ability :: struct {
    asset:              engine.Asset_Id,
    // Data below is copied directly from Asset_Unit when creating an instance of a unit, see: `create_ability_from_asset`
    name:               string,
    damage:             i32,
    range:              i32,
    push:               i32,
    damage_type:        Damage_Types,
}

Damage_Types :: enum {
    Strike = 0,
    Push   = 1,
    Fall   = 2,
}

GAME_VOLUME_MAIN        :: #config(GAME_VOLUME_MAIN, 0.0)
SKIP_TITLE              :: #config(SKIP_TITLE, true)
AUTO_PLAY               :: #config(AUTO_PLAY, true)
TITLE_ENABLE            :: #config(TITLE_ENABLE, ODIN_DEBUG)

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
GRID_SIZE_F32           :: f32(GRID_SIZE)
GRID_SIZE_V2F32         :: Vector2f32 { f32(GRID_SIZE), f32(GRID_SIZE) }

COLOR_MOVE         :: Color { 0, 0, 0.75, 0.5 }
COLOR_ABILITY      :: Color { 0, 0.75, 0, 0.5 }
COLOR_ALLY         :: Color { 0, 0, 0.75, 0.5 }
COLOR_FOE          :: Color { 0, 0.75, 0, 0.5 }
COLOR_IN_RANGE     :: Color { 1, 1, 0, 1 }
COLOR_OUT_OF_RANGE :: Color { 1, 0, 0, 1 }

game_update :: proc(app_memory: ^App_Memory) -> (quit: bool, reload: bool) {
    context.allocator = _mem.game.arena.allocator

    when ODIN_DEBUG {
        mem_usage, _ := tools.mem_get_usage()
        if mem_usage > mem.Gigabyte * 10 { // At the moment the profiler is using a LOT of memory so this can actually happen
            fmt.panicf("Quitting to avoid using too much memory, %v used!", tools.format_bytes_size(int(mem_usage)))
        }
    }

    engine.set_window_title(get_window_title())
    engine.frame_begin()
    defer engine.frame_end()

    window_size := engine.get_window_size()
    frame_stat := engine.get_frame_stat()
    pixel_density := engine.get_pixel_density()

    ui_push_theme_debug()
    defer ui_pop_theme_debug()

    game_ui_debug()

    shader_default, shader_default_err := engine.asset_get_asset_info_shader(_mem.game.asset_shader_sprite)
    shader_info_line, shader_line_err := engine.asset_get_asset_info_shader(_mem.game.asset_shader_line)

    camera := &_mem.game.world_camera
    camera_bounds := get_world_camera_bounds()
    camera_bounds_padded := camera_bounds
    camera_bounds_padded.zw *= 1.2
    level_bounds := get_level_bounds()
    camera_move := Vector3f32 {}
    camera_zoom : f32 = 0

    { engine.profiler_zone("inputs")
        inputs := engine.get_inputs()
        update_player_inputs(inputs)

        mouse_position := engine.mouse_get_position()
        _mem.game.mouse_world_position = window_to_world_position(mouse_position)
        _mem.game.mouse_grid_position = world_to_grid_position(_mem.game.mouse_world_position)

        // TODO: do this inside battle only
        {
            if _mem.game.player_inputs.aim != {} {
                camera_move.xy = cast([2]f32) _mem.game.player_inputs.aim
            }
            if _mem.game.player_inputs.zoom != 0 && engine.ui_is_any_window_hovered() == false {
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
                    engine.renderer_reload_all_shaders()
                }
            }

            if .Mod_1 in _mem.game.player_inputs.modifier {
                if _mem.game.player_inputs.debug_1.released {

                }
                if _mem.game.player_inputs.debug_2.released {
                    _mem.game.debug_draw_tiles = !_mem.game.debug_draw_tiles
                }
                if _mem.game.player_inputs.debug_3.released {
                    _mem.game.debug_draw_fog = !_mem.game.debug_draw_fog
                }
                if _mem.game.player_inputs.debug_4.released {
                    _mem.game.debug_show_bounding_boxes = !_mem.game.debug_show_bounding_boxes
                }
                if _mem.game.player_inputs.debug_7.released {
                }

                if inputs.keys[.Q].down {
                    camera.rotation += frame_stat.delta_time / 1000
                }
                if inputs.keys[.E].down {
                    camera.rotation -= frame_stat.delta_time / 1000
                }

                if .Mod_2 in _mem.game.player_inputs.modifier {
                    if _mem.game.player_inputs.move.x < 0 {
                        _mem.game.debug_ui_entity -= 10
                    }
                    if _mem.game.player_inputs.move.x > 0 {
                        _mem.game.debug_ui_entity += 10
                    }
                } else {
                    if _mem.game.player_inputs.move.x < 0 {
                        _mem.game.debug_ui_entity -= 1
                    }
                    if _mem.game.player_inputs.move.x > 0 {
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

    if engine.should_quit() || _mem.game.quit_requested {
        quit = true
        return
    }

    if camera_zoom != 0 {
        // FIXME: level bounds
        // max_zoom := engine.vector_i32_to_f32(window_size) * pixel_density / level_bounds.zx / 2
        max_zoom := Vector2f32 { 1, 1 }
        next_camera_zoom := math.clamp(camera.zoom + (camera_zoom * frame_stat.delta_time / 35), max(max_zoom.x, max_zoom.y), 16)

        // next_camera_position := camera.position
        // next_camera_bounds := get_camera_bounds(engine.vector_i32_to_f32(window_size), next_camera_position.xy, next_camera_zoom)

        // if engine.aabb_collides_x(level_bounds, next_camera_bounds) == false {
        //     min_x := (level_bounds.x - level_bounds.z) + next_camera_bounds.z
        //     max_x := (level_bounds.x + level_bounds.z) - next_camera_bounds.z
        //     next_camera_position.x = math.clamp(next_camera_position.x, min_x, max_x)
        // }
        // if engine.aabb_collides_y(level_bounds, next_camera_bounds) == false {
        //     min_y := (level_bounds.y - level_bounds.w) + next_camera_bounds.w
        //     max_y := (level_bounds.y + level_bounds.w) - next_camera_bounds.w
        //     next_camera_position.y = math.clamp(next_camera_position.y, min_y, max_y)
        // }

        // FIXME: clamp camera position to bounds
        // camera.position = next_camera_position
        camera.zoom = next_camera_zoom
    }
    if camera_move != {} {
        // FIXME: camera bounds
        // next_camera_bounds := get_camera_bounds(engine.vector_i32_to_f32(window_size), (camera.position + camera_move).xy, camera.zoom)

        // if engine.aabb_collides_x(level_bounds, next_camera_bounds) == false {
        //     camera_move.x = 0
        // }
        // if engine.aabb_collides_y(level_bounds, next_camera_bounds) == false {
        //     camera_move.y = 0
        // }
        camera_move = linalg.vector_normalize(camera_move)

        if camera_move != {} {
            camera.position = camera.position + (camera_move * frame_stat.delta_time / 10)
        }
    }

    engine.animation_update()

    {
        engine.profiler_zone("render_v2")

        camera_update_matrix()

        if _mem.game.game_mode.current != int(Game_Mode.Debug) {
            sorted_entities: []Entity

            // FIXME: sometimes we get an invalid entity in sorted_entities, we really need to fix this

            // Dear future self, before you start optimizing this sort and render loop because is is slow,
            // please remember that you have to profile in RELEASE mode and this is only taking 20µs there.
            sort_entities: { engine.profiler_zone("sort_entities", PROFILER_COLOR_RENDER)
                sprite_components, entity_indices, sprite_components_err := engine.entity_get_components(engine.Component_Sprite)
                assert(sprite_components_err == .None)

                when ODIN_DEBUG {
                    // FIXME: this is to prevent out of band access because right now we have a bug where z_indices_by_entity and sprite_components have different length
                    if engine.get_code_version() > 0 {
                        log.warnf("skipping z sort")
                        sorted_entities_err: runtime.Allocator_Error
                        sorted_entities, sorted_entities_err = slice.map_keys(entity_indices, context.temp_allocator)
                        break sort_entities
                    }
                }

                z_indices_by_entity := make([]i32, engine.entity_get_entities_count(), context.temp_allocator)

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

            {
                engine.profiler_zone("sprites_update_data")

                transform_components_by_entity := engine.entity_get_components_by_entity(engine.Component_Transform)
                sprite_components_by_entity := engine.entity_get_components_by_entity(engine.Component_Sprite)

                mem.zero(&_mem.game.render_command_sprites.data, len(_mem.game.render_command_sprites.data))
                _mem.game.render_command_sprites.count = 0

                draw_entities := true
                when ODIN_DEBUG {
                    draw_entities = _mem.game.debug_draw_entities
                }

                if draw_entities {
                    sprite_index := 0
                    for entity, i in sorted_entities {
                        sprite := sprite_components_by_entity[entity]
                        transform := transform_components_by_entity[entity]

                        when ODIN_DEBUG {
                            if _mem.game.debug_draw_tiles == false {
                                flag, flag_err := engine.entity_get_component(entity, Component_Flag)
                                if flag_err == .None && (.Tile in flag.value) {
                                    continue
                                }
                            }
                        }

                        // FIXME: How can we have asset_ok == false? We really shoudln't check if the texture is loaded in this loop anyways...
                        asset_info, asset_info_ok := engine.asset_get_asset_info_image(sprite.texture_asset)
                        if asset_info_ok == false {
                            log.errorf("texture_asset not loaded for entity: %v", entity)
                            continue
                        }
                        // assert(asset_info_ok, fmt.tprintf("texture_asset not loaded for entity: %v", entity))
                        texture_position, texture_size, _pixel_size := engine.texture_position_and_size(asset_info.size, sprite.texture_position, sprite.texture_size, sprite.texture_padding)

                        // FIXME: this is slow, but i need to measure just how much
                        absolute_position, absolute_scale := entity_get_absolute_transform(&transform)

                        _mem.game.render_command_sprites.data[sprite_index].position = absolute_position
                        _mem.game.render_command_sprites.data[sprite_index].scale = absolute_scale * GRID_SIZE_V2F32
                        _mem.game.render_command_sprites.data[sprite_index].color = transmute(Vector4f32) sprite.tint
                        _mem.game.render_command_sprites.data[sprite_index].texture_position = texture_position
                        _mem.game.render_command_sprites.data[sprite_index].texture_size = texture_size
                        _mem.game.render_command_sprites.data[sprite_index].texture_index = f32(texture_asset_to_texture_index(sprite.texture_asset))
                        _mem.game.render_command_sprites.data[sprite_index].palette = f32(sprite.palette)
                        _mem.game.render_command_sprites.count += 1
                        sprite_index += 1
                    }
                }
            }
        }

        draw_highlighted_cells: {
            engine.profiler_zone(fmt.tprintf("draw_highlighted_cells (%v)", len(_mem.game.highlighted_cells)), PROFILER_COLOR_RENDER)
            asset_id := _mem.game.asset_image_spritesheet
            asset_info, asset_info_ok := engine.asset_get_asset_info_image(asset_id)
            if asset_info_ok == false {
                log.errorf("draw_highlighted_cells: %v")
                break draw_highlighted_cells
            }

            texture_position, texture_size, pixel_size := engine.texture_position_and_size(asset_info.size, grid_position(5, 5), GRID_SIZE_V2)
            for cell, i in _mem.game.highlighted_cells {

                color := engine.Color { 1, 1, 1, 1 }
                switch cell.type {
                    case .Move: color = COLOR_MOVE
                    case .Ability: color = COLOR_ABILITY
                    case .Ally: color = COLOR_ALLY
                    case .Foe: color = COLOR_FOE
                }

                sprite_index := _mem.game.render_command_sprites.count

                _mem.game.render_command_sprites.data[sprite_index].position = grid_to_world_position_center(cell.position)
                _mem.game.render_command_sprites.data[sprite_index].scale = GRID_SIZE_V2F32
                _mem.game.render_command_sprites.data[sprite_index].color = transmute(Vector4f32) color
                _mem.game.render_command_sprites.data[sprite_index].texture_position = texture_position
                _mem.game.render_command_sprites.data[sprite_index].texture_size = texture_size
                _mem.game.render_command_sprites.data[sprite_index].texture_index = f32(texture_asset_to_texture_index(asset_id))
                _mem.game.render_command_sprites.count += 1
            }
        }

        if _mem.game.debug_draw_fog {
            engine.profiler_zone(fmt.tprintf("fog_of_war(%v)", len(_mem.game.fog_cells)))

            asset_id := _mem.game.asset_image_spritesheet
            asset_info, asset_info_ok := engine.asset_get_asset_info_image(asset_id)
            assert(asset_info_ok)

            for fog_cell, cell_index in _mem.game.fog_cells {
                if fog_cell.active == false {
                    continue
                }

                sprite_index := _mem.game.render_command_sprites.count
                texture_position, texture_size, _pixel_size := engine.texture_position_and_size(asset_info.size, grid_position(6, 11), GRID_SIZE_V2)

                _mem.game.render_command_sprites.data[sprite_index].position = grid_to_world_position_center(fog_cell.position)
                _mem.game.render_command_sprites.data[sprite_index].scale = GRID_SIZE_V2F32
                _mem.game.render_command_sprites.data[sprite_index].color = { 0, 0, 0, 1 }
                _mem.game.render_command_sprites.data[sprite_index].texture_position = texture_position
                _mem.game.render_command_sprites.data[sprite_index].texture_size = texture_size
                _mem.game.render_command_sprites.data[sprite_index].texture_index = f32(texture_asset_to_texture_index(asset_id))
                _mem.game.render_command_sprites.count += 1
            }
        }

        if _mem.game.render_command_sprites.count > 0 {
            engine.profiler_zone("sprites_update_vertex_buffer")
            engine.sg_update_buffer(_mem.game.render_command_sprites.bindings.vertex_buffers[1], {
                ptr = &_mem.game.render_command_sprites.data,
                size = u64(_mem.game.render_command_sprites.count) * size_of(_mem.game.render_command_sprites.data[0]),
            })
            _mem.game.render_command_sprites.vs_uniform.projection_view = camera.projection_matrix * camera.view_matrix
        }

        for command_ptr in _mem.game.render_commands {
            engine.r_command_exec(command_ptr)
        }
        engine.sg_commit()
    }

    when false {
        engine.profiler_zone("render_legacy")

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
                        shader = shader_default,
                    )
                }
            }

            engine.renderer_push_quad(
                camera_bounds.xy,
                camera_bounds.zw * 2,
                { 0, 1, 0, 0.2 },
                shader = shader_default,
            )

            engine.renderer_push_quad(
                level_bounds.xy,
                level_bounds.zw * 2,
                { 0, 0, 1, 0.2 },
                shader = shader_default,
            )
        }

        { // Mouse cursor
            engine.renderer_push_quad(
                _mem.game.mouse_world_position,
                { 1, 1 },
                { 1, 0, 0, 1 },
                nil, 0, 0, 0, shader_default,
            )
        }

        if scene_transition_is_done() == false {
            shader, shader_ok := engine.asset_get_asset_info_shader(_mem.game.asset_shader_swipe)
            // assert(shader_ok)
            if shader_ok {
                progress := scene_transition_calculate_progress()
                type := _mem.game.scene_transition.type
                // FIXME: shader
                // switch type {
                //     case .Swipe_Left_To_Right:
                //         engine.renderer_set_uniform_NEW_1f_to_shader(shader, "u_progress", progress)
                //     case .Unswipe_Left_To_Right:
                //         engine.renderer_set_uniform_NEW_1f_to_shader(shader, "u_progress", 1 - progress)
                // }
                engine.renderer_push_quad(
                    { 0, 0 },
                    { f32(window_size.x), f32(window_size.y) },
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

    when TITLE_ENABLE {
        strings.write_string(&builder, fmt.tprintf(" | FPS: %5.0f", engine.get_frame_stat().fps))
        strings.write_string(&builder, fmt.tprintf(" | Memory usage: %v/%v", tools.mem_get_usage()))
    }

    title := strings.to_string(builder)
    return title
}

update_player_inputs :: proc(inputs: ^engine.Inputs) {
    {
        player_inputs := &_mem.game.player_inputs
        player_inputs^ = {}

        player_inputs.mouse_left = inputs.mouse_keys[.Left]
        player_inputs.zoom = f32(inputs.mouse_wheel.y)

        if inputs.keyboard_was_used {
            if inputs.keys[.A].down {
                player_inputs.aim.x -= 1
            } else if inputs.keys[.D].down {
                player_inputs.aim.x += 1
            }
            if inputs.keys[.W].down {
                player_inputs.aim.y -= 1
            } else if inputs.keys[.S].down {
                player_inputs.aim.y += 1
            }

            if inputs.keys[.LEFT].down {
                player_inputs.move.x -= 1
            } else if inputs.keys[.RIGHT].down {
                player_inputs.move.x += 1
            }
            if inputs.keys[.UP].down {
                player_inputs.move.y -= 1
            } else if inputs.keys[.DOWN].down {
                player_inputs.move.y += 1
            }

            if inputs.keys[.LSHIFT].down {
                player_inputs.modifier |= { .Mod_1 }
            }
            if inputs.keys[.LCTRL].down {
                player_inputs.modifier |= { .Mod_2 }
            }
            if inputs.keys[.LALT].down {
                player_inputs.modifier |= { .Mod_3 }
            }

            player_inputs.back = inputs.keys[.BACKSPACE]
            player_inputs.start = inputs.keys[.DELETE]
            player_inputs.confirm = inputs.keys[.RETURN]
            player_inputs.cancel = inputs.keys[.ESCAPE]
            player_inputs.debug_0 = inputs.keys[.GRAVE]
            player_inputs.debug_1 = inputs.keys[.F1]
            player_inputs.debug_2 = inputs.keys[.F2]
            player_inputs.debug_3 = inputs.keys[.F3]
            player_inputs.debug_4 = inputs.keys[.F4]
            player_inputs.debug_5 = inputs.keys[.F5]
            player_inputs.debug_6 = inputs.keys[.F6]
            player_inputs.debug_7 = inputs.keys[.F7]
            player_inputs.debug_8 = inputs.keys[.F8]
            player_inputs.debug_9 = inputs.keys[.F9]
            player_inputs.debug_10 = inputs.keys[.F10]
            player_inputs.debug_11 = inputs.keys[.F11]
            player_inputs.debug_12 = inputs.keys[.F12]
        } else {
            controller_state, controller_found := engine.controller_get_by_player_index(0)
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

window_to_world_position :: proc(window_position: Vector2i32) -> (result: Vector2f32) {
    window_size := engine.get_window_size()

    window_position_f32 := engine.vector_i32_to_f32(window_position)
    window_size_f32 := engine.vector_i32_to_f32(window_size)
    pixel_density := engine.get_pixel_density()
    camera_position_f32 := Vector2f32 { _mem.game.world_camera.position.x, _mem.game.world_camera.position.y }
    zoom := _mem.game.world_camera.zoom
    game_view_position := engine.Vector2f32 { 0, 0 }
    game_view_size := window_size_f32
    ratio := window_size_f32 / game_view_size

    result = (((window_position_f32 - window_size_f32 / 2 - game_view_position)) / zoom * pixel_density + camera_position_f32) * ratio * pixel_density

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
    window_size := engine.get_window_size()
    return get_camera_bounds(engine.vector_i32_to_f32(window_size), _mem.game.world_camera.position.xy, _mem.game.world_camera.zoom)
}
get_camera_bounds :: proc(camera_size, position, zoom: Vector2f32) -> Vector4f32 {
    pixel_density := engine.get_pixel_density()
    size := camera_size * pixel_density / zoom
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
