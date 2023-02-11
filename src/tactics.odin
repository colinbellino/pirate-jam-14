package main

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:strings"
import "core:strconv"

import platform "engine/platform"
import logger "engine/logger"
import renderer "engine/renderer"
import ui "engine/renderer/ui"
import ldtk "engine/ldtk"
import math "engine/math"

rooms_path :: "./media/levels/rooms.ldtk";
room_size  :: math.Vector2i { 15, 9 };
room_len   :: room_size.x * room_size.y;
grid_layer_index :: 1;

State :: struct {
    log_state:          logger.State,
    bg_color:           renderer.Color,
    version:            string,
    window_width:       i32,
    window_height:      i32,

    ldtk:               ldtk.LDTK,
    world:              World,

    arena:              virtual.Arena,
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
    // level_index:        int,
    grid:               [room_len]int,
}

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
    track : mem.Tracking_Allocator;
    mem.tracking_allocator_init(&track, context.allocator);
    context.allocator = mem.tracking_allocator(&track);
    context.logger = logger.create_logger();

    platform.init();
    platform.state.input_mouse_move = input_mouse_move;
    platform.state.input_mouse_down = input_mouse_down;
    platform.state.input_mouse_up = input_mouse_up;
    platform.state.input_text = input_text;
    platform.state.input_scroll = input_scroll;
    platform.state.input_key_down = input_key_down;
    platform.state.input_key_up = input_key_up;
    platform.open_window(state.window_width, state.window_height);
    renderer.init(platform.state.window);

    state.version = string(#load("../version.txt") or_else "999999");

    {
        ldtk, ok := ldtk.load_file(rooms_path);
        logger.write_log("[Game] Level %v loaded: %s (%s)", rooms_path, ldtk.iid, ldtk.jsonVersion);
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
    // logger.write_log("[Game] World: %v", state.world);

    sprite0_surface, ok := platform.load_surface_from_image_file("media/art/icon.png");
    defer platform.free_surface(sprite0_surface);
    logger.write_log("sprite0_surface loaded: %v | %v", ok, sprite0_surface);
    sprite0_texture, ok2 := renderer.create_texture_from_surface(sprite0_surface);
    logger.write_log("sprite0_texture loaded: %v | %v", ok2, sprite0_texture);
    append(&renderer.state.textures, sprite0_texture);

    for platform.state.quit == false {
        platform.process_events();

        if (platform.state.inputs.f1.released) {
            state.show_menu_1 = !state.show_menu_1;
        }
        if (platform.state.inputs.f2.released) {
            state.show_menu_2 = !state.show_menu_2;
        }
        if (platform.state.inputs.f3.released) {
            state.show_menu_3 = !state.show_menu_3;
        }

        if (platform.state.inputs.f12.released) {
            renderer.take_screenshot(platform.state.window);
        }

        renderer.clear(state.bg_color);

        ui.draw_begin();
        ui_draw_debug_window(&state.bg_color, &state.log_state);
        ui.draw_end();

        renderer.process_ui_commands();
        // renderer.draw_texture(0, i32(800), i32(800));

        for room, room_index in state.world.rooms {
            room_x, room_y := math.grid_index_to_position(room_index, state.world.size.x);
            renderer.draw_texture(0, i32(room_x * 256), i32(room_y * 256));
            // logger.write_log("[Game] Room: %v | %v", room_index, room.id);
            for cell_value, cell_index in room.grid {
                // x, y := math.grid_index_to_position(cell_index, room_size.x);
                // renderer.draw_texture(0, i32(x), i32(y));
            }
        }

        renderer.present();

        // FIXME:
        // platform.state.quit = true;
    }

    // renderer.quit();
    // platform.close_window();
    // platform.quit();

    logger.destroy_logger();

    logger.write_log("[Game] Quitting...");

    // for _, leak in track.allocation_map {
    //     logger.write_log("%v leaked %v bytes", leak.location, leak.size);
    // }
    // for bad_free in track.bad_free_array {
    //     logger.write_log("%v allocation %p was freed badly", bad_free.location, bad_free.memory);
    // }
}

ui_draw_debug_window :: proc(bg_color: ^renderer.Color, log_state: ^logger.State) {
    ctx := &renderer.state.ui_context

    if state.show_menu_1 {
        if ui.window(ctx, "Debug", {40, 40, 320, 200}) {
            ui.layout_row(ctx, {80, -1}, 0);
            ui.label(ctx, "Version:");
            ui.label(ctx, state.version);
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
        if ui.window(ctx, "Logs", {370, 40, 600, 600}) {
            ui.layout_row(ctx, {-1}, -28)
            ui.begin_panel(ctx, "Log")
            ui.layout_row(ctx, {-1}, -1)
            ui.text(ctx, logger.read_log())
            if log_state.log_buf_updated {
                panel := ui.get_current_container(ctx)
                panel.scroll.y = panel.content_size.y
                log_state.log_buf_updated = false
            }
            ui.end_panel(ctx)

            @static buf: [128]byte
            @static buf_len: int
            submitted := false
            ui.layout_row(ctx, {-70, -1})
            if .SUBMIT in ui.textbox(ctx, buf[:], &buf_len) {
                ui.set_focus(ctx, ctx.last_id)
                submitted = true
            }
            if .SUBMIT in ui.button(ctx, "Submit") {
                submitted = true
            }
            if submitted {
                logger.write_log(string(buf[:buf_len]))
                buf_len = 0
            }
        }
    }
}

make_world :: proc(world_size: math.Vector2i, room_size: math.Vector2i, room_ids: []int, ldtk: ^ldtk.LDTK) -> World {
    world := World {};
    world.size = math.Vector2i { world_size.x, world_size.y };
    world.rooms = make([]Room, world_size.x * world_size.y);

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
        layer_instance := ldtk.levels[level_index].layerInstances[grid_layer_index];
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
