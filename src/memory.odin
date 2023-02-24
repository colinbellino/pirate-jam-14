// TODO: identify types of allocations by colors

package main

import "core:log"
import "core:mem"
import "core:runtime"
import "core:fmt"
import "core:os"

import platform "engine/platform"
import renderer "engine/renderer"
import ui "engine/renderer/ui"

APP_MEMORY_SIZE      :: 1024 * mem.Kilobyte;
PLATFORM_MEMORY_SIZE :: 256 * mem.Kilobyte;
RENDERER_MEMORY_SIZE :: 512 * mem.Kilobyte;
GAME_MEMORY_SIZE     :: 256 * mem.Kilobyte;

Debug_Info :: struct {
    quit:           bool,
    alloc_map:      map[Allocator_Id]Allocator_Info,
}

Allocator_Id :: enum { App, Platform, Renderer, Game }

Allocator_Info :: struct {
    data:           rawptr,
    data_end:       rawptr,
    size:           int,
    entries:        [dynamic]Allocator_Entry,
}

Allocator_Entry :: struct {
    id:             Allocator_Id,
    data:           rawptr,
    mode:           mem.Allocator_Mode,
    size:           int,
    alignment:      int,
    old_memory:     rawptr,
    old_size:       int,
    location:       runtime.Source_Code_Location,
}

debug: Debug_Info;

main :: proc() {
    context.allocator = mem.Allocator { default_allocator_proc, nil };
    context.logger = log.create_console_logger(runtime.Logger_Level.Debug, { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color });

    app_memory := mem.alloc(APP_MEMORY_SIZE);
    app_allocator := mem.Allocator { app_allocator_proc, app_memory };
    allocator_info_init(.App, app_allocator.data, APP_MEMORY_SIZE);

    platform_buffer := make([]u8, PLATFORM_MEMORY_SIZE, app_allocator);
    platform_allocator := mem.Allocator { platform_allocator_proc, &platform_buffer };
    allocator_info_init(.Platform, platform_allocator.data, PLATFORM_MEMORY_SIZE);

    renderer_buffer := make([]u8, RENDERER_MEMORY_SIZE, app_allocator);
    renderer_allocator := mem.Allocator { renderer_allocator_proc, &renderer_buffer };
    allocator_info_init(.Renderer, renderer_allocator.data, RENDERER_MEMORY_SIZE);

    game_buffer := make([]u8, GAME_MEMORY_SIZE, app_allocator);
    game_allocator := mem.Allocator { game_allocator_proc, &game_buffer };
    allocator_info_init(.Game, game_allocator.data, GAME_MEMORY_SIZE);

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

    for debug.quit == false {
        platform.process_events();

        if platform_state.keys[.ESCAPE].released || platform_state.quit{
            debug.quit = true;
        }

        renderer.clear({ 255, 0, 255, 255 });

        ui.draw_begin();
        if ui.window("Memory", { 0, 0, 360, 740 }) {
            {
                ui.layout_row({ 170, -1 }, 0);
                ui.label("App");
                alloc_map := debug.alloc_map[.App];
                used := int(uintptr(alloc_map.data_end) - uintptr(alloc_map.data));
                total := alloc_map.size;
                ui.label(format_arena_usage_static_data(used, total));
                ui.layout_row({ -1 }, 0);
                ui.progress_bar(f32(used) / f32(total), 5);
            }
            {
                ui.layout_row({ 170, -1 }, 0);
                ui.label("Platform");
                alloc_map := debug.alloc_map[.Platform];
                used := int(uintptr(alloc_map.data_end) - uintptr(alloc_map.data));
                total := alloc_map.size;
                ui.label(format_arena_usage_static_data(used, total));
                ui.layout_row({ -1 }, 0);
                ui.progress_bar(f32(used) / f32(total), 5);
            }
            {
                ui.layout_row({ 170, -1 }, 0);
                ui.label("Renderer");
                alloc_map := debug.alloc_map[.Renderer];
                used := int(uintptr(alloc_map.data_end) - uintptr(alloc_map.data));
                total := alloc_map.size;
                ui.label(format_arena_usage_static_data(used, total));
                ui.layout_row({ -1 }, 0);
                ui.progress_bar(f32(used) / f32(total), 5);
            }
            {
                ui.layout_row({ 170, -1 }, 0);
                ui.label("Game");
                alloc_map := debug.alloc_map[.Game];
                used := int(uintptr(alloc_map.data_end) - uintptr(alloc_map.data));
                total := alloc_map.size;
                ui.label(format_arena_usage_static_data(used, total));
                ui.layout_row({ -1 }, 0);
                ui.progress_bar(f32(used) / f32(total), 5);
            }
        }
        ui.draw_end();
        ui.process_commands();

        // renderer.draw_fill_rect_no_offset(&{ 0, 0, 200, 200 }, { 100, 100, 100, 255 });
        renderer.present();
    }

    for id, alloc_map in debug.alloc_map {
        memory_used := uintptr(alloc_map.data_end) - uintptr(alloc_map.data);
        log.debugf("Allocator: %v --- %v / %v", id, memory_used, alloc_map.size);
        for alloc_info, index in alloc_map.entries {
            log.debugf("[%v] -> %v", index, alloc_info_format(alloc_info));
        }
    }

    log.debug("Quitting...");
}

default_allocator_proc :: proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    fmt.printf("default_allocator_proc %v %v -> %v\n", mode, size, location);
    data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    if error != .None {
        fmt.eprintf("default_allocator_proc ERROR: %v\n", error);
    }

    return;
}

custom_allocator_proc :: proc(allocator_id: Allocator_Id, allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    // fmt.printf("custom_allocator_proc: %v %v %v %v %v %v %v\n", allocator_data, mode, size, alignment, old_memory, old_size, location);

    alloc_info := &debug.alloc_map[allocator_id];
    append(&alloc_info.entries, Allocator_Entry { allocator_id, allocator_data, mode, size, alignment, old_memory, old_size, location });

    if mem.ptr_offset(transmute(^u8)alloc_info.data_end, size) > mem.ptr_offset(transmute(^u8)alloc_info.data_end, alloc_info.size) {
        error = .Out_Of_Memory;
        log.errorf("custom_allocator_proc(%v) ERROR: %v", allocator_id, error);
        return;
    }

    data, error = os.heap_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    if mode == .Alloc || mode == .Alloc_Non_Zeroed {
        alloc_info.data_end = mem.ptr_offset(transmute(^u8)alloc_info.data_end, size);
    }
    if mode == .Free {
        alloc_info.data_end = rawptr(uintptr(alloc_info.data_end) - uintptr(old_size));
    }
    if mode == .Resize {
        log.debug(".Resize not implemented");
        os.exit(1);
    }
    // log.debugf("old_memory: %p %v", old_memory, old_size);

    if error != .None {
        log.errorf("custom_allocator_proc(%v) ERROR: %v", allocator_id, error);
    }

    return;
}

app_allocator_proc : mem.Allocator_Proc : proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    return custom_allocator_proc(.App, allocator_data, mode, size, alignment, old_memory, old_size, location);
}
platform_allocator_proc : mem.Allocator_Proc : proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    return custom_allocator_proc(.Platform, allocator_data, mode, size, alignment, old_memory, old_size, location);
}
renderer_allocator_proc : mem.Allocator_Proc : proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    return custom_allocator_proc(.Renderer, allocator_data, mode, size, alignment, old_memory, old_size, location);
}
game_allocator_proc : mem.Allocator_Proc : proc(allocator_data: rawptr, mode: mem.Allocator_Mode, size, alignment: int, old_memory: rawptr, old_size: int, location := #caller_location) -> (data: []u8, error: mem.Allocator_Error) {
    return custom_allocator_proc(.Game, allocator_data, mode, size, alignment, old_memory, old_size, location);
}

alloc_info_format :: proc(alloc_info: Allocator_Entry) -> string {
    using alloc_info;
    return fmt.tprintf("[%v] %v: %v -> %v", id, mode, size, location);
}

allocator_info_init :: proc(id: Allocator_Id, data: rawptr, size: int) {
    debug.alloc_map[id] = {};
    (&debug.alloc_map[id]).entries = make([dynamic]Allocator_Entry, 0);
    (&debug.alloc_map[id]).data = data;
    (&debug.alloc_map[id]).data_end = data;
    (&debug.alloc_map[id]).size = size;

    memory_start := uintptr(data);
    memory_end := uintptr(mem.ptr_offset(transmute(^u8)data, size));
    log.debugf("[%v] %v + %v = %v", id, memory_start, size, memory_end);
    assert((memory_end - memory_start) == uintptr(size));
}

format_arena_usage_static_data :: proc(offset: int, data_length: int) -> string {
    return fmt.tprintf("%v Kb / %v Kb",
        f32(offset) / mem.Kilobyte,
        f32(data_length) / mem.Kilobyte);
}
