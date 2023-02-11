package game

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:runtime"
import "core:strconv"
import "core:strings"
import "core:math/linalg"

import platform "../engine/platform"
import renderer "../engine/renderer"
import ui "../engine/renderer/ui"
import logger "../engine/logger"
import math "../engine/math"
import ldtk "../engine/ldtk"

APP_ARENA_PATH          :: "./arena.mem";
APP_ARENA_PATH2         :: "./arena2.mem";
GAME_MODE_ARENA_SIZE    :: 1 * mem.Megabyte;
ROOMS_PATH              :: "./media/levels/rooms.ldtk";
ROOM_SIZE               :: math.Vector2i { 15, 9 };
ROOM_LEN                :: ROOM_SIZE.x * ROOM_SIZE.y;
ROOM_PREFIX             :: "Room_";
LDTK_GRID_LAYER_INDEX   :: 1;
PIXEL_PER_CELL          :: 16;
SPRITE_GRID_SIZE        :: 16;
SPRITE_GRID_WIDTH       :: 4;
PLAYER_SPRITE_SIZE      :: 32;
NATIVE_RESOLUTION       :: math.Vector2i { 320, 180 };
LETTERBOX_TOP           := Rect { 0, 0, 320, 18 };
LETTERBOX_BOTTOM        := Rect { 0, 162, 320, 18 };
LETTERBOX_LEFT          := Rect { 0, 0, 40, 180 };
LETTERBOX_RIGHT         := Rect { 280, 0, 40, 180 };
LETTERBOX_COLOR         :: Color { 0, 0, 0, 255 };

Color :: renderer.Color;
Rect :: renderer.Rect;

Game_State :: struct {
    game_mode:              Game_Mode,
    game_mode_arena:        ^mem.Arena,
    game_mode_allocator:    mem.Allocator,
    title_mode:             ^Title_Mode,
    world_mode:             ^World_Mode,
    camera_zoom:            f32,
    camera_position:        linalg.Vector2f32,
    rendering_scale:        f32,
    display_dpi:            f32,
    bg_color:               Color,
    window_size:            math.Vector2i,
    show_menu_1:            bool,
    show_menu_2:            bool,
    texture_room:           int,
    texture_placeholder:    int,
    texture_hero0:          int,
    texture_hero1:          int,
    version:                string,
    ldtk:                   ldtk.LDTK,
    world:                  World,
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

World_Mode :: struct {
    initialized:        bool,
}

Entity :: distinct i32;

Component_Name :: struct {
    name:               string,
}

Component_Position :: struct {
    position:           math.Vector2i,
}

Component_Rendering :: struct {
    visible:            bool,
    texture:            int,
}

World :: struct {
    size:               math.Vector2i,
    rooms:              []Room,
}

Room :: struct {
    id:                 i32,
    size:               math.Vector2i,
    grid:               [ROOM_LEN]i32,
    tiles:              map[int]ldtk.Tile,
}

update_and_render :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.State,
    renderer_state: ^renderer.State,
    logger_state: ^logger.State,
    ui_state: ^ui.State,
    arena_allocator: runtime.Allocator,
) {
    if platform_state.window_resized {
        window_size := platform.get_window_size(platform_state.window);
        game_state.rendering_scale = f32(window_size.y) / f32(NATIVE_RESOLUTION.y);
        game_state.display_dpi = renderer.get_display_dpi(platform_state.window);
        // FIXME: handle different resolution ratio (16/9, 16/10, etc)
        log.debugf("window_size:     %v", window_size);
        log.debugf("rendering_scale: %v", game_state.rendering_scale);
        log.debugf("display_dpi:     %v", game_state.display_dpi);
    }

    if (platform_state.inputs[.F1].released) {
        game_state.show_menu_1 = !game_state.show_menu_1;
    }
    if (platform_state.inputs[.F2].released) {
        game_state.show_menu_2 = !game_state.show_menu_2;
    }

    renderer.clear(game_state.bg_color);

    switch game_state.game_mode {
        case .Init: {
            game_state.bg_color = { 90, 95, 100, 255 };
            game_state.version = string(#load("../version.txt") or_else "000000");
            game_state.show_menu_1 = true;
            game_state.show_menu_2 = true;
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
            _, game_state.texture_hero0, _       = load_texture("./media/art/hero0.png");
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
            world_mode_update_and_render(game_state, platform_state, renderer_state, logger_state, ui_state);
        }
    }

    ui.draw_begin();
    draw_debug_windows(game_state, platform_state, renderer_state, logger_state, ui_state, cast(^mem.Arena)arena_allocator.data);
    ui.draw_end();
    ui.process_ui_commands(renderer_state.renderer, game_state.display_dpi);

    renderer.present();
}

draw_debug_windows :: proc(
    game_state: ^Game_State,
    platform_state: ^platform.State,
    renderer_state: ^renderer.State,
    logger_state: ^logger.State,
    ui_state: ^ui.State,
    app_arena: ^mem.Arena,
) {
    ctx := &ui_state.ctx;

    if game_state.show_menu_1 {
        if ui.window(ctx, "Debug", {40, 40, 320, 640}) {
            ui.layout_row(ctx, {80, -1}, 0);
            ui.label(ctx, "App arena:");
            ui.label(ctx, format_arena_usage(app_arena));
            ui.label(ctx, "Game mode:");
            ui.label(ctx, format_arena_usage(game_state.game_mode_arena));
            ui.label(ctx, "Textures:");
            ui.label(ctx, fmt.tprintf("%v", len(renderer_state.textures)));
            ui.label(ctx, "Version:");
            ui.label(ctx, game_state.version);
            ui.label(ctx, "Party:");
            ui.label(ctx, fmt.tprintf("%v", game_state.party));
            ui.layout_row(ctx, {80, 80, -1}, 0);
            for entity in game_state.entities {
                ui.push_id_uintptr(ctx, uintptr(entity));
                ui.label(ctx, fmt.tprintf("%v", format_entity(game_state, entity)));
                ui.label(ctx, fmt.tprintf("%v", game_state.components_position[entity].position));
                if .SUBMIT in ui.button(ctx, "Recruit") {
                    add_to_party(game_state, entity);
                    make_entity_visible(game_state, entity);
                }
                ui.pop_id(ctx);
            }
        }
    }

    if game_state.show_menu_2 {
        if ui.window(ctx, "Logs", {370, 40, 1000, 300}) {
            ui.layout_row(ctx, {-1}, -28);

            if logger_state != nil {
                ui.begin_panel(ctx, "Log");
                ui.layout_row(ctx, {-1}, -1);
                lines := logger.read_all_lines();
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
                    ui.layout_row(ctx, {-1}, height);
                    ui.text(ctx, line.text);
                }
                ctx.style.colors[.TEXT] = color;
                if logger_state.buffer_updated {
                    panel := ui.get_current_container(ctx);
                    panel.scroll.y = panel.content_size.y;
                    logger_state.buffer_updated = false;
                }
                ui.end_panel(ctx);

                @static buf: [128]byte;
                @static buf_len: int;
                submitted := false;
                ui.layout_row(ctx, {-70, -1});
                if .SUBMIT in ui.textbox(ctx, buf[:], &buf_len) {
                    ui.set_focus(ctx, ctx.last_id);
                    submitted = true;
                }
                if .SUBMIT in ui.button(ctx, "Submit") {
                    submitted = true;
                }
                if submitted {
                    str := string(buf[:buf_len]);
                    log.debug(str);
                    buf_len = 0;
                    run_command(game_state, str);
                }
            }
        }
    }

    if game_state.game_mode == .Title {
        if ui.window(ctx, "Title", {600, 400, 320, 320}) {
            if .SUBMIT in ui.button(ctx, "Start") {
                start_game(game_state);
            }
            if .SUBMIT in ui.button(ctx, "Quit") {
                quit_game(platform_state);
            }
        }
    }
}

start_game :: proc (game_state: ^Game_State) {
    set_game_mode(game_state, .World);
    game_state.world_mode = new(World_Mode, game_state.game_mode_allocator);
}

quit_game :: proc (platform_state: ^platform.State) {
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

make_world :: proc(world_size: math.Vector2i, room_ids: []i32, data: ^ldtk.LDTK, allocator: runtime.Allocator = context.allocator) -> World {
    context.allocator = allocator;

    rooms := make([]Room, world_size.x * world_size.y);
    world := World {};
    world.size = math.Vector2i { world_size.x, world_size.y };
    world.rooms = rooms;

    for room_index := 0; room_index < len(room_ids); room_index += 1 {
        id := room_ids[room_index];

        level_index := -1;
        for level, i in data.levels {
            parts := strings.split(level.identifier, ROOM_PREFIX);
            if len(parts) > 0 {
                parsed_id, ok := strconv.parse_int(parts[1]);
                if ok && i32(parsed_id) == id {
                    level_index = i;
                    break;
                }
            }
        }
        assert(level_index > -1, fmt.tprintf("Can't find level with identifier: %v%v", ROOM_PREFIX, id));

        level := data.levels[level_index];
        layer_instance := level.layerInstances[LDTK_GRID_LAYER_INDEX];

        layer_index := -1;
        for layer, i in data.defs.layers {
            if layer.uid == layer_instance.layerDefUid {
                layer_index = i;
                break;
            }
        }
        assert(layer_index > -1, fmt.tprintf("Can't find layer with uid: %v", layer_instance.layerDefUid));

        layer := data.defs.layers[layer_index];

        // room_size := math.Vector2i {
        //     level.pxWid / layer.gridSize,
        //     level.pxHei / layer.gridSize,
        // };

        grid := [ROOM_LEN]i32 {};
        for value, i in layer_instance.intGridCsv {
            grid[i] = value;
        }

        tiles := make(map[int]ldtk.Tile, len(layer_instance.autoLayerTiles));
        for tile, i in layer_instance.autoLayerTiles {
            position := math.Vector2i {
                tile.px.x / layer.gridSize,
                tile.px.y / layer.gridSize,
            };
            index := math.grid_position_to_index(position, ROOM_SIZE.x);
            tiles[int(index)] = tile;
        }

        world.rooms[room_index] = Room { id, ROOM_SIZE, grid, tiles };
    }
    return world;
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

    log.debugf("Load texture: %v", path);
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
        id, error := strconv.parse_int(parts[1]);
        entity := Entity(id);
        add_to_party(game_state, entity);
        make_entity_visible(game_state, entity);
        log.debugf("%v added to the party.", format_entity(game_state, entity));
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
