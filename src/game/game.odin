package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:time"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:sort"
import "core:strings"

import "../engine"

Vector2i32              :: engine.Vector2i32
Vector2f32              :: engine.Vector2f32
Vector3f32              :: engine.Vector3f32
Vector4f32              :: engine.Vector4f32
Matrix4x4f32            :: engine.Matrix4x4f32
Color                   :: engine.Color
Rect                    :: engine.Rect
RectF32                 :: engine.RectF32
array_cast              :: linalg.array_cast

MEM_GAME_SIZE           :: 10 * mem.Megabyte
NATIVE_RESOLUTION       :: Vector2f32 { 320, 180 }
CONTROLLER_DEADZONE     :: 15_000
PROFILER_COLOR_RENDER   :: 0x550000
CLEAR_COLOR             :: Color { 1, 0, 1, 1 } // This is supposed to never show up, so it's a super flashy color. If you see it, something is broken.
VOID_COLOR              :: Color { 0.4, 0.4, 0.4, 1 }
WINDOW_BORDER_COLOR     :: Color { 0, 0, 0, 255 }
GRID_SIZE               :: 8
GRID_SIZE_V2            :: Vector2i32 { GRID_SIZE, GRID_SIZE }
LETTERBOX_COLOR         :: Color { 0.2, 0.2, 0.2, 1 }
LETTERBOX_SIZE          :: Vector2f32 { 40, 18 }
HUD_SIZE                :: Vector2f32 { 40, 20 }
HUD_COLOR               :: Color { 1, 1, 1, 1 }

Game_Mode_Proc :: #type proc()

Game_Mode :: enum { Init, Title, WorldMap, Battle, Debug }

Player_Inputs :: struct {
    mouse_left: engine.Key_State,
    move:       Vector2f32,
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

Game_State :: struct {
    _engine:                    ^engine.Engine_State,
    engine_allocator:           runtime.Allocator,
    engine_arena:               mem.Arena,
    game_allocator:             runtime.Allocator,
    game_arena:                 mem.Arena,

    game_mode:                  Mode,
    player_inputs:              Player_Inputs,
    asset_worldmap:             engine.Asset_Id,
    asset_areas:                engine.Asset_Id,
    asset_placeholder:          engine.Asset_Id,
    asset_tilemap:              engine.Asset_Id,
    asset_worldmap_background:  engine.Asset_Id,
    asset_battle_background:    engine.Asset_Id,
    battle_index:               int,
    entities:                   Entity_Data,
    world_data:                 ^Game_Mode_Worldmap,
    battle_data:                ^Game_Mode_Battle,
    tileset_assets:             map[engine.LDTK_Tileset_Uid]engine.Asset_Id,
    background_asset:           engine.Asset_Id,

    hud_rect:                   RectF32,
    letterbox_top:              RectF32,
    letterbox_bottom:           RectF32,
    letterbox_left:             RectF32,
    letterbox_right:            RectF32,

    debug_render_z_index_0:     bool,
    debug_render_z_index_1:     bool,

    debug_window_info:          bool,
    debug_ui_window_entities:   bool,
    debug_ui_room_only:         bool,
    debug_ui_entity:            Entity,
    debug_ui_show_tiles:        bool,
    debug_show_bounding_boxes:  bool,
    debug_entity_under_mouse:   Entity,
    debug_show_demo_ui:         bool,
    debug_show_anim_ui:         bool,
    debug_draw_entities:        bool,

    draw_letterbox:             bool,
    draw_hud:                   bool,
}

@(private)
_game: ^Game_State

@(export)
game_init :: proc() -> rawptr {
    game := new(Game_State)
    _game = game
    _game.game_allocator = engine.platform_make_arena_allocator(.Game, MEM_GAME_SIZE, &_game.game_arena, context.allocator)

    _game.engine_allocator = engine.platform_make_arena_allocator(.Engine, engine.MEM_ENGINE_SIZE, &_game.engine_arena, context.allocator)
    _game._engine = engine.engine_init(game.engine_allocator)

    engine.platform_open_window("", { 1920, 1080 }, NATIVE_RESOLUTION)

    _game.game_mode.allocator = arena_allocator_make(1000 * mem.Kilobyte, _game.game_allocator)
    _game.hud_rect = RectF32 { 0, NATIVE_RESOLUTION.y - HUD_SIZE.y, NATIVE_RESOLUTION.x, HUD_SIZE.y }
    _game.letterbox_top    = { 0, 0, NATIVE_RESOLUTION.x, LETTERBOX_SIZE.y }
    _game.letterbox_bottom = { 0, NATIVE_RESOLUTION.y - LETTERBOX_SIZE.y, NATIVE_RESOLUTION.x, LETTERBOX_SIZE.y }
    _game.letterbox_left   = { 0, 0, LETTERBOX_SIZE.x, NATIVE_RESOLUTION.y }
    _game.letterbox_right  = { NATIVE_RESOLUTION.x - LETTERBOX_SIZE.x, 0, LETTERBOX_SIZE.x, NATIVE_RESOLUTION.y }

    return _game
}

@(export)
window_open :: proc() {

}

// FIXME: free game state memory (in arena) when changing state
@(export)
game_update :: proc(game: ^Game_State) -> (quit: bool, reload: bool) {
    engine.platform_frame_begin()

    context.allocator = _game.game_allocator

    game_ui_debug_window(&_game.debug_window_info)
    game_ui_anim_window(&_game.debug_show_anim_ui)
    game_ui_entity_window(_game.debug_ui_entity)
    engine.renderer_ui_show_demo_window(&_game.debug_show_demo_ui)

    if engine.ui_main_menu_bar() {
        if engine.ui_menu_item(fmt.tprintf("Debug%v", _game.debug_window_info ? "*" : ""), "F1", &_game.debug_window_info) {}
        if engine.ui_menu_item(fmt.tprintf("Demo%v", _game.debug_show_demo_ui ? "*" : ""), "F10", &_game.debug_show_demo_ui) {}
        if engine.ui_menu_item(fmt.tprintf("Anim%v", _game.debug_show_anim_ui ? "*" : ""), "F6", &_game.debug_show_anim_ui) {}
        if engine.ui_menu_item(fmt.tprintf("Bounding box%v", _game.debug_show_bounding_boxes ? "*" : ""), "F3", &_game.debug_show_bounding_boxes) {}
        if engine.ui_menu_item(fmt.tprintf("Tiles%v", _game.debug_ui_show_tiles ? "*" : ""), "F4", &_game.debug_ui_show_tiles) {}
        if engine.ui_menu_item(fmt.tprintf("Entities%v", _game.debug_draw_entities ? "*" : ""), "F5", &_game.debug_draw_entities) {}
        if engine.ui_menu_item(("Reload shaders"), "P") {
            engine.debug_reload_shaders()
        }
        if engine.ui_menu(fmt.tprintf("Refresh rate (%vHz)", _game._engine.renderer.refresh_rate)) {
            if engine.ui_menu_item("1Hz", "", _game._engine.renderer.refresh_rate == 1) { _game._engine.renderer.refresh_rate = 1 }
            if engine.ui_menu_item("10Hz", "", _game._engine.renderer.refresh_rate == 10) { _game._engine.renderer.refresh_rate = 10 }
            if engine.ui_menu_item("30Hz", "", _game._engine.renderer.refresh_rate == 30) { _game._engine.renderer.refresh_rate = 30 }
            if engine.ui_menu_item("60Hz", "", _game._engine.renderer.refresh_rate == 60) { _game._engine.renderer.refresh_rate = 60 }
            if engine.ui_menu_item("144Hz", "", _game._engine.renderer.refresh_rate == 144) { _game._engine.renderer.refresh_rate = 144 }
            if engine.ui_menu_item("240Hz", "", _game._engine.renderer.refresh_rate == 240) { _game._engine.renderer.refresh_rate = 240 }
            if engine.ui_menu_item("Unlocked", "", _game._engine.renderer.refresh_rate == 999999) { _game._engine.renderer.refresh_rate = 999999 }
        }
    }

    camera := &_game._engine.renderer.world_camera
    if _game._engine.platform.keys[.A].down {
        camera.position.x -= _game._engine.platform.delta_time / 10
    }
    if _game._engine.platform.keys[.D].down {
        camera.position.x += _game._engine.platform.delta_time / 10
    }
    if _game._engine.platform.keys[.W].down {
        camera.position.y -= _game._engine.platform.delta_time / 10
    }
    if _game._engine.platform.keys[.S].down {
        camera.position.y += _game._engine.platform.delta_time / 10
    }
    if _game._engine.platform.keys[.Q].down {
        camera.rotation += _game._engine.platform.delta_time / 1000
    }
    if _game._engine.platform.keys[.E].down {
        camera.rotation -= _game._engine.platform.delta_time / 1000
    }
    if _game._engine.platform.mouse_wheel.y != 0 {
        camera.zoom = math.clamp(camera.zoom + f32(_game._engine.platform.mouse_wheel.y) * _game._engine.platform.delta_time / 50, 0.2, 20)
    }
    if _game._engine.platform.keys[.LEFT].released {
        _game.debug_ui_entity -= 1
    }
    if _game._engine.platform.keys[.RIGHT].released {
        _game.debug_ui_entity += 1
    }
    if _game._engine.platform.keys[.P].released {
        engine.debug_reload_shaders()
    }

    if _game._engine.platform.keys[.LSHIFT].down {
        @static iTime: f32 = 0
        iTime += _game._engine.platform.delta_time / 1000
        camera.zoom = math.sin(iTime * 0.4) * 2.0 + 6.0;
    }

    { engine.profiler_zone("game_update")

        engine.debug_update()
        game_inputs()
        draw_debug_windows()

        switch Game_Mode(_game.game_mode.current) {
            case .Init: game_mode_init()
            case .Title: game_mode_title()
            case .WorldMap: game_mode_update_worldmap()
            case .Battle: game_mode_update_battle()
            case .Debug: game_mode_update_debug_scene()
        }

        if _game._engine.platform.keys[.F5].released {
            reload = true
        }
        if _game._engine.platform.quit_requested || _game.player_inputs.cancel.released {
            quit = true
        }

        engine.platform_set_window_title(get_window_title())
    }

    game_render()

    engine.platform_frame_end()

    return
}

@(export)
game_quit :: proc(game: Game_State) {
    log.debug("game_quit")
    // FIXME: reset everything?
}

@(export)
game_reload :: proc(game: ^Game_State) {
    _game = game
    // FIXME: find out why we have to reset the allocator.procedure after reload
    // _game.game_allocator.procedure = engine.platform_arena_allocator_proc
    // _game.game_mode.allocator.procedure = mem.arena_allocator_proc
    engine.engine_reload(game._engine)
}

@(export)
window_close :: proc(game: Game_State) {
    log.debug("window_close")
}

get_window_title :: proc() -> string {
    return fmt.tprintf("Snowball (Renderer: %v | Refresh rate: %3.0fHz | FPS: %5.0f / %5.0f | Stats: %v)",
        engine.RENDERER, f32(_game._engine.renderer.refresh_rate),
        f32(_game._engine.platform.locked_fps), f32(_game._engine.platform.actual_fps), _game._engine.renderer.stats)
}

game_render :: proc() {
    engine.profiler_zone("game_render", PROFILER_COLOR_RENDER)

    engine.renderer_render_begin()
    //       log.debug(">>>>>>>>>>>>>>>>>>>>>");
    // defer log.debug("<<<<<<<<<<<<<<<<<<<<<");
    defer engine.renderer_render_end();

    engine.renderer_clear(CLEAR_COLOR)
    engine.renderer_clear(VOID_COLOR)

    // engine.renderer_push_quad({ 0, 0 }, { 1920, 1080 }, { 0, 0, 0, 255 })

    if engine.renderer_is_enabled() == false {
        log.warn("Renderer disabled")
        return
    }

    if _game._engine.platform.window_resized {
        engine.platform_resize_window()
        update_rendering_offset()
    }

    engine.renderer_update_camera_matrix()

    engine.renderer_change_camera_begin(&_game._engine.renderer.world_camera)

    if _game.debug_draw_entities {
        sorted_entities: []Entity
        { engine.profiler_zone("sort_entities", PROFILER_COLOR_RENDER)
            // TODO: This is kind of expensive to do each frame.
            // Either filter the entities before the sort or don't do this every single frame.
            sorted_entities = slice.clone(_game.entities.entities[:], context.temp_allocator)
            {
                context.user_ptr = rawptr(&_game.entities.components_z_index)
                sort_entities_by_z_index :: proc(a, b: Entity) -> int {
                    components_z_index := cast(^map[Entity]Component_Z_Index)context.user_ptr
                    return int(components_z_index[a].z_index - components_z_index[b].z_index)
                }
                sort.heap_sort_proc(sorted_entities, sort_entities_by_z_index)
            }
        }

        { engine.profiler_zone("draw_entities", PROFILER_COLOR_RENDER)
            for entity in sorted_entities {
                transform_component, has_transform := _game.entities.components_transform[entity]
                rendering_component, has_rendering := _game.entities.components_rendering[entity]
                z_index_component, has_z_index := _game.entities.components_z_index[entity]
                flag_component, has_flag := _game.entities.components_flag[entity]

                if has_rendering && rendering_component.visible && has_transform {
                    asset := _game._engine.assets.assets[rendering_component.texture_asset]
                    // if asset.state != .Loaded {
                    //     continue
                    // }

                    if _game.debug_ui_show_tiles == false && has_flag && .Tile in flag_component.value {
                        continue
                    }

                    // 1px padding
                    texture_dimensions := Vector2f32 { 70, 210 }
                    pix := Vector2f32 { 1 / texture_dimensions.x, 1 / texture_dimensions.y }
                    pos := Vector2f32 { f32(rendering_component.texture_position.x), f32(rendering_component.texture_position.y) }
                    size := Vector2f32 { f32(rendering_component.texture_size.x), f32(rendering_component.texture_size.y) }
                    texture_position := Vector2f32 {
                        (pix.x) + (pix.x * pos.x) + (2 * pix.x * pos.x / 8),
                        (pix.y) + (pix.y * pos.y) + (2 * pix.y * pos.y / 8),
                    }
                    texture_size := Vector2f32 {
                        8 * pix.x,
                        8 * pix.y,
                    }

                    // log.debugf("position: %v %v | %v %v", pos, texture_size, size, texture_size);

                    // TODO: use flags for this
                    if z_index_component.z_index == 0 && _game.debug_render_z_index_0 ||
                       z_index_component.z_index == 1 && _game.debug_render_z_index_1 {
                        engine.renderer_push_quad(
                            { f32(transform_component.world_position.x * GRID_SIZE), f32(transform_component.world_position.y * GRID_SIZE) },
                            { f32(transform_component.size.x), f32(transform_component.size.y) },
                            { 1, 1, 1, 1 },
                            _game._engine.renderer.texture_0,
                            texture_position, texture_size,
                            rendering_component.flip,
                        )
                    }
                }
            }
        }
    }


    { engine.profiler_zone("draw_debug", PROFILER_COLOR_RENDER)
        // We want to do it after the entity rendering because we want to draw it on top
        for entity, flag_component in _game.entities.components_flag {
            if .Interactive in flag_component.value {
                transform_component := _game.entities.components_transform[entity]
                color := entity_to_color(entity)
                color.a = 0.3
                engine.renderer_push_quad(
                    engine.vector_i32_to_f32(transform_component.grid_position * GRID_SIZE_V2),
                    engine.vector_i32_to_f32(GRID_SIZE_V2),
                    color,
                )
            }
        }

        if _game.debug_ui_entity != 0 {
            transform_component, has_transform := _game.entities.components_transform[_game.debug_ui_entity]
            if has_transform {
                engine.renderer_push_quad(
                    { transform_component.world_position.x * f32(GRID_SIZE), transform_component.world_position.y * f32(GRID_SIZE) },
                    { transform_component.size.x, transform_component.size.y },
                    { 1, 0, 0, 0.3 },
                )
            }
        }
    }

    // engine.debug_render()

    // // FIXME: this needs to be enabled back when we have render targets on OpenGL
    // when engine.RENDERER == .SDL {
    //     engine.profiler_zone("entity_picker", PROFILER_COLOR_RENDER)

    //     // FIXME: optimize
    //     // FIXME: Handle window resize
    //     // TODO: Clean this
    //     if _game.entities_texture == nil {
    //         texture_ok : bool
    //         _game.entities_texture, _, texture_ok = engine.renderer_create_texture(u32(engine.PixelFormatEnum.RGBA32), .TARGET, NATIVE_RESOLUTION.x, NATIVE_RESOLUTION.y)
    //     }
    //     engine.renderer_set_render_target(_game.entities_texture)
    //     engine.renderer_set_texture_blend_mode(_game.entities_texture, .BLEND)
    //     // engine.renderer_clear({ 0, 0, 0, 0 })

    //     for entity, flag_component in _game.entities.components_flag {
    //         if .Interactive in flag_component.value {
    //             transform_component := _game.entities.components_transform[entity]
    //             engine.renderer_draw_fill_rect_raw(&RectF32 {
    //                 f32(transform_component.grid_position.x * GRID_SIZE), f32(transform_component.grid_position.y * GRID_SIZE),
    //                 GRID_SIZE, GRID_SIZE,
    //             }, entity_to_color(entity))
    //             // log.debugf("color: %v | %v | %g", entity, color, entity)
    //         }
    //     }

    //     {
    //         engine.profiler_zone("read_pixels", PROFILER_COLOR_RENDER)
    //         pixel_size : i32 = 4
    //         width : i32 = 1
    //         height : i32 = 1
    //         pixels := make([]Color, width * height, context.temp_allocator)
    //         pitch := width * pixel_size
    //         position := (_game._engine.platform.mouse_position - _game._engine.renderer.rendering_offset) / _game._engine.renderer.rendering_scale
    //         engine.renderer_read_pixels(&{ position.x, position.y, width, height }, .ABGR8888, &pixels[0], pitch)

    //         _game.debug_entity_under_mouse = color_to_entity(pixels[0])
    //         // log.debugf("entity: %v | %v | %b", pixels[0], _game.debug_entity_under_mouse, _game.debug_entity_under_mouse)
    //     }

    //     engine.renderer_set_render_target(nil)
    // }

    // FIXME: we need to have multiple camera (one for the world, one for the UI) before we can do this
    // { engine.profiler_zone("draw_letterbox", PROFILER_COLOR_RENDER)
    //     color := Color { 1, 0, 0, 1 }
    //     scale := _game._engine.renderer.ideal_scale
    //     // offset := _game._engine.renderer.rendering_offset

    //     engine.renderer_push_quad({ 0, 0 }, { f32(_game._engine.platform.window_size.x), f32(10) }, color)
    //     // engine.renderer_push_quad({ 0, f32(window_size.y * scale + offset.y) }, { f32(window_size.x * scale + offset.x * 2), f32(offset.y) }, color)
    //     // engine.renderer_push_quad({ 0, 0 }, { f32(offset.x), f32(window_size.y * scale + offset.y * 2) }, color)
    //     // engine.renderer_push_quad({ f32(window_size.x * scale + offset.x), 0 }, { f32(offset.x), f32(window_size.y * scale + offset.y * 2) }, color)

    //     // if _game.draw_letterbox { // Draw the letterboxes on top of the world
    //     //     engine.renderer_push_quad({ _game.letterbox_top.x, _game.letterbox_top.y }, { _game.letterbox_top.w, _game.letterbox_top.h }, LETTERBOX_COLOR)
    //     //     engine.renderer_push_quad({ _game.letterbox_bottom.x, _game.letterbox_bottom.y }, { _game.letterbox_bottom.w, _game.letterbox_bottom.h }, LETTERBOX_COLOR)
    //     //     engine.renderer_push_quad({ _game.letterbox_left.x, _game.letterbox_left.y }, { _game.letterbox_left.w, _game.letterbox_left.h }, LETTERBOX_COLOR)
    //     //     engine.renderer_push_quad({ _game.letterbox_right.x, _game.letterbox_right.y }, { _game.letterbox_right.w, _game.letterbox_right.h }, LETTERBOX_COLOR)
    //     // }
    // }

    {
        // engine.renderer_change_camera(&_game._engine.renderer.ui_camera)
        for x := 0; x < 2; x += 1 {
            for y := 0; y < 1; y += 1 {
                size : f32 = 8
                engine.renderer_push_quad(
                    { f32(x) * size, f32(y) * size },
                    { size, size },
                    { 1, 1, 1, 0.3 },
                    // _game._engine.renderer.texture_0,
                    // { 0, 0 }, { 1.0 / 7, 1 / 21 },
                )
            }
        }
    }

    { engine.profiler_zone("draw_hud", PROFILER_COLOR_RENDER)
        if _game.draw_hud {
            {
                engine.renderer_change_camera_begin(&_game._engine.renderer.ui_camera)
                engine.renderer_push_quad({ _game.hud_rect.x, _game.hud_rect.y }, { _game.hud_rect.w, _game.hud_rect.h }, HUD_COLOR)
            }
        }
    }
}

update_player_inputs :: proc() {
    keyboard_was_used := false
    for key in _game._engine.platform.keys {
        if _game._engine.platform.keys[key].down || _game._engine.platform.keys[key].released {
            keyboard_was_used = true
            break
        }
    }

    {
        player_inputs := &_game.player_inputs
        player_inputs^ = {}

        player_inputs.mouse_left = _game._engine.platform.mouse_keys[engine.BUTTON_LEFT]

        if keyboard_was_used {
            if (_game._engine.platform.keys[.UP].down) {
                player_inputs.move.y -= 1
            } else if (_game._engine.platform.keys[.DOWN].down) {
                player_inputs.move.y += 1
            }
            if (_game._engine.platform.keys[.LEFT].down) {
                player_inputs.move.x -= 1
            } else if (_game._engine.platform.keys[.RIGHT].down) {
                player_inputs.move.x += 1
            }

            player_inputs.back = _game._engine.platform.keys[.BACKSPACE]
            player_inputs.start = _game._engine.platform.keys[.RETURN]
            player_inputs.confirm = _game._engine.platform.keys[.SPACE]
            player_inputs.cancel = _game._engine.platform.keys[.ESCAPE]
            player_inputs.debug_0 = _game._engine.platform.keys[.GRAVE]
            player_inputs.debug_1 = _game._engine.platform.keys[.F1]
            player_inputs.debug_2 = _game._engine.platform.keys[.F2]
            player_inputs.debug_3 = _game._engine.platform.keys[.F3]
            player_inputs.debug_4 = _game._engine.platform.keys[.F4]
            player_inputs.debug_5 = _game._engine.platform.keys[.F5]
            player_inputs.debug_6 = _game._engine.platform.keys[.F6]
            player_inputs.debug_7 = _game._engine.platform.keys[.F7]
            player_inputs.debug_8 = _game._engine.platform.keys[.F8]
            player_inputs.debug_9 = _game._engine.platform.keys[.F9]
            player_inputs.debug_10 = _game._engine.platform.keys[.F10]
            player_inputs.debug_11 = _game._engine.platform.keys[.F11]
            player_inputs.debug_12 = _game._engine.platform.keys[.F12]
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

                player_inputs.back = controller_state.buttons[.BACK]
                player_inputs.start = controller_state.buttons[.START]
                player_inputs.confirm = controller_state.buttons[.A]
                player_inputs.cancel = controller_state.buttons[.B]
            }
        }

        if player_inputs.move.x != 0 || player_inputs.move.y != 0 {
            player_inputs.move = linalg.vector_normalize(player_inputs.move)
        }
    }
}

arena_allocator_make :: proc(size: int, allocator: mem.Allocator) -> runtime.Allocator {
    context.allocator = allocator
    arena := new(mem.Arena)
    arena_backing_buffer := make([]u8, size)
    mem.arena_init(arena, arena_backing_buffer)
    allocator := mem.arena_allocator(arena)
    allocator.procedure = arena_allocator_proc
    return allocator
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

import "core:testing"

@test
entity_to_color_encoding_decoding :: proc(t: ^testing.T) {
    testing.expect(t, entity_to_color(0x000000) == Color { 0,   0,   0,   255 })
    testing.expect(t, entity_to_color(0x0000ff) == Color { 0,   0,   255, 255 })
    testing.expect(t, entity_to_color(0x00ffff) == Color { 0,   255, 255, 255 })
    testing.expect(t, entity_to_color(0xffffff) == Color { 255, 255, 255, 255 })
    testing.expect(t, entity_to_color(0xffff00) == Color { 255, 255, 0,   255 })
    testing.expect(t, entity_to_color(0xff0000) == Color { 255, 0,   0,   255 })
    testing.expect(t, color_to_entity(Color { 0,   0,   0,   0   }) == 0x000000)
    testing.expect(t, color_to_entity(Color { 0,   0,   0,   255 }) == 0x000000)
    testing.expect(t, color_to_entity(Color { 0,   0,   255, 255 }) == 0x0000ff)
    testing.expect(t, color_to_entity(Color { 0,   255, 255, 255 }) == 0x00ffff)
    testing.expect(t, color_to_entity(Color { 255, 255, 255, 255 }) == 0xffffff)
    testing.expect(t, color_to_entity(Color { 255, 255, 0,   255 }) == 0xffff00)
    testing.expect(t, color_to_entity(Color { 255, 0,   0,   255 }) == 0xff0000)
}

entity_to_color :: proc(entity: Entity) -> Color {
    assert(entity <= 0xffffff)

    // FIXME: the "* 48" is here for visual debugging, this will break color to entity
    return Color {
        f32(((entity * 48 / 255) & 0x00ff0000) >> 16),
        f32(((entity * 48 / 255) & 0x0000ff00) >> 8),
        f32(((entity * 48 / 255) & 0x000000ff)),
        1,
    }
}

color_to_entity :: proc(color: Color) -> Entity {
    return transmute(Entity) [4]u8 { u8(color.b) * 48 * 255, u8(color.g) * 48 * 255, u8(color.r) * 48 * 255, 0 }
}

update_rendering_offset :: proc() {
    // odd_offset : i32 = 0
    // if _game._engine.platform.window_size.y % 2 == 1 {
    //     odd_offset = 1
    // }
    // _game._engine.renderer.rendering_offset = {
    //     (_game._engine.platform.window_size.x - NATIVE_RESOLUTION.x * _game._engine.renderer.rendering_scale) / 2 + odd_offset,
    //     (_game._engine.platform.window_size.y - NATIVE_RESOLUTION.y * _game._engine.renderer.rendering_scale) / 2 + odd_offset,
    // }
}

game_inputs :: proc() {
    engine.profiler_zone("game_inputs")
    update_player_inputs()

    player_inputs := _game.player_inputs
    // if player_inputs.debug_0.released {
    //     _game.debug_ui_window_console = (_game.debug_ui_window_console + 1) % 2
    // }
    if player_inputs.debug_1.released {
        _game.debug_window_info = !_game.debug_window_info
    }
    if player_inputs.debug_2.released {
        _game.debug_ui_window_entities = !_game.debug_ui_window_entities
    }
    if player_inputs.debug_3.released {
        _game.debug_show_bounding_boxes = !_game.debug_show_bounding_boxes
    }
    if player_inputs.debug_4.released {
        _game.debug_ui_show_tiles = !_game.debug_ui_show_tiles
    }
    if player_inputs.debug_5.released {
        _game.draw_hud = !_game.draw_hud
    }
    if player_inputs.debug_6.released {
        _game.debug_show_anim_ui = !_game.debug_show_anim_ui
    }
    if player_inputs.debug_10.released {
        _game.debug_show_demo_ui = !_game.debug_show_demo_ui
    }
    // if player_inputs.debug_5.released {
    //     _game.debug.save_memory = 1
    // }
    // if player_inputs.debug_8.released {
    //     _game.debug.load_memory = 1
    // }
    // if player_inputs.debug_7.released {
    //     engine.renderer_take_screenshot(_game._engine.platform.window)
    // }
    if player_inputs.debug_11.released {
        _game.draw_letterbox = !_game.draw_letterbox
    }
    if player_inputs.debug_12.released {
        game_mode_transition(.Debug)
    }
}
