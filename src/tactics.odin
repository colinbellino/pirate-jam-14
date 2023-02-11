package main

import "core:log"
import "core:mem"
import "core:os"
import "core:math"

import "vendor:sdl2"

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

    // TODO: Get window_size from settings
    open_ok := platform.open_window("Tactics", 6 * game.NATIVE_RESOLUTION);
    if open_ok == false {
        log.error("Couldn't platform.open_window correctly.");
        return;
    }

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

    // TODO: move to platform
    update_rate : i32 = 60;
    update_multiplicity := 1;
    unlock_framerate := false;

    // //compute how many ticks one update should be
    fixed_deltatime : f64 = 1.0 / f64(update_rate);
    desired_frametime : u64 = sdl2.GetPerformanceFrequency() / u64(update_rate);

    // these are to snap deltaTime to vsync values if it's close enough
    vsync_maxerror : u64 = sdl2.GetPerformanceFrequency() / 5000;
    time_60hz : u64 = sdl2.GetPerformanceFrequency() / 60; // since this is about snapping to common vsync values
    snap_frequencies : []u64 = {
        time_60hz,           // 60fps
        time_60hz * 2,       // 30fps
        time_60hz * 3,       // 20fps
        time_60hz * 4,       // 15fps
        (time_60hz + 1) / 2, // 120fps //120hz, 240hz, or higher need to round up, so that adding 120hz twice guaranteed is at least the same as adding time_60hz once
    };

    time_history_count :: 4;
    time_averager : [time_history_count]u64 = { desired_frametime, desired_frametime, desired_frametime, desired_frametime };
    averager_residual : u64 = 0;

    resync := true;
    prev_frame_time: u64 = sdl2.GetPerformanceCounter();
    frame_accumulator : u64 = 0;

    for app.platform.quit == false {
        // frame timer
        current_frame_time : u64 = sdl2.GetPerformanceCounter();
        delta_time : u64 = current_frame_time - prev_frame_time;
        prev_frame_time = current_frame_time;

        // handle unexpected timer anomalies (overflow, extra slow frames, etc)
        if delta_time > desired_frametime * 8 { // ignore extra-slow frames
            delta_time = desired_frametime;
        }
        if delta_time < 0 {
            delta_time = 0;
        }

        // vsync time snapping
        for snap in snap_frequencies {
            if math.abs(delta_time - snap) < vsync_maxerror {
                delta_time = snap;
                break;
            }
        }

        // delta time averaging
        for i := 0; i < time_history_count - 1; i += 1 {
            time_averager[i] = time_averager[i + 1];
        }
        time_averager[time_history_count - 1] = delta_time;
        averager_sum : u64 = 0;
        for i := 0; i < time_history_count; i += 1 {
            averager_sum += time_averager[i];
        }
        delta_time = averager_sum / time_history_count;

        averager_residual += averager_sum % time_history_count;
        delta_time += averager_residual / time_history_count;
        averager_residual %= time_history_count;

        // add to the accumulator
        frame_accumulator += delta_time;

        // spiral of death protection
        if frame_accumulator > desired_frametime * 8 {
            resync = true;
        }

        // timer resync if requested
        if resync {
            frame_accumulator = 0;
            delta_time = desired_frametime;
            resync = false;
        }

        if unlock_framerate {
            log.error("unlock_framerate mode not implemented");
            os.exit(1);
        } else {
            for frame_accumulator >= desired_frametime * u64(update_multiplicity) {
                for i := 0; i < update_multiplicity; i += 1 {
                    platform.process_events();
                    game.fixed_update(app.game, app.platform, app.renderer, app.logger, app.ui, arena_allocator, fixed_deltatime);
                    // game.variable_update(fixed_deltatime);
                    frame_accumulator -= desired_frametime;
                }
            }

            game.render(app.game, app.platform, app.renderer, app.logger, app.ui, arena_allocator, 1.0);
        }
    }

    log.debug("Quitting...");
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
