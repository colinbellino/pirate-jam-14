package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:mem/virtual"
import "core:runtime"
import "core:slice"
import "core:sort"
import "core:strconv"
import "core:strings"
import "core:time"

import "../debug"
import "../engine/ldtk"
import "../engine/logger"
import engine_math "../engine/math"
import "../engine/platform"
import "../engine/profiler"
import "../engine/renderer"

APP_ARENA_PATH          :: "./arena.mem";
APP_ARENA_PATH2         :: "./arena2.mem";
GAME_MODE_ARENA_SIZE    :: 256 * mem.Kilobyte;
WORLD_MODE_ARENA_SIZE   :: 32 * mem.Kilobyte;
TARGET_FPS              :: time.Duration(16_666_667);
ROOMS_PATH              :: "./media/levels/rooms.ldtk";
ROOM_SIZE               :: Vector2i { 15, 9 };
ROOM_LEN                :: ROOM_SIZE.x * ROOM_SIZE.y;
ROOM_PREFIX             :: "Room_";
LDTK_ENTITY_LAYER       :: 0;
LDTK_GRID_LAYER         :: 1;
PIXEL_PER_CELL          :: 16;
SPRITE_GRID_SIZE        :: 16;
SPRITE_GRID_WIDTH       :: 4;
CLEAR_COLOR             :: Color { 255, 0, 255, 255 }; // This is supposed to never show up, so it's a super flashy color. If you see it, something is broken.
VOID_COLOR              :: Color { 100, 100, 100, 255 };
WINDOW_BORDER_COLOR     :: Color { 0, 0, 0, 255 };
NATIVE_RESOLUTION       :: Vector2i { 320, 180 };
LETTERBOX_COLOR         :: Color { 10, 10, 10, 255 };
LETTERBOX_SIZE          := Vector2i { 40, 18 };
LETTERBOX_TOP           := Rect { 0, 0,                                      NATIVE_RESOLUTION.x, LETTERBOX_SIZE.y };
LETTERBOX_BOTTOM        := Rect { 0, NATIVE_RESOLUTION.y - LETTERBOX_SIZE.y, NATIVE_RESOLUTION.x, LETTERBOX_SIZE.y };
LETTERBOX_LEFT          := Rect { 0, 0,                                      LETTERBOX_SIZE.x, NATIVE_RESOLUTION.y };
LETTERBOX_RIGHT         := Rect { NATIVE_RESOLUTION.x - LETTERBOX_SIZE.x, 0, LETTERBOX_SIZE.x, NATIVE_RESOLUTION.y };

Color :: renderer.Color;
Rect :: renderer.Rect;
array_cast :: linalg.array_cast;
Vector2f32 :: linalg.Vector2f32;
Vector2i :: engine_math.Vector2i;

Game_Update_Proc :: #type proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    game_state: ^uintptr,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^renderer.UI_State,
    debug_state: ^debug.Debug_State,
)

Game_State :: struct {
    arena:                      ^mem.Arena,

    game_mode:                  Game_Mode,
    game_mode_arena:            mem.Arena,
    game_mode_allocator:        mem.Allocator,
    game_mode_data:             ^Game_Mode_Data,

    quit:                       bool,
    unlock_framerate:           bool,
    window_size:                Vector2i,
    rendering_scale:            i32,
    draw_letterbox:             bool,

    debug_ui_window_info:       bool,
    debug_ui_window_console:    i8,
    debug_ui_window_entities:   bool,
    debug_ui_window_profiler:   bool,
    debug_ui_entity:            Entity,
    debug_ui_room_only:         bool,

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
game_update : Game_Update_Proc : proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    _game_state: ^uintptr,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^renderer.UI_State,
    debug_state: ^debug.Debug_State,
) {
    game_state: ^Game_State;
    if _game_state^ == 0 {
        _game_state^ = uintptr(new(Game_State, arena_allocator));
    }
    game_state = cast(^Game_State) _game_state;

    renderer.ui_draw_begin(renderer_state);
    debug.timed_block_begin(debug_state, "game_update");

    // {
    //     debug.timed_block(debug_state, "draw_debug_windows");
    //     draw_debug_windows(game_state, platform_state, renderer_state, logger_state, debug_state);
    // }

    if platform_state.keys[.P].released {
        platform_state.code_reload_requested = true;
    }

    if platform_state.keys[.ESCAPE].released {
        game_state.quit = true;
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
    if platform_state.keys[.F7].released {
        renderer.take_screenshot(renderer_state, platform_state.window);
    }
    if platform_state.keys[.F11].released {
        game_state.draw_letterbox = !game_state.draw_letterbox;
    }
    if platform_state.keys[.F12].released {
        renderer_state.disabled = !renderer_state.disabled;
    }

    game_state.mouse_screen_position = platform_state.mouse_position;

    switch game_state.game_mode {
        case .Init: {
            // FIXME:
            // platform_state.input_mouse_move = ui_input_mouse_move;
            // platform_state.input_mouse_down = ui_input_mouse_down;
            // platform_state.input_mouse_up = ui_input_mouse_up;
            // platform_state.input_text = ui_input_text;
            // platform_state.input_scroll = ui_input_scroll;
            // platform_state.input_key_down = ui_input_key_down;
            // platform_state.input_key_up = ui_input_key_up;

            game_state.window_size = 6 * NATIVE_RESOLUTION;
            game_state.arena = cast(^mem.Arena)arena_allocator.data;
            // game_state.unlock_framerate = true;
            game_state.version = string(#load("../version.txt") or_else "000000");
            game_state.debug_ui_window_info = false;
            game_state.debug_ui_room_only = true;
            game_state.debug_ui_window_profiler = true;
            game_state.debug_ui_window_console = 0;
            game_state.game_mode_allocator = platform.make_arena_allocator(.GameMode, GAME_MODE_ARENA_SIZE, &game_state.game_mode_arena, arena_allocator);

            resize_window(platform_state, renderer_state, game_state);

            game_state.textures["placeholder_0"], _, _ = load_texture(platform_state, renderer_state, "media/art/placeholder_0.png");
            game_state.textures["calm"], _, _          = load_texture(platform_state, renderer_state, "media/art/character_calm_spritesheet.png");
            game_state.textures["angry"], _, _         = load_texture(platform_state, renderer_state, "media/art/character_angry_spritesheet.png");
            game_state.textures["elfette"], _, _       = load_texture(platform_state, renderer_state, "media/art/elfette.png");
            game_state.textures["hobbit"], _, _        = load_texture(platform_state, renderer_state, "media/art/hobbit.png");
            game_state.textures["jurons"], _, _        = load_texture(platform_state, renderer_state, "media/art/jurons.png");
            game_state.textures["pyro"], _, _          = load_texture(platform_state, renderer_state, "media/art/pyro.png");
            game_state.textures["sage"], _, _          = load_texture(platform_state, renderer_state, "media/art/sage.png");
            game_state.textures["sylvain"], _, _       = load_texture(platform_state, renderer_state, "media/art/sylvain.png");

            set_game_mode(game_state, .Title, Game_Mode_Title);
        }

        case .Title: {
            title_mode_update(game_state, platform_state, renderer_state, delta_time);
        }

        case .World: {
            world_mode_update(game_state, platform_state, renderer_state, delta_time);
        }
    }

    debug.timed_block_begin(debug_state, "game_entities");
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
    debug.timed_block_end(debug_state, "game_entities");

    debug.timed_block_end(debug_state, "game_update");

    renderer.ui_draw_end(renderer_state);
}

@(export)
game_fixed_update : Game_Update_Proc : proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    game_state: ^uintptr,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^renderer.UI_State,
    debug_state: ^debug.Debug_State,
) {
    // log.debugf("game_fixed_update: %v", delta_time);
    // debug.timed_block("game_fixed_update");
}

start_last_save :: proc (game_state: ^Game_State) {
    // Pretend we are loading a save game
    {
        game_state.current_room_index = 4;
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

load_texture :: proc(platform_state: ^platform.Platform_State, renderer_state: ^renderer.Renderer_State, path: string) -> (texture_index : int = -1, texture: ^renderer.Texture, ok: bool) {
    surface : ^platform.Surface;
    surface, ok = platform.load_surface_from_image_file(platform_state, path);
    defer platform.free_surface(surface);

    if ok == false {
        log.error("Texture not loaded (load_surface_from_image_file).");
        return;
    }

    texture, texture_index, ok = renderer.create_texture_from_surface(renderer_state, surface);
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

draw_debug_windows :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    debug_state: ^debug.Debug_State,
) {
    if game_state.debug_ui_window_info {
        if renderer.ui_window(renderer_state, "Debug", { 0, 0, 360, 740 }) {
            renderer.ui_layout_row(renderer_state, { -1 }, 0);
            renderer.ui_label(renderer_state, ":: Memory");
            renderer.ui_layout_row(renderer_state, { 170, -1 }, 0);
            renderer.ui_label(renderer_state, "app");
            app_offset := platform_state.arena.offset + renderer_state.arena.offset + game_state.arena.offset;
            app_length := len(platform_state.arena.data) + len(renderer_state.arena.data) + len(game_state.arena.data);
            renderer.ui_label(renderer_state, format_arena_usage(app_offset, app_length));
            renderer.ui_layout_row(renderer_state, { -1 }, 0);
            renderer.ui_progress_bar(renderer_state, f32(app_offset) / f32(app_length), 5);
            renderer.ui_layout_row(renderer_state, { 170, -1 }, 0);
            renderer.ui_label(renderer_state, "    platform");
            renderer.ui_label(renderer_state, format_arena_usage(platform_state.arena));
            renderer.ui_progress_bar(renderer_state, f32(platform_state.arena.offset) / f32(len(platform_state.arena.data)), 5);
            renderer.ui_layout_row(renderer_state, { 170, -1 }, 0);
            renderer.ui_label(renderer_state, "    renderer");
            renderer.ui_label(renderer_state, format_arena_usage(renderer_state.arena));
            renderer.ui_progress_bar(renderer_state, f32(renderer_state.arena.offset) / f32(len(renderer_state.arena.data)), 5);
            renderer.ui_layout_row(renderer_state, { 170, -1 }, 0);
            renderer.ui_label(renderer_state, "    game");
            renderer.ui_label(renderer_state, format_arena_usage(game_state.arena));
            renderer.ui_progress_bar(renderer_state, f32(game_state.arena.offset) / f32(len(game_state.arena.data)), 5);
            renderer.ui_layout_row(renderer_state, { 170, -1 }, 0);
            renderer.ui_label(renderer_state, "        game_mode");
            renderer.ui_label(renderer_state, format_arena_usage(&game_state.game_mode_arena));
            renderer.ui_progress_bar(renderer_state, f32(game_state.game_mode_arena.offset) / f32(len(game_state.game_mode_arena.data)), 5);
            renderer.ui_layout_row(renderer_state, { 170, -1 }, 0);
            if game_state.game_mode == .World {
                world_data := cast(^Game_Mode_World) game_state.game_mode_data;

                if world_data.initialized {
                    renderer.ui_label(renderer_state, "            world_mode");
                    renderer.ui_label(renderer_state, format_arena_usage(&world_data.world_mode_arena));
                    renderer.ui_progress_bar(renderer_state, f32(world_data.world_mode_arena.offset) / f32(len(world_data.world_mode_arena.data)), 5);
                    renderer.ui_layout_row(renderer_state, { 170, -1 }, 0);
                }
            }

            renderer.ui_layout_row(renderer_state, { -1 }, 0);
            renderer.ui_label(renderer_state, ":: Game");
            renderer.ui_layout_row(renderer_state, { 170, -1 }, 0);
            renderer.ui_label(renderer_state, "version");
            renderer.ui_label(renderer_state, game_state.version);
            renderer.ui_label(renderer_state, "unlock_framerate");
            renderer.ui_label(renderer_state, fmt.tprintf("%v", game_state.unlock_framerate));
            renderer.ui_label(renderer_state, "window_size");
            renderer.ui_label(renderer_state, fmt.tprintf("%v", game_state.window_size));
            renderer.ui_label(renderer_state, "rendering_scale");
            renderer.ui_label(renderer_state, fmt.tprintf("%v", game_state.rendering_scale));
            renderer.ui_label(renderer_state, "draw_letterbox");
            renderer.ui_label(renderer_state, fmt.tprintf("%v", game_state.draw_letterbox));
            renderer.ui_label(renderer_state, "mouse_screen_position");
            renderer.ui_label(renderer_state, fmt.tprintf("%v", game_state.mouse_screen_position));
            renderer.ui_label(renderer_state, "mouse_grid_position");
            renderer.ui_label(renderer_state, fmt.tprintf("%v", game_state.mouse_grid_position));
            renderer.ui_label(renderer_state, "current_room_index");
            renderer.ui_label(renderer_state, fmt.tprintf("%v", game_state.current_room_index));
            renderer.ui_label(renderer_state, "party");
            renderer.ui_label(renderer_state, fmt.tprintf("%v", game_state.party));

            renderer.ui_layout_row(renderer_state, { -1 }, 0);
            renderer.ui_label(renderer_state, ":: Renderer");
            renderer.ui_layout_row(renderer_state, { 170, -1 }, 0);
            renderer.ui_label(renderer_state, "update_rate");
            renderer.ui_label(renderer_state, fmt.tprintf("%v", platform_state.update_rate));
            renderer.ui_label(renderer_state, "display_dpi");
            renderer.ui_label(renderer_state, fmt.tprintf("%v", renderer_state.display_dpi));
            renderer.ui_label(renderer_state, "rendering_size");
            renderer.ui_label(renderer_state, fmt.tprintf("%v", renderer_state.rendering_size));
            renderer.ui_label(renderer_state, "rendering_offset");
            renderer.ui_label(renderer_state, fmt.tprintf("%v", renderer_state.rendering_offset));
            renderer.ui_label(renderer_state, "textures");
            renderer.ui_label(renderer_state, fmt.tprintf("%v", len(renderer_state.textures)));

            if game_state.game_mode == .World {
                world_data := cast(^Game_Mode_World) game_state.game_mode_data;

                if world_data.initialized {
                    renderer.ui_layout_row(renderer_state, { -1 }, 0);
                    renderer.ui_label(renderer_state, ":: World");
                    renderer.ui_layout_row(renderer_state, { 170, -1 }, 0);
                    renderer.ui_label(renderer_state, "world_mode");
                    renderer.ui_label(renderer_state, fmt.tprintf("%v", world_data.world_mode));

                    if world_data.world_mode == .Battle {
                        battle_data := cast(^World_Mode_Battle) world_data.world_mode_data;

                        renderer.ui_layout_row(renderer_state, { -1 }, 0);
                        renderer.ui_label(renderer_state, ":: Battle");
                        renderer.ui_layout_row(renderer_state, { 170, -1 }, 0);
                        renderer.ui_layout_row(renderer_state, { -1 }, 0);
                        renderer.ui_layout_row(renderer_state, { 170, -1 }, 0);
                        renderer.ui_label(renderer_state, "battle_mode");
                        renderer.ui_label(renderer_state, fmt.tprintf("%v", battle_data.battle_mode));
                        renderer.ui_label(renderer_state, "entities");
                        renderer.ui_label(renderer_state, fmt.tprintf("%v", battle_data.entities));
                        renderer.ui_label(renderer_state, "turn_actor");
                        renderer.ui_label(renderer_state, entity_format(battle_data.turn_actor, &game_state.entities));
                    }
                }
            }
        }
    }

    if game_state.debug_ui_window_console > 0 {
        height : i32 = 240;
        // if game_state.debug_ui_window_console == 2 {
            height = game_state.window_size.y - 103;
        // }
        if renderer.ui_window(renderer_state, "Logs", { 0, 0, renderer_state.rendering_size.x, height }, { .NO_CLOSE, .NO_RESIZE }) {
            renderer.ui_layout_row(renderer_state, { -1 }, -28);

            if logger_state != nil {
                renderer.ui_begin_panel(renderer_state, "Log");
                renderer.ui_layout_row(renderer_state, { -1 }, -1);
                lines := logger.read_all_lines();
                ctx := renderer.ui_get_context(renderer_state, );
                color := ctx.style.colors[.TEXT];
                for line in lines {
                    height := ctx.text_height(ctx.style.font);
                    RESET     :: renderer.Color { 255, 255, 255, 255 };
                    RED       :: renderer.Color { 230, 0, 0, 255 };
                    YELLOW    :: renderer.Color { 230, 230, 0, 255 };
                    DARK_GREY :: renderer.Color { 150, 150, 150, 255 };

                    text_color := RESET;
                    switch line.level {
                        case .Debug:            text_color = DARK_GREY;
                        case .Info:             text_color = RESET;
                        case .Warning:          text_color = YELLOW;
                        case .Error, .Fatal:    text_color = RED;
                    }

                    ctx.style.colors[.TEXT] = renderer.cast_color(text_color);
                    renderer.ui_layout_row(renderer_state, { -1 }, height);
                    renderer.ui_text(renderer_state, line.text);
                }
                ctx.style.colors[.TEXT] = color;
                if logger_state.buffer_updated {
                    panel := renderer.ui_get_current_container(renderer_state, );
                    panel.scroll.y = panel.content_size.y;
                    logger_state.buffer_updated = false;
                }
                renderer.ui_end_panel(renderer_state, );

                @static buf: [128]byte;
                @static buf_len: int;
                submitted := false;
                renderer.ui_layout_row(renderer_state, { -70, -1 });
                if .SUBMIT in renderer.ui_textbox(renderer_state, buf[:], &buf_len) {
                    renderer.ui_set_focus(renderer_state, ctx.last_id);
                    submitted = true;
                }
                if .SUBMIT in renderer.ui_button(renderer_state, "Submit") {
                    submitted = true;
                }
                if submitted {
                    str := string(buf[:buf_len]);
                    log.debug(str);
                    buf_len = 0;
                    run_debug_command(game_state, str);
                }
            }
        }
    }

    if game_state.debug_ui_window_entities {
        if renderer.ui_window(renderer_state, "Entities", { 1240, 0, 360, 640 }) {
            renderer.ui_layout_row(renderer_state, { 160, -1 }, 0);
            // renderer.ui_label(renderer_state, "len(component_name)");
            // renderer.ui_label(renderer_state, fmt.tprintf("%v", len(game_state.entities.components_name)));

            renderer.ui_layout_row(renderer_state, { 160, -1 }, 0);
            renderer.ui_checkbox(renderer_state, "Room only", &game_state.debug_ui_room_only)

            renderer.ui_layout_row(renderer_state, { 160, -1 }, 0);
            for entity in game_state.entities.entities {
                component_flag, has_flag := game_state.entities.components_flag[entity];
                if has_flag && .Tile in component_flag.value {
                    continue;
                }

                component_world_info, has_world_info := game_state.entities.components_world_info[entity];
                if game_state.debug_ui_room_only && (has_world_info == false || component_world_info.room_index != game_state.current_room_index) {
                    continue;
                }

                renderer.ui_push_id_uintptr(renderer_state, uintptr(entity));
                renderer.ui_label(renderer_state, fmt.tprintf("%v", entity_format(entity, &game_state.entities)));
                if .SUBMIT in renderer.ui_button(renderer_state, "Inspect") {
                    game_state.debug_ui_entity = entity;
                }
                renderer.ui_pop_id(renderer_state, );
            }
        }

        if game_state.debug_ui_entity != 0 {
            entity := game_state.debug_ui_entity;
            if renderer.ui_window(renderer_state, fmt.tprintf("Entity %v", entity), { 900, 40, 320, 640 }) {
                component_name, has_name := game_state.entities.components_name[entity];
                if has_name {
                    renderer.ui_layout_row(renderer_state, { -1 }, 0);
                    renderer.ui_label(renderer_state, ":: Component_Name");
                    renderer.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    renderer.ui_label(renderer_state, "name");
                    renderer.ui_label(renderer_state, component_name.name);
                }

                component_world_info, has_world_info := game_state.entities.components_world_info[entity];
                if has_world_info {
                    renderer.ui_layout_row(renderer_state, { -1 }, 0);
                    renderer.ui_label(renderer_state, ":: Component_World_Info");
                    renderer.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    renderer.ui_label(renderer_state, "room_index");
                    renderer.ui_label(renderer_state, fmt.tprintf("%v", component_world_info.room_index));
                }

                component_position, has_position := game_state.entities.components_position[entity];
                if has_position {
                    renderer.ui_layout_row(renderer_state, { -1 }, 0);
                    renderer.ui_label(renderer_state, ":: Component_Position");
                    renderer.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    renderer.ui_label(renderer_state, "grid_position");
                    renderer.ui_label(renderer_state, fmt.tprintf("%v", component_position.grid_position));
                    renderer.ui_label(renderer_state, "world_position");
                    renderer.ui_label(renderer_state, fmt.tprintf("%v", component_position.world_position));
                }

                component_rendering, has_rendering := game_state.entities.components_rendering[entity];
                if has_rendering {
                    renderer.ui_layout_row(renderer_state, { -1 }, 0);
                    renderer.ui_label(renderer_state, ":: Component_Rendering");
                    renderer.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    renderer.ui_label(renderer_state, "visible");
                    renderer.ui_label(renderer_state, fmt.tprintf("%v", component_rendering.visible));
                    renderer.ui_label(renderer_state, "texture_index");
                    renderer.ui_label(renderer_state, fmt.tprintf("%v", component_rendering.texture_index));
                    renderer.ui_label(renderer_state, "texture_position");
                    renderer.ui_label(renderer_state, fmt.tprintf("%v", component_rendering.texture_position));
                    renderer.ui_label(renderer_state, "texture_size");
                    renderer.ui_label(renderer_state, fmt.tprintf("%v", component_rendering.texture_size));
                }

                component_z_index, has_z_index := game_state.entities.components_z_index[entity];
                if has_z_index {
                    renderer.ui_layout_row(renderer_state, { -1 }, 0);
                    renderer.ui_label(renderer_state, ":: Component_Z_Index");
                    renderer.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    renderer.ui_label(renderer_state, "z_index");
                    renderer.ui_label(renderer_state, fmt.tprintf("%v", component_z_index.z_index));
                }

                component_animation, has_animation := game_state.entities.components_animation[entity];
                if has_animation {
                    renderer.ui_layout_row(renderer_state, { -1 }, 0);
                    renderer.ui_label(renderer_state, ":: Component_Animation");
                    renderer.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    renderer.ui_label(renderer_state, "current_frame");
                    renderer.ui_label(renderer_state, fmt.tprintf("%v", component_animation.current_frame));
                }

                component_flag, has_flag := game_state.entities.components_flag[entity];
                if has_flag {
                    renderer.ui_layout_row(renderer_state, { -1 }, 0);
                    renderer.ui_label(renderer_state, ":: Component_Flag");
                    renderer.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    renderer.ui_label(renderer_state, "value");
                    renderer.ui_label(renderer_state, fmt.tprintf("%v", component_flag.value));
                }

                component_battle_info, has_battle_info := game_state.entities.components_battle_info[entity];
                if has_battle_info {
                    renderer.ui_layout_row(renderer_state, { -1 }, 0);
                    renderer.ui_label(renderer_state, ":: Component_Battle_Info");
                    renderer.ui_layout_row(renderer_state, { 120, -1 }, 0);
                    renderer.ui_label(renderer_state, "charge_time");
                    renderer.ui_label(renderer_state, fmt.tprintf("%v", component_battle_info.charge_time));
                }
            }
        }
    }

    if game_state.debug_ui_window_profiler {
        debug.draw_timers(debug_state, renderer_state, TARGET_FPS);
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

///// World

Game_Mode_World :: struct {
    initialized:            bool,
    world_mode:             World_Mode,
    world_mode_arena:       mem.Arena,
    world_mode_allocator:   mem.Allocator,
    world_mode_data:        ^World_Mode_Data,

    // TODO: Rename world to level
    // TODO: Don't store ldtk data into world/level, only game logic stuff
    world_entities:         [dynamic]Entity,
    world:                  World,
    room_next_index:        i32,
    mouse_cursor:           Entity,
}

World_Mode :: enum {
    Explore,
    RoomTransition,
    Battle,
}

World_Mode_Data :: union {
    World_Mode_Explore,
    World_Mode_RoomTransition,
    World_Mode_Battle,
}
World_Mode_Explore :: struct { }
World_Mode_RoomTransition :: struct { }

World :: struct {
    size:               Vector2i,
    entities:           map[i32]ldtk.Entity,
    rooms:              []Room,
}

Room :: struct {
    id:                 i32,
    position:           Vector2i,
    size:               Vector2i,
    grid:               [ROOM_LEN]i32,
    tiles:              map[int]ldtk.Tile,
    entity_instances:   []ldtk.EntityInstance,
    tileset_uid:        i32,
}

world_mode_update :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    delta_time: f64,
) {
    world_data := cast(^Game_Mode_World) game_state.game_mode_data;

    if world_data.initialized == false {
        world_data.world_mode_allocator = platform.make_arena_allocator(.WorldMode, WORLD_MODE_ARENA_SIZE, &world_data.world_mode_arena, game_state.game_mode_allocator);

        game_state.draw_letterbox = true;
        world_size := Vector2i { 3, 3 };

        {
            entity := entity_make("Camera", &game_state.entities);
            room_position := engine_math.grid_index_to_position(i32(game_state.current_room_index), world_size.x);
            world_position := Vector2f32 {
                f32(room_position.x * ROOM_SIZE.x) - 40.0 / f32(PIXEL_PER_CELL),
                f32(room_position.y * ROOM_SIZE.y) - 18.0 / f32(PIXEL_PER_CELL),
            };
            game_state.entities.components_position[entity] = Component_Position {};
            (&game_state.entities.components_position[entity]).world_position = world_position;
            game_state.camera = entity;
        }

        ldtk, ok := ldtk.load_file(ROOMS_PATH, context.temp_allocator);
        log.infof("Level %v loaded: %s (%s)", ROOMS_PATH, ldtk.iid, ldtk.jsonVersion);

        for tileset in ldtk.defs.tilesets {
            rel_path, value_ok := tileset.relPath.?;
            if value_ok == false {
                continue;
            }

            path, path_ok := strings.replace(rel_path, "../art", "media/art", 1);
            if path_ok == false {
                log.warnf("Invalid tileset: %s", rel_path);
                continue;
            }

            key := tileset_ui_to_texture_key(tileset.uid);
            game_state.textures[key], _, _ = load_texture(platform_state, renderer_state, path);
        }

        world_data.world = make_world(
            world_size,
            {
                6, 2, 7,
                5, 1, 3,
                9, 4, 8,
            },
            &ldtk,
            game_state.game_mode_allocator,
        );
        world_data.world_entities = make_world_entities(game_state, &world_data.world, game_state.game_mode_allocator);

        for entity in game_state.party {
            entity_set_visibility(entity, true, &game_state.entities);
        }

        {
            entity := entity_make("Mouse cursor", &game_state.entities);
            game_state.entities.components_position[entity] = entity_make_component_position({ 0, 0 });
            // game_state.entities.components_world_info[entity] = Component_World_Info { game_state.current_room_index };
            game_state.entities.components_rendering[entity] = Component_Rendering {
                true, game_state.textures["placeholder_0"],
                { 0, 0 }, { 32, 32 },
            };
            game_state.entities.components_z_index[entity] = Component_Z_Index { 99 };
            world_data.mouse_cursor = entity;
        }

        world_data.initialized = true;
    }

    room := &world_data.world.rooms[game_state.current_room_index];
    leader := game_state.party[0];
    leader_position := &game_state.entities.components_position[leader];
    camera_position := &game_state.entities.components_position[game_state.camera];

    { // Update mouse position
        game_state.mouse_grid_position = screen_position_to_global_position(game_state.mouse_screen_position, room, renderer_state.rendering_offset, game_state.rendering_scale);
        entity_move_instant(world_data.mouse_cursor, game_state.mouse_grid_position, &game_state.entities);
    }

    switch world_data.world_mode {
        case .Explore: {
            explore_data := cast(^World_Mode_Explore) world_data.world_mode_data;

            if platform.contains_os_args("test-battle") {
                move_leader_to(leader, { 22, 9 }, game_state, world_data);
                return;
            }

            if platform_state.mouse_keys[platform.BUTTON_LEFT].released && renderer.ui_is_hovered(renderer_state) == false {
                move_leader_to(leader, game_state.mouse_grid_position, game_state, world_data);
            }

            if platform_state.keys[.F10].released { // Back to title
                for entity in game_state.party {
                    entity_delete(entity, &game_state.entities);
                }
                for entity in world_data.world_entities {
                    entity_delete(entity, &game_state.entities);
                }
                clear(&game_state.party);
                set_game_mode(game_state, .Title, Game_Mode_Title);
            }

            {
                move_input := Vector2i {};
                if (platform_state.keys[.UP].released) {
                    move_input.y -= 1;
                } else if (platform_state.keys[.DOWN].released) {
                    move_input.y += 1;
                } else if (platform_state.keys[.LEFT].released) {
                    move_input.x -= 1;
                } else if (platform_state.keys[.RIGHT].released) {
                    move_input.x += 1;
                }
                if move_input.x != 0 ||  move_input.y != 0 {
                    entity_move_grid(leader_position, leader_position.grid_position + move_input);
                }
            }
        }

        case .RoomTransition: {
            if camera_position.move_t >= 1 {
                game_state.current_room_index = world_data.room_next_index;

                for entity in game_state.party {
                    (&game_state.entities.components_world_info[entity]).room_index = game_state.current_room_index;
                }

                room = &world_data.world.rooms[game_state.current_room_index];
                leader_destination := room_position_to_global_position({ 7, 4 }, room);
                entity_move_instant(leader, leader_destination, &game_state.entities);

                has_foe := false;
                for entity, component_world_info in game_state.entities.components_world_info {
                    if component_world_info.room_index == game_state.current_room_index {
                        component_flag, has_flag := game_state.entities.components_flag[entity];
                        if has_flag && .Foe in component_flag.value {
                            has_foe = true;
                        }
                    }
                }

                if has_foe {
                    set_world_mode(world_data, .Battle, World_Mode_Battle);
                } else {
                    set_world_mode(world_data, .Explore, World_Mode_Explore);
                }
            }
        }

        case .Battle: {
            battle_mode_update(renderer_state, game_state, platform_state, world_data);
        }
    }
}

make_world :: proc(
    world_size: Vector2i, room_ids: []i32, data: ^ldtk.LDTK,
    allocator: runtime.Allocator = context.allocator,
) -> World {
    context.allocator = allocator;

    rooms := make([]Room, world_size.x * world_size.y);
    world := World {};
    world.size = Vector2i { world_size.x, world_size.y };
    world.rooms = rooms;

    // Entities
    entities := make(map[i32]ldtk.Entity, len(data.defs.entities));
    for entity in data.defs.entities {
        entities[entity.uid] = entity;
    }
    world.entities = entities;

    for room_index := 0; room_index < len(room_ids); room_index += 1 {
        room_id := room_ids[room_index];
        room_position := engine_math.grid_index_to_position(i32(room_index), world.size.x);

        level_index := -1;
        for level, i in data.levels {
            parts := strings.split(level.identifier, ROOM_PREFIX);
            if len(parts) > 0 {
                parsed_id, ok := strconv.parse_int(parts[1]);
                if ok && i32(parsed_id) == room_id {
                    level_index = i;
                    break;
                }
            }
        }
        assert(level_index > -1, fmt.tprintf("Can't find level with identifier: %v%v", ROOM_PREFIX, room_id));
        level := data.levels[level_index];

        // IntGrid
        grid_layer_instance := level.layerInstances[LDTK_GRID_LAYER];
        grid_layer_index := -1;
        for layer, i in data.defs.layers {
            if layer.uid == grid_layer_instance.layerDefUid {
                grid_layer_index = i;
                break;
            }
        }
        assert(grid_layer_index > -1, fmt.tprintf("Can't find layer with uid: %v", grid_layer_instance.layerDefUid));
        grid_layer := data.defs.layers[grid_layer_index];

        tileset_uid : i32 = 0;
        for tileset in data.defs.tilesets {
            if tileset.uid == grid_layer.tilesetDefUid {
                tileset_uid = tileset.uid
                break;
            }
        }

        room_size := Vector2i {
            level.pxWid / grid_layer.gridSize,
            level.pxHei / grid_layer.gridSize,
        };

        grid := [ROOM_LEN]i32 {};
        for value, i in grid_layer_instance.intGridCsv {
            grid[i] = value;
        }

        tiles := make(map[int]ldtk.Tile, len(grid_layer_instance.autoLayerTiles));
        for tile in grid_layer_instance.autoLayerTiles {
            position := Vector2i {
                tile.px.x / grid_layer.gridSize,
                tile.px.y / grid_layer.gridSize,
            };
            index := engine_math.grid_position_to_index(position, ROOM_SIZE.x);
            tiles[int(index)] = tile;
        }

        // Entity instances
        entity_layer_instance := level.layerInstances[LDTK_ENTITY_LAYER];
        entity_layer_index := -1;
        for layer, i in data.defs.layers {
            if layer.uid == entity_layer_instance.layerDefUid {
                entity_layer_index = i;
                break;
            }
        }
        assert(entity_layer_index > -1, fmt.tprintf("Can't find layer with uid: %v", entity_layer_instance.layerDefUid));
        // entity_layer := data.defs.layers[entity_layer_index];

        entity_instances := make([]ldtk.EntityInstance, len(entity_layer_instance.entityInstances));
        for entity_instance, index in entity_layer_instance.entityInstances {
            entity_instances[int(index)] = entity_instance;
        }

        world.rooms[room_index] = Room { room_id, room_position, room_size, grid, tiles, entity_instances, tileset_uid };
    }
    return world;
}

make_world_entities :: proc(game_state: ^Game_State, world: ^World, allocator: runtime.Allocator) -> [dynamic]Entity {
    world_entities := make([dynamic]Entity, allocator);

    for room, room_index in world.rooms {
        room_position := engine_math.grid_index_to_position(i32(room_index), world.size.x);

        // Grid
        for cell_value, cell_index in room.grid {
            cell_room_position := engine_math.grid_index_to_position(i32(cell_index), room.size.x);
            grid_position := room_position * room.size + cell_room_position;
            tile, tile_exists := room.tiles[cell_index];
            source_position := Vector2i { tile.src[0], tile.src[1] };

            entity := entity_make(strings.clone(fmt.tprintf("Tile %v", grid_position)), &game_state.entities);
            game_state.entities.components_position[entity] = entity_make_component_position(grid_position);
            game_state.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
            game_state.entities.components_rendering[entity] = Component_Rendering {
                true, game_state.textures[tileset_ui_to_texture_key(room.tileset_uid)],
                source_position, { SPRITE_GRID_SIZE, SPRITE_GRID_SIZE },
            };
            game_state.entities.components_z_index[entity] = Component_Z_Index { 0 };
            game_state.entities.components_flag[entity] = Component_Flag { { .Tile } };

            append(&world_entities, entity);
        }

        // Entities
        for entity_instance in room.entity_instances {
            entity_def := world.entities[entity_instance.defUid];
            entity := entity_make(strings.clone(entity_def.identifier), &game_state.entities);

            source_position: Vector2i;
            switch entity_def.identifier {
                case "Door": {
                    source_position = { 32, 0 };
                    direction: Vector2i;
                    switch entity_instance.__grid {
                        case { 14, 4 }:
                            direction = { +1, 0 };
                        case { 0, 4 }:
                            direction = { -1, 0 };
                        case { 7, 0 }:
                            direction = { 0, -1 };
                        case { 7, 8 }:
                            direction = { 0, +1 };
                    }
                    game_state.entities.components_flag[entity] = Component_Flag { { .Interactive } };
                    game_state.entities.components_door[entity] = Component_Door { direction };
                }
                case "Foe": {
                    // TODO: use foe.id
                    source_position = { 64, 0 };
                    game_state.entities.components_flag[entity] = Component_Flag { { .Unit, .Foe } };
                }
                case "Event": {
                    source_position = { 96, 0 };
                    game_state.entities.components_flag[entity] = Component_Flag { { .Interactive } };
                }
            }

            grid_position : Vector2i = {
                room_position.x * ROOM_SIZE.x + entity_instance.__grid.x,
                room_position.y * ROOM_SIZE.y + entity_instance.__grid.y,
            };
            game_state.entities.components_position[entity] = entity_make_component_position(grid_position);
            game_state.entities.components_world_info[entity] = Component_World_Info { i32(room_index) };
            game_state.entities.components_rendering[entity] = Component_Rendering {
                true, game_state.textures["placeholder_0"],
                source_position, { 32, 32 },
            };
            game_state.entities.components_z_index[entity] = Component_Z_Index { 1 };

            append(&world_entities, entity);
        }
    }

    // log.debugf("world_entities: %v", world_entities);

    return world_entities;
}

room_position_to_global_position :: proc(room_position: Vector2i, room: ^Room) -> Vector2i {
    return {
        (room.position.x * room.size.x) + room_position.x,
        (room.position.y * room.size.y) + room_position.y,
    };
}

screen_position_to_global_position :: proc(screen_position: Vector2i, room: ^Room, rendering_offset: Vector2i, rendering_scale: i32) -> Vector2i {
    room_base := Vector2i {
        room.position.x * room.size.x,
        room.position.y * room.size.y,
    };
    cell_position := Vector2i {
        i32(f32(screen_position.x - rendering_offset.x - LETTERBOX_SIZE.x * rendering_scale) / f32(PIXEL_PER_CELL * rendering_scale)),
        i32(f32(screen_position.y - rendering_offset.y - LETTERBOX_SIZE.y * rendering_scale) / f32(PIXEL_PER_CELL * rendering_scale)),
    };
    return room_base + cell_position;
}

set_world_mode :: proc(world_data: ^Game_Mode_World, mode: World_Mode, $data_type: typeid) {
    log.debugf("world_mode changed %v -> %v", world_data.world_mode, mode);
    free_all(world_data.world_mode_allocator);
    world_data.world_mode = mode;
    world_data.world_mode_data = cast(^World_Mode_Data) new(data_type, world_data.world_mode_allocator);
}

set_battle_mode :: proc(battle_data: ^World_Mode_Battle, mode: Battle_Mode) {
    log.debugf("battle_mode changed %v -> %v", battle_data.battle_mode, mode);
    battle_data.battle_mode = mode;
    battle_data.battle_mode_initialized = false;
}

move_leader_to :: proc(leader: Entity, destination: Vector2i, game_state: ^Game_State, world_data: ^Game_Mode_World) {
    camera_position := &game_state.entities.components_position[game_state.camera];

    // TODO: move tile to tile with A* pathfinding
    entity_move_instant(leader, destination, &game_state.entities);

    entity_at_position, found := entity_get_first_at_position(destination, .Interactive, &game_state.entities);
    if found {
        log.debugf("Entity found: %v", entity_format(entity_at_position, &game_state.entities));
        component_door, has_door := game_state.entities.components_door[entity_at_position];
        if has_door {
            destination := camera_position.world_position + Vector2f32(array_cast(component_door.direction * ROOM_SIZE, f32));
            entity_move_world(camera_position, destination, 3.0);

            current_room_position := engine_math.grid_index_to_position(game_state.current_room_index, world_data.world.size.x);
            next_room_position := current_room_position + component_door.direction;
            world_data.room_next_index = engine_math.grid_position_to_index(next_room_position, world_data.world.size.x);

            set_world_mode(world_data, .RoomTransition, World_Mode_RoomTransition);
        }
    }
}

tileset_ui_to_texture_key :: proc(tileset_uid: i32) -> string {
    return strings.clone(fmt.tprintf("tileset_%v", tileset_uid));
}

///// UI

ui_input_mouse_move :: proc(renderer_state: ^renderer.Renderer_State, x: i32, y: i32) {
    // log.debugf("mouse_move: %v,%v", x, y);
    renderer.ui_input_mouse_move(renderer_state, x, y);
}
ui_input_mouse_down :: proc(renderer_state: ^renderer.Renderer_State, x: i32, y: i32, button: u8) {
    switch button {
        case platform.BUTTON_LEFT:   renderer.ui_input_mouse_down(renderer_state, x, y, .LEFT);
        case platform.BUTTON_MIDDLE: renderer.ui_input_mouse_down(renderer_state, x, y, .MIDDLE);
        case platform.BUTTON_RIGHT:  renderer.ui_input_mouse_down(renderer_state, x, y, .RIGHT);
    }
}
ui_input_mouse_up :: proc(renderer_state: ^renderer.Renderer_State, x: i32, y: i32, button: u8) {
    switch button {
        case platform.BUTTON_LEFT:   renderer.ui_input_mouse_up(renderer_state, x, y, .LEFT);
        case platform.BUTTON_MIDDLE: renderer.ui_input_mouse_up(renderer_state, x, y, .MIDDLE);
        case platform.BUTTON_RIGHT:  renderer.ui_input_mouse_up(renderer_state, x, y, .RIGHT);
    }
}
ui_input_text :: renderer.ui_input_text;
ui_input_scroll :: renderer.ui_input_scroll;
ui_input_key_down :: proc(renderer_state: ^renderer.Renderer_State, keycode: platform.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    renderer.ui_input_key_down(renderer_state, .SHIFT);
        case .RSHIFT:    renderer.ui_input_key_down(renderer_state, .SHIFT);
        case .LCTRL:     renderer.ui_input_key_down(renderer_state, .CTRL);
        case .RCTRL:     renderer.ui_input_key_down(renderer_state, .CTRL);
        case .LALT:      renderer.ui_input_key_down(renderer_state, .ALT);
        case .RALT:      renderer.ui_input_key_down(renderer_state, .ALT);
        case .RETURN:    renderer.ui_input_key_down(renderer_state, .RETURN);
        case .KP_ENTER:  renderer.ui_input_key_down(renderer_state, .RETURN);
        case .BACKSPACE: renderer.ui_input_key_down(renderer_state, .BACKSPACE);
    }
}
ui_input_key_up :: proc(renderer_state: ^renderer.Renderer_State, keycode: platform.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    renderer.ui_input_key_up(renderer_state, .SHIFT);
        case .RSHIFT:    renderer.ui_input_key_up(renderer_state, .SHIFT);
        case .LCTRL:     renderer.ui_input_key_up(renderer_state, .CTRL);
        case .RCTRL:     renderer.ui_input_key_up(renderer_state, .CTRL);
        case .LALT:      renderer.ui_input_key_up(renderer_state, .ALT);
        case .RALT:      renderer.ui_input_key_up(renderer_state, .ALT);
        case .RETURN:    renderer.ui_input_key_up(renderer_state, .RETURN);
        case .KP_ENTER:  renderer.ui_input_key_up(renderer_state, .RETURN);
        case .BACKSPACE: renderer.ui_input_key_up(renderer_state, .BACKSPACE);
    }
}

///// Title

Game_Mode_Title :: struct {
    initialized:        bool,
    some_stuff:         []u8,
}

title_mode_update :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    delta_time: f64,
) {
    title_data := cast(^Game_Mode_Title)game_state.game_mode_data;
    start_selected := false;

    if title_data.initialized == false {
        title_data.initialized = true;
        title_data.some_stuff = make([]u8, 100, game_state.game_mode_allocator);

        if platform.contains_os_args("skip-title") {
            start_selected = true;
        }
    }

    if renderer.ui_window(renderer_state, "Title", { 600, 400, 320, 320 }, { .NO_CLOSE, .NO_RESIZE }) {
        if .SUBMIT in renderer.ui_button(renderer_state, "Start") {
            start_selected = true;
        }
        if .SUBMIT in renderer.ui_button(renderer_state, "Quit") {
            game_state.quit = true;
        }
    }
    if platform_state.keys[.SPACE].released {
        start_selected = true;
    }

    if start_selected {
        start_last_save(game_state);
    }
}

resize_window :: proc(platform_state: ^platform.Platform_State, renderer_state: ^renderer.Renderer_State, game_state: ^Game_State) {
    game_state.window_size = platform.get_window_size(platform_state.window);
    if game_state.window_size.x > game_state.window_size.y {
        game_state.rendering_scale = i32(f32(game_state.window_size.y) / f32(NATIVE_RESOLUTION.y));
    } else {
        game_state.rendering_scale = i32(f32(game_state.window_size.x) / f32(NATIVE_RESOLUTION.x));
    }
    renderer_state.display_dpi = renderer.get_display_dpi(renderer_state, platform_state.window);
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
    log.debugf("window_resized: %v %v %v", game_state.window_size, renderer_state.display_dpi, game_state.rendering_scale);
}

///// Render

@(export)
game_render : Game_Update_Proc : proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    _game_state: ^uintptr,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^renderer.UI_State,
    debug_state: ^debug.Debug_State,
) {
    game_state := cast(^Game_State) _game_state;

    if platform_state.window_resized {
        resize_window(platform_state, renderer_state, game_state);
    }

    renderer.clear(renderer_state, CLEAR_COLOR);
    renderer.draw_fill_rect(renderer_state, &{ 0, 0, game_state.window_size.x, game_state.window_size.y }, VOID_COLOR);

    camera_position := game_state.entities.components_position[game_state.camera];

    debug.timed_block_begin(debug_state, "sort_entities");
    // TODO: This is kind of expensive to do each frame.
    // Either filter the entities before the sort or don't do this every single frame.
    sorted_entities := slice.clone(game_state.entities.entities[:], context.temp_allocator);
    {
        context.user_ptr = rawptr(&game_state.entities.components_z_index);
        sort_entities_by_z_index :: proc(a, b: Entity) -> int {
            components_z_index := cast(^map[Entity]Component_Z_Index)context.user_ptr;
            return int(components_z_index[a].z_index - components_z_index[b].z_index);
        }
        sort.heap_sort_proc(sorted_entities, sort_entities_by_z_index);
    }
    debug.timed_block_end(debug_state, "sort_entities");

    debug.timed_block_begin(debug_state, "draw_entities");
    for entity in sorted_entities {
        position_component, has_position := game_state.entities.components_position[entity];
        rendering_component, has_rendering := game_state.entities.components_rendering[entity];
        world_info_component, has_world_info := game_state.entities.components_world_info[entity];

        // if has_world_info == false || world_info_component.room_index != game_state.current_room_index {
        //     continue;
        // }

        if has_rendering && rendering_component.visible && has_position {
            source := renderer.Rect {
                rendering_component.texture_position.x, rendering_component.texture_position.y,
                rendering_component.texture_size.x, rendering_component.texture_size.y,
            };
            destination := renderer.Rectf32 {
                (position_component.world_position.x - camera_position.world_position.x) * f32(PIXEL_PER_CELL),
                (position_component.world_position.y - camera_position.world_position.y) * f32(PIXEL_PER_CELL),
                f32(PIXEL_PER_CELL),
                f32(PIXEL_PER_CELL),
            };
            renderer.draw_texture_by_index(renderer_state, rendering_component.texture_index, &source, &destination, f32(game_state.rendering_scale));
        }
    }
    debug.timed_block_end(debug_state, "draw_entities");

    debug.timed_block_begin(debug_state, "draw_letterbox");
    // Draw the letterboxes on top of the world
    if game_state.draw_letterbox {
        renderer.draw_fill_rect(renderer_state, &LETTERBOX_TOP, LETTERBOX_COLOR, f32(game_state.rendering_scale));
        renderer.draw_fill_rect(renderer_state, &LETTERBOX_BOTTOM, LETTERBOX_COLOR, f32(game_state.rendering_scale));
        renderer.draw_fill_rect(renderer_state, &LETTERBOX_LEFT, LETTERBOX_COLOR, f32(game_state.rendering_scale));
        renderer.draw_fill_rect(renderer_state, &LETTERBOX_RIGHT, LETTERBOX_COLOR, f32(game_state.rendering_scale));
    }
    renderer.draw_window_border(renderer_state, game_state.window_size, WINDOW_BORDER_COLOR);
    debug.timed_block_end(debug_state, "draw_letterbox");

    debug.timed_block_begin(debug_state, "renderer.ui_process_commands");
    renderer.ui_process_commands(renderer_state);
    debug.timed_block_end(debug_state, "renderer.ui_process_commands");

    {
        debug.timed_block(debug_state, "renderer.present");
        renderer.present(renderer_state);
    }

    // profiler.profiler_print_all();
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

battle_mode_update :: proc(renderer_state: ^renderer.Renderer_State, game_state: ^Game_State, platform_state: ^platform.Platform_State, world_data: ^Game_Mode_World) {
    battle_data := cast(^World_Mode_Battle) world_data.world_mode_data;

    if renderer.ui_window(renderer_state, "Units", { 900, 0, 200, 300 }, { .NO_CLOSE, .NO_RESIZE }) {
        for entity in battle_data.entities {
            renderer.ui_layout_row(renderer_state, { -1 }, 0);
            component_battle_info := &game_state.entities.components_battle_info[entity];

            if entity == battle_data.turn_actor {
                renderer.ui_label(renderer_state, fmt.tprintf("%v *", entity_format(entity, &game_state.entities)));
            } else {
                renderer.ui_label(renderer_state, entity_format(entity, &game_state.entities));
            }

            charge_progress := f32(component_battle_info.charge_time) / 100.0;
            renderer.ui_progress_bar(renderer_state, charge_progress, 5);
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
            if renderer.ui_window(renderer_state, label, { 500, 500, 200, 200 }, { .NO_CLOSE, .NO_RESIZE }) {
                renderer.ui_layout_row(renderer_state, { -1 }, 0);
                actions := []string { "Move", "Act", "Wait" };
                for action in actions {
                    if .SUBMIT in renderer.ui_button(renderer_state, action) {
                        log.debugf("action clicked: %v", action);
                        action_selected = true;
                    }
                }
            }

            if platform_state.keys[.SPACE].released {
                action_selected = true;
            }

            component_battle_info := &game_state.entities.components_battle_info[entity];

            if platform_state.mouse_keys[platform.BUTTON_LEFT].released && renderer.ui_is_hovered(renderer_state) == false {
                move_leader_to(entity, game_state.mouse_grid_position, game_state, world_data);
                component_battle_info.charge_time = 0;
                set_battle_mode(battle_data, .Wait_For_Charge);
            }

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

///// Entities


// TODO: Do some assertions to make sure this is always up-to-date
ENTITY_COMPONENT_COUNT :: 9;

Entity_Data :: struct {
    entities:                   [dynamic]Entity,
    components_name:            map[Entity]Component_Name,
    components_position:        map[Entity]Component_Position,
    components_rendering:       map[Entity]Component_Rendering,
    components_animation:       map[Entity]Component_Animation,
    components_world_info:      map[Entity]Component_World_Info,
    components_flag:            map[Entity]Component_Flag,
    components_door:            map[Entity]Component_Door,
    components_battle_info:     map[Entity]Component_Battle_Info,
    components_z_index:         map[Entity]Component_Z_Index,
}

Entity :: distinct i32;

Component_Map :: map[Entity]Component;

Component :: struct { }

Component_Name :: struct {
    name:               string,
}

Component_Position :: struct {
    grid_position:      Vector2i,
    world_position:     Vector2f32,
    move_in_progress:   bool,
    move_origin:        Vector2f32,
    move_destination:   Vector2f32,
    move_t:             f32,
    move_speed:         f32,
}

Component_World_Info :: struct {
    room_index:         i32,
}

Component_Battle_Info :: struct {
    charge_time:        i32,
    charge_speed:       i32,
}

Component_Rendering :: struct {
    visible:            bool,
    // z_index:            i32,
    texture_index:      int,
    texture_position:   Vector2i,
    texture_size:       Vector2i,
}
Component_Z_Index :: struct {
    z_index:            i32,
}

Component_Animation :: struct {
    t:                  f32,
    speed:              f32,
    direction:          i8,
    revert:             bool,
    current_frame:      int,
    frames:             [dynamic]Vector2i,
}

Component_Flag :: struct {
    value: Component_Flags,
}
Component_Flags :: bit_set[Component_Flags_Enum];
Component_Flags_Enum :: enum i32 {
    None,
    Interactive,
    Tile,
    Unit, // Remove this if we add Component_Unit (more Ally/Foe into it)
    Ally,
    Foe,
}

Component_Door :: struct {
    direction:         Vector2i,
}

entity_delete :: proc(entity: Entity, entity_data: ^Entity_Data) {
    entity_index := -1;
    for e, i in entity_data.entities {
        if e == entity {
            entity_index = i;
            break;
        }
    }
    if entity_index == -1 {
        log.errorf("Entity not found: %v", entity);
        return;
    }

    // TODO: don't delete, disable & flag for reuse
    unordered_remove(&entity_data.entities, entity_index);

    for i := 0; i < ENTITY_COMPONENT_COUNT; i += 1 {
        delete_key(mem.ptr_offset(&entity_data.components_name, i * size_of(Component_Map)), entity);
    }
}

entity_format :: proc(entity: Entity, entity_data: ^Entity_Data) -> string {
    name := entity_data.components_name[entity].name;
    return fmt.tprintf("%v (%v)", entity, name);
}

entity_make :: proc(name: string, entity_data: ^Entity_Data) -> Entity {
    entity := Entity(len(entity_data.entities) + 1);
    append(&entity_data.entities, entity);
    entity_data.components_name[entity] = Component_Name { name };
    // log.debugf("Entity created: %v", entity_format(game_state, entity));
    return entity;
}

entity_set_visibility :: proc(entity: Entity, value: bool, entity_data: ^Entity_Data) {
    (&entity_data.components_rendering[entity]).visible = value;
}

entity_make_component_position :: proc(grid_position: Vector2i) -> Component_Position {
    world_position := Vector2f32(array_cast(grid_position, f32));
    component_position := Component_Position {};
    component_position.grid_position = grid_position;
    component_position.world_position = world_position;
    return component_position;
}

entity_move_grid :: proc(position_component: ^Component_Position, destination: Vector2i, speed: f32 = 3.0) {
    position_component.move_origin = position_component.world_position;
    position_component.move_destination = Vector2f32(array_cast(destination, f32));
    position_component.grid_position = destination;
    position_component.move_in_progress = true;
    position_component.move_t = 0;
    position_component.move_speed = speed;
}

entity_move_world :: proc(position_component: ^Component_Position, destination: Vector2f32, speed: f32 = 3.0) {
    position_component.move_origin = position_component.world_position;
    position_component.move_destination = destination;
    position_component.move_in_progress = true;
    position_component.move_t = 0;
    position_component.move_speed = speed;
}

entity_move_instant :: proc(entity: Entity, destination: Vector2i, entity_data: ^Entity_Data) {
    position_component := &(entity_data.components_position[entity]);
    position_component.grid_position = destination;
    position_component.world_position = Vector2f32(array_cast(destination, f32));
    position_component.move_in_progress = false;
}

entity_get_first_at_position :: proc(grid_position: Vector2i, flag: Component_Flags_Enum, entity_data: ^Entity_Data) -> (found_entity: Entity, found: bool) {
    for entity, component_position in entity_data.components_position {
        component_flag, has_flag := entity_data.components_flag[entity];
        if component_position.grid_position == grid_position && has_flag && flag in component_flag.value {
            found_entity = entity;
            found = true;
            return;
        }
    }

    return;
}
