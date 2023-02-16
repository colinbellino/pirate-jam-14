package game

import "core:fmt"
import "core:log"
import "core:mem"
import "core:math"
import "core:runtime"
import "core:strings"
import "core:strconv"
import "core:mem/virtual"
import "core:math/linalg"

import platform "../engine/platform"
import renderer "../engine/renderer"
import ui "../engine/renderer/ui"
import logger "../engine/logger"
import engine_math "../engine/math"
import profiler "../engine/profiler"

APP_ARENA_PATH          :: "./arena.mem";
APP_ARENA_PATH2         :: "./arena2.mem";
GAME_MODE_ARENA_SIZE    :: 6 * mem.Megabyte;
WORLD_MODE_ARENA_SIZE   :: 2 * mem.Megabyte;
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
    arena:                      ^mem.Arena,

    game_mode:                  Game_Mode,
    game_mode_arena:            ^mem.Arena,
    game_mode_allocator:        mem.Allocator,
    game_mode_data:             ^Game_Mode_Data,

    quit:                       bool,
    unlock_framerate:           bool,
    window_size:                Vector2i,
    rendering_scale:            i32,
    draw_letterbox:             bool,

    ui:                         Game_UI_State,

    debug_ui_window_info:       bool,
    debug_ui_window_console:    i8,
    debug_ui_window_entities:   bool,
    debug_ui_entity:            Entity,
    ui_hovered:                 bool, // This set by the UI in the render phase and reset at the end of the frame (so it can't be displayed in the UI as is).
    debug_ui_room_only:         bool,

    version:                    string,
    textures:                   map[string]int,
    camera:                     Entity,

    mouse_screen_position:      Vector2i,
    // mouse_room_position:        Vector2i,
    mouse_grid_position:        Vector2i,

    party:                      [dynamic]Entity,
    current_room_index:         i32,

    entities:                   Entity_Data,
}

Game_Mode :: enum { Init, Title, World }
Game_Mode_Data :: union { Game_Mode_Title, Game_Mode_World }

game_update :: proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^ui.UI_State,
) {
    profiler.profiler_start("game_update");

    ui.draw_begin();

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

            game_state.arena = cast(^mem.Arena)arena_allocator.data;
            // game_state.unlock_framerate = true;
            game_state.version = string(#load("../version.txt") or_else "000000");
            game_state.debug_ui_window_info = true;
            game_state.debug_ui_room_only = true;
            game_state.debug_ui_window_console = 0;
            {
                game_state.game_mode_arena = new(mem.Arena, arena_allocator);
                buffer := make([]u8, GAME_MODE_ARENA_SIZE, arena_allocator);
                mem.arena_init(game_state.game_mode_arena, buffer);
                game_state.game_mode_allocator = new(mem.Allocator, arena_allocator)^;
                game_state.game_mode_allocator.procedure = platform.arena_allocator_proc;
                game_state.game_mode_allocator.data = game_state.game_mode_arena;
            }

            ui_init(&game_state.ui, &renderer_state.rendering_offset, &ui_state.ctx);

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

            set_game_mode(game_state, .Title, Game_Mode_Title);
        }

        case .Title: {
            title_mode_update(game_state, platform_state, renderer_state, delta_time);
        }

        case .World: {
            world_mode_update(game_state, platform_state, renderer_state, delta_time);
        }
    }

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

    game_state.ui_hovered = false;
    draw_debug_windows(game_state, platform_state, renderer_state, logger_state);
    ui.draw_end();

    profiler.profiler_end("game_update");

    // profiler.profiler_print_all();
}

game_fixed_update :: proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^ui.UI_State,
) {
    // log.debugf("game_fixed_update: %v", delta_time);
}

start_game :: proc (game_state: ^Game_State) {
    // Pretend we are loading a save game
    {
        game_state.current_room_index = 4;
        {
            entity := entity_make("Ramza", &game_state.entities);
            game_state.entities.components_position[entity] = entity_make_component_position({ 25, 14 });
            game_state.entities.components_world_info[entity] = Component_World_Info { game_state.current_room_index }
            game_state.entities.components_rendering[entity] = Component_Rendering {
                false, 1, game_state.textures["calm"],
                { 0, 0 }, { 48, 48 },
            };
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
                false, 1, game_state.textures["angry"],
                { 0, 0 }, { 48, 48 },
            };
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

draw_debug_windows :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
) {
    if game_state.debug_ui_window_info {
        if ui_window("Debug", { 0, 0, 360, 740 }) {
            ui_layout_row({ -1 }, 0);
            ui_label(":: Memory");
            ui_layout_row({ 170, -1 }, 0);
            ui_label("app_arena");
            ui_label(format_arena_usage(
                platform_state.arena.offset + renderer_state.arena.offset + game_state.arena.offset,
                len(platform_state.arena.data) + len(renderer_state.arena.data) + len(game_state.arena.data),
            ));
            ui_label("    platform_arena");
            ui_label(format_arena_usage(platform_state.arena));
            ui_label("    renderer_arena");
            ui_label(format_arena_usage(renderer_state.arena));
            ui_label("    game_arena");
            ui_label(format_arena_usage(game_state.arena));
            ui_label("        game_mode_arena");
            ui_label(format_arena_usage(game_state.game_mode_arena));
            if game_state.game_mode == .World {
                world_data := cast(^Game_Mode_World) game_state.game_mode_data;

                if world_data.initialized {
                    ui_label("            world_mode_arena");
                    ui_label(format_arena_usage(world_data.world_mode_arena));
                }
            }

            ui_layout_row({ -1 }, 0);
            ui_label(":: Game");
            ui_layout_row({ 170, -1 }, 0);
            ui_label("version");
            ui_label(game_state.version);
            ui_label("unlock_framerate");
            ui_label(fmt.tprintf("%v", game_state.unlock_framerate));
            ui_label("window_size");
            ui_label(fmt.tprintf("%v", game_state.window_size));
            ui_label("rendering_scale");
            ui_label(fmt.tprintf("%v", game_state.rendering_scale));
            ui_label("draw_letterbox");
            ui_label(fmt.tprintf("%v", game_state.draw_letterbox));
            ui_label("mouse_screen_position");
            ui_label(fmt.tprintf("%v", game_state.mouse_screen_position));
            ui_label("mouse_grid_position");
            ui_label(fmt.tprintf("%v", game_state.mouse_grid_position));
            ui_label("current_room_index");
            ui_label(fmt.tprintf("%v", game_state.current_room_index));
            ui_label("party");
            ui_label(fmt.tprintf("%v", game_state.party));

            ui_layout_row({ -1 }, 0);
            ui_label(":: Renderer");
            ui_layout_row({ 170, -1 }, 0);
            ui_label("update_rate");
            ui_label(fmt.tprintf("%v", platform_state.update_rate));
            ui_label("display_dpi");
            ui_label(fmt.tprintf("%v", renderer_state.display_dpi));
            ui_label("rendering_size");
            ui_label(fmt.tprintf("%v", renderer_state.rendering_size));
            ui_label("rendering_offset");
            ui_label(fmt.tprintf("%v", renderer_state.rendering_offset));
            ui_label("textures");
            ui_label(fmt.tprintf("%v", len(renderer_state.textures)));

            if game_state.game_mode == .World {
                world_data := cast(^Game_Mode_World) game_state.game_mode_data;

                if world_data.initialized {
                    ui_layout_row({ -1 }, 0);
                    ui_label(":: World");
                    ui_layout_row({ 170, -1 }, 0);
                    ui_label("world_mode");
                    ui_label(fmt.tprintf("%v", world_data.world_mode));

                    if world_data.world_mode == .Battle {
                        battle_data := cast(^World_Mode_Battle) world_data.world_mode_data;

                        ui_layout_row({ -1 }, 0);
                        ui_label(":: Battle");
                        ui_layout_row({ 170, -1 }, 0);
                        ui_layout_row({ -1 }, 0);
                        ui_layout_row({ 170, -1 }, 0);
                        ui_label("battle_mode");
                        ui_label(fmt.tprintf("%v", battle_data.battle_mode));
                        ui_label("entities");
                        ui_label(fmt.tprintf("%v", battle_data.entities));
                        ui_label("turn_actor");
                        ui_label(entity_format(battle_data.turn_actor, &game_state.entities));
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
        if ui_window("Logs", { 0, 0, renderer_state.rendering_size.x, height }, { .NO_CLOSE, .NO_RESIZE }) {
            ui_layout_row({ -1 }, -28);

            if logger_state != nil {
                ui_begin_panel("Log");
                ui_layout_row({ -1 }, -1);
                lines := logger.read_all_lines();
                ctx := ui_get_context();
                color := ctx.style.colors[.TEXT];
                for line in lines {
                    height := ctx.text_height(ctx.style.font);
                    RESET     :: ui.Color { 255, 255, 255, 255 };
                    RED       :: ui.Color { 230, 0, 0, 255 };
                    YELLOW    :: ui.Color { 230, 230, 0, 255 };
                    DARK_GREY :: ui.Color { 150, 150, 150, 255 };

                    color := RESET;
                    switch line.level {
                        case .Debug:            color = DARK_GREY;
                        case .Info:             color = RESET;
                        case .Warning:          color = YELLOW;
                        case .Error, .Fatal:    color = RED;
                    }

                    ctx.style.colors[.TEXT] = color;
                    ui_layout_row({ -1 }, height);
                    ui_text(line.text);
                }
                ctx.style.colors[.TEXT] = color;
                if logger_state.buffer_updated {
                    panel := ui_get_current_container();
                    panel.scroll.y = panel.content_size.y;
                    logger_state.buffer_updated = false;
                }
                ui_end_panel();

                @static buf: [128]byte;
                @static buf_len: int;
                submitted := false;
                ui_layout_row({ -70, -1 });
                if .SUBMIT in ui_textbox(buf[:], &buf_len) {
                    ui_set_focus(ctx.last_id);
                    submitted = true;
                }
                if .SUBMIT in ui_button("Submit") {
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
        if ui_window("Entities", { 1240, 0, 360, 640 }) {
            ui_layout_row({ 160, -1 }, 0);
            // ui_label("len(component_name)");
            // ui_label(fmt.tprintf("%v", len(game_state.entities.components_name)));

            ui_layout_row({ 160, -1 }, 0);
            ui_checkbox("Room only", &game_state.debug_ui_room_only)

            ui_layout_row({ 160, -1 }, 0);
            for entity in game_state.entities.entities {
                component_flag, has_flag := game_state.entities.components_flag[entity];
                if has_flag && .Tile in component_flag.value {
                    continue;
                }

                component_world_info, has_world_info := game_state.entities.components_world_info[entity];
                if game_state.debug_ui_room_only && (has_world_info == false || component_world_info.room_index != game_state.current_room_index) {
                    continue;
                }

                ui_push_id_uintptr(uintptr(entity));
                ui_label(fmt.tprintf("%v", entity_format(entity, &game_state.entities)));
                if .SUBMIT in ui_button("Inspect") {
                    game_state.debug_ui_entity = entity;
                }
                ui_pop_id();
            }
        }

        if game_state.debug_ui_entity != 0 {
            entity := game_state.debug_ui_entity;
            if ui_window(fmt.tprintf("Entity %v", entity), { 900, 40, 320, 640 }) {
                component_name, has_name := game_state.entities.components_name[entity];
                if has_name {
                    ui_layout_row({ -1 }, 0);
                    ui_label(":: Component_Name");
                    ui_layout_row({ 120, -1 }, 0);
                    ui_label("name");
                    ui_label(component_name.name);
                }

                component_world_info, has_world_info := game_state.entities.components_world_info[entity];
                if has_world_info {
                    ui_layout_row({ -1 }, 0);
                    ui_label(":: Component_World_Info");
                    ui_layout_row({ 120, -1 }, 0);
                    ui_label("room_index");
                    ui_label(fmt.tprintf("%v", component_world_info.room_index));
                }

                component_position, has_position := game_state.entities.components_position[entity];
                if has_position {
                    ui_layout_row({ -1 }, 0);
                    ui_label(":: Component_Position");
                    ui_layout_row({ 120, -1 }, 0);
                    ui_label("grid_position");
                    ui_label(fmt.tprintf("%v", component_position.grid_position));
                    ui_label("world_position");
                    ui_label(fmt.tprintf("%v", component_position.world_position));
                }

                component_rendering, has_rendering := game_state.entities.components_rendering[entity];
                if has_rendering {
                    ui_layout_row({ -1 }, 0);
                    ui_label(":: Component_Rendering");
                    ui_layout_row({ 120, -1 }, 0);
                    ui_label("visible");
                    ui_label(fmt.tprintf("%v", component_rendering.visible));
                    ui_label("texture_index");
                    ui_label(fmt.tprintf("%v", component_rendering.texture_index));
                    ui_label("texture_position");
                    ui_label(fmt.tprintf("%v", component_rendering.texture_position));
                    ui_label("texture_size");
                    ui_label(fmt.tprintf("%v", component_rendering.texture_size));
                }

                component_animation, has_animation := game_state.entities.components_animation[entity];
                if has_animation {
                    ui_layout_row({ -1 }, 0);
                    ui_label(":: Component_Animation");
                    ui_layout_row({ 120, -1 }, 0);
                    ui_label("current_frame");
                    ui_label(fmt.tprintf("%v", component_animation.current_frame));
                }

                component_flag, has_flag := game_state.entities.components_flag[entity];
                if has_flag {
                    ui_layout_row({ -1 }, 0);
                    ui_label(":: Component_Flag");
                    ui_layout_row({ 120, -1 }, 0);
                    ui_label("value");
                    ui_label(fmt.tprintf("%v", component_flag.value));
                }

                component_battle_info, has_battle_info := game_state.entities.components_battle_info[entity];
                if has_battle_info {
                    ui_layout_row({ -1 }, 0);
                    ui_label(":: Component_Battle_Info");
                    ui_layout_row({ 120, -1 }, 0);
                    ui_label("charge_time");
                    ui_label(fmt.tprintf("%v", component_battle_info.charge_time));
                }
            }
        }
    }
}

run_debug_command :: proc(game_state: ^Game_State, command: string) {
    if command == "load" {
        load_texture("./media/art/placeholder_0.png");
    }

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
