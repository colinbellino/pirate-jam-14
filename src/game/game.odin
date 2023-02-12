package game

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:runtime"
import "core:math"
import "core:math/linalg"

import platform "../engine/platform"
import renderer "../engine/renderer"
import ui "../engine/renderer/ui"
import logger "../engine/logger"
import engine_math "../engine/math"
import profiler "../engine/profiler"

APP_ARENA_PATH          :: "./arena.mem";
APP_ARENA_PATH2         :: "./arena2.mem";
GAME_MODE_ARENA_SIZE    :: 1 * mem.Megabyte;
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

Game_State :: struct {
    game_mode:                  Game_Mode,
    game_mode_arena:            ^mem.Arena,
    game_mode_allocator:        mem.Allocator,
    game_mode_data:             ^Game_Mode_Data,

    unlock_framerate:           bool,
    window_size:                Vector2i,
    rendering_scale:            i32,
    draw_letterbox:             bool,

    debug_ui_window_info:       bool,
    debug_ui_window_console:    i8,
    debug_ui_window_entities:   bool,
    debug_ui_entity:            Entity,
    ui_hovered:                 bool, // This set by the UI in the render phase and reset at the end of the frame (so it can't be displayed in the UI as is).

    version:                    string,
    textures:                   map[string]int,

    camera_zoom:                f32,
    camera_position:            Vector2f32,

    mouse_screen_position:      Vector2i,
    // mouse_room_position:        Vector2i,
    mouse_grid_position:        Vector2i,

    party:                      [dynamic]Entity,
    current_room_index:         i32,

    entities:                   [dynamic]Entity,
    components_name:            map[Entity]Component_Name,
    components_position:        map[Entity]Component_Position,
    components_rendering:       map[Entity]Component_Rendering,
    components_animation:       map[Entity]Component_Animation,
    components_world_info:      map[Entity]Component_World_Info,
    components_flag:            map[Entity]Component_Flag,
}

Game_Mode :: enum {
    Init,
    Title,
    World,
}
Game_Mode_Data :: union {
    Title_Data,
    World_Data,
}
Title_Data :: struct {
    initialized:        bool,
    some_stuff:         []u8,
}

fixed_update :: proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^ui.UI_State,
) {
    // log.debugf("fixed_update: %v", delta_time);
}

variable_update :: proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^ui.UI_State,
) {
    // log.debugf("variable_update: %v", delta_time);
    profiler.profiler_start("variable_update");

    if platform_state.keys[.F1].released {
        game_state.debug_ui_window_info = !game_state.debug_ui_window_info;
    }
    if platform_state.keys[.F2].released {
        game_state.debug_ui_window_console = (game_state.debug_ui_window_console + 1) % 2;
    }
    if platform_state.keys[.F3].released {
        game_state.debug_ui_window_entities = !game_state.debug_ui_window_entities;
    }
    if platform_state.keys[.F11].released {
        game_state.draw_letterbox = !game_state.draw_letterbox;
    }
    game_state.mouse_screen_position = platform_state.mouse_position;

    switch game_state.game_mode {
        case .Init: {
            platform_state.input_mouse_move = ui_input_mouse_move;
            platform_state.input_mouse_down = ui_input_mouse_down;
            platform_state.input_mouse_up = ui_input_mouse_up;
            platform_state.input_text = ui_input_text;
            platform_state.input_scroll = ui_input_scroll;
            platform_state.input_key_down = ui_input_key_down;
            platform_state.input_key_up = ui_input_key_up;

            // game_state.unlock_framerate = true;
            game_state.version = string(#load("../version.txt") or_else "000000");
            game_state.debug_ui_window_info = true;
            game_state.debug_ui_window_console = 0;
            {
                game_state.game_mode_arena = new(mem.Arena, arena_allocator);
                buffer := make([]u8, GAME_MODE_ARENA_SIZE, arena_allocator);
                mem.arena_init(game_state.game_mode_arena, buffer);
                game_state.game_mode_allocator = new(mem.Allocator, arena_allocator)^;
                game_state.game_mode_allocator.procedure = platform.arena_allocator_proc;
                game_state.game_mode_allocator.data = game_state.game_mode_arena;
            }

            game_state.textures["placeholder_0"], _, _ = load_texture("./media/art/placeholder_0.png");
            game_state.textures["room"], _, _          = load_texture("./media/art/autotile_placeholder.png");
            game_state.textures["hero0"], _, _         = load_texture("./media/art/hero0.png");
            game_state.textures["hero1"], _, _         = load_texture("./media/art/hero1.png");
            game_state.textures["calm"], _, _          = load_texture("./media/art/character_calm_spritesheet.png");
            game_state.textures["angry"], _, _         = load_texture("./media/art/character_angry_spritesheet.png");
            game_state.textures["elfette"], _, _       = load_texture("./media/art/elfette.png");
            game_state.textures["hobbit"], _, _        = load_texture("./media/art/hobbit.png");
            game_state.textures["jurons"], _, _        = load_texture("./media/art/jurons.png");
            game_state.textures["pyro"], _, _          = load_texture("./media/art/pyro.png");
            game_state.textures["sage"], _, _          = load_texture("./media/art/sage.png");
            game_state.textures["sylvain"], _, _       = load_texture("./media/art/sylvain.png");

            set_game_mode(game_state, .Title, Title_Data);
        }

        case .Title: {
            title_data := cast(^Title_Data)game_state.game_mode_data;

            if title_data.initialized == false {
                title_data.initialized = true;
                title_data.some_stuff = make([]u8, 100, game_state.game_mode_allocator);
            }

            if platform_state.keys[.SPACE].released {
                start_game(game_state);
            }
        }

        case .World: {
            world_mode_fixed_update(game_state, platform_state, renderer_state, logger_state, ui_state, delta_time);
        }
    }

    for entity in game_state.entities {
        rendering_component, has_rendering := &game_state.components_rendering[entity];
        position_component, has_position := &game_state.components_position[entity];
        animation_component, has_animation := &game_state.components_animation[entity];

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

    game_state.ui_hovered = false;

    profiler.profiler_end("variable_update");

    // profiler.profiler_print_all();
}

start_game :: proc (game_state: ^Game_State) {
    // Pretend we are loading a save game
    {
        game_state.current_room_index = 4;
        {
            entity := entity_make("Ramza", game_state);
            game_state.components_position[entity] = entity_make_component_position({ 25, 14 });
            game_state.components_world_info[entity] = Component_World_Info { game_state.current_room_index }
            game_state.components_rendering[entity] = Component_Rendering {
                false, 1, game_state.textures["calm"],
                { 0, 0 }, { 48, 48 },
            };
            game_state.components_animation[entity] = Component_Animation {
                0, 1.5, +1, false,
                0, { { 0 * 48, 0 }, { 1 * 48, 0 }, { 2 * 48, 0 }, { 3 * 48, 0 }, { 4 * 48, 0 }, { 5 * 48, 0 }, { 6 * 48, 0 }, { 7 * 48, 0 } },
            };
            game_state.components_flag[entity] = Component_Flag { Component_Flags { .Unit } };
            add_to_party(game_state, entity);
        }

        {
            entity := entity_make("Delita", game_state);
            game_state.components_position[entity] = entity_make_component_position({ 24, 14 });
            game_state.components_world_info[entity] = Component_World_Info { game_state.current_room_index }
            game_state.components_rendering[entity] = Component_Rendering {
                false, 1, game_state.textures["angry"],
                { 0, 0 }, { 48, 48 },
            };
            game_state.components_animation[entity] = Component_Animation {
                0, 1.5, +1, false,
                0, { { 0 * 48, 0 }, { 1 * 48, 0 }, { 2 * 48, 0 }, { 3 * 48, 0 }, { 4 * 48, 0 }, { 5 * 48, 0 }, { 6 * 48, 0 }, { 7 * 48, 0 } },
            };
            game_state.components_flag[entity] = Component_Flag { Component_Flags { .Unit } };
            add_to_party(game_state, entity);
        }
    }

    set_game_mode(game_state, .World, World_Data);
}

quit_game :: proc (platform_state: ^platform.Platform_State) {
    platform_state.quit = true;
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
    format_arena_usage_static,
    format_arena_usage_virtual,
}

load_texture :: proc(path: string) -> (texture_index : int = -1, texture: ^renderer.Texture, ok: bool) {
    surface : ^platform.Surface;
    surface, ok = platform.load_surface_from_image_file(path);
    defer platform.free_surface(surface);

    if ok == false {
        return;
    }

    texture, texture_index, ok = renderer.create_texture_from_surface(surface);
    if ok == false {
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
