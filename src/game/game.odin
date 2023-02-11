package game

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:runtime"
import "core:strconv"
import "core:strings"
import "core:math"
import "core:math/linalg"

import platform "../engine/platform"
import renderer "../engine/renderer"
import ui "../engine/renderer/ui"
import logger "../engine/logger"
import emath "../engine/math"
import ldtk "../engine/ldtk"

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
NATIVE_RESOLUTION       :: Vector2i { 320, 180 };
CLEAR_COLOR             :: Color { 255, 0, 255, 255 }; // This is supposed to never show up, so it's a super flashy color. If you see it, something is broken.
VOID_COLOR              :: Color { 100, 100, 100, 255 };
WINDOW_BORDER_COLOR     :: Color { 0, 0, 0, 255 };
LETTERBOX_COLOR         :: Color { 0, 0, 0, 255 };
LETTERBOX_TOP           := Rect { 0, 0, 320, 18 };
LETTERBOX_BOTTOM        := Rect { 0, 162, 320, 18 };
LETTERBOX_LEFT          := Rect { 0, 0, 40, 180 };
LETTERBOX_RIGHT         := Rect { 280, 0, 40, 180 };

Color :: renderer.Color;
Rect :: renderer.Rect;
array_cast :: linalg.array_cast;
Vector2f32 :: linalg.Vector2f32;
Vector2i :: emath.Vector2i;

Game_State :: struct {
    game_mode:              Game_Mode,
    game_mode_arena:        ^mem.Arena,
    game_mode_allocator:    mem.Allocator,
    title_mode:             ^Title_Mode,
    world_mode:             ^World_Mode,

    unlock_framerate:       bool,
    window_size:            Vector2i,
    rendering_scale:        i32,
    draw_letterbox:         bool,

    show_menu_1:            bool,
    show_menu_2:            bool,

    ldtk:                   ldtk.LDTK,
    world:                  World,
    version:                string,
    texture_room:           int,
    texture_placeholder:    int,
    texture_hero0:          int,
    texture_hero1:          int,

    camera_zoom:            f32,
    camera_position:        Vector2f32,

    party:                  [dynamic]Entity,
    entities:               [dynamic]Entity,
    components_name:        map[Entity]Component_Name,
    components_position:    map[Entity]Component_Position,
    components_rendering:   map[Entity]Component_Rendering,
}

Game_Mode :: enum {
    Init,
    Title,
    World,
}

Title_Mode :: struct {
    initialized:        bool,
    some_stuff:         []u8,
}

Entity :: distinct i32;

Component_Name :: struct {
    name:               string,
}

Component_Position :: struct {
    grid_position:      Vector2i,
    world_position:     Vector2f32,
    move_origin:        Vector2f32,
    move_destination:   Vector2f32,
    move_t:             f32,
}

Component_Rendering :: struct {
    visible:            bool,
    texture_index:      int,
    texture_position:   Vector2i,
    texture_size:       Vector2i,
}

World :: struct {
    size:               Vector2i,
    rooms:              []Room,
    entities:           map[i32]ldtk.Entity,
}

Room :: struct {
    id:                 i32,
    size:               Vector2i,
    grid:               [ROOM_LEN]i32,
    tiles:              map[int]ldtk.Tile,
    entities:           []ldtk.EntityInstance,
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

    if platform_state.inputs[.F1].released {
        game_state.show_menu_1 = !game_state.show_menu_1;
    }
    if platform_state.inputs[.F2].released {
        game_state.show_menu_2 = !game_state.show_menu_2;
    }
    if platform_state.inputs[.F3].released {
        game_state.draw_letterbox = !game_state.draw_letterbox;
    }

    switch game_state.game_mode {
        case .Init: {
            // game_state.unlock_framerate = true;
            game_state.version = string(#load("../version.txt") or_else "000000");
            game_state.show_menu_1 = false;
            game_state.show_menu_2 = false;
            {
                game_state.game_mode_arena = new(mem.Arena, arena_allocator);
                buffer := make([]u8, GAME_MODE_ARENA_SIZE, arena_allocator);
                mem.arena_init(game_state.game_mode_arena, buffer);
                game_state.game_mode_allocator = new(mem.Allocator, arena_allocator)^;
                game_state.game_mode_allocator.procedure = platform.arena_allocator_proc;
                game_state.game_mode_allocator.data = game_state.game_mode_arena;
            }

            _, game_state.texture_placeholder, _ = load_texture("./media/art/placeholder_0.png");
            _, game_state.texture_room, _        = load_texture("./media/art/autotile_placeholder.png");
            renderer.debug_texture, game_state.texture_hero0, _       = load_texture("./media/art/hero0.png");
            _, game_state.texture_hero1, _       = load_texture("./media/art/hero1.png");
            // load_texture("./screenshots/screenshot_1673615737.bmp");

            set_game_mode(game_state, .Title);
            game_state.title_mode = new(Title_Mode, game_state.game_mode_allocator);
        }

        case .Title: {
            if game_state.title_mode.initialized == false {
                game_state.title_mode.initialized = true;
                game_state.title_mode.some_stuff = make([]u8, 100, game_state.game_mode_allocator);
            }

            if platform_state.inputs[.SPACE].released {
                start_game(game_state);
            }
        }

        case .World: {
            world_mode_update(game_state, platform_state, renderer_state, logger_state, ui_state, delta_time);
        }
    }

    for entity in game_state.entities {
        position_component, has_position := &game_state.components_position[entity];

        if has_position && position_component.world_position != position_component.move_destination {
            position_component.move_t = clamp(position_component.move_t + f32(delta_time), 0, 1);
            position_component.world_position = linalg.lerp(position_component.move_origin, position_component.move_destination, position_component.move_t);
            // log.debugf("move entity: %v | %v -> %v", entity, position_component.world_position, position_component.move_destination);
            if position_component.move_t >= 1 {
                position_component.move_t = 0;
            }
        }
    }
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
}

render :: proc(
    arena_allocator: runtime.Allocator,
    delta_time: f64,
    game_state: ^Game_State,
    platform_state: ^platform.Platform_State,
    renderer_state: ^renderer.Renderer_State,
    logger_state: ^logger.Logger_State,
    ui_state: ^ui.UI_State,
) {
    // log.debugf("render: %v", delta_time);

    if platform_state.window_resized {
        game_state.window_size = platform.get_window_size(platform_state.window);
        if game_state.window_size.x > game_state.window_size.y {
            game_state.rendering_scale = i32(f32(game_state.window_size.y) / f32(NATIVE_RESOLUTION.y));
        } else {
            game_state.rendering_scale = i32(f32(game_state.window_size.x) / f32(NATIVE_RESOLUTION.x));
        }
        renderer_state.display_dpi = renderer.get_display_dpi(platform_state.window);
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
        log.debugf("display_dpi:     %v", renderer_state.display_dpi);
        log.debugf("rendering_scale: %v", game_state.rendering_scale);
        log.debugf("window_size:     %v", game_state.window_size);
        log.debugf("rendering_size:  %v", renderer_state.rendering_size);
        log.debugf("rendering_offset:%v", renderer_state.rendering_offset);
    }

    renderer.clear(CLEAR_COLOR);

    renderer.draw_fill_rect(&{ 0, 0, game_state.window_size.x, game_state.window_size.y }, VOID_COLOR);

    for room, room_index in game_state.world.rooms {
        room_position := emath.grid_index_to_position(i32(room_index), game_state.world.size.x);

        for cell_value, cell_index in room.grid {
            cell_position := emath.grid_index_to_position(i32(cell_index), room.size.x);
            source_position := emath.grid_index_to_position(cell_value, SPRITE_GRID_WIDTH);
            tile, ok := room.tiles[cell_index];
            if ok {
                cell_global_position := (room_position * room.size + cell_position);
                source := renderer.Rect { tile.src[0], tile.src[1], SPRITE_GRID_SIZE, SPRITE_GRID_SIZE };
                destination := renderer.Rect {
                    (cell_global_position.x * PIXEL_PER_CELL) - i32(game_state.camera_position.x),
                    (cell_global_position.y * PIXEL_PER_CELL) - i32(game_state.camera_position.y),
                    PIXEL_PER_CELL,
                    PIXEL_PER_CELL,
                };
                renderer.draw_texture_by_index(game_state.texture_room, &source, &destination, f32(game_state.rendering_scale));
            }
        }
    }

    for entity in game_state.entities {
        position_component, has_position := game_state.components_position[entity];

        rendering_component, has_rendering := game_state.components_rendering[entity];
        if has_rendering && rendering_component.visible && has_position {
            source := renderer.Rect {
                rendering_component.texture_position.x, rendering_component.texture_position.y,
                rendering_component.texture_size.x, rendering_component.texture_size.y,
            };
            destination := renderer.Rect {
                i32(math.round(position_component.world_position.x * f32(PIXEL_PER_CELL) - game_state.camera_position.x)),
                i32(math.round(position_component.world_position.y * f32(PIXEL_PER_CELL) - game_state.camera_position.y)),
                PIXEL_PER_CELL,
                PIXEL_PER_CELL,
            };
            if destination.y == 81 {
                log.debugf("position_component.world_position.y: %v", position_component.world_position.y);
            }
            renderer.draw_texture_by_index(rendering_component.texture_index, &source, &destination, f32(game_state.rendering_scale));
        }
    }
    // log.debugf("game_state.camera_position: %v", game_state.camera_position);

    // Draw the letterboxes on top of the world
    if game_state.draw_letterbox {
        renderer.draw_fill_rect(&LETTERBOX_TOP, LETTERBOX_COLOR, f32(game_state.rendering_scale));
        renderer.draw_fill_rect(&LETTERBOX_BOTTOM, LETTERBOX_COLOR, f32(game_state.rendering_scale));
        renderer.draw_fill_rect(&LETTERBOX_LEFT, LETTERBOX_COLOR, f32(game_state.rendering_scale));
        renderer.draw_fill_rect(&LETTERBOX_RIGHT, LETTERBOX_COLOR, f32(game_state.rendering_scale));
    }

    ui.draw_begin();
    draw_debug_windows(game_state, platform_state, renderer_state, logger_state, ui_state, cast(^mem.Arena)arena_allocator.data);
    if game_state.game_mode == .Title {
        draw_title_menu(game_state, platform_state, renderer_state, logger_state, ui_state, cast(^mem.Arena)arena_allocator.data);
    }
    ui.draw_end();
    ui.process_ui_commands();

    renderer.draw_window_border(game_state.window_size, WINDOW_BORDER_COLOR);

    renderer.present();
}

start_game :: proc (game_state: ^Game_State) {
    set_game_mode(game_state, .World);
    game_state.world_mode = new(World_Mode, game_state.game_mode_allocator);
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

load_texture :: proc(path: string) -> (texture: ^renderer.Texture, texture_index : int = -1, ok: bool) {
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

run_command :: proc(game_state: ^Game_State, command: string) {
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
            make_entity_visible(game_state, entity);
            log.debugf("%v added to the party.", format_entity(game_state, entity));
        }
    }
}

make_entity :: proc(game_state: ^Game_State, name: string) -> Entity {
    entity := Entity(len(game_state.entities) + 1);
    append(&game_state.entities, entity);
    game_state.components_name[entity] = Component_Name { name };
    log.debugf("Entity created: %v", format_entity(game_state, entity));
    return entity;
}

format_entity :: proc(game_state: ^Game_State, entity: Entity) -> string {
    name := game_state.components_name[entity].name;
    return fmt.tprintf("Entity (%v)", name);
}

add_to_party :: proc(game_state: ^Game_State, entity: Entity) {
    append(&game_state.party, entity);
}

make_entity_visible :: proc(game_state: ^Game_State, entity: Entity) {
    (&game_state.components_rendering[entity]).visible = true;
}

set_game_mode :: proc(game_state: ^Game_State, mode: Game_Mode) {
    log.debugf("game_mode changed %v -> %v", game_state.game_mode, mode);
    // TODO: clear mode_arena
    game_state.game_mode = mode;
    free_all(game_state.game_mode_allocator);
}
