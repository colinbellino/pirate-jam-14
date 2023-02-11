package main

import "core:fmt"
import "core:mem"
import "core:log"
import "core:mem/virtual"
import "core:strings"
import "core:strconv"

import "vendor:sdl2" // FIXME: remove

import platform "engine/platform"
import logger "engine/logger"
import renderer "engine/renderer"
import ui "engine/renderer/ui"
import ldtk "engine/ldtk"
import math "engine/math"

Color :: renderer.Color;

rooms_path              :: "./media/levels/rooms.ldtk";
room_size               :: math.Vector2i { 15, 9 };
room_len                :: room_size.x * room_size.y;
ldtk_grid_layer_index   :: 1;
pixel_per_cell          :: 32;
sprite_grid_size        :: 32;
sprite_grid_width       :: 4;
arena_size_platform     :: 64 * mem.Megabyte;
arena_size_main         :: 8 * mem.Megabyte;
arena_size_frame        :: 8 * mem.Megabyte;
arena_size_app          :: arena_size_platform + arena_size_main + arena_size_frame;

App :: struct {
    platform_arena:     virtual.Arena,
    main_arena:         virtual.Arena,
    frame_arena:        virtual.Arena,

    platform:           platform.State,
    logger:             logger.State,
    renderer:           renderer.State,
    ui:                 ui.State,
    game:               State,
}

State :: struct {
    bg_color:           Color,
    version:            string,
    window_width:       i32,
    window_height:      i32,
    ldtk:               ldtk.LDTK,
    world:              World,
    show_menu_1:        bool,
    show_menu_2:        bool,
    show_menu_3:        bool,
}

World :: struct {
    size:               math.Vector2i,
    rooms:              []Room,
}

Room :: struct {
    id:                 int,
    grid:               [room_len]int,
}

/* TODO: App structure like this:
- persistent
  - platform
  - main
- transient
  - run
  - frame
*/
app := App {};

main :: proc() {
    app.game = State {
        bg_color = {90, 95, 100, 255},
        version = "000000",
        window_width = 1920,
        window_height = 1080,
        show_menu_1 = true,
        show_menu_2 = true,
        show_menu_3 = true,
    }

    _ = virtual.arena_init_static(&app.platform_arena, arena_size_platform);
    platform_allocator := virtual.arena_allocator(&app.platform_arena);

    _ = virtual.arena_init_static(&app.main_arena, arena_size_main);
    main_allocator := virtual.arena_allocator(&app.main_arena);
    main_track : mem.Tracking_Allocator;
    mem.tracking_allocator_init(&main_track, main_allocator);
    main_allocator = mem.tracking_allocator(&main_track);

    _ = virtual.arena_init_static(&app.frame_arena, arena_size_frame);
    frame_allocator := virtual.arena_allocator(&app.frame_arena);
    frame_track : mem.Tracking_Allocator;
    mem.tracking_allocator_init(&frame_track, frame_allocator);
    frame_allocator = mem.tracking_allocator(&frame_track);

    context.allocator = main_allocator;
    context.temp_allocator = frame_allocator;
    context.logger = logger.create_logger(&app.logger);

    // log.debug("THIS IS A DEBUG");
    // log.info("THIS IS AN INFO");
    // log.warn("THIS IS A WARNING");
    // log.error("THIS IS AN ERROR");

    app.platform.allocator = &platform_allocator;
    platform_ok := platform.init(&app.platform);
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

    renderer.init(app.platform.window, &app.renderer);

    ui_ok := ui.init(&app.ui);
    if ui_ok == false {
        log.error("Couldn't ui.init correctly.");
        return;
    }

    app.game.version = string(#load("../version.txt") or_else "999999");

    {
        ldtk, ok := ldtk.load_file(rooms_path);
        log.infof("Level %v loaded: %s (%s)", rooms_path, ldtk.iid, ldtk.jsonVersion);
        app.game.ldtk = ldtk;
    }

    app.game.world = make_world(
        math.Vector2i { 3, 3 },
        room_size,
        []int {
            6, 2, 7,
            5, 1, 3,
            9, 4, 8,
        }, &app.game.ldtk);
    // log.debugf("World: %v", app.game.world);

    room_texture, room_texture_index, ok := load_texture("./media/art/placeholder_0.png");
    load_texture("./screenshots/screenshot_1673615737.bmp");

    for app.platform.quit == false {
        platform.process_events();

        if (app.platform.inputs.f1.released) {
            app.game.show_menu_1 = !app.game.show_menu_1;
        }
        if (app.platform.inputs.f2.released) {
            app.game.show_menu_2 = !app.game.show_menu_2;
        }
        if (app.platform.inputs.f3.released) {
            app.game.show_menu_3 = !app.game.show_menu_3;
        }

        if (app.platform.inputs.f12.released) {
            renderer.take_screenshot(app.platform.window);
        }

        renderer.clear(app.game.bg_color);

        for room, room_index in app.game.world.rooms {
            room_x, room_y := math.grid_index_to_position(room_index, app.game.world.size.x);

            for cell_value, cell_index in room.grid {
                cell_x, cell_y := math.grid_index_to_position(cell_index, room_size.x);
                source_x, source_y := math.grid_index_to_position(cell_value, sprite_grid_width);
                destination_rect := renderer.Rect{
                    x = i32((room_x * room_size.x + cell_x) * pixel_per_cell),
                    y = i32((room_y * room_size.y + cell_y) * pixel_per_cell),
                    w = pixel_per_cell,
                    h = pixel_per_cell,
                };
                source_rect := renderer.Rect{
                    x = i32(source_x * sprite_grid_size),
                    y = i32(source_y * sprite_grid_size),
                    w = sprite_grid_size,
                    h = sprite_grid_size,
                };
                renderer.draw_texture_by_index(room_texture_index, &source_rect, &destination_rect);
            }
        }

        ui.draw_begin();
        ui_draw_debug_window();
        ui.draw_end();

        ui.process_ui_commands(app.renderer.renderer);

        renderer.present();

        free_all(frame_allocator);

        for _, leak in frame_track.allocation_map {
            log.warnf("Leaked %v bytes at %v.", leak.size, leak.location);
        }
        for bad_free in frame_track.bad_free_array {
            log.warnf("Allocation %p was freed badly at %v.", bad_free.location, bad_free.memory);
        }
    }

    // renderer.quit();
    // platform.close_window();
    // platform.quit();

    log.debugf("App      : %v Kb / %v Kb", f32(app.platform_arena.total_used + app.main_arena.total_used + app.frame_arena.total_used) / mem.Kilobyte, f32(app.platform_arena.total_reserved + app.main_arena.total_reserved + app.frame_arena.total_reserved) / mem.Kilobyte);
    log.debugf("Platform : %v Kb / %v Kb", f32(app.platform_arena.total_used) / mem.Kilobyte, f32(app.platform_arena.total_reserved) / mem.Kilobyte);
    log.debugf("Main     : %v Kb / %v Kb", f32(app.main_arena.total_used) / mem.Kilobyte, f32(app.main_arena.total_reserved) / mem.Kilobyte);
    log.debugf("Frame    : %v Kb / %v Kb", f32(app.frame_arena.total_used) / mem.Kilobyte, f32(app.frame_arena.total_reserved) / mem.Kilobyte);

    log.debug("Quitting...");

    free_all(context.allocator);

    for _, leak in main_track.allocation_map {
        log.warnf("Leaked %v bytes at %v.", leak.size, leak.location);
    }
    for bad_free in main_track.bad_free_array {
        log.warnf("Allocation %p was freed badly at %v.", bad_free.location, bad_free.memory);
    }
}

ui_draw_debug_window :: proc() {
    ctx := &app.ui.ctx;

    if app.game.show_menu_1 {
        if ui.window(ctx, "Debug", {40, 40, 320, 640}) {
            ui.layout_row(ctx, {80, -1}, 0);
            ui.label(ctx, "App:");
            ui.label(ctx, fmt.tprintf("%v Kb / %v Kb", f32(app.platform_arena.total_used + app.main_arena.total_used + app.frame_arena.total_used) / mem.Kilobyte, f32(app.platform_arena.total_reserved + app.main_arena.total_reserved + app.frame_arena.total_reserved) / mem.Kilobyte));
            ui.label(ctx, "Platform:");
            ui.label(ctx, fmt.tprintf("%v Kb / %v Kb", f32(app.platform_arena.total_used) / mem.Kilobyte, f32(app.platform_arena.total_reserved) / mem.Kilobyte));
            ui.label(ctx, "Main:");
            ui.label(ctx, fmt.tprintf("%v Kb / %v Kb", f32(app.main_arena.total_used) / mem.Kilobyte, f32(app.main_arena.total_reserved) / mem.Kilobyte));
            ui.label(ctx, "Frame:");
            ui.label(ctx, fmt.tprintf("%v Kb / %v Kb", f32(app.frame_arena.total_used) / mem.Kilobyte, f32(app.frame_arena.total_reserved) / mem.Kilobyte));
            ui.label(ctx, "Textures:");
            ui.label(ctx, fmt.tprintf("%v", len(app.renderer.textures)));
        }
    }

    // if app.game.show_menu_2 {
    //     if ui.window(ctx, "Shortcuts", {40, 250, 320, 200}) {
    //         ui.layout_row(ctx, {80, -1}, 0);
    //         ui.label(ctx, "Screenshot:");
    //         ui.label(ctx, "F12");
    //     }
    // }

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
            if app.logger.log_buf_updated {
                panel := ui.get_current_container(ctx);
                panel.scroll.y = panel.content_size.y;
                app.logger.log_buf_updated = false;
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
                if str == "load" {
                    load_texture("./media/art/placeholder_0.png");
                }
            }
        }
    }
}

make_world :: proc(world_size: math.Vector2i, room_size: math.Vector2i, room_ids: []int, ldtk: ^ldtk.LDTK) -> World {
    rooms := make([]Room, world_size.x * world_size.y);
    defer delete(rooms);
    world := World {};
    world.size = math.Vector2i { world_size.x, world_size.y };
    world.rooms = rooms;

    for room_index := 0; room_index < len(room_ids); room_index += 1 {
        id := room_ids[room_index];

        level_index := -1;
        for level, i in ldtk.levels {
            parts := strings.split(level.identifier, "Room_");
            if len(parts) > 0 {
                parsed_id, ok := strconv.parse_int(parts[1]);
                if ok && parsed_id == id {
                    level_index = i;
                    break;
                }
            }
        }

        grid := [room_len]int {};
        layer_instance := ldtk.levels[level_index].layerInstances[ldtk_grid_layer_index];
        for value, i in layer_instance.intGridCsv {
            grid[i] = value;
        }

        world.rooms[room_index] = Room { id, grid };
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
        log.errorf("Surface not loaded: %v", path);
        return;
    }

    texture, texture_index, ok = renderer.create_texture_from_surface(surface);
    if ok == false {
        log.errorf("Texture not loaded: %v", path);
        return;
    }

    log.debugf("Texture loaded: %v", path);
    return;
}
