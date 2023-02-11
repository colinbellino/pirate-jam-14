package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:slice"

import platform "engine/platform"
import logger "engine/logger"
import renderer "engine/renderer"
import ui "engine/renderer/ui"

import game "game"

APP_ARENA_SIZE          :: 16 * mem.Megabyte;
TEMP_ARENA_SIZE         :: 4 * mem.Megabyte;

App :: struct {
    game:               ^game.Game_State,
    platform:           ^platform.State,
    renderer:           ^renderer.State,
    logger:             ^logger.State,
    ui:                 ^ui.State,
}

main :: proc() {
    arena: mem.Arena;
    temp_arena: mem.Arena;
    app: App;

    app_allocator := mem.Allocator { platform.allocator_proc, nil };
    app_tracking_allocator : mem.Tracking_Allocator;
    mem.tracking_allocator_init(&app_tracking_allocator, app_allocator);
    app_allocator = mem.tracking_allocator(&app_tracking_allocator);
    // context.allocator = app_allocator;

    // FIXME: this is allocating everytime we log something
    logger_allocator := mem.Allocator { logger.allocator_proc, nil };
    app.logger = logger.create_logger(logger_allocator);
    context.logger = app.logger.logger;
    // options := log.Options { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color };
    // context.logger = log.create_console_logger(runtime.Logger_Level.Debug, options);

    {
        buffer := make([]u8, APP_ARENA_SIZE, app_allocator);
        mem.arena_init(&arena, buffer);
    }
    arena_allocator := mem.Allocator { platform.arena_allocator_proc, &arena };
    // context.allocator = arena_allocator;

    {
        buffer := make([]u8, TEMP_ARENA_SIZE, arena_allocator);
        mem.arena_init(&temp_arena, buffer);
    }
    temp_arena_allocator := mem.Allocator { platform.arena_allocator_proc, &temp_arena };

    platform_ok: bool;
    app.platform, platform_ok = platform.init(arena_allocator, temp_arena_allocator);
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

    app.game = new(game.Game_State, arena_allocator);

    open_ok := platform.open_window("Tactics", 4 * game.NATIVE_RESOLUTION);
    if open_ok == false {
        log.error("Couldn't platform.open_window correctly.");
        return;
    }

    // TODO: Get window_size from settings
    window_size := platform.get_window_size(app.platform.window);
    app.game.rendering_scale = f32(window_size.y) / f32(game.NATIVE_RESOLUTION.y);
    // FIXME: handle different resolution ratio (16/9, 16/10, etc)
    log.debugf("window_size: %v", window_size);
    log.debugf("app.game.rendering_scale: %v", app.game.rendering_scale);

    renderer_ok: bool;
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

    for app.platform.quit == false {
        platform.process_events();

        game.update_and_render(app.game, app.platform, app.renderer, app.logger, app.ui, arena_allocator);

        // free_all(temp_arena_allocator);

        // for _, leak in frame_track.allocation_map {
        //     log.warnf("Leaked %v bytes at %v.", leak.size, leak.location);
        // }
        // for bad_free in frame_track.bad_free_array {
        //     log.warnf("Allocation %p was freed badly at %v.", bad_free.location, bad_free.memory);
        // }
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
