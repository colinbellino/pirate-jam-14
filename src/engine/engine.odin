package engine

import "core:fmt"
import "core:log"
import "core:os"
import "core:mem"
import "core:runtime"

App :: struct {
    platform_arena:         mem.Arena,
    renderer_arena:         mem.Arena,
    logger_arena:           mem.Arena,
    debug_arena:            mem.Arena,
    game_arena:             mem.Arena,

    app_allocator:          ^mem.Allocator,
    platform_allocator:     mem.Allocator,
    renderer_allocator:     mem.Allocator,
    debug_allocator:        mem.Allocator,
    logger_allocator:       mem.Allocator,
    temp_allocator:         mem.Allocator,
    game_allocator:         mem.Allocator,

    logger:                 log.Logger,

    platform_state:         ^Platform_State,
    renderer_state:         ^Renderer_State,
    ui_state:               ^UI_State,
    logger_state:           ^Logger_State,
    debug_state:            ^Debug_State,
    game_state:             rawptr,

    save_memory:            int,
    load_memory:            int,
}

init_app :: proc(
    window_size: Vector2i,
    base_address: uint, platform_memory_size, renderer_memory_size, logger_memory_size, debug_memory_size, game_memory_size: int,
    allocator, temp_allocator: mem.Allocator,
) -> (^App, mem.Arena) {
    context.allocator = allocator;
    context.temp_allocator = temp_allocator;

    app_size_memory_size := platform_memory_size + renderer_memory_size + logger_memory_size + debug_memory_size + game_memory_size + size_of(App) + size_of(^App);
    app_buffer, alloc_error := reserve_and_commit(uint(app_size_memory_size), rawptr(uintptr((base_address))));
    if alloc_error > .None {
        fmt.eprintf("Memory reserve/commit error: %v\n", alloc_error);
        os.exit(1);
    }
    fmt.printf("Memory allocated:       %i\n", app_size_memory_size);
    fmt.printf("- app_size:             %i\n", size_of(App));
    fmt.printf("- platform_memory_size: %i\n", platform_memory_size);
    fmt.printf("- renderer_memory_size: %i\n", renderer_memory_size);
    fmt.printf("- logger_memory_size:   %i\n", logger_memory_size);
    fmt.printf("- debug_memory_size:    %i\n", debug_memory_size);
    fmt.printf("- game_memory_size:     %i\n", game_memory_size);

    app_arena := mem.Arena {};
    mem.arena_init(&app_arena, app_buffer);
    app_allocator := mem.Allocator { profiler_arena_allocator_proc, &app_arena };
    arena_name := new(Arena_Name, app_allocator);
    arena_name^ = .App;
    context.allocator = app_allocator;

    app := new(App, app_allocator);
    app.app_allocator = &app_allocator;

    app.platform_allocator = make_arena_allocator(.Platform, platform_memory_size, &app.platform_arena, app_allocator);
    app.renderer_allocator = make_arena_allocator(.Renderer, renderer_memory_size, &app.renderer_arena, app_allocator);

    default_logger : runtime.Logger;
    if contains_os_args("no-log") == false {
        app.logger_allocator = make_arena_allocator(.Logger, logger_memory_size, &app.logger_arena, app_allocator);
        context.allocator = app.logger_allocator;
        app.logger_state = logger_create(app.logger_allocator);

        options := log.Options { .Level, .Time, .Short_File_Path, .Line, .Terminal_Color };
        data := new(log.File_Console_Logger_Data);
        data.file_handle = os.INVALID_HANDLE;
        data.ident = "";
        console_logger := log.Logger { log.file_console_logger_proc, data, runtime.Logger_Level.Debug, options };

        default_logger = log.create_multi_logger(console_logger, app.logger_state.logger);
    }
    app.logger = default_logger;
    context.logger = default_logger;

    app.debug_allocator = make_arena_allocator(.Debug, debug_memory_size, &app.debug_arena, app_allocator);
    app.game_allocator = make_arena_allocator(.Game, game_memory_size, &app.game_arena, app_allocator);

    // app.temp_allocator = os.heap_allocator();
    app.temp_allocator = context.temp_allocator;


    platform_state, platform_ok := platform_init(app.platform_allocator, app.temp_allocator);
    if platform_ok == false {
        log.error("Couldn't platform_init correctly.");
        os.exit(1);
    }
    app.platform_state = platform_state;

    open_window_ok := open_window(app.platform_state, "Tactics", window_size);
    if open_window_ok == false {
        log.error("Couldn't open_window correctly.");
        os.exit(1);
    }

    renderer_state, renderer_ok := renderer_init(app.platform_state.window, app.renderer_allocator);
    if renderer_ok == false {
        log.error("Couldn't renderer_init correctly.");
        os.exit(1);
    }
    app.renderer_state = renderer_state;

    ui_state, ui_ok := ui_init(app.renderer_state);
    if ui_ok == false {
        log.error("Couldn't renderer.ui_init correctly.");
        os.exit(1);
    }
    app.ui_state = ui_state;

    // TODO: error handling
    app.debug_state = debug_init(app.debug_allocator);

    assert(&app.platform_arena != nil, "platform_arena not initialized correctly!");
    assert(&app.renderer_arena != nil, "renderer_arena not initialized correctly!");
    assert(&app.logger_arena != nil, "logger_arena not initialized correctly!");
    assert(&app.debug_arena != nil, "debug_arena not initialized correctly!");
    assert(&app.game_arena != nil, "game_arena not initialized correctly!");
    assert(&app.platform_allocator != nil, "platform_allocator not initialized correctly!");
    assert(&app.renderer_allocator != nil, "renderer_allocator not initialized correctly!");
    assert(&app.debug_allocator != nil, "debug_allocator not initialized correctly!");
    assert(&app.temp_allocator != nil, "temp_allocator not initialized correctly!");
    assert(&app.game_allocator != nil, "game_allocator not initialized correctly!");
    assert(&app.logger != nil, "logger not initialized correctly!");
    assert(app.platform_state != nil, "platform_state not initialized correctly!");
    assert(app.renderer_state != nil, "renderer_state not initialized correctly!");
    assert(app.ui_state != nil, "ui_state not initialized correctly!");
    assert(app.logger_state != nil, "logger_state not initialized correctly!");
    assert(app.debug_state != nil, "debug_state not initialized correctly!");
    assert(app.game_state == nil, "game_state not initialized correctly!");

    return app, app_arena;
}
