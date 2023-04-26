package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:os"
import "core:slice"
import "core:sort"
import "core:strconv"
import "core:strings"
import "core:time"

import "../engine"

APP_ARENA_PATH          :: "./arena.mem";
APP_ARENA_PATH2         :: "./arena2.mem";
GAME_MODE_ARENA_SIZE    :: 512 * mem.Kilobyte;
WORLD_MODE_ARENA_SIZE   :: 32 * mem.Kilobyte;
TARGET_FPS              :: time.Duration(16_666_667);
PIXEL_PER_CELL          :: 16;
SPRITE_GRID_SIZE        :: 16;
SPRITE_GRID_WIDTH       :: 4;
CLEAR_COLOR             :: Color { 255, 0, 255, 255 }; // This is supposed to never show up, so it's a super flashy color. If you see it, something is broken.
VOID_COLOR              :: Color { 100, 100, 100, 255 };
WINDOW_BORDER_COLOR     :: Color { 0, 0, 0, 255 };
NATIVE_RESOLUTION       :: Vector2i { 320, 180 };
LETTERBOX_COLOR         :: Color { 10, 10, 10, 255 };
LETTERBOX_SIZE          :: Vector2i { 40, 18 };
LETTERBOX_TOP           :: Rect { 0, 0,                                      NATIVE_RESOLUTION.x, LETTERBOX_SIZE.y };
LETTERBOX_BOTTOM        :: Rect { 0, NATIVE_RESOLUTION.y - LETTERBOX_SIZE.y, NATIVE_RESOLUTION.x, LETTERBOX_SIZE.y };
LETTERBOX_LEFT          :: Rect { 0, 0,                                      LETTERBOX_SIZE.x, NATIVE_RESOLUTION.y };
LETTERBOX_RIGHT         :: Rect { NATIVE_RESOLUTION.x - LETTERBOX_SIZE.x, 0, LETTERBOX_SIZE.x, NATIVE_RESOLUTION.y };
HUD_SIZE                :: Vector2i { 40, 20 };
HUD_RECT                :: Rect { 0, NATIVE_RESOLUTION.y - HUD_SIZE.y, NATIVE_RESOLUTION.x, HUD_SIZE.y };
HUD_COLOR               :: Color { 255, 255, 255, 255 };
PLAYER_MAX              :: 4;
CONTROLLER_DEADZONE     :: 15_000;

PROFILER_COLOR_RENDER   :: 0x550000;

array_cast :: linalg.array_cast;

Color :: engine.Color;
Rect :: engine.Rect;
Vector2f32 :: engine.Vector2f32;
Vector2i :: engine.Vector2i;

Game_State :: struct #packed {
    arena:                      ^mem.Arena,

    game_mode:                  Game_Mode,
    game_mode_arena:            mem.Arena,
    game_mode_allocator:        mem.Allocator,
    game_mode_data:             ^Game_Mode_Data,

    window_size:                Vector2i,
    draw_letterbox:             bool,
    draw_hud:                   bool,

    debug_ui_window_info:       bool,
    debug_ui_window_console:    i8,
    debug_ui_window_entities:   bool,
    debug_ui_show_tiles:        bool,
    debug_ui_entity:            Entity,
    debug_ui_room_only:         bool,
    debug_ui_no_tiles:          bool,
    debug_entity_cursor:        Entity,
    debug_lines:                [100]engine.Line,

    version:                    string,
    camera:                     Entity,
    asset_world:                engine.Asset_Id,
    asset_placeholder:          engine.Asset_Id,
    asset_units:                engine.Asset_Id,
    // FIXME: remove textures and use assets instead
    textures:                   map[string]int,

    mouse_screen_position:      Vector2i,
    mouse_grid_position:        Vector2i,

    party:                      [dynamic]Entity,
    current_room_index:         i32,
    player_inputs:              [PLAYER_MAX]Player_Inputs,

    entities:                   Entity_Data,
}

Game_Mode :: enum { Init, Title, World }
Game_Mode_Data :: union { Game_Mode_Title, Game_Mode_World }

@(export)
game_update :: proc(delta_time: f64, app: ^engine.App) {
    engine.profiler_zone("game_update");

    game: ^Game_State;
    if app.game == nil {
        game = new(Game_State, app.game_allocator);
        app.game = game;
    }
    context.allocator = app.game_allocator;
    game = cast(^Game_State) app.game;

    player_inputs := &game.player_inputs[0];

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
        if player_inputs.cancel.released {
            app.platform.quit = true;
        }
        if player_inputs.debug_0.released {
            game.debug_ui_window_console = (game.debug_ui_window_console + 1) % 2;
        }
        if player_inputs.debug_1.released {
            game.debug_ui_window_info = !game.debug_ui_window_info;
        }
        if player_inputs.debug_2.released {
            game.debug_ui_window_entities = !game.debug_ui_window_entities;
        }
        if player_inputs.debug_3.released {

        }
        if player_inputs.debug_4.released {
            game.debug_ui_show_tiles = !game.debug_ui_show_tiles;
        }
        if player_inputs.debug_5.released {
            app.debug.save_memory = 1;
        }
        if player_inputs.debug_8.released {
            app.debug.load_memory = 1;
        }
        if player_inputs.debug_7.released {
            engine.take_screenshot(app.renderer, app.platform.window);
        }
        if player_inputs.debug_11.released {
            game.draw_letterbox = !game.draw_letterbox;
        }
        if player_inputs.debug_12.released {
            app.renderer.disabled = !app.renderer.disabled;
        }
    }

    engine.ui_begin(app.ui);

    game.mouse_screen_position = app.platform.mouse_position;

    { engine.profiler_zone("draw_debug_windows");
        draw_debug_windows(app, game);
    }

    if game.debug_ui_entity > 0 {
        target_position_component := &game.entities.components_position[game.debug_ui_entity];
        position_component := &game.entities.components_position[game.debug_entity_cursor];
        position_component.world_position = target_position_component.world_position;
    }

    switch game.game_mode {
        case .Init: {
            game.window_size = 6 * NATIVE_RESOLUTION;
            if app.config.TRACY_ENABLE {
                game.arena = cast(^mem.Arena)(cast(^engine.ProfiledAllocatorData)app.game_allocator.data).backing_allocator.data;
            } else {
                game.arena = cast(^mem.Arena)app.game_allocator.data;
            }
            game.version = static_string("000000");
            version_data, version_success := os.read_entire_file_from_filename("./version.txt", app.game_allocator);
            if version_success {
                game.version = string(version_data);
            }
            game.debug_ui_window_info = false;
            game.debug_ui_room_only = false;
            game.debug_ui_no_tiles = true;
            game.debug_ui_show_tiles = true;
            game.debug_ui_window_console = 0;
            game.game_mode_allocator = engine.make_arena_allocator(.GameMode, GAME_MODE_ARENA_SIZE, &game.game_mode_arena, app.game_allocator, app);

            resize_window(app.platform, app.renderer, game);

            engine.asset_init(app);
            game.asset_placeholder = engine.asset_add(app, "media/art/placeholder_0.png", .Image);
            game.asset_world = engine.asset_add(app, "media/levels/world.ldtk", .Map, world_map_file_changed);
            game.asset_units = engine.asset_add(app, "media/art/units.png", .Image);
            engine.asset_add(app, "media/art/zelda_oracle_of_seasons_snow.png", .Image);
            engine.asset_add(app, "media/art/autotile_snow.png", .Image);
            engine.asset_add(app, "media/art/zelda_oracle_of_seasons_110850.png", .Image);

            {
                entity := entity_make("Debug entity cursor", &game.entities);
                game.entities.components_position[entity] = entity_make_component_position({ 0, 0 });
                game.entities.components_rendering[entity] = Component_Rendering {
                    true, game.asset_placeholder,
                    { 0, 0 }, { 32, 32 },
                };
                game.entities.components_z_index[entity] = Component_Z_Index { 99 };
                game.debug_entity_cursor = entity;
            }

            set_game_mode(game, .Title, Game_Mode_Title);
        }

        case .Title: {
            title_mode_update(app, delta_time);
        }

        case .World: {
            world_mode_update(app, delta_time);
        }
    }

    {
        engine.profiler_zone("update_entities");
        for entity in game.entities.entities {
            rendering_component, has_rendering := &game.entities.components_rendering[entity];
            position_component, has_position := &game.entities.components_position[entity];
            animation_component, has_animation := &game.entities.components_animation[entity];

            if has_position && position_component.move_in_progress {
                position_component.move_t = clamp(position_component.move_t + f32(delta_time) * position_component.move_speed, 0, 1);
                position_component.world_position = linalg.lerp(position_component.move_origin, position_component.move_destination, position_component.move_t);
                if position_component.move_t >= 1 {
                    position_component.move_in_progress = false;
                }
            }

            if has_animation && has_rendering {
                animation_component.t = clamp(animation_component.t + f32(delta_time) * animation_component.speed, 0, 1);
                length := i32(len(animation_component.frames) - 1);
                frame := i32(math.round(animation_component.t * f32(length)));
                if animation_component.direction < 0 {
                    frame = i32(length - i32(math.round(animation_component.t * f32(length))));
                }
                rendering_component.texture_position = animation_component.frames[frame];

                if animation_component.t >= 1 {
                    animation_component.t = 0;
                    if animation_component.revert {
                        animation_component.direction = -animation_component.direction;
                    }
                }
            }
        }
    }

    engine.ui_end(app.ui);
}

// We don't want to use string literals since they are built into the binary and we want to avoid this when using code reload
// TODO: cache and reuse strings
static_string :: proc(str: string, allocator := context.allocator) -> string {
    return strings.clone(str, allocator);
}

@(export)
game_fixed_update :: proc(delta_time: f64, app: ^engine.App) {
    engine.profiler_zone("game_fixed_update");
}

@(export)
game_render :: proc(delta_time: f64, app: ^engine.App) {
    engine.profiler_zone("game_render", PROFILER_COLOR_RENDER);

    game := cast(^Game_State) app.game;

    // It's possible render is called before the game state is initialized
    if app.game == nil {
        return;
    }

    if app.platform.window_resized {
        resize_window(app.platform, app.renderer, game);
    }

    engine.renderer_clear(app.renderer, CLEAR_COLOR);
    engine.draw_fill_rect(app.renderer, &Rect { 0, 0, game.window_size.x, game.window_size.y }, VOID_COLOR);

    camera_position := game.entities.components_position[game.camera];

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
            position_component, has_position := game.entities.components_position[entity];
            rendering_component, has_rendering := game.entities.components_rendering[entity];
            flag_component, has_flag := game.entities.components_flag[entity];

            if game.debug_ui_show_tiles == false && has_flag && .Tile in flag_component.value {
                continue;
            }

            if has_rendering && rendering_component.visible && has_position {
                asset := app.assets.assets[rendering_component.texture_asset];
                if asset.state != .Loaded {
                    continue;
                }

                source := engine.Rect {
                    rendering_component.texture_position.x, rendering_component.texture_position.y,
                    rendering_component.texture_size.x, rendering_component.texture_size.y,
                };
                destination := engine.RectF32 {
                    (position_component.world_position.x - camera_position.world_position.x) * f32(PIXEL_PER_CELL),
                    (position_component.world_position.y - camera_position.world_position.y) * f32(PIXEL_PER_CELL),
                    PIXEL_PER_CELL,
                    PIXEL_PER_CELL,
                };
                info := asset.info.(engine.Asset_Info_Image);
                engine.draw_texture(app.renderer, info.texture, &source, &destination);
            }
        }
    }

    { engine.profiler_zone("draw_letterbox", PROFILER_COLOR_RENDER);
        engine.draw_window_border(app.renderer, NATIVE_RESOLUTION, WINDOW_BORDER_COLOR);
        if game.draw_letterbox { // Draw the letterboxes on top of the world
            engine.draw_fill_rect(app.renderer, &Rect { LETTERBOX_TOP.x, LETTERBOX_TOP.y, LETTERBOX_TOP.w, LETTERBOX_TOP.h }, LETTERBOX_COLOR);
            engine.draw_fill_rect(app.renderer, &Rect { LETTERBOX_BOTTOM.x, LETTERBOX_BOTTOM.y, LETTERBOX_BOTTOM.w, LETTERBOX_BOTTOM.h }, LETTERBOX_COLOR);
            engine.draw_fill_rect(app.renderer, &Rect { LETTERBOX_LEFT.x, LETTERBOX_LEFT.y, LETTERBOX_LEFT.w, LETTERBOX_LEFT.h }, LETTERBOX_COLOR);
            engine.draw_fill_rect(app.renderer, &Rect { LETTERBOX_RIGHT.x, LETTERBOX_RIGHT.y, LETTERBOX_RIGHT.w, LETTERBOX_RIGHT.h }, LETTERBOX_COLOR);
        }
    }

    { engine.profiler_zone("draw_hud", PROFILER_COLOR_RENDER);
        if game.draw_hud {
            engine.draw_fill_rect(app.renderer, &Rect { HUD_RECT.x, HUD_RECT.y, HUD_RECT.w, HUD_RECT.h }, HUD_COLOR);
        }
    }

    { engine.profiler_zone("draw_debug_lines", PROFILER_COLOR_RENDER);
        for i := 0; i < len(game.debug_lines); i += 1 {
            line := game.debug_lines[i];
            engine.set_draw_color(app.renderer, line.color);
            engine.draw_line(app.renderer, &line.start, &line.end);
        }
    }

    { engine.profiler_zone("ui_process_commands", PROFILER_COLOR_RENDER);
        engine.ui_process_commands(app.renderer, app.ui);
    }

    { engine.profiler_zone("present", PROFILER_COLOR_RENDER);
        engine.renderer_present(app.renderer);
    }
}

start_last_save :: proc (game: ^Game_State) {
    // Pretend we are loading a save game
    {
        game.current_room_index = 0;
        {
            entity := entity_make("Ramza", &game.entities);
            game.entities.components_position[entity] = entity_make_component_position({ 4, 4 });
            game.entities.components_rendering[entity] = Component_Rendering {
                true, game.asset_units,
                { 0, 0 }, { 16, 16 },
            };
            game.entities.components_z_index[entity] = Component_Z_Index { 2 };
            // game.entities.components_animation[entity] = Component_Animation {
            //     0, 1.5, +1, false,
            //     0, { { 0 * 48, 0 }, { 1 * 48, 0 }, { 2 * 48, 0 }, { 3 * 48, 0 }, { 4 * 48, 0 }, { 5 * 48, 0 }, { 6 * 48, 0 }, { 7 * 48, 0 } },
            // };
            game.entities.components_flag[entity] = Component_Flag { { .Unit, .Ally } };
            add_to_party(game, entity);
        }
        {
            entity := entity_make("Alma", &game.entities);
            game.entities.components_position[entity] = entity_make_component_position({ 8, 4 });
            game.entities.components_rendering[entity] = Component_Rendering {
                true, game.asset_units,
                { 0, 0 }, { 16, 16 },
            };
            game.entities.components_z_index[entity] = Component_Z_Index { 2 };
            // game.entities.components_animation[entity] = Component_Animation {
            //     0, 1.5, +1, false,
            //     0, { { 0 * 48, 0 }, { 1 * 48, 0 }, { 2 * 48, 0 }, { 3 * 48, 0 }, { 4 * 48, 0 }, { 5 * 48, 0 }, { 6 * 48, 0 }, { 7 * 48, 0 } },
            // };
            game.entities.components_flag[entity] = Component_Flag { { .Unit, .Ally } };
            add_to_party(game, entity);
        }
    }

    set_game_mode(game, .World, Game_Mode_World);
}

add_to_party :: proc(game: ^Game_State, entity: Entity) {
    append(&game.party, entity);
}

set_game_mode :: proc(game: ^Game_State, mode: Game_Mode, $data_type: typeid) {
    log.debugf("game_mode changed %v -> %v", game.game_mode, mode);
    free_all(game.game_mode_allocator);
    game.game_mode = mode;
    game.game_mode_data = cast(^Game_Mode_Data) new(data_type, game.game_mode_allocator);
}

run_debug_command :: proc(game: ^Game_State, command: string) {
    if command == "rainbow" {
        log.debug("THIS IS A DEBUG");
        log.info("THIS IS AN INFO");
        log.warn("THIS IS A WARNING");
        log.error("THIS IS AN ERROR");
    }

    if command == "size" {
        log.debugf("SIZE: bool: %v b8: %v b16: %v b32: %v b64: %v", size_of(bool), size_of(b8), size_of(b16), size_of(b32), size_of(b64));
        log.debugf("SIZE: int: %v i8: %v i16: %v i32: %v i64: %v i128: %v", size_of(int), size_of(i8), size_of(i16), size_of(i32), size_of(i64), size_of(i128));
        log.debugf("SIZE: uint: %v u8: %v u16: %v u32: %v u64: %v u128: %v uintptr: %v", size_of(uint), size_of(u8), size_of(u16), size_of(u32), size_of(u64), size_of(u128), size_of(uintptr));
        log.debugf("SIZE: f16: %v f32: %v f64: %v", size_of(f16), size_of(f32), size_of(f64));
        log.debugf("SIZE: complex32: %v complex64: %v complex128: %v", size_of(complex32), size_of(complex64), size_of(complex128));
        log.debugf("SIZE: quaternion64: %v quaternion128: %v quaternion256: %v", size_of(quaternion64), size_of(quaternion128), size_of(quaternion256));
    }

    if strings.has_prefix(command, "add_to_party") {
        parts := strings.split(command, " ");
        id, parse_error := strconv.parse_int(parts[1]);
        if parse_error == false {
            entity := Entity(id);
            add_to_party(game, entity);
            entity_set_visibility(entity, true, &game.entities);
            log.debugf("%v added to the party.", entity_format(entity, &game.entities));
        }
    }
}

resize_window :: proc(platform: ^engine.Platform_State, renderer: ^engine.Renderer_State, game: ^Game_State) {
    game.window_size = engine.get_window_size(platform.window);
    if game.window_size.x > game.window_size.y {
        renderer.rendering_scale = i32(f32(game.window_size.y) / f32(NATIVE_RESOLUTION.y));
    } else {
        renderer.rendering_scale = i32(f32(game.window_size.x) / f32(NATIVE_RESOLUTION.x));
    }
    renderer.display_dpi = engine.get_display_dpi(renderer, platform.window);
    renderer.rendering_size = {
        NATIVE_RESOLUTION.x * renderer.rendering_scale,
        NATIVE_RESOLUTION.y * renderer.rendering_scale,
    };
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

// Notes: We are not freeing the old world so we are leaking like hell,
// but we don't have file hot reloading in release builds so whatever.
// TODO: I'm not sure what to do exactly when we reload the world:
// - Do we delete the tiles or update them?
// - Do we reload tilesets?
world_map_file_changed :: proc(file_watch: ^engine.File_Watch, file_info: ^os.File_Info, app: ^engine.App) {
    // game := cast(^Game_State) app.game;
    // world_data := cast(^Game_Mode_World) game.game_mode_data;
    // asset := &app.assets.assets[file_watch.asset_id];
    // asset_info := asset.info.(engine.Asset_Info_Map);

    // make_world(asset_info.ldtk, game, world_data, game.game_mode_allocator);
}
