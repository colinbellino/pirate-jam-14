package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:math/rand"
import "core:mem"
import "core:runtime"
import "core:slice"
import "core:sort"
import "core:strings"
import "../tools"
import "../engine"

GAME_VOLUME_MAIN        :: #config(GAME_VOLUME_MAIN, 0.0)
SKIP_TITLE              :: #config(SKIP_TITLE, true)
AUTO_PLAY               :: #config(AUTO_PLAY, false)
TITLE_ENABLE            :: #config(TITLE_ENABLE, ODIN_DEBUG)
DEBUG_UI_ENABLE         :: #config(DEBUG_UI_ENABLE, ODIN_DEBUG)

Vector2i32              :: engine.Vector2i32
Vector2f32              :: engine.Vector2f32
Vector3f32              :: engine.Vector3f32
Vector4f32              :: engine.Vector4f32
Matrix4x4f32            :: engine.Matrix4x4f32
Entity                  :: engine.Entity
Asset_Id                :: engine.Asset_Id
Color                   :: engine.Color

NATIVE_RESOLUTION       :: Vector2f32 { 320, 180 }
CONTROLLER_DEADZONE     :: 15_000
PROFILER_COLOR_RENDER   :: 0x550000

COLOR_MOVE         :: Color { 0, 0, 0.75, 0.5 }
COLOR_ABILITY      :: Color { 0, 0.75, 0, 0.5 }
COLOR_ALLY         :: Color { 0, 0, 0.75, 0.5 }
COLOR_FOE          :: Color { 0, 0.75, 0, 0.5 }
COLOR_IN_RANGE     :: Color { 1, 1, 0, 1 }
COLOR_OUT_OF_RANGE :: Color { 1, 0, 0, 1 }

Game_State :: struct {
    arena:                      tools.Named_Virtual_Arena,

    quit_requested:             bool,
    game_mode:                  Mode,
    player_inputs:              Player_Inputs,

    world_camera:               engine.Camera_Orthographic,

    volume_main:                f32,
    volume_music:               f32,
    volume_sound:               f32,

    asset_image_spritesheet:    Asset_Id,
    asset_image_tileset:        Asset_Id,
    asset_image_player:         Asset_Id,
    asset_image_adventurer:     Asset_Id,
    asset_image_heart:          Asset_Id,
    asset_shader_sprite:        Asset_Id,
    asset_shader_swipe:         Asset_Id,
    asset_shader_line:          Asset_Id,
    asset_music_worldmap:       Asset_Id,
    asset_music_battle:         Asset_Id,
    asset_sound_cancel:         Asset_Id,
    asset_sound_confirm:        Asset_Id,
    asset_sound_invalid:        Asset_Id,
    asset_sound_hit:            Asset_Id,
    asset_map_rooms:            Asset_Id,

    rand:                       rand.Rand,

    render_enabled:             bool,
    render_command_clear:       ^Render_Command_Clear,
    render_command_sprites:     ^Render_Command_Draw_Sprite,
    render_command_gl:          ^Render_Command_Draw_GL,
    render_command_line:        ^Render_Command_Draw_Line,
    render_command_swipe:       ^Render_Command_Draw_Swipe,
    palettes:                   [engine.PALETTE_MAX]engine.Color_Palette,
    loaded_textures:            [SPRITE_TEXTURE_MAX]Asset_Id,

    mouse_world_position:       Vector2f32,
    mouse_grid_position:        Vector2i32,

    scene_transition:           Scene_Transition,

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
    debug_draw_gl:              bool,
    debug_draw_top_bar:         bool,
    debug_force_transition:     Maybe(Game_Mode),

    cheat_act_anywhere:         bool,
    cheat_act_repeatedly:       bool,
    cheat_move_anywhere:        bool,
    cheat_move_repeatedly:      bool,

    play:                       Play_State,
}

Game_Mode :: enum {
    Init = 0,
    Title = 1,
    Play = 2,
    Debug = 3,
}

Key_Modifier :: enum {
    None  = 0,
    Mod_1 = 1,
    Mod_2 = 2,
    Mod_3 = 4,
}

Key_Modifier_BitSet :: bit_set[Key_Modifier]

Player_Inputs :: struct {
    modifier:               Key_Modifier_BitSet,
    mouse_left:             engine.Key_State,
    move:                   Vector2f32,
    aim:                    Vector2f32,
    zoom:                   f32,
    confirm:                engine.Key_State,
    cancel:                 engine.Key_State,
    back:                   engine.Key_State,
    start:                  engine.Key_State,
    debug_0:                engine.Key_State,
    debug_1:                engine.Key_State,
    debug_2:                engine.Key_State,
    debug_3:                engine.Key_State,
    debug_4:                engine.Key_State,
    debug_5:                engine.Key_State,
    debug_6:                engine.Key_State,
    debug_7:                engine.Key_State,
    debug_8:                engine.Key_State,
    debug_9:                engine.Key_State,
    debug_10:               engine.Key_State,
    debug_11:               engine.Key_State,
    debug_12:               engine.Key_State,
    keyboard_was_used:      bool,
    controller_was_used:    bool,
}

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
    asset_id := _mem.game.asset_image_spritesheet
    asset_info, asset_info_ok := engine.asset_get_asset_info_image(asset_id)

    ui_push_theme_debug()
    defer ui_pop_theme_debug()

    game_ui_debug()

    camera := &_mem.game.world_camera
    camera_move := Vector2f32 {}
    camera_zoom : f32 = 0

    { engine.profiler_zone("inputs")
        inputs := engine.get_inputs()
        update_player_inputs(inputs)

        when ODIN_DEBUG {
            if _mem.game.player_inputs.modifier == { .Mod_1 } {
                if _mem.game.player_inputs.cancel.released {
                    _mem.game.debug_draw_top_bar = !_mem.game.debug_draw_top_bar
                }
                if _mem.game.player_inputs.move != {} {
                    camera_move = _mem.game.player_inputs.move
                }
                if _mem.game.player_inputs.zoom != 0 && engine.ui_is_any_window_hovered() == false {
                    if _mem.game.play.room_transition != nil {
                        engine.animation_delete_animation(_mem.game.play.room_transition)
                    }
                    camera_zoom = _mem.game.player_inputs.zoom
                }
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
            }

            if .Mod_1 in _mem.game.player_inputs.modifier {
                if _mem.game.player_inputs.debug_1.released {
                    _mem.game.debug_draw_tiles = !_mem.game.debug_draw_tiles
                }
                if _mem.game.player_inputs.debug_2.released {
                    _mem.game.debug_draw_entities = !_mem.game.debug_draw_entities
                }
                if _mem.game.player_inputs.debug_3.released {
                    _mem.game.debug_draw_fog = !_mem.game.debug_draw_fog
                }
                if _mem.game.player_inputs.debug_4.released {
                    _mem.game.debug_draw_gl = !_mem.game.debug_draw_gl
                }
                if _mem.game.player_inputs.debug_5.released {
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

        // TODO: Apply max zoom and level bounds only during battle
        if camera_zoom != 0 {
            camera.zoom = math.clamp(camera.zoom + (camera_zoom * frame_stat.delta_time / 200), CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
        }
        if camera_move != {} {
            camera.position = camera.position + (camera_move * frame_stat.delta_time / 10)
        }
    }

    {
        // min := glsl.vec2 { level_bounds.x, level_bounds.y }
        // max := glsl.vec2 { level_bounds.y + level_bounds.z, level_bounds.y + level_bounds.w }
        // camera.position.xy = auto_cast(glsl.clamp_vec2(camera.position.xy, min, max))
        camera_update_matrix()
    }

    _mem.game.mouse_world_position = window_to_world_position(engine.mouse_get_position())
    _mem.game.mouse_grid_position = world_to_grid_position(_mem.game.mouse_world_position)

    { engine.profiler_zone("game_mode")
        defer game_mode_check_exit()
        mode, mode_ok := _mem.game.debug_force_transition.?
        if mode_ok {
            log.debugf("force transition to : %v", mode)
            game_mode_transition(mode)
        }
        switch Game_Mode(_mem.game.game_mode.current) {
            case .Init: game_mode_init()
            case .Title: game_mode_title()
            case .Play: game_mode_play()
            case .Debug: game_mode_debug()
        }
    }

    if engine.should_quit() || _mem.game.quit_requested {
        quit = true
        return
    }

    engine.animation_update()

    transform_components_by_entity := engine.entity_get_components_by_entity(engine.Component_Transform)
    sprite_components_by_entity := engine.entity_get_components_by_entity(engine.Component_Sprite)

    render: {
        entities: {
            // if _mem.game.game_mode.current == int(Game_Mode.Debug) {
            //     break entities
            // }

            // FIXME: sometimes we get an invalid entity in sorted_entities, we really need to fix this

            // Dear future self, before you start optimizing this sort and render loop because is is slow,
            // please remember that you have to profile in RELEASE mode and this is only taking 20µs there.
            sorted_entities: []Entity
            sort_entities: { engine.profiler_zone("sort_entities", PROFILER_COLOR_RENDER)
                sprite_components, entity_indices, sprite_components_err := engine.entity_get_components(engine.Component_Sprite)
                assert(sprite_components_err == .None)

                Sort_Data :: struct {
                    z_index:    i32,
                    y_position: f32,
                }
                sort_data_by_entity := make([]Sort_Data, engine.entity_get_entities_count(), context.temp_allocator)

                for entity, component_index in entity_indices {
                    if int(entity) >= len(sort_data_by_entity) {
                        log.warnf("entity out of range: %v/%v", entity, len(sort_data_by_entity))
                        return
                    }
                    sort_data_by_entity[entity] = {
                        z_index    = sprite_components[component_index].z_index,
                        y_position = transform_components_by_entity[entity].position.y,
                    }
                }

                sorted_entities_err: runtime.Allocator_Error
                sorted_entities, sorted_entities_err = slice.map_keys(entity_indices, context.temp_allocator)
                assert(sorted_entities_err == .None)
                assert(len(sorted_entities) == len(sprite_components), "oh no")

                {
                    engine.profiler_zone("quick_sort_proc", PROFILER_COLOR_RENDER)
                    context.user_ptr = &sort_data_by_entity
                    sort_entities_by_z_index :: proc(a, b: Entity) -> int {
                        sort_data_by_entity := cast(^[]Sort_Data) context.user_ptr
                        return int(sort_data_by_entity[a].z_index - sort_data_by_entity[b].z_index) * 1000 + int(sort_data_by_entity[a].y_position - sort_data_by_entity[b].y_position)
                    }
                    sort.quick_sort_proc(sorted_entities, sort_entities_by_z_index)
                }
            }

            update_entities: {
                engine.profiler_zone("update_entities")

                mem.zero(&_mem.game.render_command_sprites.data, len(_mem.game.render_command_sprites.data))
                _mem.game.render_command_sprites.count = 0

                draw_entities := true
                when ODIN_DEBUG {
                    draw_entities = _mem.game.debug_draw_entities
                }
                if draw_entities == false {
                    break update_entities
                }

                sprite_index := _mem.game.render_command_sprites.count
                for entity, i in sorted_entities {
                    sprite := sprite_components_by_entity[entity]
                    transform := transform_components_by_entity[entity]

                    when ODIN_DEBUG {
                        if _mem.game.debug_draw_tiles == false {
                            flag, flag_err := engine.entity_get_component_err(entity, Component_Flag)
                            if flag_err == .None && (.Tile in flag.value) {
                                continue
                            }
                        }
                    }

                    // FIXME: How can we have asset_ok == false? We really shoudln't check if the texture is loaded in this loop anyways...
                    asset_info, asset_info_ok := engine.asset_get_asset_info_image(sprite.texture_asset)
                    if asset_info_ok == false {
                        // log.errorf("texture_asset not loaded for entity: %v", entity)
                        continue
                    }
                    // assert(asset_info_ok, fmt.tprintf("texture_asset not loaded for entity: %v", entity))
                    texture_position, texture_size := engine.texture_position_and_size(asset_info.size, sprite.texture_position, sprite.texture_size, sprite.texture_padding)

                    // TODO: this is slow, but i need to measure just how much
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

        update_swipe: {
            shader, shader_ok := engine.asset_get_asset_info_shader(_mem.game.asset_shader_swipe)
            assert(shader_ok)
            if shader_ok {
                progress := scene_transition_calculate_progress()
                type := _mem.game.scene_transition.type

                if type == .Unswipe_Left_To_Right {
                    progress = 1 - progress
                }

                _mem.game.render_command_swipe.data.position = { 0, 0 }
                _mem.game.render_command_swipe.data.color = { 0, 0, 0, 1 }
                engine.sg_update_buffer(_mem.game.render_command_swipe.bindings.vertex_buffers[1], {
                    ptr = &_mem.game.render_command_swipe.data,
                    size = size_of(_mem.game.render_command_swipe.data),
                })

                _mem.game.render_command_swipe.vs_uniform.mvp = camera.view_projection_matrix
                _mem.game.render_command_swipe.vs_uniform.window_size = window_size
                _mem.game.render_command_swipe.fs_uniform.progress = progress
                _mem.game.render_command_swipe.fs_uniform.window_size = window_size
            }
        }

        update_sprites: {
            if _mem.game.render_command_sprites.count == 0 {
                break update_sprites
            }

            engine.profiler_zone("sprites_update_vertex_buffer")
            engine.sg_update_buffer(_mem.game.render_command_sprites.bindings.vertex_buffers[1], {
                ptr = &_mem.game.render_command_sprites.data,
                size = u64(_mem.game.render_command_sprites.count) * size_of(_mem.game.render_command_sprites.data[0]),
            })
            _mem.game.render_command_sprites.vs_uniform.mvp = camera.view_projection_matrix
        }

        draw: {
            {
                command := _mem.game.render_command_clear
                engine.sg_begin_default_pass(command.pass_action, window_size.x, window_size.y)
                engine.sg_end_pass()
            }
            {
                command := _mem.game.render_command_sprites
                engine.sg_begin_default_pass(command.pass_action, window_size.x, window_size.y)
                    engine.sg_apply_pipeline(command.pipeline)
                    engine.sg_apply_bindings(command.bindings)
                    engine.sg_apply_uniforms(.VS, 0, { &command.vs_uniform, size_of(command.vs_uniform) })
                    engine.sg_apply_uniforms(.FS, 0, { &command.fs_uniform, size_of(command.fs_uniform) })
                    engine.sg_draw(0, 6, command.count)
                engine.sg_end_pass()
            }
            {
                command := _mem.game.render_command_line
                engine.sg_begin_default_pass(command.pass_action, window_size.x, window_size.y)
                    engine.sg_apply_pipeline(command.pipeline)
                    engine.sg_apply_bindings(command.bindings)
                    // engine.sg_apply_uniforms(.VS, 0, { &command.vs_uniform, size_of(command.vs_uniform) })
                    engine.sg_apply_uniforms(.FS, 0, { &command.fs_uniform, size_of(command.fs_uniform) })
                    engine.sg_draw(0, 6, 1)
                engine.sg_end_pass()
            }
            if _mem.game.debug_draw_gl {
                command := _mem.game.render_command_gl
                engine.sg_begin_default_pass(command.pass_action, window_size.x, window_size.y)
                    engine.sgl_draw()
                engine.sg_end_pass()
            }
            // {
            //     command := _mem.game.render_command_swipe
            //     engine.sg_begin_default_pass(command.pass_action, window_size.x, window_size.y)
            //         engine.sg_apply_pipeline(command.pipeline)
            //         engine.sg_apply_bindings(command.bindings)
            //         engine.sg_apply_uniforms(.VS, 0, { &command.vs_uniform, size_of(command.vs_uniform) })
            //         engine.sg_apply_uniforms(.FS, 0, { &command.fs_uniform, size_of(command.fs_uniform) })
            //         engine.sg_draw(0, 6, 1)
            //     engine.sg_end_pass()
            // }
            engine.sg_commit()
        }
    }

    return
}

get_window_title :: proc() -> string {
    builder := strings.builder_make(context.temp_allocator)
    strings.write_string(&builder, fmt.tprintf("Pirate Jam 14"))

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
        player_inputs.keyboard_was_used = inputs.keyboard_was_used
        player_inputs.controller_was_used = inputs.controller_was_used

        if player_inputs.keyboard_was_used {
            if inputs.keys[.A].down {
                player_inputs.move.x -= 1
            } else if inputs.keys[.D].down {
                player_inputs.move.x += 1
            }
            if inputs.keys[.W].down {
                player_inputs.move.y -= 1
            } else if inputs.keys[.S].down {
                player_inputs.move.y += 1
            }

            // if inputs.keys[.LEFT].down {
            //     player_inputs.move.x -= 1
            // } else if inputs.keys[.RIGHT].down {
            //     player_inputs.move.x += 1
            // }
            // if inputs.keys[.UP].down {
            //     player_inputs.move.y -= 1
            // } else if inputs.keys[.DOWN].down {
            //     player_inputs.move.y += 1
            // }

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
            player_inputs.confirm = inputs.keys[.SPACE]
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

window_to_world_position :: proc(window_position: Vector2f32) -> Vector2f32 {
    camera := _mem.game.world_camera
    ratio := NATIVE_RESOLUTION / engine.get_window_size()
    return {
        (window_position.x * ratio.x / camera.zoom) + camera.position.x * camera.zoom,
        (window_position.y * ratio.y / camera.zoom) + camera.position.y * camera.zoom,
    }
}

entity_get_absolute_transform :: proc(component_transform: ^engine.Component_Transform) -> (position: Vector2f32, scale: Vector2f32) {
    current_transform := component_transform
    position = current_transform.position
    scale = current_transform.scale
    for current_transform.parent != engine.ENTITY_INVALID {
        // assert(current_transform.parent != entity, "entity shouldn't be their own parent!")
        parent_transform, parent_transform_err := engine.entity_get_component_err(current_transform.parent, engine.Component_Transform)
        assert(parent_transform_err == .None, "entity parent doesn't have a transform component.")

        current_transform = parent_transform
        position += current_transform.position
        // scale *= current_transform.scale
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
    camera := _mem.game.world_camera
    pixel_density := engine.get_pixel_density()
    return {
        camera.position.x * 2,                  camera.position.y * 2,
        NATIVE_RESOLUTION.x / camera.zoom,      NATIVE_RESOLUTION.y / camera.zoom,
    }
}
get_level_bounds :: proc() -> Vector4f32 {
    return { }
}
