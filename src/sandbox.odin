package main

import "core:log"
import "core:mem"
import "core:runtime"
import "core:fmt"
import "core:os"
import "core:time"
import "core:strings"
import "core:math/rand"
import "vendor:sdl2"

import platform "engine/platform"
import renderer "engine/renderer"
import logger "engine/logger"
import ui "engine/renderer/ui"
import debug "debug"
import game "game"

APP_MEMORY_SIZE      :: 2048 * mem.Kilobyte * 10;
PLATFORM_MEMORY_SIZE :: 256 * mem.Kilobyte * 10;
RENDERER_MEMORY_SIZE :: 512 * mem.Kilobyte * 10;
GAME_MEMORY_SIZE     :: 256 * mem.Kilobyte * 10;

TARGET_FPS :: time.Duration(16_666_667);

game_update:        rawptr;
game_fixed_update:  rawptr;
game_render:        rawptr;

main :: proc() {
    context.logger = log.create_console_logger(runtime.Logger_Level.Debug, { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color });
    context.allocator = mem.Allocator { default_allocator_proc, nil };

    app_memory := mem.alloc(APP_MEMORY_SIZE);
    app_allocator := mem.Allocator { custom_allocator_proc, app_memory };
    debug.alloc_init(.App, app_allocator, APP_MEMORY_SIZE);

    platform_buffer := make([]u8, PLATFORM_MEMORY_SIZE, app_allocator);
    platform_allocator := mem.Allocator { custom_allocator_proc, &platform_buffer };
    debug.alloc_init(.Platform, platform_allocator, PLATFORM_MEMORY_SIZE);

    renderer_buffer := make([]u8, RENDERER_MEMORY_SIZE, app_allocator);
    renderer_allocator := mem.Allocator { custom_allocator_proc, &renderer_buffer };
    debug.alloc_init(.Renderer, renderer_allocator, RENDERER_MEMORY_SIZE);

    game_buffer := make([]u8, GAME_MEMORY_SIZE, app_allocator);
    game_allocator := mem.Allocator { custom_allocator_proc, &game_buffer };
    debug.alloc_init(.Game, game_allocator, GAME_MEMORY_SIZE);

    platform_state, platform_init_ok := platform.init(platform_allocator, platform_allocator);
    if platform_init_ok == false {
        log.error("Couldn't platform.init correctly.");
        return;
    }

    open_window_ok := platform.open_window(platform_state, "Hello", { 800, 600 });
    if open_window_ok == false {
        log.error("Couldn't platform.open_window correctly.");
        return;
    }

    renderer_state, renderer_init_ok := renderer.init(platform_state.window, renderer_allocator);
    if renderer_init_ok == false {
        log.error("Couldn't renderer.init correctly.");
        return;
    }

    ui_state : rawptr = nil;
    // ui_state, ui_init_ok := ui.init(renderer_state, renderer_allocator);
    // if ui_init_ok == false {
    //     log.error("Couldn't ui.init correctly.");
    //     return;
    // }

    logger_state : rawptr = nil;

    show_memory := false;
    show_profiler := false;
    game_state: ^game.Game_State;
    game_state = new(game.Game_State, game_allocator);

    game_update = rawptr(game.game_update);
    game_fixed_update = rawptr(game.game_fixed_update);
    game_render = rawptr(game.game_render);
    hot_reload();

    for game_state.quit == false && platform_state.quit == false {
        debug.frame_timing_start();
        platform.update_and_render(
            game_state.unlock_framerate,
            game_update, game_fixed_update, game_render,
            game_allocator,
            game_state, platform_state, renderer_state, logger_state, ui_state,
        );
        debug.frame_timing_end();
    }

    // app_quit := false;
    // for app_quit == false {
    //     debug.frame_timing_start();

    //     ui.draw_begin();

    //     {
    //         debug.timed_block("process_events");
    //         platform.process_events();
    //         debug.state.frame_timings[debug.state.snapshot_index].input_processed = time.diff(debug.state.frame_started, time.now());
    //     }

    //     if platform_state.keys[.ESCAPE].released || platform_state.quit {
    //         app_quit = true;
    //     }
    //     if platform_state.keys[.F1].released {
    //         show_memory = !show_memory;
    //     }
    //     if platform_state.keys[.F2].released {
    //         show_profiler = !show_profiler;
    //     }
    //     if platform_state.keys[.SPACE].released {
    //         hot_reload();
    //     }

    //     renderer.clear({ 100, 100, 100, 255 });

    //     if show_memory {
    //         debug.timed_block("draw_memory");
    //         if ui.window("Memory", { 400, 0, 360, 740 }) {
    //             {
    //                 ui.layout_row({ 170, -1 }, 0);
    //                 ui.label("App");
    //                 alloc_info := debug.get_alloc_info(.App);
    //                 used := int(uintptr(alloc_info.data_end) - uintptr(alloc_info.data));
    //                 total := alloc_info.size;
    //                 ui.label(format_arena_usage_static_data(used, total));
    //                 ui.layout_row({ -1 }, 0);
    //                 ui.progress_bar(f32(used) / f32(total), 5);
    //             }
    //             {
    //                 ui.layout_row({ 170, -1 }, 0);
    //                 ui.label("Platform");
    //                 alloc_info := debug.get_alloc_info(.Platform);
    //                 used := int(uintptr(alloc_info.data_end) - uintptr(alloc_info.data));
    //                 total := alloc_info.size;
    //                 ui.label(format_arena_usage_static_data(used, total));
    //                 ui.layout_row({ -1 }, 0);
    //                 ui.progress_bar(f32(used) / f32(total), 5);
    //             }
    //             {
    //                 ui.layout_row({ 170, -1 }, 0);
    //                 ui.label("Renderer");
    //                 alloc_info := debug.get_alloc_info(.Renderer);
    //                 used := int(uintptr(alloc_info.data_end) - uintptr(alloc_info.data));
    //                 total := alloc_info.size;
    //                 ui.label(format_arena_usage_static_data(used, total));
    //                 ui.layout_row({ -1 }, 0);
    //                 ui.progress_bar(f32(used) / f32(total), 5);
    //             }
    //             {
    //                 ui.layout_row({ 170, -1 }, 0);
    //                 ui.label("Game");
    //                 alloc_info := debug.get_alloc_info(.Game);
    //                 used := int(uintptr(alloc_info.data_end) - uintptr(alloc_info.data));
    //                 total := alloc_info.size;
    //                 ui.label(format_arena_usage_static_data(used, total));
    //                 ui.layout_row({ -1 }, 0);
    //                 ui.progress_bar(f32(used) / f32(total), 5);
    //             }
    //         }
    //     }

    //     if show_profiler {
    //         debug.draw_timers(TARGET_FPS);
    //     }

    //     ui.draw_end();
    //     ui.process_commands();

    //     renderer.present();

    //     debug.frame_timing_end();
    //     platform.reset_events();
    //     platform.reset_inputs();
    // }

    // for id, alloc_info in debug.state.alloc_infos {
    //     memory_used := uintptr(alloc_info.data_end) - uintptr(alloc_info.data);
    //     log.debugf("Allocator: %v --- %v / %v", id, memory_used, alloc_info.size);
    //     for alloc_entry, index in alloc_info.entries {
    //         log.debugf("[%v] -> %v", index, debug.format_alloc_entry(alloc_entry));
    //     }
    // }

    log.debug("Quitting...");
}

default_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    fmt.printf("%v %v -> %v\n", mode, size, location);
    data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    if error != .None {
        context.allocator = runtime.default_allocator();
        fmt.eprintf("ERROR: %v\n", error);
    }

    return;
}

custom_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    // fmt.printf("custom_allocator_proc: %v %v %v %v %v %v %v\n", allocator_data, mode, size, alignment, old_memory, old_size, location);
    debug.alloc_start(allocator_data, mode, size, alignment, old_memory, old_size, location);
    data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);
    debug.alloc_end(data, error);

    return;
}

format_arena_usage_static_data :: proc(offset: int, data_length: int) -> string {
    return fmt.tprintf("%v Kb / %v Kb",
        f32(offset) / mem.Kilobyte,
        f32(data_length) / mem.Kilobyte);
}

hot_reload :: proc() {
    dll := sdl2.LoadObject("hot.bin");
    if dll == nil {
        log.errorf("Hot reload error: %v", sdl2.GetError());
    }
    assert(dll != nil, "hot.dll can't be nil.");

    game_update = sdl2.LoadFunction(dll, "game_update");
    assert(game_update != nil, "game_update can't be nil.");
    game_fixed_update = sdl2.LoadFunction(dll, "game_fixed_update");
    assert(game_fixed_update != nil, "game_fixed_update can't be nil.");
    game_render = sdl2.LoadFunction(dll, "game_render");
    assert(game_render != nil, "game_render can't be nil.");

    // log.debugf("Hot reloaded: %v, %b, %b, %b", dll, game_update, game_fixed_update, game_render);
}
