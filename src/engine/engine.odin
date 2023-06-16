package engine

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/slashpath"
import "core:runtime"

import tracy "../odin-tracy"

TRACY_ENABLE        :: #config(TRACY_ENABLE, true)
ASSETS_PATH         :: #config(ASSETS_PATH, "../")
HOT_RELOAD_CODE     :: #config(HOT_RELOAD_CODE, true)
HOT_RELOAD_ASSETS   :: #config(HOT_RELOAD_ASSETS, true)

Engine_State :: struct {
    // FIXME: we probably don't need this many allocators and arenas
    default_allocator:      mem.Allocator,
    engine_allocator:       mem.Allocator,
    temp_allocator:         mem.Allocator,
    engine_arena:           mem.Arena,

    platform:               ^Platform_State,
    renderer:               ^Renderer_State,
    ui:                     ^UI_State,
    logger:                 ^Logger_State,
    debug:                  ^Debug_State,
    assets:                 ^Assets_State,
}

@(private)
_engine: ^Engine_State

engine_init :: proc(
    window_size: Vector2i, window_title: string,
    base_address: uint, engine_memory_size, game_memory_size: int,
    allocator := context.allocator, temp_allocator := context.temp_allocator,
) -> (^Engine_State, mem.Arena) {
    profiler_zone("engine_init")
    default_allocator := context.allocator

    context.allocator = allocator
    context.temp_allocator = temp_allocator

    if TRACY_ENABLE {
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
    app_arena_name^ = .Engine
    context.allocator = app_allocator

    _engine = new(Engine_State, app_allocator)
    _engine.default_allocator = default_allocator

    _engine.engine_allocator = make_arena_allocator(.Engine, engine_memory_size, &_engine.engine_arena, app_allocator)
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
    log.infof(" total:                %i", app_size_memory_size)
    log.infof(" app_size:             %i", size_of(Engine_State))
    log.infof(" engine_memory_size:   %i", engine_memory_size)
    log.infof(" game_memory_size:     %i", game_memory_size)
    log.infof("Config:")
    log.infof(" TRACY_ENABLE:         %v", TRACY_ENABLE)
    log.infof(" HOT_RELOAD_CODE:      %v", HOT_RELOAD_CODE)
    log.infof(" HOT_RELOAD_ASSETS:    %v", HOT_RELOAD_ASSETS)
    log.infof(" ASSETS_PATH:          %v", ASSETS_PATH)
    log.infof(" os.args:              %v", os.args)

    // _engine.temp_allocator = os.heap_allocator()
    _engine.temp_allocator = context.temp_allocator

    if platform_init(_engine.engine_allocator, _engine.temp_allocator, TRACY_ENABLE) == false {
        log.error("Couldn't platform_init correctly.")
        os.exit(1)
    }

    if asset_init() == false {
        log.error("Couldn't asset_init correctly.")
        os.exit(1)
    }

    // FIXME: Move this to engine.window_open
    {
        if open_window(_engine.platform, window_title, window_size) == false {
            log.error("Couldn't open_window correctly.")
            os.exit(1)
        }
        if renderer_init(_engine.platform.window, _engine.engine_allocator, TRACY_ENABLE) == false {
            log.error("Couldn't renderer_init correctly.")
            os.exit(1)
        }
        if ui_init() == false {
            log.error("Couldn't ui_init correctly.")
            os.exit(1)
        }
        assert(_engine.renderer != nil, "renderer not initialized correctly!")
        assert(_engine.ui != nil, "ui not initialized correctly!")
    }

    assert(&_engine.engine_arena != nil, "engine_arena not initialized correctly!")
    assert(&_engine.engine_allocator != nil, "engine_allocator not initialized correctly!")
    assert(&_engine.temp_allocator != nil, "temp_allocator not initialized correctly!")
    assert(&_engine.logger != nil, "logger not initialized correctly!")
    assert(_engine.platform != nil, "platform not initialized correctly!")
    assert(_engine.debug != nil, "debug not initialized correctly!")
    if contains_os_args("no-log") == false {
        assert(_engine.logger != nil, "logger not initialized correctly!")
    }

    return _engine, app_arena
}
