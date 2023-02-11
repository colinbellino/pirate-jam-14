package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:strconv"
import "core:strings"

import platform "engine/platform"
import logger "engine/logger"
import renderer "engine/renderer"
import ui "engine/renderer/ui"
import ldtk "engine/ldtk"
import math "engine/math"
import memory "memory"

Color :: renderer.Color;

ARENA_SIZE_PLATFORM     :: 64 * mem.Megabyte;
ARENA_SIZE_MAIN         :: 8 * mem.Megabyte;
ARENA_SIZE_FRAME        :: 8 * mem.Megabyte;
ARENA_SIZE_APP          :: ARENA_SIZE_PLATFORM + ARENA_SIZE_MAIN + ARENA_SIZE_FRAME;
ROOMS_PATH              :: "./media/levels/rooms.ldtk";
ROOM_SIZE               :: math.Vector2i { 15, 9 };
ROOM_LEN                :: ROOM_SIZE.x * ROOM_SIZE.y;
ROOM_PREFIX             :: "Room_";
LDTK_GRID_LAYER_INDEX   :: 1;
PIXEL_PER_CELL          :: 32;
SPRITE_GRID_SIZE        :: 16;
SPRITE_GRID_WIDTH       :: 4;
PLAYER_SPRITE_SIZE      :: 32;

App :: struct {
    arena:              mem.Arena,

    platform:           ^platform.State,
    logger:             ^logger.State,
    renderer:           ^renderer.State,
    ui:                 ^ui.State,
    game:               ^State,
}

State :: struct {
    bg_color:               Color,
    version:                string,
    window_width:           i32,
    window_height:          i32,
    ldtk:                   ldtk.LDTK,
    world:                  World,
    show_menu_1:            bool,
    show_menu_2:            bool,
    show_menu_3:            bool,
    texture_room:           int,
    texture_placeholder:    int,
    texture_player0:        int,
    player_position:        math.Vector2i,
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

app : App;

main :: proc() {
    app_allocator := mem.Allocator { allocator_proc, nil };
    app_tracking_allocator : mem.Tracking_Allocator;
    mem.tracking_allocator_init(&app_tracking_allocator, app_allocator);
    app_allocator = mem.tracking_allocator(&app_tracking_allocator);
    context.allocator = app_allocator;

    logger_allocator := mem.Allocator { logger.allocator_proc, nil };
    app.logger = logger.create_logger(logger_allocator);
    context.logger = app.logger.logger;

    app.arena = mem.Arena {};
    {
        buffer := make([]u8, ARENA_SIZE_APP);
        mem.arena_init(&app.arena, buffer);
    }
    arena_allocator := mem.Allocator { arena_allocator_proc, &app.arena };
    context.allocator = arena_allocator;

    app.game = new(State);
    app.game.bg_color = { 90, 95, 100, 255 };
    app.game.version = "000000";
    app.game.window_width = 1920;
    app.game.window_height = 1080;
    app.game.show_menu_1 = true;
    app.game.show_menu_2 = false;
    app.game.show_menu_3 = true;

    platform_ok: bool;
    // platform_allocator := mem.Allocator { platform.allocator_proc, nil };
    platform_allocator := arena_allocator;
    app.platform, platform_ok = platform.init(platform_allocator);
    if platform_ok == false {
        log.error("Couldn't platform.init correctly.");
        return;
    }
    app.platform.input_mouse_move = input_mouse_move;
    app.platform.input_mouse_down = input_mouse_down;
    app.platform.input_mouse_up = input_mouse_up;
    app.platform.input_text = input_text;
    app.platform.input_scroll = input_scroll;
    app.platform.input_key_down = input_key_down;
    app.platform.input_key_up = input_key_up;

    open_ok := platform.open_window("Tactics", app.game.window_width, app.game.window_height);
    if open_ok == false {
        log.error("Couldn't platform.open_window correctly.");
        return;
    }

    renderer_ok: bool;
    // renderer_allocator := mem.Allocator { renderer.allocator_proc, nil };
    renderer_allocator := arena_allocator;
    app.renderer, renderer_ok = renderer.init(app.platform.window, renderer_allocator);
    if renderer_ok == false {
        log.error("Couldn't renderer.init correctly.");
        return;
    }

    ui_ok: bool;
    app.ui, ui_ok = ui.init(renderer_allocator);
    if ui_ok == false {
        log.error("Couldn't ui.init correctly.");
        return;
    }

    app.game.version = string(#load("../version.txt") or_else "000000");

    {
        ldtk, ok := ldtk.load_file(ROOMS_PATH, app_allocator);
        log.infof("Level %v loaded: %s (%s)", ROOMS_PATH, ldtk.iid, ldtk.jsonVersion);
        app.game.ldtk = ldtk;
    }

    app.game.world = make_world(
        { 3, 3 },
        ROOM_SIZE,
        {
            6, 2, 7,
            5, 1, 3,
            9, 4, 8,
        }, &app.game.ldtk,
    );
    // log.debugf("LDTK: %v", app.game.ldtk);
    // log.debugf("World: %v", app.game.world);

    app.game.player_position = { 22, 13 };

    _, app.game.texture_placeholder, _ = load_texture("./media/art/placeholder_0.png");
    _, app.game.texture_room, _        = load_texture("./media/art/autotile_placeholder.png");
    _, app.game.texture_player0, _     = load_texture("./media/art/hero0.png");
    // load_texture("./screenshots/screenshot_1673615737.bmp");

    frame_count := 0;
    for app.platform.quit == false {
        // log.debugf("frame: %v", frame_count);
        platform.process_events();

        if (app.platform.inputs[.F1].released) {
            app.game.show_menu_1 = !app.game.show_menu_1;
        }
        if (app.platform.inputs[.F2].released) {
            app.game.show_menu_2 = !app.game.show_menu_2;
        }
        if (app.platform.inputs[.F3].released) {
            app.game.show_menu_3 = !app.game.show_menu_3;
        }

        if (app.platform.inputs[.F12].released) {
            renderer.take_screenshot(app.platform.window);
        }

        {
            move_input := math.Vector2i {};
            if (app.platform.inputs[.UP].released) {
                move_input.y -= 1;
            } else if (app.platform.inputs[.DOWN].released) {
                move_input.y += 1;
            } else if (app.platform.inputs[.LEFT].released) {
                move_input.x -= 1;
            } else if (app.platform.inputs[.RIGHT].released) {
                move_input.x += 1;
            }
            app.game.player_position += move_input;
        }

        renderer.clear(app.game.bg_color);

        for room, room_index in app.game.world.rooms {
            room_position := math.grid_index_to_position(i32(room_index), app.game.world.size.x);
            // log.debugf("room: %v", room.size);

            for cell_value, cell_index in room.grid {
                cell_position := math.grid_index_to_position(i32(cell_index), room.size.x);
                source_position := math.grid_index_to_position(cell_value, SPRITE_GRID_WIDTH);
                tile, ok := room.tiles[cell_index];
                if ok {
                    destination_rect := renderer.Rect{
                        (room_position.x * room.size.x + cell_position.x) * PIXEL_PER_CELL,
                        (room_position.y * room.size.y + cell_position.y) * PIXEL_PER_CELL,
                        PIXEL_PER_CELL,
                        PIXEL_PER_CELL,
                    };
                    source_rect := renderer.Rect{
                        tile.src[0], tile.src[1],
                        SPRITE_GRID_SIZE, SPRITE_GRID_SIZE,
                    };
                    renderer.draw_texture_by_index(app.game.texture_room, &source_rect, &destination_rect);
                }
            }
        }

        {
            destination_rect := renderer.Rect{
                app.game.player_position.x * PIXEL_PER_CELL,
                app.game.player_position.y * PIXEL_PER_CELL,
                PIXEL_PER_CELL,
                PIXEL_PER_CELL,
            };
            source_rect := renderer.Rect{
                0, 0,
                PLAYER_SPRITE_SIZE, PLAYER_SPRITE_SIZE,
            };
            renderer.draw_texture_by_index(app.game.texture_player0, &source_rect, &destination_rect);
        }

        ui.draw_begin();
        ui_draw_debug_window();
        ui.draw_end();

        ui.process_ui_commands(app.renderer.renderer);

        renderer.present();

    //     free_all(frame_allocator);

    //     for _, leak in frame_track.allocation_map {
    //         log.warnf("Leaked %v bytes at %v.", leak.size, leak.location);
    //     }
    //     for bad_free in frame_track.bad_free_array {
    //         log.warnf("Allocation %p was freed badly at %v.", bad_free.location, bad_free.memory);
    //     }

        frame_count += 1;
    }

    // renderer.quit();
    // platform.close_window();
    // platform.quit();

    log.debug("Quitting...");

    // free_all(context.allocator);

    // for _, leak in app_tracking_allocator.allocation_map {
    //     log.warnf("Leaked %v bytes at %v.", leak.size, leak.location);
    // }
    // for bad_free in app_tracking_allocator.bad_free_array {
    //     log.warnf("Allocation %p was freed badly at %v.", bad_free.location, bad_free.memory);
    // }
}

allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    if slice.contains(os.args, "show-alloc") {
        fmt.printf("[TACTICS] %v %v byte at %v\n", mode, size, location);
    }
    result, error = runtime.default_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    if error > .None {
        fmt.eprintf("[TACTICS] alloc error %v\n", error);
        os.exit(0);
    }
    return;
}

ui_draw_debug_window :: proc() {
    ctx := &app.ui.ctx;

    if app.game.show_menu_1 {
        if ui.window(ctx, "Debug", {40, 40, 320, 640}) {
            ui.layout_row(ctx, {80, -1}, 0);
            ui.label(ctx, "App:");
            ui.label(ctx, format_arena_usage(&app.arena));
            // ui.label(ctx, "Platform:");
            // ui.label(ctx, format_arena_usage(app.platform_arena));
            // ui.label(ctx, "Main:");
            // ui.label(ctx, format_arena_usage(app.main_arena));
            // ui.label(ctx, "Frame:");
            // ui.label(ctx, format_arena_usage(app.frame_arena));
            ui.label(ctx, "Player:");
            ui.label(ctx, fmt.tprintf("%v", app.game.player_position));
            ui.label(ctx, "Textures:");
            ui.label(ctx, fmt.tprintf("%v", len(app.renderer.textures)));
            ui.label(ctx, "Version:");
            ui.label(ctx, app.game.version);
        }
    }

    if app.game.show_menu_2 {
        if ui.window(ctx, "Shortcuts", {40, 250, 320, 200}) {
            ui.layout_row(ctx, {80, -1}, 0);
            ui.label(ctx, "Screenshot:");
            ui.label(ctx, "F12");
        }
    }

    if app.game.show_menu_3 {
        if ui.window(ctx, "Logs", {370, 40, 1000, 300}) {
            ui.layout_row(ctx, {-1}, -28);
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
            if app.logger.buffer_updated {
                panel := ui.get_current_container(ctx);
                panel.scroll.y = panel.content_size.y;
                app.logger.buffer_updated = false;
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
                run_command(str);
            }
        }
    }
}

make_world :: proc(world_size: math.Vector2i, ROOM_SIZE: math.Vector2i, room_ids: []i32, data: ^ldtk.LDTK, allocator: runtime.Allocator = context.allocator) -> World {
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

        room_size := math.Vector2i {
            level.pxWid / layer.gridSize,
            level.pxHei / layer.gridSize,
        };

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
            index := math.grid_position_to_index(position, room_size.x);
            tiles[int(index)] = tile;
        }

        world.rooms[room_index] = Room { id, room_size, grid, tiles };
    }
    return world;
}

input_mouse_move :: proc(x: i32, y: i32) {
    // log.debugf("mouse_move: %v,%v", x, y);
    ui.input_mouse_move(x, y);
}
input_mouse_down :: proc(x: i32, y: i32, button: u8) {
    switch button {
        case platform.BUTTON_LEFT:   ui.input_mouse_down(x, y, .LEFT);
        case platform.BUTTON_MIDDLE: ui.input_mouse_down(x, y, .MIDDLE);
        case platform.BUTTON_RIGHT:  ui.input_mouse_down(x, y, .RIGHT);
    }
}
input_mouse_up :: proc(x: i32, y: i32, button: u8) {
    switch button {
        case platform.BUTTON_LEFT:   ui.input_mouse_up(x, y, .LEFT);
        case platform.BUTTON_MIDDLE: ui.input_mouse_up(x, y, .MIDDLE);
        case platform.BUTTON_RIGHT:  ui.input_mouse_up(x, y, .RIGHT);
    }
}
input_text :: ui.input_text;
input_scroll :: ui.input_scroll;
input_key_down :: proc(keycode: platform.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    ui.input_key_down(.SHIFT);
        case .RSHIFT:    ui.input_key_down(.SHIFT);
        case .LCTRL:     ui.input_key_down(.CTRL);
        case .RCTRL:     ui.input_key_down(.CTRL);
        case .LALT:      ui.input_key_down(.ALT);
        case .RALT:      ui.input_key_down(.ALT);
        case .RETURN:    ui.input_key_down(.RETURN);
        case .KP_ENTER:  ui.input_key_down(.RETURN);
        case .BACKSPACE: ui.input_key_down(.BACKSPACE);
    }
}
input_key_up :: proc(keycode: platform.Keycode) {
    #partial switch keycode {
        case .LSHIFT:    ui.input_key_up(.SHIFT);
        case .RSHIFT:    ui.input_key_up(.SHIFT);
        case .LCTRL:     ui.input_key_up(.CTRL);
        case .RCTRL:     ui.input_key_up(.CTRL);
        case .LALT:      ui.input_key_up(.ALT);
        case .RALT:      ui.input_key_up(.ALT);
        case .RETURN:    ui.input_key_up(.RETURN);
        case .KP_ENTER:  ui.input_key_up(.RETURN);
        case .BACKSPACE: ui.input_key_up(.BACKSPACE);
    }
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

run_command :: proc(command: string) {
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

format_arena_usage :: proc{
    format_arena_usage_static,
    format_arena_usage_virtual,
}

arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (result: []byte, error: mem.Allocator_Error) {
    result, error = mem.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    if error > .None {
        // fmt.eprintf("[ARENA] ERROR: %v %v byte at %v -> %v\n", mode, size, location, error);
        // os.exit(0);
    }else {
        if slice.contains(os.args, "show-alloc") {
            fmt.printf("[ARENA] %v %v byte at %v -> %v\n", mode, size, location, format_arena_usage(&app.arena));
        }
    }
    return;
}
