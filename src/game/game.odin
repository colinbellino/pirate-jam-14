package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:sort"
import "core:strconv"
import "core:strings"
import "core:time"

import "../engine"
import "../engine/ldtk"

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

Color :: engine.Color;
Rect :: engine.Rect;
array_cast :: linalg.array_cast;
Vector2f32 :: linalg.Vector2f32;
Vector2i :: engine.Vector2i;

Game_State :: struct #packed {
    arena:                      ^mem.Arena,

    game_mode:                  Game_Mode,
    game_mode_arena:            mem.Arena,
    game_mode_allocator:        mem.Allocator,
    game_mode_data:             ^Game_Mode_Data,

    window_size:                Vector2i,
    rendering_scale:            i32,
    draw_letterbox:             bool,
    draw_hud:                   bool,

    debug_ui_window_info:       bool,
    debug_ui_window_console:    i8,
    debug_ui_window_entities:   bool,
    debug_ui_window_profiler:   bool,
    debug_ui_entity:            Entity,
    debug_ui_room_only:         bool,
    debug_ui_no_tiles:          bool,
    debug_entity_cursor:        Entity,

    version:                    string,
    textures:                   map[string]int,
    camera:                     Entity,

    mouse_screen_position:      Vector2i,
    mouse_grid_position:        Vector2i,

    party:                      [dynamic]Entity,
    current_room_index:         i32,

    entities:                   Entity_Data,
}

Game_Mode :: enum { Init, Title, World }
Game_Mode_Data :: union { Game_Mode_Title, Game_Mode_World }

@(export)
game_update :: proc(delta_time: f64, app: ^engine.App) {
    engine.zone("game_update");

    game_state: ^Game_State;
    if app.game_state == nil {
        game_state = new(Game_State, app.game_allocator);
        // game_state.marker_0 = engine.Memory_Marker { '#', '#', '#', '#', 'G', 'A', 'M', 'E', 'S', 'T', 'A', 'T', 'E', '0', '#', '#' };
        // game_state.marker_1 = engine.Memory_Marker { '#', '#', '#', '#', 'G', 'A', 'M', 'E', 'S', 'T', 'A', 'T', 'E', '1', '#', '#' };
        app.game_state = game_state;
    }
    context.allocator = app.game_allocator;
    game_state = cast(^Game_State) app.game_state;
    platform_state := app.platform_state;
    renderer_state := app.renderer_state;
    debug_state := app.debug_state;

    if platform_state.keys[.P].released {
        platform_state.code_reload_requested = true;
    }
    if platform_state.keys[.ESCAPE].released {
        platform_state.quit = true;
    }
    if platform_state.keys[.F1].released {
        game_state.debug_ui_window_info = !game_state.debug_ui_window_info;
    }
    if platform_state.keys[.F2].released {
        game_state.debug_ui_window_console = (game_state.debug_ui_window_console + 1) % 2;
    }
    if platform_state.keys[.F3].released {
        game_state.debug_ui_window_entities = !game_state.debug_ui_window_entities;
    }
    if platform_state.keys[.F4].released {
        game_state.debug_ui_window_profiler = !game_state.debug_ui_window_profiler;
    }
    if platform_state.keys[.F5].released {
        app.save_memory = 1;
    }
    if platform_state.keys[.F8].released {
        app.load_memory = 1;
    }
    if platform_state.keys[.F7].released {
        engine.take_screenshot(renderer_state, platform_state.window);
    }
    if platform_state.keys[.F11].released {
        game_state.draw_letterbox = !game_state.draw_letterbox;
    }
    if platform_state.keys[.F12].released {
        renderer_state.disabled = !renderer_state.disabled;
    }

    game_state.mouse_screen_position = platform_state.mouse_position;

    { engine.zone("ui_inputs");
        engine.ui_input_mouse_move(renderer_state, platform_state.mouse_position.x, platform_state.mouse_position.y);
        engine.ui_input_scroll(renderer_state, platform_state.input_scroll.x * 30, platform_state.input_scroll.y * 30);

        for key, key_state in platform_state.mouse_keys {
            if key_state.pressed {
                ui_input_mouse_down(renderer_state, platform_state.mouse_position, u8(key));
            }
            if key_state.released {
                ui_input_mouse_up(renderer_state, platform_state.mouse_position, u8(key));
            }
        }
        for key, key_state in platform_state.keys {
            if key_state.pressed {
                ui_input_key_down(renderer_state, engine.Keycode(key));
            }
            if key_state.released {
                ui_input_key_up(renderer_state, engine.Keycode(key));
            }
        }
        if platform_state.input_text != "" {
            ui_input_text(renderer_state, platform_state.input_text);
        }

        engine.ui_draw_begin(renderer_state);
    }

    { engine.zone("draw_debug_windows");
        draw_debug_windows(app, game_state);
    }

    if game_state.debug_ui_entity > 0 {
        target_position_component := &game_state.entities.components_position[game_state.debug_ui_entity];
        position_component := &game_state.entities.components_position[game_state.debug_entity_cursor];
        position_component.world_position = target_position_component.world_position;
    }

    switch game_state.game_mode {
        case .Init: {
            game_state.window_size = 6 * NATIVE_RESOLUTION;
            game_state.arena = cast(^mem.Arena)app.game_allocator.data;
            game_state.version = "000000";
            version_data, version_success := os.read_entire_file_from_filename("./version.txt", app.game_allocator);
            if version_success {
                game_state.version = string(version_data);
            }
            game_state.debug_ui_window_info = false;
            game_state.debug_ui_room_only = true;
            game_state.debug_ui_no_tiles = true;
            game_state.debug_ui_window_profiler = false;
            game_state.debug_ui_window_console = 0;
            game_state.game_mode_allocator = engine.make_arena_allocator(.GameMode, GAME_MODE_ARENA_SIZE, &game_state.game_mode_arena, app.game_allocator);

            resize_window(platform_state, renderer_state, game_state);

            game_state.textures["placeholder_0"], _, _ = load_texture(platform_state, renderer_state, "media/art/placeholder_0.png");

            {
                entity := entity_make("Debug entity cursor", &game_state.entities);
                game_state.entities.components_position[entity] = entity_make_component_position({ 0, 0 });
                game_state.entities.components_rendering[entity] = Component_Rendering {
                    true, game_state.textures["placeholder_0"],
                    { 0, 0 }, { 32, 32 },
                };
                game_state.entities.components_z_index[entity] = Component_Z_Index { 99 };
                game_state.debug_entity_cursor = entity;
            }

            set_game_mode(game_state, .Title, Game_Mode_Title);
        }

        case .Title: {
            title_mode_update(game_state, platform_state, renderer_state, delta_time);
        }

        case .World: {
            world_mode_update(game_state, platform_state, renderer_state, delta_time);
        }
    }

    {
        engine.zone("update_entities");
        for entity in game_state.entities.entities {
            rendering_component, has_rendering := &game_state.entities.components_rendering[entity];
            position_component, has_position := &game_state.entities.components_position[entity];
            animation_component, has_animation := &game_state.entities.components_animation[entity];

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

    engine.ui_draw_end(renderer_state);
}

@(export)
game_fixed_update :: proc(delta_time: f64, app: ^engine.App) {
    debug_state := app.debug_state;
    engine.zone("game_fixed_update");
}

@(export)
game_render :: proc(delta_time: f64, app: ^engine.App) {
    // It's possible render is called before the game state is initialized
    if app.game_state == nil {
        return;
    }

    game_state := cast(^Game_State) app.game_state;
    platform_state := app.platform_state;
    renderer_state := app.renderer_state;
    debug_state := app.debug_state;

    if platform_state.window_resized {
        resize_window(platform_state, renderer_state, game_state);
    }

    engine.renderer_clear(renderer_state, CLEAR_COLOR);
    engine.draw_fill_rect(renderer_state, &{ 0, 0, game_state.window_size.x, game_state.window_size.y }, VOID_COLOR);

    camera_position := game_state.entities.components_position[game_state.camera];

    sorted_entities: []Entity;
    { engine.zone("sort_entities");
        // TODO: This is kind of expensive to do each frame.
        // Either filter the entities before the sort or don't do this every single frame.
        sorted_entities = slice.clone(game_state.entities.entities[:], context.temp_allocator);
        {
            context.user_ptr = rawptr(&game_state.entities.components_z_index);
            sort_entities_by_z_index :: proc(a, b: Entity) -> int {
                components_z_index := cast(^map[Entity]Component_Z_Index)context.user_ptr;
                return int(components_z_index[a].z_index - components_z_index[b].z_index);
            }
            sort.heap_sort_proc(sorted_entities, sort_entities_by_z_index);
        }
    }

    { engine.zone("draw_entities");
        for entity in sorted_entities {
            position_component, has_position := game_state.entities.components_position[entity];
            rendering_component, has_rendering := game_state.entities.components_rendering[entity];
            world_info_component, has_world_info := game_state.entities.components_world_info[entity];

            // if has_world_info == false || world_info_component.room_index != game_state.current_room_index {
            //     continue;
            // }

            if has_rendering && rendering_component.visible && has_position {
                source := engine.Rect {
                    rendering_component.texture_position.x, rendering_component.texture_position.y,
                    rendering_component.texture_size.x, rendering_component.texture_size.y,
                };
                destination := engine.Rectf32 {
                    (position_component.world_position.x - camera_position.world_position.x) * f32(PIXEL_PER_CELL),
                    (position_component.world_position.y - camera_position.world_position.y) * f32(PIXEL_PER_CELL),
                    f32(PIXEL_PER_CELL),
                    f32(PIXEL_PER_CELL),
                };
                engine.draw_texture_by_index(renderer_state, rendering_component.texture_index, &source, &destination, f32(game_state.rendering_scale));
            }
        }
    }

    { engine.zone("draw_letterbox");
        engine.draw_window_border(renderer_state, game_state.window_size, WINDOW_BORDER_COLOR);
        if game_state.draw_letterbox { // Draw the letterboxes on top of the world
            engine.draw_fill_rect(renderer_state, &{ LETTERBOX_TOP.x, LETTERBOX_TOP.y, LETTERBOX_TOP.w, LETTERBOX_TOP.h }, LETTERBOX_COLOR, f32(game_state.rendering_scale));
            engine.draw_fill_rect(renderer_state, &{ LETTERBOX_BOTTOM.x, LETTERBOX_BOTTOM.y, LETTERBOX_BOTTOM.w, LETTERBOX_BOTTOM.h }, LETTERBOX_COLOR, f32(game_state.rendering_scale));
            engine.draw_fill_rect(renderer_state, &{ LETTERBOX_LEFT.x, LETTERBOX_LEFT.y, LETTERBOX_LEFT.w, LETTERBOX_LEFT.h }, LETTERBOX_COLOR, f32(game_state.rendering_scale));
            engine.draw_fill_rect(renderer_state, &{ LETTERBOX_RIGHT.x, LETTERBOX_RIGHT.y, LETTERBOX_RIGHT.w, LETTERBOX_RIGHT.h }, LETTERBOX_COLOR, f32(game_state.rendering_scale));
        }
    }

    { engine.zone("draw_hud");
        if game_state.draw_hud {
            engine.draw_fill_rect(renderer_state, &{ HUD_RECT.x, HUD_RECT.y, HUD_RECT.w, HUD_RECT.h }, HUD_COLOR, f32(game_state.rendering_scale));
        }
    }

    { engine.zone("ui_process_commands");
        engine.ui_process_commands(renderer_state);
    }

    { engine.zone("present");
        engine.renderer_present(renderer_state);
    }
}

start_last_save :: proc (game_state: ^Game_State) {
    // Pretend we are loading a save game
    {
        game_state.current_room_index = 0;
        {
            entity := entity_make("Ramza", &game_state.entities);
            game_state.entities.components_position[entity] = entity_make_component_position({ 25, 14 });
            game_state.entities.components_world_info[entity] = Component_World_Info { game_state.current_room_index }
            game_state.entities.components_rendering[entity] = Component_Rendering {
                false, game_state.textures["calm"],
                { 0, 0 }, { 48, 48 },
            };
            game_state.entities.components_z_index[entity] = Component_Z_Index { 1 };
            game_state.entities.components_animation[entity] = Component_Animation {
                0, 1.5, +1, false,
                0, { { 0 * 48, 0 }, { 1 * 48, 0 }, { 2 * 48, 0 }, { 3 * 48, 0 }, { 4 * 48, 0 }, { 5 * 48, 0 }, { 6 * 48, 0 }, { 7 * 48, 0 } },
            };
            game_state.entities.components_flag[entity] = Component_Flag { { .Unit, .Ally } };
            add_to_party(game_state, entity);
        }

        {
            entity := entity_make("Delita", &game_state.entities);
            game_state.entities.components_position[entity] = entity_make_component_position({ 24, 14 });
            game_state.entities.components_world_info[entity] = Component_World_Info { game_state.current_room_index }
            game_state.entities.components_rendering[entity] = Component_Rendering {
                false, game_state.textures["angry"],
                { 0, 0 }, { 48, 48 },
            };
            game_state.entities.components_z_index[entity] = Component_Z_Index { 1 };
            game_state.entities.components_animation[entity] = Component_Animation {
                0, 1.5, +1, false,
                0, { { 0 * 48, 0 }, { 1 * 48, 0 }, { 2 * 48, 0 }, { 3 * 48, 0 }, { 4 * 48, 0 }, { 5 * 48, 0 }, { 6 * 48, 0 }, { 7 * 48, 0 } },
            };
            game_state.entities.components_flag[entity] = Component_Flag { { .Unit, .Ally } };
            add_to_party(game_state, entity);
        }
    }

    set_game_mode(game_state, .World, Game_Mode_World);
}

format_arena_usage_static_data :: proc(offset: int, data_length: int) -> string {
    return fmt.tprintf("%v Kb / %v Kb",
        f32(offset) / mem.Kilobyte,
        f32(data_length) / mem.Kilobyte);
}

format_arena_usage_static :: proc(arena: ^mem.Arena) -> string {
    return fmt.tprintf("%v Kb / %v Kb",
        f32(arena.offset) / mem.Kilobyte,
        f32(len(arena.data)) / mem.Kilobyte);
}

format_arena_usage_virtual :: proc(arena: ^virtual.Arena) -> string {
    return fmt.tprintf("%v Kb / %v Kb",
        f32(arena.total_used) / mem.Kilobyte,
        f32(arena.total_reserved) / mem.Kilobyte);
}

format_arena_usage :: proc {
    format_arena_usage_static_data,
    format_arena_usage_static,
    format_arena_usage_virtual,
}

load_texture :: proc(platform_state: ^engine.Platform_State, renderer_state: ^engine.Renderer_State, path: string) -> (texture_index : int = -1, texture: ^engine.Texture, ok: bool) {
    surface : ^engine.Surface;
    surface, ok = engine.load_surface_from_image_file(platform_state, path);
    defer engine.free_surface(surface);

    if ok == false {
        log.error("Texture not loaded (load_surface_from_image_file).");
        return;
    }

    texture, texture_index, ok = engine.create_texture_from_surface(renderer_state, surface);
    if ok == false {
        log.error("Texture not loaded (create_texture_from_surface).");
        return;
    }

    log.infof("Texture loaded: %v", path);
    return;
}

add_to_party :: proc(game_state: ^Game_State, entity: Entity) {
    append(&game_state.party, entity);
}

set_game_mode :: proc(game_state: ^Game_State, mode: Game_Mode, $data_type: typeid) {
    log.debugf("game_mode changed %v -> %v", game_state.game_mode, mode);
    free_all(game_state.game_mode_allocator);
    game_state.game_mode = mode;
    game_state.game_mode_data = cast(^Game_Mode_Data) new(data_type, game_state.game_mode_allocator);
}

draw_debug_windows :: proc(app: ^engine.App, game_state: ^Game_State) {
    platform_state := app.platform_state;
    renderer_state := app.renderer_state;
    logger_state := app.logger_state;
    debug_state := app.debug_state;

    if game_state.debug_ui_window_info {
        if engine.ui_window(renderer_state, "Debug", { 0, 0, 360, 740 }) {
            engine.ui_layout_row(renderer_state, { -1 }, 0);
            engine.ui_label(renderer_state, ":: Memory");
            engine.ui_layout_row(renderer_state, { 50, 50, 50, 50 }, 0);
            if .SUBMIT in engine.ui_button(renderer_state, "Save 1") {
                app.save_memory = 1;
            }
            if .SUBMIT in engine.ui_button(renderer_state, "Save 2") {
                app.save_memory = 2;
            }
            if .SUBMIT in engine.ui_button(renderer_state, "Save 3") {
                app.save_memory = 3;
            }
            if .SUBMIT in engine.ui_button(renderer_state, "Save 4") {
                app.save_memory = 4;
            }
            engine.ui_layout_row(renderer_state, { 50, 50, 50, 50 }, 0);
            if .SUBMIT in engine.ui_button(renderer_state, "Load 1") {
                app.load_memory = 1;
            }
            if .SUBMIT in engine.ui_button(renderer_state, "Load 2") {
                app.load_memory = 2;
            }
            if .SUBMIT in engine.ui_button(renderer_state, "Load 3") {
                app.load_memory = 3;
            }
            if .SUBMIT in engine.ui_button(renderer_state, "Load 4") {
                app.load_memory = 4;
            }
            engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
            engine.ui_label(renderer_state, "app");
            app_offset := platform_state.arena.offset + renderer_state.arena.offset + game_state.arena.offset;
            app_length := len(platform_state.arena.data) + len(renderer_state.arena.data) + len(game_state.arena.data);
            engine.ui_label(renderer_state, format_arena_usage(app_offset, app_length));
            engine.ui_layout_row(renderer_state, { -1 }, 0);
            engine.ui_progress_bar(renderer_state, f32(app_offset) / f32(app_length), 5);
            engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
            engine.ui_label(renderer_state, "    platform");
            engine.ui_label(renderer_state, format_arena_usage(platform_state.arena));
            engine.ui_progress_bar(renderer_state, f32(platform_state.arena.offset) / f32(len(platform_state.arena.data)), 5);
            engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
            engine.ui_label(renderer_state, "    renderer");
            engine.ui_label(renderer_state, format_arena_usage(renderer_state.arena));
            engine.ui_progress_bar(renderer_state, f32(renderer_state.arena.offset) / f32(len(renderer_state.arena.data)), 5);
            engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
            engine.ui_label(renderer_state, "    game");
            engine.ui_label(renderer_state, format_arena_usage(game_state.arena));
            engine.ui_progress_bar(renderer_state, f32(game_state.arena.offset) / f32(len(game_state.arena.data)), 5);
            engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
            engine.ui_label(renderer_state, "        game_mode");
            engine.ui_label(renderer_state, format_arena_usage(&game_state.game_mode_arena));
            engine.ui_progress_bar(renderer_state, f32(game_state.game_mode_arena.offset) / f32(len(game_state.game_mode_arena.data)), 5);
            engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
            if game_state.game_mode == .World {
                world_data := cast(^Game_Mode_World) game_state.game_mode_data;

                if world_data.initialized {
                    engine.ui_label(renderer_state, "            world_mode");
                    engine.ui_label(renderer_state, format_arena_usage(&world_data.world_mode_arena));
                    engine.ui_progress_bar(renderer_state, f32(world_data.world_mode_arena.offset) / f32(len(world_data.world_mode_arena.data)), 5);
                    engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
                }
            }

            engine.ui_layout_row(renderer_state, { -1 }, 0);
            engine.ui_label(renderer_state, ":: Config");
            engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
            engine.ui_label(renderer_state, "HOT_RELOAD");
            engine.ui_label(renderer_state, fmt.tprintf("game%v.bin", #config(HOT_RELOAD, 0)));

            engine.ui_layout_row(renderer_state, { -1 }, 0);
            engine.ui_label(renderer_state, ":: Platform");
            engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
            engine.ui_label(renderer_state, "mouse_position");
            engine.ui_label(renderer_state, fmt.tprintf("%v", platform_state.mouse_position));
            engine.ui_label(renderer_state, "unlock_framerate");
            engine.ui_label(renderer_state, fmt.tprintf("%v", platform_state.unlock_framerate));

            engine.ui_layout_row(renderer_state, { -1 }, 0);
            engine.ui_label(renderer_state, ":: Game");
            engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
            engine.ui_label(renderer_state, "version");
            engine.ui_label(renderer_state, game_state.version);
            engine.ui_label(renderer_state, "window_size");
            engine.ui_label(renderer_state, fmt.tprintf("%v", game_state.window_size));
            engine.ui_label(renderer_state, "rendering_scale");
            engine.ui_label(renderer_state, fmt.tprintf("%v", game_state.rendering_scale));
            engine.ui_label(renderer_state, "draw_letterbox");
            engine.ui_label(renderer_state, fmt.tprintf("%v", game_state.draw_letterbox));
            engine.ui_label(renderer_state, "mouse_screen_position");
            engine.ui_label(renderer_state, fmt.tprintf("%v", game_state.mouse_screen_position));
            engine.ui_label(renderer_state, "mouse_grid_position");
            engine.ui_label(renderer_state, fmt.tprintf("%v", game_state.mouse_grid_position));
            engine.ui_label(renderer_state, "current_room_index");
            engine.ui_label(renderer_state, fmt.tprintf("%v", game_state.current_room_index));
            engine.ui_label(renderer_state, "party");
            engine.ui_label(renderer_state, fmt.tprintf("%v", game_state.party));

            engine.ui_layout_row(renderer_state, { -1 }, 0);
            engine.ui_label(renderer_state, ":: Renderer");
            engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
            engine.ui_label(renderer_state, "update_rate");
            engine.ui_label(renderer_state, fmt.tprintf("%v", platform_state.update_rate));
            engine.ui_label(renderer_state, "display_dpi");
            engine.ui_label(renderer_state, fmt.tprintf("%v", renderer_state.display_dpi));
            engine.ui_label(renderer_state, "rendering_size");
            engine.ui_label(renderer_state, fmt.tprintf("%v", renderer_state.rendering_size));
            engine.ui_label(renderer_state, "rendering_offset");
            engine.ui_label(renderer_state, fmt.tprintf("%v", renderer_state.rendering_offset));
            engine.ui_label(renderer_state, "textures");
            engine.ui_label(renderer_state, fmt.tprintf("%v", len(renderer_state.textures)));

            if game_state.game_mode == .World {
                world_data := cast(^Game_Mode_World) game_state.game_mode_data;

                if world_data.initialized {
                    engine.ui_layout_row(renderer_state, { -1 }, 0);
                    engine.ui_label(renderer_state, ":: World");
                    engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
                    engine.ui_label(renderer_state, "world_mode");
                    engine.ui_label(renderer_state, fmt.tprintf("%v", world_data.world_mode));

                    if world_data.world_mode == .Battle {
                        battle_data := cast(^World_Mode_Battle) world_data.world_mode_data;

                        engine.ui_layout_row(renderer_state, { -1 }, 0);
                        engine.ui_label(renderer_state, ":: Battle");
                        engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
                        engine.ui_layout_row(renderer_state, { -1 }, 0);
                        engine.ui_layout_row(renderer_state, { 170, -1 }, 0);
                        engine.ui_label(renderer_state, "battle_mode");
                        engine.ui_label(renderer_state, fmt.tprintf("%v", battle_data.battle_mode));
                        engine.ui_label(renderer_state, "entities");
                        engine.ui_label(renderer_state, fmt.tprintf("%v", battle_data.entities));
                        engine.ui_label(renderer_state, "turn_actor");
                        engine.ui_label(renderer_state, entity_format(battle_data.turn_actor, &game_state.entities));
                    }
                }
            }
        }
    }

    if game_state.debug_ui_window_console > 0 {
        height : i32 = 340;
        // if game_state.debug_ui_window_console == 2 {
        //     height = game_state.window_size.y - 103;
        // }
        if engine.ui_window(renderer_state, "Logs", { 0, 0, renderer_state.rendering_size.x, height }, { .NO_CLOSE, .NO_RESIZE }) {
            engine.ui_layout_row(renderer_state, { -1 }, -28);

            if logger_state != nil {
                engine.ui_begin_panel(renderer_state, "Log");
                engine.ui_layout_row(renderer_state, { -1 }, -1);
                lines := logger_state.lines;
                ctx := engine.ui_get_context(renderer_state);
                color := ctx.style.colors[.TEXT];
                for line in lines {
                    height := ctx.text_height(ctx.style.font);
                    RESET     :: engine.Color { 255, 255, 255, 255 };
                    RED       :: engine.Color { 230, 0, 0, 255 };
                    YELLOW    :: engine.Color { 230, 230, 0, 255 };
                    DARK_GREY :: engine.Color { 150, 150, 150, 255 };

                    text_color := RESET;
                    switch line.level {
                        case .Debug:            text_color = DARK_GREY;
                        case .Info:             text_color = RESET;
                        case .Warning:          text_color = YELLOW;
                        case .Error, .Fatal:    text_color = RED;
                    }

                    ctx.style.colors[.TEXT] = engine.cast_color(text_color);
                    engine.ui_layout_row(renderer_state, { -1 }, height);
                    engine.ui_text(renderer_state, line.text);
                }
                ctx.style.colors[.TEXT] = color;
                if logger_state.buffer_updated {
                    panel := engine.ui_get_current_container(renderer_state, );
                    panel.scroll.y = panel.content_size.y;
                    logger_state.buffer_updated = false;
                }
                engine.ui_end_panel(renderer_state);

                // @static buf: [128]byte;
                // @static buf_len: int;
                // submitted := false;
                // engine.ui_layout_row(renderer_state, { -70, -1 });
                // if .SUBMIT in engine.ui_textbox(renderer_state, buf[:], &buf_len) {
                //     engine.ui_set_focus(renderer_state, ctx.last_id);
                //     submitted = true;
                // }
                // if .SUBMIT in engine.ui_button(renderer_state, "Submit") {
                //     submitted = true;
                // }
                // if submitted {
                //     str := string(buf[:buf_len]);
                //     log.debug(str);
                //     buf_len = 0;
                //     run_debug_command(game_state, str);
                // }
            }
        }
    }

    if game_state.debug_ui_window_entities {
        if engine.ui_window(renderer_state, "Entities", { 1240, 0, 360, 640 }) {
            engine.ui_layout_row(renderer_state, { 160, -1 }, 0);

            engine.ui_label(renderer_state, "entities");
            engine.ui_label(renderer_state, fmt.tprintf("%v", len(game_state.entities.entities)));

            engine.ui_layout_row(renderer_state, { 160, -1 }, 0);
            engine.ui_checkbox(renderer_state, "Show room only", &game_state.debug_ui_room_only);

            engine.ui_layout_row(renderer_state, { 160, -1 }, 0);
            engine.ui_checkbox(renderer_state, "Hide tiles", &game_state.debug_ui_no_tiles);

            engine.ui_layout_row(renderer_state, { 160, -1 }, 0);
            for entity in game_state.entities.entities {
                component_flag, has_flag := game_state.entities.components_flag[entity];
                if game_state.debug_ui_no_tiles && has_flag && .Tile in component_flag.value {
                    continue;
                }

                component_world_info, has_world_info := game_state.entities.components_world_info[entity];
                if game_state.debug_ui_room_only && (has_world_info == false || component_world_info.room_index != game_state.current_room_index) {
                    continue;
                }

                engine.ui_push_id_uintptr(renderer_state, uintptr(entity));
                engine.ui_label(renderer_state, fmt.tprintf("%v", entity_format(entity, &game_state.entities)));
                if .SUBMIT in engine.ui_button(renderer_state, "Inspect") {
                    if game_state.debug_ui_entity == entity {
                        game_state.debug_ui_entity = 0;
                    } else {
                        game_state.debug_ui_entity = entity;
                    }
                }
                engine.ui_pop_id(renderer_state, );
            }
        }

        if game_state.debug_ui_entity != 0 {
            entity := game_state.debug_ui_entity;
            if engine.ui_window(renderer_state, fmt.tprintf("Entity %v", entity), { 900, 40, 320, 640 }) {
                component_name, has_name := game_state.entities.components_name[entity];
                if has_name {
                    engine.ui_layout_row(renderer_state, { -1 }, 0);
                    engine.ui_label(renderer_state, ":: Component_Name");
                    engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    engine.ui_label(renderer_state, "name");
                    engine.ui_label(renderer_state, component_name.name);
                }

                component_world_info, has_world_info := game_state.entities.components_world_info[entity];
                if has_world_info {
                    engine.ui_layout_row(renderer_state, { -1 }, 0);
                    engine.ui_label(renderer_state, ":: Component_World_Info");
                    engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    engine.ui_label(renderer_state, "room_index");
                    engine.ui_label(renderer_state, fmt.tprintf("%v", component_world_info.room_index));
                }

                component_position, has_position := game_state.entities.components_position[entity];
                if has_position {
                    engine.ui_layout_row(renderer_state, { -1 }, 0);
                    engine.ui_label(renderer_state, ":: Component_Position");
                    engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    engine.ui_label(renderer_state, "grid_position");
                    engine.ui_label(renderer_state, fmt.tprintf("%v", component_position.grid_position));
                    engine.ui_label(renderer_state, "world_position");
                    engine.ui_label(renderer_state, fmt.tprintf("%v", component_position.world_position));
                }

                component_rendering, has_rendering := game_state.entities.components_rendering[entity];
                if has_rendering {
                    engine.ui_layout_row(renderer_state, { -1 }, 0);
                    engine.ui_label(renderer_state, ":: Component_Rendering");
                    engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    engine.ui_label(renderer_state, "visible");
                    engine.ui_label(renderer_state, fmt.tprintf("%v", component_rendering.visible));
                    engine.ui_label(renderer_state, "texture_index");
                    engine.ui_label(renderer_state, fmt.tprintf("%v", component_rendering.texture_index));
                    engine.ui_label(renderer_state, "texture_position");
                    engine.ui_label(renderer_state, fmt.tprintf("%v", component_rendering.texture_position));
                    engine.ui_label(renderer_state, "texture_size");
                    engine.ui_label(renderer_state, fmt.tprintf("%v", component_rendering.texture_size));
                }

                component_z_index, has_z_index := game_state.entities.components_z_index[entity];
                if has_z_index {
                    engine.ui_layout_row(renderer_state, { -1 }, 0);
                    engine.ui_label(renderer_state, ":: Component_Z_Index");
                    engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    engine.ui_label(renderer_state, "z_index");
                    engine.ui_label(renderer_state, fmt.tprintf("%v", component_z_index.z_index));
                }

                component_animation, has_animation := game_state.entities.components_animation[entity];
                if has_animation {
                    engine.ui_layout_row(renderer_state, { -1 }, 0);
                    engine.ui_label(renderer_state, ":: Component_Animation");
                    engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    engine.ui_label(renderer_state, "current_frame");
                    engine.ui_label(renderer_state, fmt.tprintf("%v", component_animation.current_frame));
                }

                component_flag, has_flag := game_state.entities.components_flag[entity];
                if has_flag {
                    engine.ui_layout_row(renderer_state, { -1 }, 0);
                    engine.ui_label(renderer_state, ":: Component_Flag");
                    engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    engine.ui_label(renderer_state, "value");
                    engine.ui_label(renderer_state, fmt.tprintf("%v", component_flag.value));
                }

                component_battle_info, has_battle_info := game_state.entities.components_battle_info[entity];
                if has_battle_info {
                    engine.ui_layout_row(renderer_state, { -1 }, 0);
                    engine.ui_label(renderer_state, ":: Component_Battle_Info");
                    engine.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    engine.ui_label(renderer_state, "charge_time");
                    engine.ui_label(renderer_state, fmt.tprintf("%v", component_battle_info.charge_time));
                }
            }
        }
    }

    if game_state.debug_ui_window_profiler {
        engine.draw_timers(debug_state, renderer_state, TARGET_FPS, game_state.window_size);
    }
}

run_debug_command :: proc(game_state: ^Game_State, command: string) {
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
            add_to_party(game_state, entity);
            entity_set_visibility(entity, true, &game_state.entities);
            log.debugf("%v added to the party.", entity_format(entity, &game_state.entities));
        }
    }
}

///// Battle

World_Mode_Battle :: struct {
    battle_mode:                Battle_Mode,
    battle_mode_initialized:    bool,

    entities:                   [dynamic]Entity,
    turn_actor:                 Entity,
}

Battle_Mode :: enum {
    None,
    Wait_For_Charge,
    Select_Action,
    Ended,
}

battle_mode_update :: proc(renderer_state: ^engine.Renderer_State, game_state: ^Game_State, platform_state: ^engine.Platform_State, world_data: ^Game_Mode_World) {
    battle_data := cast(^World_Mode_Battle) world_data.world_mode_data;

    if engine.ui_window(renderer_state, "Units", { 900, 0, 200, 300 }, { .NO_CLOSE, .NO_RESIZE }) {
        for entity in battle_data.entities {
            engine.ui_layout_row(renderer_state, { -1 }, 0);
            component_battle_info := &game_state.entities.components_battle_info[entity];

            if entity == battle_data.turn_actor {
                engine.ui_label(renderer_state, fmt.tprintf("%v *", entity_format(entity, &game_state.entities)));
            } else {
                engine.ui_label(renderer_state, entity_format(entity, &game_state.entities));
            }

            charge_progress := f32(component_battle_info.charge_time) / 100.0;
            engine.ui_progress_bar(renderer_state, charge_progress, 5);
        }
    }

    switch battle_data.battle_mode {
        case .None: {
            for entity, world_info in game_state.entities.components_world_info {
                component_flag, has_flag := game_state.entities.components_flag[entity];
                if world_info.room_index == game_state.current_room_index && (has_flag && .Unit in component_flag.value) {
                    append(&battle_data.entities, entity);
                    speed : i32 = 2;
                    if entity % 2 == 0 {
                        speed = 3;
                    }
                    game_state.entities.components_battle_info[entity] = Component_Battle_Info { 0, speed };
                }
            }

            set_battle_mode(battle_data, .Wait_For_Charge);
        }

        case .Wait_For_Charge: {
            battle_data.turn_actor = 0;

            for entity in battle_data.entities {
                component_battle_info := &game_state.entities.components_battle_info[entity];
                component_battle_info.charge_time += component_battle_info.charge_speed;

                if component_battle_info.charge_time >= 100 {
                    battle_data.turn_actor = entity;
                    set_battle_mode(battle_data, .Select_Action);
                    break;
                }
            }
        }

        case .Select_Action: {
            entity := battle_data.turn_actor;

            if battle_data.battle_mode_initialized == false {
                battle_data.battle_mode_initialized = true;
            }

            action_selected := false;

            label := fmt.tprintf("Turn: %v", entity_format(entity, &game_state.entities));
            if engine.ui_window(renderer_state, label, { 500, 500, 200, 200 }, { .NO_CLOSE, .NO_RESIZE }) {
                engine.ui_layout_row(renderer_state, { -1 }, 0);
                actions := []string { "Move", "Act", "Wait" };
                for action in actions {
                    if .SUBMIT in engine.ui_button(renderer_state, action) {
                        log.debugf("action clicked: %v", action);
                        action_selected = true;
                    }
                }
            }

            if platform_state.keys[.SPACE].released {
                action_selected = true;
            }

            component_battle_info := &game_state.entities.components_battle_info[entity];

            // if platform_state.mouse_keys[engine.BUTTON_LEFT].released && engine.ui_is_hovered(renderer_state) == false {
            //     // move_leader_to(entity, game_state.mouse_grid_position, game_state, world_data);
            //     component_battle_info.charge_time = 0;
            //     set_battle_mode(battle_data, .Wait_For_Charge);
            // }

            if action_selected {
                component_battle_info.charge_time = 0;
                set_battle_mode(battle_data, .Wait_For_Charge);
            }
        }

        case .Ended: {
            log.debug("Ended");
        }
    }
}

///// UI

ui_input_mouse_down :: proc(renderer_state: ^engine.Renderer_State, mouse_position: Vector2i, button: u8) {
    switch button {
        case engine.BUTTON_LEFT:   engine.ui_input_mouse_down(renderer_state, mouse_position.x, mouse_position.y, .LEFT);
        case engine.BUTTON_MIDDLE: engine.ui_input_mouse_down(renderer_state, mouse_position.x, mouse_position.y, .MIDDLE);
        case engine.BUTTON_RIGHT:  engine.ui_input_mouse_down(renderer_state, mouse_position.x, mouse_position.y, .RIGHT);
    }
}
ui_input_mouse_up :: proc(renderer_state: ^engine.Renderer_State, mouse_position: Vector2i, button: u8) {
    switch button {
        case engine.BUTTON_LEFT:   engine.ui_input_mouse_up(renderer_state, mouse_position.x, mouse_position.y, .LEFT);
        case engine.BUTTON_MIDDLE: engine.ui_input_mouse_up(renderer_state, mouse_position.x, mouse_position.y, .MIDDLE);
        case engine.BUTTON_RIGHT:  engine.ui_input_mouse_up(renderer_state, mouse_position.x, mouse_position.y, .RIGHT);
    }
}
ui_input_text :: engine.ui_input_text;
ui_input_scroll :: engine.ui_input_scroll;
ui_input_key_down :: proc(renderer_state: ^engine.Renderer_State, keycode: engine.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    engine.ui_input_key_down(renderer_state, .SHIFT);
        case .RSHIFT:    engine.ui_input_key_down(renderer_state, .SHIFT);
        case .LCTRL:     engine.ui_input_key_down(renderer_state, .CTRL);
        case .RCTRL:     engine.ui_input_key_down(renderer_state, .CTRL);
        case .LALT:      engine.ui_input_key_down(renderer_state, .ALT);
        case .RALT:      engine.ui_input_key_down(renderer_state, .ALT);
        case .RETURN:    engine.ui_input_key_down(renderer_state, .RETURN);
        case .KP_ENTER:  engine.ui_input_key_down(renderer_state, .RETURN);
        case .BACKSPACE: engine.ui_input_key_down(renderer_state, .BACKSPACE);
    }
}
ui_input_key_up :: proc(renderer_state: ^engine.Renderer_State, keycode: engine.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    engine.ui_input_key_up(renderer_state, .SHIFT);
        case .RSHIFT:    engine.ui_input_key_up(renderer_state, .SHIFT);
        case .LCTRL:     engine.ui_input_key_up(renderer_state, .CTRL);
        case .RCTRL:     engine.ui_input_key_up(renderer_state, .CTRL);
        case .LALT:      engine.ui_input_key_up(renderer_state, .ALT);
        case .RALT:      engine.ui_input_key_up(renderer_state, .ALT);
        case .RETURN:    engine.ui_input_key_up(renderer_state, .RETURN);
        case .KP_ENTER:  engine.ui_input_key_up(renderer_state, .RETURN);
        case .BACKSPACE: engine.ui_input_key_up(renderer_state, .BACKSPACE);
    }
}

///// Title

Game_Mode_Title :: struct {
    initialized:        bool,
    some_stuff:         []u8,
}

title_mode_update :: proc(
    game_state: ^Game_State,
    platform_state: ^engine.Platform_State,
    renderer_state: ^engine.Renderer_State,
    delta_time: f64,
) {
    title_data := cast(^Game_Mode_Title)game_state.game_mode_data;
    start_selected := false;

    if title_data.initialized == false {
        title_data.initialized = true;
        title_data.some_stuff = make([]u8, 1_000, game_state.game_mode_allocator);

        if engine.contains_os_args("skip-title") {
            start_selected = true;
        }
    }

    if engine.ui_window(renderer_state, "Title", { 600, 400, 320, 320 }, { .NO_CLOSE, .NO_RESIZE }) {
        if .SUBMIT in engine.ui_button(renderer_state, "Start") {
            start_selected = true;
        }
        if .SUBMIT in engine.ui_button(renderer_state, "Quit") {
            platform_state.quit = true;
        }
    }
    if platform_state.keys[.SPACE].released {
        start_selected = true;
    }

    if start_selected {
        start_last_save(game_state);
    }
}

resize_window :: proc(platform_state: ^engine.Platform_State, renderer_state: ^engine.Renderer_State, game_state: ^Game_State) {
    game_state.window_size = engine.get_window_size(platform_state.window);
    if game_state.window_size.x > game_state.window_size.y {
        game_state.rendering_scale = i32(f32(game_state.window_size.y) / f32(NATIVE_RESOLUTION.y));
    } else {
        game_state.rendering_scale = i32(f32(game_state.window_size.x) / f32(NATIVE_RESOLUTION.x));
    }
    renderer_state.display_dpi = engine.get_display_dpi(renderer_state, platform_state.window);
    renderer_state.rendering_size = {
        NATIVE_RESOLUTION.x * game_state.rendering_scale,
        NATIVE_RESOLUTION.y * game_state.rendering_scale,
    };
    odd_offset : i32 = 0;
    if game_state.window_size.y % 2 == 1 {
        odd_offset = 1;
    }
    renderer_state.rendering_offset = {
        (game_state.window_size.x - renderer_state.rendering_size.x) / 2 + odd_offset,
        (game_state.window_size.y - renderer_state.rendering_size.y) / 2 + odd_offset,
    };
    // log.debugf("window_resized: %v %v %v", game_state.window_size, renderer_state.display_dpi, game_state.rendering_scale);
}
