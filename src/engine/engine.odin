package engine

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/slashpath"
import "core:runtime"

import tracy "../odin-tracy"

Engine_State :: struct {
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

@(private)
_engine: ^Engine_State

init_engine :: proc(
    window_size: Vector2i, window_title: string, config: Config,
    base_address: uint, engine_memory_size, game_memory_size: int,
    allocator := context.allocator, temp_allocator := context.temp_allocator,
) -> (^Engine_State, mem.Arena) {
    default_allocator := context.allocator

    context.allocator = allocator
    context.temp_allocator = temp_allocator

    if config.TRACY_ENABLE {
        profiler_set_thread_name("main")
        context.allocator = tracy.MakeProfiledAllocator(
            self              = &ProfiledAllocatorData {},
            callstack_size    = 5,
            backing_allocator = context.allocator,
            secure            = false,
        )
    }

    app_size_memory_size := engine_memory_size + game_memory_size + size_of(Engine_State) + size_of(^Engine_State)
    app_buffer, alloc_error := reserve_and_commit(uint(app_size_memory_size), rawptr(uintptr((base_address))))
    if alloc_error > .None {
        fmt.eprintf("Memory reserve/commit error: %v\n", alloc_error)
        os.exit(1)
    }

    app_arena := mem.Arena {}
    mem.arena_init(&app_arena, app_buffer)
    app_allocator := mem.Allocator { arena_allocator_proc, &app_arena }
    app_arena_name := new(Arena_Name, app_allocator)
    app_arena_name^ = .Engine_State
    context.allocator = app_allocator

    _engine = new(Engine_State, app_allocator)
    _engine.default_allocator = default_allocator
    _engine.config = config
    _engine.config.os_args = os.args

    _engine.engine_allocator = make_arena_allocator(.Engine_State, engine_memory_size, &_engine.engine_arena, app_allocator)
    context.allocator = _engine.engine_allocator

    if logger_init() == false {
        fmt.eprintf("Coundln't logger_init correctly.\n")
        os.exit(1)
    }
    default_logger : runtime.Logger
    if contains_os_args("no-log") == false {
        options := log.Options { .Level, /* .Long_File_Path, .Line, */ .Terminal_Color }
        data := new(log.File_Console_Logger_Data)
        data.file_handle = os.INVALID_HANDLE
        data.ident = ""
        console_logger := log.Logger { log.file_console_logger_proc, data, runtime.Logger_Level.Debug, options }
        default_logger = log.create_multi_logger(console_logger, _engine.logger.logger)
    }
    _engine.logger.logger = default_logger
    context.logger = default_logger

    _engine.debug = debug_init()

    log.infof("Memory allocated:")
    log.infof("| total:                %i", app_size_memory_size)
    log.infof("| app_size:             %i", size_of(Engine_State))
    log.infof("| engine_memory_size:   %i", engine_memory_size)
    log.infof("| game_memory_size:     %i", game_memory_size)
    log.infof("Config:")
    log.infof("| os_args:              %v", config.os_args)
    log.infof("| TRACY_ENABLE:         %v", config.TRACY_ENABLE)
    log.infof("| HOT_RELOAD_CODE:      %v", config.HOT_RELOAD_CODE)
    log.infof("| HOT_RELOAD_ASSETS:    %v", config.HOT_RELOAD_ASSETS)
    log.infof("| ASSETS_PATH:          %v", config.ASSETS_PATH)

    _engine.game_allocator = make_arena_allocator(.Game, game_memory_size, &_engine.game_arena, app_allocator)

    // _engine.temp_allocator = os.heap_allocator()
    _engine.temp_allocator = context.temp_allocator

    if platform_init(_engine.engine_allocator, _engine.temp_allocator, _engine.config.TRACY_ENABLE) == false {
        log.error("Couldn't platform_init correctly.")
        os.exit(1)
    }

    if open_window(_engine.platform, window_title, window_size) == false {
        log.error("Couldn't open_window correctly.")
        os.exit(1)
    }

    if renderer_init(_engine.platform.window, _engine.engine_allocator, _engine.config.TRACY_ENABLE) == false {
        log.error("Couldn't renderer_init correctly.")
        os.exit(1)
    }

    if ui_init() == false {
        log.error("Couldn't renderer.ui_init correctly.")
        os.exit(1)
    }

    _engine.assets = new(Assets_State)
    _engine.assets.assets = make([]Asset, 200)
    root_directory := "."
    if len(_engine.config.os_args) > 0 {
        root_directory = slashpath.dir(_engine.config.os_args[0], context.temp_allocator)
    }
    _engine.assets.root_folder = slashpath.join({ root_directory, "/", _engine.config.ASSETS_PATH })

    asset_init()

    assert(&_engine.engine_arena != nil, "engine_arena not initialized correctly!")
    assert(&_engine.game_arena != nil, "game_arena not initialized correctly!")
    assert(&_engine.engine_allocator != nil, "engine_allocator not initialized correctly!")
    assert(&_engine.temp_allocator != nil, "temp_allocator not initialized correctly!")
    assert(&_engine.game_allocator != nil, "game_allocator not initialized correctly!")
    assert(&_engine.logger != nil, "logger not initialized correctly!")
    assert(_engine.platform != nil, "platform not initialized correctly!")
    assert(_engine.renderer != nil, "renderer not initialized correctly!")
    assert(_engine.ui != nil, "ui not initialized correctly!")
    assert(_engine.debug != nil, "debug not initialized correctly!")
    assert(_engine.game == nil, "game not initialized correctly!")
    if contains_os_args("no-log") == false {
        assert(_engine.logger != nil, "logger not initialized correctly!")
    }

    return _engine, app_arena
}
