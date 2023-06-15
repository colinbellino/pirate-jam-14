package game

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:time"
import "core:slice"
import "core:sort"
import "core:strings"
import "core:math/linalg"
import "core:math/rand"

import tracy "../odin-tracy"
import "../engine"

Vector2i                :: engine.Vector2i;
Vector2f32              :: engine.Vector2f32;
Rect                    :: engine.Rect;
RectF32                 :: engine.RectF32;
Color                   :: engine.Color;
array_cast              :: linalg.array_cast;

NATIVE_RESOLUTION       :: Vector2i { 256, 144 };
CONTROLLER_DEADZONE     :: 15_000;
PROFILER_COLOR_RENDER   :: 0x550000;
CLEAR_COLOR             :: Color { 255, 0, 255, 255 }; // This is supposed to never show up, so it's a super flashy color. If you see it, something is broken.
VOID_COLOR              :: Color { 100, 100, 100, 255 };
WINDOW_BORDER_COLOR     :: Color { 0, 0, 0, 255 };
GRID_SIZE               :: 8;
GRID_SIZE_V2            :: Vector2i { GRID_SIZE, GRID_SIZE };
LETTERBOX_COLOR         :: Color { 10, 10, 10, 255 };
LETTERBOX_SIZE          :: Vector2i { 40, 18 };
LETTERBOX_TOP           :: Rect { 0, 0,                                      NATIVE_RESOLUTION.x, LETTERBOX_SIZE.y };
LETTERBOX_BOTTOM        :: Rect { 0, NATIVE_RESOLUTION.y - LETTERBOX_SIZE.y, NATIVE_RESOLUTION.x, LETTERBOX_SIZE.y };
LETTERBOX_LEFT          :: Rect { 0, 0,                                      LETTERBOX_SIZE.x, NATIVE_RESOLUTION.y };
LETTERBOX_RIGHT         :: Rect { NATIVE_RESOLUTION.x - LETTERBOX_SIZE.x, 0, LETTERBOX_SIZE.x, NATIVE_RESOLUTION.y };
HUD_SIZE                :: Vector2i { 40, 20 };
HUD_RECT                :: Rect { 0, NATIVE_RESOLUTION.y - HUD_SIZE.y, NATIVE_RESOLUTION.x, HUD_SIZE.y };
HUD_COLOR               :: Color { 255, 255, 255, 255 };

Game_State :: struct {
    arena:                      ^mem.Arena,
    delta_time:                 f64,
    player_inputs:              Player_Inputs,
    window_size:                Vector2i,
    asset_worldmap:             engine.Asset_Id,
    asset_areas:                engine.Asset_Id,
    asset_placeholder:          engine.Asset_Id,
    asset_tilemap:              engine.Asset_Id,
    asset_worldmap_background:  engine.Asset_Id,
    asset_battle_background:    engine.Asset_Id,
    game_allocator:             runtime.Allocator,
    game_mode:                  Game_Mode,
    game_mode_entered:          bool,
    game_mode_exited:           bool,
    game_mode_exit_proc:        Game_Mode_Proc,
    game_mode_allocator:        runtime.Allocator,
    battle_index:               int,
    entities:                   Entity_Data,
    world_data:                 ^Game_Mode_Worldmap,
    battle_data:                ^Game_Mode_Battle,
    tileset_assets:             map[engine.LDTK_Tileset_Uid]engine.Asset_Id,
    background_asset:           engine.Asset_Id,

    debug_ui_window_info:       bool,
    debug_ui_window_entities:   bool,
    debug_ui_no_tiles:          bool,
    debug_ui_room_only:         bool,
    debug_ui_entity:            Entity,
    debug_ui_show_tiles:        bool,
    debug_show_bounding_boxes:  bool,
    debug_entity_under_mouse:   Entity,

    draw_letterbox:             bool,
    draw_hud:                   bool,
}

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

game: ^Game_State;

// TODO: delete or merge with game_update
legacy_game_update :: proc(delta_time: f64, app: ^engine.App) {
    engine.profiler_zone("game_update")

    engine.engine_update(delta_time, app);

    if app.game == nil {
        game = new(Game_State, app.game_allocator);
        game.game_allocator = app.game_allocator;
        game.game_mode_allocator = arena_allocator_make(1000 * mem.Kilobyte);
        game.debug_ui_no_tiles = true;
        // game.debug_show_bounding_boxes = true;
        app.game = game;
    }
    context.allocator = app.game_allocator;
    game = cast(^Game_State) app.game;
    game.delta_time = delta_time;

    { engine.profiler_zone("game_inputs");
        update_player_inputs(app.platform, game);

        engine.ui_input_mouse_move(app.ui, app.platform.mouse_position.x, app.platform.mouse_position.y);
        engine.ui_input_scroll(app.ui, app.platform.input_scroll.x * 30, app.platform.input_scroll.y * 30);

        for key, key_state in app.platform.mouse_keys {
            if key_state.pressed {
                ui_input_mouse_down(app.ui, app.platform.mouse_position, u8(key));
            }
            if key_state.released {
                ui_input_mouse_up(app.ui, app.platform.mouse_position, u8(key));
            }
        }
        for key, key_state in app.platform.keys {
            if key_state.pressed {
                ui_input_key_down(app.ui, engine.Keycode(key));
            }
            if key_state.released {
                ui_input_key_up(app.ui, engine.Keycode(key));
            }
        }
        if app.platform.input_text != "" {
            ui_input_text(app.ui, app.platform.input_text);
        }
    }

    {
        player_inputs := game.player_inputs;
        if player_inputs.cancel.released {
            app.platform.quit = true;
        }
        // if player_inputs.debug_0.released {
        //     game.debug_ui_window_console = (game.debug_ui_window_console + 1) % 2;
        // }
        if player_inputs.debug_1.released {
            game.debug_ui_window_info = !game.debug_ui_window_info;
        }
        if player_inputs.debug_2.released {
            game.debug_ui_window_entities = !game.debug_ui_window_entities;
        }
        if player_inputs.debug_3.released {
            game.debug_show_bounding_boxes = !game.debug_show_bounding_boxes;
        }
        if player_inputs.debug_4.released {
            game.debug_ui_show_tiles = !game.debug_ui_show_tiles;
        }
        // if player_inputs.debug_5.released {
        //     app.debug.save_memory = 1;
        // }
        // if player_inputs.debug_8.released {
        //     app.debug.load_memory = 1;
        // }
        // if player_inputs.debug_7.released {
        //     engine.take_screenshot(app.platform.window);
        // }
        if player_inputs.debug_11.released {
            game.draw_letterbox = !game.draw_letterbox;
        }
        if player_inputs.debug_12.released {
            game_mode_transition(.Debug);
        }
    }

    engine.ui_begin(app.ui);

    draw_debug_windows(app, game);

    switch game.game_mode {
        case .Init: {
            if app.config.TRACY_ENABLE {
                game.arena = cast(^mem.Arena)(cast(^engine.ProfiledAllocatorData)app.game_allocator.data).backing_allocator.data;
            } else {
                game.arena = cast(^mem.Arena)app.game_allocator.data;
            }

            game.window_size = 6 * NATIVE_RESOLUTION;
            resize_window(app.platform, app.renderer, game);

            game.asset_tilemap = engine.asset_add(app, "media/art/spritesheet.png", .Image);
            game.asset_battle_background = engine.asset_add(app, "media/art/battle_background.png", .Image);
            game.asset_worldmap = engine.asset_add(app, "media/levels/worldmap.ldtk", .Map);
            game.asset_areas = engine.asset_add(app, "media/levels/areas.ldtk", .Map);

            engine.asset_load(app, game.asset_tilemap);
            engine.asset_load(app, game.asset_battle_background);
            engine.asset_load(app, game.asset_worldmap);
            engine.asset_load(app, game.asset_areas);

            world_asset := &app.assets.assets[game.asset_worldmap];
            asset_info := world_asset.info.(engine.Asset_Info_Map);
            log.infof("Level %v loaded: %s (%s)", world_asset.file_name, asset_info.ldtk.iid, asset_info.ldtk.jsonVersion);

            for tileset in asset_info.ldtk.defs.tilesets {
                rel_path, value_ok := tileset.relPath.?;
                if value_ok != true {
                    continue;
                }

                path, path_ok := strings.replace(rel_path, static_string("../art"), static_string("media/art"), 1);
                if path_ok != true {
                    log.warnf("Invalid tileset: %s", rel_path);
                    continue;
                }

                asset, asset_found := engine.asset_get_by_file_name(app.assets, path);
                if asset_found == false {
                    log.warnf("Tileset asset not found: %s", path);
                    continue;
                }

                game.tileset_assets[tileset.uid] = asset.id;
                engine.asset_load(app, asset.id);
            }

            game_mode_transition(.Title);
        }

        case .Title: {
            game_mode_transition(.WorldMap);
        }

        case .WorldMap: {
            game_mode_update_worldmap(app);
        }

        case .Battle: {
            game_mode_update_battle(app);
        }

        case .Debug: {
            game_mode_update_debug_scene(delta_time, app);
        }
    }

    engine.ui_end(app.ui);
}

// TODO: delete ?
legacy_game_render :: proc(delta_time: f64, app: ^engine.App) {
    engine.profiler_zone("game_render", PROFILER_COLOR_RENDER);

    game := cast(^Game_State) app.game;

    // It's possible render is called before the game state is initialized
    if app.game == nil {
        return;
    }

    if app.platform.window_resized {
        resize_window(app.platform, app.renderer, game);
    }

    engine.renderer_clear(CLEAR_COLOR);
    engine.draw_fill_rect(&Rect { 0, 0, game.window_size.x, game.window_size.y }, VOID_COLOR);

    sorted_entities: []Entity;
    { engine.profiler_zone("sort_entities", PROFILER_COLOR_RENDER);
        // TODO: This is kind of expensive to do each frame.
        // Either filter the entities before the sort or don't do this every single frame.
        sorted_entities = slice.clone(game.entities.entities[:], context.temp_allocator);
        {
            context.user_ptr = rawptr(&game.entities.components_z_index);
            sort_entities_by_z_index :: proc(a, b: Entity) -> int {
                components_z_index := cast(^map[Entity]Component_Z_Index)context.user_ptr;
                return int(components_z_index[a].z_index - components_z_index[b].z_index);
            }
            sort.heap_sort_proc(sorted_entities, sort_entities_by_z_index);
        }
    }

    { engine.profiler_zone("draw_entities", PROFILER_COLOR_RENDER);
        for entity in sorted_entities {
            transform_component, has_transform := game.entities.components_transform[entity];
            rendering_component, has_rendering := game.entities.components_rendering[entity];

            if has_rendering && rendering_component.visible && has_transform {
                asset := app.assets.assets[rendering_component.texture_asset];
                if asset.state != .Loaded {
                    continue;
                }

                source := engine.Rect {
                    rendering_component.texture_position.x, rendering_component.texture_position.y,
                    rendering_component.texture_size.x, rendering_component.texture_size.y,
                };
                destination := engine.RectF32 {
                    transform_component.world_position.x * GRID_SIZE, transform_component.world_position.y * GRID_SIZE,
                    transform_component.size.x, transform_component.size.y,
                };
                info := asset.info.(engine.Asset_Info_Image);
                engine.draw_texture(info.texture, &source, &destination, rendering_component.flip);
            }
        }
    }

    { engine.profiler_zone("draw_letterbox", PROFILER_COLOR_RENDER);
        engine.draw_window_border(NATIVE_RESOLUTION, WINDOW_BORDER_COLOR);
        if game.draw_letterbox { // Draw the letterboxes on top of the world
            engine.draw_fill_rect(&Rect { LETTERBOX_TOP.x, LETTERBOX_TOP.y, LETTERBOX_TOP.w, LETTERBOX_TOP.h }, LETTERBOX_COLOR);
            engine.draw_fill_rect(&Rect { LETTERBOX_BOTTOM.x, LETTERBOX_BOTTOM.y, LETTERBOX_BOTTOM.w, LETTERBOX_BOTTOM.h }, LETTERBOX_COLOR);
            engine.draw_fill_rect(&Rect { LETTERBOX_LEFT.x, LETTERBOX_LEFT.y, LETTERBOX_LEFT.w, LETTERBOX_LEFT.h }, LETTERBOX_COLOR);
            engine.draw_fill_rect(&Rect { LETTERBOX_RIGHT.x, LETTERBOX_RIGHT.y, LETTERBOX_RIGHT.w, LETTERBOX_RIGHT.h }, LETTERBOX_COLOR);
        }
    }

    { engine.profiler_zone("draw_hud", PROFILER_COLOR_RENDER);
        if game.draw_hud {
            engine.draw_fill_rect(&Rect { HUD_RECT.x, HUD_RECT.y, HUD_RECT.w, HUD_RECT.h }, HUD_COLOR);
        }
    }

    { engine.profiler_zone("draw_debug", PROFILER_COLOR_RENDER);
        if game.debug_ui_entity != 0 {
            transform_component, has_transform := game.entities.components_transform[game.debug_ui_entity];
            if has_transform {
                destination := RectF32 {
                    transform_component.world_position.x * f32(GRID_SIZE),
                    transform_component.world_position.y * f32(GRID_SIZE),
                    transform_component.size.x,
                    transform_component.size.y,
                };
                engine.draw_fill_rect(&destination, { 255, 0, 0, 100 });
            }
            // engine.draw_fill_rect_raw(&RectF32 {
            //     f32(transform_component.grid_position.x * GRID_SIZE), f32(transform_component.grid_position.y * GRID_SIZE),
            //     GRID_SIZE, GRID_SIZE,
            // }, color);
        }
    }

    engine.engine_render(app);

    {
        engine.profiler_zone("entity_picker", PROFILER_COLOR_RENDER);

        // FIXME: optimize
        // FIXME: Handle window resize
        // TODO: Clean this
        if _bla_texture == nil {
            texture_ok : bool
            _bla_texture, _, texture_ok = engine.create_texture(u32(engine.PixelFormatEnum.RGBA32), .TARGET, NATIVE_RESOLUTION.x, NATIVE_RESOLUTION.y);
        }
        engine.set_render_target(_bla_texture);
        engine.set_texture_blend_mode(_bla_texture, .BLEND);
        engine.renderer_clear({ 0, 0, 0, 0 });

        for entity, flag_component in game.entities.components_flag {
            if .Interactive in flag_component.value {
                transform_component := game.entities.components_transform[entity];
                engine.draw_fill_rect_raw(&RectF32 {
                    f32(transform_component.grid_position.x * GRID_SIZE), f32(transform_component.grid_position.y * GRID_SIZE),
                    GRID_SIZE, GRID_SIZE,
                }, entity_to_color(entity));
                // log.debugf("color: %v | %v | %g", entity, color, entity);
            }
        }

        {
            engine.profiler_zone("read_pixels", PROFILER_COLOR_RENDER);
            pixel_size : i32 = 4;
            width : i32 = 1;
            height : i32 = 1;
            pixels := make([]Color, width * height);
            pitch := width * pixel_size;
            position := (app.platform.mouse_position - app.renderer.rendering_offset) / app.renderer.rendering_scale;
            engine.render_read_pixels(&{ position.x, position.y, width, height }, .ABGR8888, &pixels[0], pitch);

            game.debug_entity_under_mouse = color_to_entity(pixels[0]);
            // log.debugf("entity: %v | %v | %b", pixels[0], game.debug_entity_under_mouse, game.debug_entity_under_mouse);
        }

        engine.set_render_target(nil);
    }

    if game.debug_show_bounding_boxes {
        engine.draw_texture_by_ptr(_bla_texture, &{ 0, 0, NATIVE_RESOLUTION.x, NATIVE_RESOLUTION.y }, &{ 0, 0, f32(NATIVE_RESOLUTION.x), f32(NATIVE_RESOLUTION.y) });
    }

    { engine.profiler_zone("ui_process_commands", PROFILER_COLOR_RENDER);
        engine.ui_process_commands(app.ui);
    }

    { engine.profiler_zone("present", PROFILER_COLOR_RENDER);
        engine.renderer_present();
    }
}

// FIXME:
_bla_texture : ^engine.Texture;

resize_window :: proc(platform: ^engine.Platform_State, renderer: ^engine.Renderer_State, game: ^Game_State) {
    game.window_size = engine.get_window_size(platform.window);
    if game.window_size.x > game.window_size.y {
        renderer.rendering_scale = i32(f32(game.window_size.y) / f32(NATIVE_RESOLUTION.y));
    } else {
        renderer.rendering_scale = i32(f32(game.window_size.x) / f32(NATIVE_RESOLUTION.x));
    }
    renderer.display_dpi = engine.get_display_dpi(platform.window);
    renderer.rendering_size = NATIVE_RESOLUTION * renderer.rendering_scale;
    update_rendering_offset(renderer, game);
    // log.debugf("window_resized: %v %v %v", game.window_size, renderer.display_dpi, renderer.rendering_scale);
}

update_rendering_offset :: proc(renderer: ^engine.Renderer_State, game: ^Game_State) {
    odd_offset : i32 = 0;
    if game.window_size.y % 2 == 1 {
        odd_offset = 1;
    }
    renderer.rendering_offset = {
        (game.window_size.x - NATIVE_RESOLUTION.x * renderer.rendering_scale) / 2 + odd_offset,
        (game.window_size.y - NATIVE_RESOLUTION.y * renderer.rendering_scale) / 2 + odd_offset,
    };
}

update_player_inputs :: proc(platform: ^engine.Platform_State, game: ^Game_State) {
    keyboard_was_used := false;
    for key in platform.keys {
        if platform.keys[key].down || platform.keys[key].released {
            keyboard_was_used = true;
            break;
        }
    }

    {
        player_inputs := &game.player_inputs;
        player_inputs^ = {};

        player_inputs.mouse_left = platform.mouse_keys[engine.BUTTON_LEFT];

        if keyboard_was_used {
            if (platform.keys[.UP].down) {
                player_inputs.move.y -= 1;
            } else if (platform.keys[.DOWN].down) {
                player_inputs.move.y += 1;
            }
            if (platform.keys[.LEFT].down) {
                player_inputs.move.x -= 1;
            } else if (platform.keys[.RIGHT].down) {
                player_inputs.move.x += 1;
            }

            player_inputs.back = platform.keys[.BACKSPACE];
            player_inputs.start = platform.keys[.RETURN];
            player_inputs.confirm = platform.keys[.SPACE];
            player_inputs.cancel = platform.keys[.ESCAPE];
            player_inputs.debug_0 = platform.keys[.GRAVE];
            player_inputs.debug_1 = platform.keys[.F1];
            player_inputs.debug_2 = platform.keys[.F2];
            player_inputs.debug_3 = platform.keys[.F3];
            player_inputs.debug_4 = platform.keys[.F4];
            player_inputs.debug_5 = platform.keys[.F5];
            player_inputs.debug_6 = platform.keys[.F6];
            player_inputs.debug_7 = platform.keys[.F7];
            player_inputs.debug_8 = platform.keys[.F8];
            player_inputs.debug_9 = platform.keys[.F9];
            player_inputs.debug_10 = platform.keys[.F10];
            player_inputs.debug_11 = platform.keys[.F11];
            player_inputs.debug_12 = platform.keys[.F12];
        } else {
            controller_state, controller_found := engine.get_controller_from_player_index(platform, 0);
            if controller_found {
                if (controller_state.buttons[.DPAD_UP].down) {
                    player_inputs.move.y -= 1;
                } else if (controller_state.buttons[.DPAD_DOWN].down) {
                    player_inputs.move.y += 1;
                }
                if (controller_state.buttons[.DPAD_LEFT].down) {
                    player_inputs.move.x -= 1;
                } else if (controller_state.buttons[.DPAD_RIGHT].down) {
                    player_inputs.move.x += 1;
                }
                if (controller_state.buttons[.DPAD_UP].down) {
                    player_inputs.move.y -= 1;
                }

                // If we use the analog sticks, we ignore the DPad inputs
                if controller_state.axes[.LEFTX].value < -CONTROLLER_DEADZONE || controller_state.axes[.LEFTX].value > CONTROLLER_DEADZONE {
                    player_inputs.move.x = f32(controller_state.axes[.LEFTX].value) / f32(size_of(controller_state.axes[.LEFTX].value));
                }
                if controller_state.axes[.LEFTY].value < -CONTROLLER_DEADZONE || controller_state.axes[.LEFTY].value > CONTROLLER_DEADZONE {
                    player_inputs.move.y = f32(controller_state.axes[.LEFTY].value) / f32(size_of(controller_state.axes[.LEFTY].value));
                }

                player_inputs.back = controller_state.buttons[.BACK];
                player_inputs.start = controller_state.buttons[.START];
                player_inputs.confirm = controller_state.buttons[.A];
                player_inputs.cancel = controller_state.buttons[.B];
            }
        }

        if player_inputs.move.x != 0 || player_inputs.move.y != 0 {
            player_inputs.move = linalg.vector_normalize(player_inputs.move);
        }
    }
}

game_mode_transition :: proc(mode: Game_Mode) {
    log.debugf("game_mode_transition: %v -> %v", game.game_mode, mode);
    if game.game_mode_exited == false && game.game_mode_exit_proc != nil {
        game.game_mode_exit_proc();
        game.game_mode_exit_proc = nil;
    }
    game.game_mode = mode;
    game.game_mode_entered = false;
    game.game_mode_exited = false;
}

@(deferred_out=game_mode_enter_end)
game_mode_enter :: proc(exit_proc: Game_Mode_Proc = nil) -> bool {
    game.game_mode_exit_proc = exit_proc;
    return game.game_mode_entered == false;
}

game_mode_enter_end :: proc(should_trigger: bool) {
    if should_trigger {
        game.game_mode_entered = true;
    }
}

@(deferred_out=game_mode_exit_end)
game_mode_exit :: proc(mode: Game_Mode) -> bool {
    return game.game_mode != mode && game.game_mode_exited == false;
}

game_mode_exit_end :: proc(should_trigger: bool) {
    if should_trigger {
        game.game_mode_exited = true;
        arena_allocator_free_all_and_zero(game.game_mode_allocator);
    }
}


arena_allocator_make :: proc(size: int) -> runtime.Allocator {
    arena := new(mem.Arena);
    arena_backing_buffer := make([]u8, size);
    mem.arena_init(arena, arena_backing_buffer);
    allocator := mem.arena_allocator(arena);
    allocator.procedure = arena_allocator_proc;
    return allocator;
}

arena_allocator_free_all_and_zero :: proc(allocator: runtime.Allocator = context.allocator) {
    arena := cast(^mem.Arena) allocator.data;
    mem.zero_slice(arena.data);
    free_all(allocator);
}

@(deferred_out=mem.end_arena_temp_memory)
arena_temp_block :: proc(arena: ^mem.Arena) -> mem.Arena_Temp_Memory {
    return mem.begin_arena_temp_memory(arena);
}

arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (new_memory: []byte, error: mem.Allocator_Error) {
    new_memory, error = mem.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    if error != .None {
        if error == .Mode_Not_Implemented {
            log.warnf("ARENA alloc (%v) %v: %v byte at %v", mode, error, size, location);
        } else {
            log.errorf("ARENA alloc (%v) %v: %v byte at %v", mode, error, size, location);
            os.exit(0);
        }
    }

    return;
}

import "core:testing"

@test
entity_to_color_encoding_decoding :: proc(t: ^testing.T) {
    testing.expect(t, entity_to_color(0x000000) == Color { 0,   0,   0,   255 });
    testing.expect(t, entity_to_color(0x0000ff) == Color { 0,   0,   255, 255 });
    testing.expect(t, entity_to_color(0x00ffff) == Color { 0,   255, 255, 255 });
    testing.expect(t, entity_to_color(0xffffff) == Color { 255, 255, 255, 255 });
    testing.expect(t, entity_to_color(0xffff00) == Color { 255, 255, 0,   255 });
    testing.expect(t, entity_to_color(0xff0000) == Color { 255, 0,   0,   255 });
    testing.expect(t, color_to_entity(Color { 0,   0,   0,   0   }) == 0x000000);
    testing.expect(t, color_to_entity(Color { 0,   0,   0,   255 }) == 0x000000);
    testing.expect(t, color_to_entity(Color { 0,   0,   255, 255 }) == 0x0000ff);
    testing.expect(t, color_to_entity(Color { 0,   255, 255, 255 }) == 0x00ffff);
    testing.expect(t, color_to_entity(Color { 255, 255, 255, 255 }) == 0xffffff);
    testing.expect(t, color_to_entity(Color { 255, 255, 0,   255 }) == 0xffff00);
    testing.expect(t, color_to_entity(Color { 255, 0,   0,   255 }) == 0xff0000);
}

entity_to_color :: proc(entity: Entity) -> Color {
    assert(entity <= 0xffffff);

    return Color {
        u8((entity & 0x00ff0000) >> 16),
        u8((entity & 0x0000ff00) >> 8),
        u8((entity & 0x000000ff)),
        255,
    };
}

color_to_entity :: proc(color: Color) -> Entity {
    return transmute(Entity) [4]u8 { color.b, color.g, color.r, 0 };
}
