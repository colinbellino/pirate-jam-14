package engine

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/slashpath"
import "core:runtime"

App :: struct {
    default_allocator:      mem.Allocator,
    engine_allocator:       mem.Allocator,
    temp_allocator:         mem.Allocator,
    game_allocator:         mem.Allocator,

    config:                 Config,

    platform:               ^Platform_State,
    renderer:               ^Renderer_State,
    ui:                     ^UI_State,
    logger:                 ^Logger_State,
    debug:                  ^Debug_State,
    assets:                 ^Assets_State,
    game:                   rawptr,

    engine_arena:           mem.Arena,
    game_arena:             mem.Arena,
}

Config :: struct {
    os_args:                []string,
    TRACY_ENABLE:           bool,
    HOT_RELOAD_CODE:        bool,
    HOT_RELOAD_ASSETS:      bool,
    ASSETS_PATH:            string,
}

init_engine :: proc(
    window_size: Vector2i, window_title: string, config: Config,
    base_address: uint, engine_memory_size, game_memory_size: int,
    allocator, temp_allocator: mem.Allocator,
) -> (^App, mem.Arena) {
    default_allocator := context.allocator;

    context.allocator = allocator;
    context.temp_allocator = temp_allocator;

    app_size_memory_size := engine_memory_size + game_memory_size + size_of(App) + size_of(^App);
    app_buffer, alloc_error := reserve_and_commit(uint(app_size_memory_size), rawptr(uintptr((base_address))));
    if alloc_error > .None {
        fmt.eprintf("Memory reserve/commit error: %v\n", alloc_error);
        os.exit(1);
    }

    app_arena := mem.Arena {};
    mem.arena_init(&app_arena, app_buffer);
    app_allocator := mem.Allocator { arena_allocator_proc, &app_arena };
    app_arena_name := new(Arena_Name, app_allocator);
    app_arena_name^ = .App;
    context.allocator = app_allocator;

    app := new(App, app_allocator);
    app.default_allocator = default_allocator;
    app.config = config;
    app.config.os_args = os.args;

    app.engine_allocator = make_arena_allocator(.Engine, engine_memory_size, &app.engine_arena, app_allocator, app);
    context.allocator = app.engine_allocator;

    app.logger = logger_create();
    default_logger : runtime.Logger;
    if contains_os_args("no-log") == false {
        options := log.Options { .Level, .Long_File_Path, .Line, .Terminal_Color };
        data := new(log.File_Console_Logger_Data);
        data.file_handle = os.INVALID_HANDLE;
        data.ident = "";
        console_logger := log.Logger { log.file_console_logger_proc, data, runtime.Logger_Level.Debug, options };
        default_logger = log.create_multi_logger(console_logger, app.logger.logger);
    }
    app.logger.logger = default_logger;
    context.logger = default_logger;

    app.debug = debug_init();

    log.debugf("Memory allocated:       %i", app_size_memory_size);
    log.debugf("- app_size:             %i", size_of(App));
    log.debugf("- engine_memory_size:   %i", engine_memory_size);
    log.debugf("- game_memory_size:     %i", game_memory_size);

    app.game_allocator = make_arena_allocator(.Game, game_memory_size, &app.game_arena, app_allocator, app);

    // app.temp_allocator = os.heap_allocator();
    app.temp_allocator = context.temp_allocator;

    platform, platform_ok := platform_init(app.engine_allocator, app.temp_allocator, app.config.TRACY_ENABLE);
    if platform_ok == false {
        log.error("Couldn't platform_init correctly.");
        os.exit(1);
    }
    app.platform = platform;

    open_window_ok := open_window(app.platform, window_title, window_size);
    if open_window_ok == false {
        log.error("Couldn't open_window correctly.");
        os.exit(1);
    }

    renderer, renderer_ok := renderer_init(app.platform.window, app.engine_allocator, app.config.TRACY_ENABLE);
    if renderer_ok == false {
        log.error("Couldn't renderer_init correctly.");
        os.exit(1);
    }
    app.renderer = renderer;

    ui, ui_ok := ui_init(app.renderer);
    if ui_ok == false {
        log.error("Couldn't renderer.ui_init correctly.");
        os.exit(1);
    }
    app.ui = ui;

    app.assets = new(Assets_State);
    app.assets.assets = make([]Asset, 200);
    root_directory := slashpath.dir(app.config.os_args[0], context.temp_allocator);
    app.assets.root_folder = slashpath.join({ root_directory, "/", app.config.ASSETS_PATH });

    assert(&app.engine_arena != nil, "engine_arena not initialized correctly!");
    assert(&app.game_arena != nil, "game_arena not initialized correctly!");
    assert(&app.engine_allocator != nil, "engine_allocator not initialized correctly!");
    assert(&app.temp_allocator != nil, "temp_allocator not initialized correctly!");
    assert(&app.game_allocator != nil, "game_allocator not initialized correctly!");
    assert(&app.logger != nil, "logger not initialized correctly!");
    assert(app.platform != nil, "platform not initialized correctly!");
    assert(app.renderer != nil, "renderer not initialized correctly!");
    assert(app.ui != nil, "ui not initialized correctly!");
    assert(app.debug != nil, "debug not initialized correctly!");
    assert(app.game == nil, "game not initialized correctly!");
    if contains_os_args("no-log") == false {
        assert(app.logger != nil, "logger not initialized correctly!");
    }

    return app, app_arena;
}
