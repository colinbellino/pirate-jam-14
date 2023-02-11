package main

import "core:fmt"
import "core:mem"
import "core:log"
import "core:mem/virtual"
import "core:strings"
import "core:strconv"

import platform "engine/platform"
import logger "engine/logger"
import renderer "engine/renderer"
import ui "engine/renderer/ui"
import ldtk "engine/ldtk"
import math "engine/math"

rooms_path              :: "./media/levels/rooms.ldtk";
room_size               :: math.Vector2i { 15, 9 };
room_len                :: room_size.x * room_size.y;
ldtk_grid_layer_index   :: 1;
pixel_per_cell          :: 32;
sprite_grid_size        :: 32;
sprite_grid_width       :: 4;

State :: struct {
    platform_state:     platform.State,
    log_state:          logger.State,
    renderer_state:     renderer.State,
    ui_state:           ui.State,

    bg_color:           renderer.Color,
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

arena := virtual.Arena {};
state := State {
    bg_color = {90, 95, 100, 255},
    version = "000000",
    window_width = 1920,
    window_height = 1080,
    show_menu_1 = true,
    show_menu_2 = true,
    show_menu_3 = true,
}

main :: proc() {
    arena_allocator := virtual.arena_allocator(&arena);

    global_track : mem.Tracking_Allocator;
    mem.tracking_allocator_init(&global_track, arena_allocator);
    context.allocator = mem.tracking_allocator(&global_track);

    frame_track : mem.Tracking_Allocator;
    mem.tracking_allocator_init(&frame_track, arena_allocator);
    frame_allocator := mem.tracking_allocator(&frame_track);

    context.logger = logger.create_logger(&state.log_state);

    // log.debug("THIS IS A DEBUG");
    // log.info("THIS IS AN INFO");
    // log.warn("THIS IS A WARNING");
    // log.error("THIS IS AN ERROR");

    platform_ok := platform.init(&state.platform_state);
    if platform_ok == false {
        log.error("Couldn't platform.init correctly.");
        return;
    }
    state.platform_state.input_mouse_move = input_mouse_move;
    state.platform_state.input_mouse_down = input_mouse_down;
    state.platform_state.input_mouse_up = input_mouse_up;
    state.platform_state.input_text = input_text;
    state.platform_state.input_scroll = input_scroll;
    state.platform_state.input_key_down = input_key_down;
    state.platform_state.input_key_up = input_key_up;

    open_ok := platform.open_window(state.window_width, state.window_height);
    if open_ok == false {
        log.error("Couldn't platform.open_window correctly.");
        return;
    }

    renderer.init(state.platform_state.window, &state.renderer_state);

    ui_ok := ui.init(&state.ui_state);
    if ui_ok == false {
        log.error("Couldn't ui.init correctly.");
        return;
    }

    state.version = string(#load("../version.txt") or_else "999999");

    {
        ldtk, ok := ldtk.load_file(rooms_path);
        log.infof("[Game] Level %v loaded: %s (%s)", rooms_path, ldtk.iid, ldtk.jsonVersion);
        state.ldtk = ldtk;
    }

    state.world = make_world(
        math.Vector2i { 3, 3 },
        room_size,
        []int {
            6, 2, 7,
            5, 1, 3,
            9, 4, 8,
        }, &state.ldtk);
    // log.debugf("[Game] World: %v", state.world);

    room_texture, room_texture_index, ok := load_texture("media/art/placeholder_0.png");
    load_texture("./screenshots/screenshot_1673615737.bmp");

    for state.platform_state.quit == false {
        context.allocator = frame_allocator;

        platform.process_events();

        if (state.platform_state.inputs.f1.released) {
            state.show_menu_1 = !state.show_menu_1;
        }
        if (state.platform_state.inputs.f2.released) {
            state.show_menu_2 = !state.show_menu_2;
        }
        if (state.platform_state.inputs.f3.released) {
            state.show_menu_3 = !state.show_menu_3;
        }

        if (state.platform_state.inputs.f12.released) {
            renderer.take_screenshot(state.platform_state.window);
        }

        renderer.clear(state.bg_color);

        for room, room_index in state.world.rooms {
            room_x, room_y := math.grid_index_to_position(room_index, state.world.size.x);

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
        ui_draw_debug_window(&state.bg_color, &state.log_state);
        ui.draw_end();

        ui.process_ui_commands(state.renderer_state.renderer);

        renderer.present();

        for _, leak in frame_track.allocation_map {
            log.warnf("Leaked %v bytes at %v.", leak.size, leak.location);
        }
        for bad_free in frame_track.bad_free_array {
            log.warnf("Allocation %p was freed badly at %v.", bad_free.location, bad_free.memory);
        }

        // FIXME:
        // state.platform_state.quit = true;
    }

    // renderer.quit();
    // platform.close_window();
    // platform.quit();

    log.debugf("Arena: %v / %v", arena.total_used, arena.total_reserved);

    log.debug("[Game] Quitting...");

    free_all(context.allocator);

    for _, leak in global_track.allocation_map {
        log.warnf("Leaked %v bytes at %v.", leak.size, leak.location);
    }
    for bad_free in global_track.bad_free_array {
        log.warnf("Allocation %p was freed badly at %v.", bad_free.location, bad_free.memory);
    }
}

ui_draw_debug_window :: proc(bg_color: ^renderer.Color, log_state: ^logger.State) {
    ctx := &state.ui_state.ctx;

    if state.show_menu_1 {
        if ui.window(ctx, "Debug", {40, 40, 320, 200}) {
            ui.layout_row(ctx, {80, -1}, 0);
            ui.label(ctx, "Arena:");
            ui.label(ctx, fmt.tprintf("%v / %v", arena.total_used, arena.total_reserved));
            ui.label(ctx, "Version:");
            ui.label(ctx, state.version);
            ui.label(ctx, "Textures:");
            ui.label(ctx, fmt.tprintf("%v", len(state.renderer_state.textures)));
        }
    }

    if state.show_menu_2 {
        if ui.window(ctx, "Shortcuts", {40, 250, 320, 200}) {
            ui.layout_row(ctx, {80, -1}, 0);
            ui.label(ctx, "Screenshot:");
            ui.label(ctx, "F12");
        }
    }

    if state.show_menu_3 {
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
            if log_state.log_buf_updated {
                panel := ui.get_current_container(ctx);
                panel.scroll.y = panel.content_size.y;
                log_state.log_buf_updated = false;
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
                log.debugf(string(buf[:buf_len]));
                buf_len = 0;
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

input_mouse_move :: ui.input_mouse_move;
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

load_texture :: proc(image_path: string) -> (texture: ^renderer.Texture, texture_index : int = -1, ok: bool) {
    surface : ^platform.Surface;
    surface, ok = platform.load_surface_from_image_file(image_path);
    defer platform.free_surface(surface);

    if ok == false {
        log.errorf("Surface not loaded: %v", image_path);
        return;
    }

    texture, texture_index, ok = renderer.create_texture_from_surface(surface);
    if ok == false {
        log.errorf("Texture not loaded: %v", image_path);
        return;
    }

    return;
}
