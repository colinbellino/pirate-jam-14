// TODO: identify types of allocations by colors
// TODO: memory save to file
// TODO: code reload
// TODO: asset reload

package main

import "core:log"
import "core:mem"
import "core:runtime"
import "core:fmt"
import "core:os"
import "core:time"
import "core:strings"
import "core:math/rand"

import platform "engine/platform"
import renderer "engine/renderer"
import ui "engine/renderer/ui"
import debug "debug"

APP_MEMORY_SIZE      :: 1024 * mem.Kilobyte;
PLATFORM_MEMORY_SIZE :: 256 * mem.Kilobyte;
RENDERER_MEMORY_SIZE :: 512 * mem.Kilobyte;
GAME_MEMORY_SIZE     :: 256 * mem.Kilobyte;

main :: proc() {
    context.logger = log.create_console_logger(runtime.Logger_Level.Debug, { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color });
    context.allocator = mem.Allocator { default_allocator_proc, nil };

    app_memory := mem.alloc(APP_MEMORY_SIZE);
    app_allocator := mem.Allocator { custom_allocator_proc, app_memory };
    debug.alloc_init(.App, app_allocator, APP_MEMORY_SIZE);

    // TODO: debug.alloc_color();
    platform_buffer := make([]u8, PLATFORM_MEMORY_SIZE, app_allocator);
    platform_allocator := mem.Allocator { custom_allocator_proc, &platform_buffer };
    debug.alloc_init(.Platform, platform_allocator, PLATFORM_MEMORY_SIZE);

    // TODO: debug.alloc_color();
    renderer_buffer := make([]u8, RENDERER_MEMORY_SIZE, app_allocator);
    renderer_allocator := mem.Allocator { custom_allocator_proc, &renderer_buffer };
    debug.alloc_init(.Renderer, renderer_allocator, RENDERER_MEMORY_SIZE);

    // TODO: debug.alloc_color();
    game_buffer := make([]u8, GAME_MEMORY_SIZE, app_allocator);
    game_allocator := mem.Allocator { custom_allocator_proc, &game_buffer };
    debug.alloc_init(.Game, game_allocator, GAME_MEMORY_SIZE);

    bla := make([]u8, 2, game_allocator);

    platform_state, platform_init_ok := platform.init(platform_allocator, platform_allocator);
    if platform_init_ok == false {
        log.error("Couldn't platform.init correctly.");
        return;
    }

    open_window_ok := platform.open_window("Hello", { 800, 600 });
    if open_window_ok == false {
        log.error("Couldn't platform.open_window correctly.");
        return;
    }

    renderer_state, renderer_init_ok := renderer.init(platform_state.window, renderer_allocator);
    if renderer_init_ok == false {
        log.error("Couldn't renderer.init correctly.");
        return;
    }

    ui_state, ui_init_ok := ui.init(renderer_state, renderer_allocator);
    if ui_init_ok == false {
        log.error("Couldn't ui.init correctly.");
        return;
    }

    app_quit := false;
    for app_quit == false {
        debug.frame_timing_start();

        ui.draw_begin();

        {
            debug.timed_block("process_events");
            platform.process_events();
            debug.state.frame_timing.input_processed = time.diff(debug.state.frame_started, time.now());
        }

        if platform_state.keys[.ESCAPE].released || platform_state.quit{
            app_quit = true;
        }

        renderer.clear({ 100, 100, 100, 255 });

        if ui.window("Memory", { 400, 0, 360, 740 }) {
            debug.timed_block("draw_memory");
            {
                ui.layout_row({ 170, -1 }, 0);
                ui.label("App");
                alloc_info := debug.get_alloc_info(.App);
                used := int(uintptr(alloc_info.data_end) - uintptr(alloc_info.data));
                total := alloc_info.size;
                ui.label(format_arena_usage_static_data(used, total));
                ui.layout_row({ -1 }, 0);
                ui.progress_bar(f32(used) / f32(total), 5);
            }
            {
                ui.layout_row({ 170, -1 }, 0);
                ui.label("Platform");
                alloc_info := debug.get_alloc_info(.Platform);
                used := int(uintptr(alloc_info.data_end) - uintptr(alloc_info.data));
                total := alloc_info.size;
                ui.label(format_arena_usage_static_data(used, total));
                ui.layout_row({ -1 }, 0);
                ui.progress_bar(f32(used) / f32(total), 5);
            }
            {
                ui.layout_row({ 170, -1 }, 0);
                ui.label("Renderer");
                alloc_info := debug.get_alloc_info(.Renderer);
                used := int(uintptr(alloc_info.data_end) - uintptr(alloc_info.data));
                total := alloc_info.size;
                ui.label(format_arena_usage_static_data(used, total));
                ui.layout_row({ -1 }, 0);
                ui.progress_bar(f32(used) / f32(total), 5);
            }
            {
                ui.layout_row({ 170, -1 }, 0);
                ui.label("Game");
                alloc_info := debug.get_alloc_info(.Game);
                used := int(uintptr(alloc_info.data_end) - uintptr(alloc_info.data));
                total := alloc_info.size;
                ui.label(format_arena_usage_static_data(used, total));
                ui.layout_row({ -1 }, 0);
                ui.progress_bar(f32(used) / f32(total), 5);
            }
        }

        if ui.window("Timers", { 0, 0, 400, 800 }, { .NO_TITLE, .NO_FRAME }) {
            ui.layout_row({ -1 }, 0);
            ui.label(fmt.tprintf("snapshot_index: %i", debug.state.snapshot_index));
            for block_id, block in debug.state.timed_block_data {
                ui.layout_row({ 200, 50, -1 }, 0);
                current_snapshot := block.snapshots[debug.state.snapshot_index];

                ui.label(fmt.tprintf("%s (%s:%i)", block.name, block.location.procedure, block.location.line));
                ui.label(fmt.tprintf("%i", current_snapshot.hit_count));
                ui.label(fmt.tprintf("%fms", time.duration_milliseconds(time.Duration(i64(current_snapshot.duration)))));

                if current_snapshot.hit_count == 0 {
                    continue;
                }

                colors := []ui.Color {
                    { 0, 255, 36, 255 },
                    { 110, 238, 0, 255 },
                    { 151, 219, 0, 255 },
                    { 180, 200, 0, 255 },
                    { 203, 178, 0, 255 },
                    { 222, 156, 0, 255 },
                    { 236, 131, 0, 255 },
                    { 247, 103, 0, 255 },
                    { 253, 69, 0, 255 },
                    { 255, 0, 0, 255 },
                };

                color_red: ui.Color = { 255, 0, 0, 255 };
                bg_color: ui.Color = { 10, 10, 10, 255 };
                height : i32 = 20;
                scale := 1 / 16.0;
                ui.layout_row({ 120 }, height);
                next_layout_rect := ui.layout_next();
                ui.draw_rect({ next_layout_rect.x, next_layout_rect.y, next_layout_rect.w, height }, bg_color);
                for snapshot, index in block.snapshots {
                    current_value : f64 = time.duration_milliseconds(snapshot.duration) * scale;
                    // color := colors[(i32(f64(len(colors)) * current_value)) % i32(len(colors))];
                    // log.debugf("current_value: %v | %v", current_value, color);
                    // TODO: See how HMH does bar colors and scaling
                    color := ui.Color { 0, 255, 0, 255 };
                    ui.draw_rect({
                        next_layout_rect.x + i32(index),
                        next_layout_rect.y + i32((1.0 - current_value) * f64(height)),
                        1,
                        i32(current_value * f64(height)),
                    }, color);
                }
                ui.draw_rect({
                    next_layout_rect.x + i32(debug.state.snapshot_index),
                    next_layout_rect.y,
                    1,
                    height,
                }, color_red);
            }
        }

        ui.draw_end();
        ui.process_commands();

        // renderer.set_draw_color({ 255, 0, 0, 255 });
        // renderer.draw_line({ 0, 0 }, { 1000, 1000 });

        // renderer.draw_fill_rect_no_offset(&{ 0, 0, 200, 200 }, { 100, 100, 100, 255 });

        renderer.present();

        debug.frame_timing_end();
        // debug.timed_block_clear();
    }

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
