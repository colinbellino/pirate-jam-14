package engine

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"

ASSETS_PATH             :: #config(ASSETS_PATH, "../")
HOT_RELOAD_CODE         :: #config(HOT_RELOAD_CODE, true)
HOT_RELOAD_ASSETS       :: #config(HOT_RELOAD_ASSETS, true)
LOG_ALLOC               :: #config(LOG_ALLOC, false)
IN_GAME_LOGGER          :: #config(IN_GAME_LOGGER, false)
RENDERER                :: Renderers(#config(RENDERER, Renderers.OpenGL))
MEM_ENGINE_SIZE         :: 24 * mem.Megabyte

Engine_State :: struct {
    allocator:              mem.Allocator,
    temp_allocator:         mem.Allocator,

    platform:               ^Platform_State,
    renderer:               ^Renderer_State,
    logger:                 ^Logger_State,
    debug:                  ^Debug_State,
    assets:                 ^Assets_State,
}

@(private)
_engine: ^Engine_State

engine_init :: proc(allocator: mem.Allocator) -> ^Engine_State {
    profiler_set_thread_name("main")
    profiler_zone("engine_init")

    context.allocator = allocator

    engine := new(Engine_State)
    _engine = engine

    // _engine.main_allocator = main_allocator
    _engine.allocator = allocator
    _engine.temp_allocator = context.temp_allocator

    if logger_init() == false {
        fmt.eprintf("Coundln't logger_init correctly.\n")
        os.exit(1)
    }
    // default_logger : runtime.Logger
    // if IN_GAME_LOGGER {
    //     options := log.Options { .Level, /* .Long_File_Path, .Line, */ .Terminal_Color }
    //     data := new(log.File_Console_Logger_Data)
    //     data.file_handle = os.INVALID_HANDLE
    //     data.ident = ""
    //     console_logger := log.Logger { log.file_console_logger_proc, data, runtime.Logger_Level.Debug, options }
    //     default_logger = log.create_multi_logger(console_logger, _engine.logger.logger)
    // }
    // _engine.logger.logger = default_logger
    // context.logger = default_logger

    if debug_init() == false {
        fmt.eprintf("Coundln't debug_init correctly.\n")
        os.exit(1)
    }

    log.infof("Engine init ------------------------------------------------")
    log.infof("  MEM_ENGINE_SIZE:      %i", MEM_ENGINE_SIZE)
    log.infof("  PROFILER:             %v", PROFILER)
    log.infof("  RENDERER_DEBUG:       %v", RENDERER_DEBUG)
    log.infof("  HOT_RELOAD_CODE:      %v", HOT_RELOAD_CODE)
    log.infof("  HOT_RELOAD_ASSETS:    %v", HOT_RELOAD_ASSETS)
    log.infof("  ASSETS_PATH:          %v", ASSETS_PATH)
    log.infof("  os.args:              %v", os.args)

    if platform_init() == false {
        log.error("Couldn't platform_init correctly.")
        os.exit(1)
    }

    if asset_init() == false {
        log.error("Couldn't asset_init correctly.")
        os.exit(1)
    }

    assert(&_engine.allocator != nil, "allocator not initialized correctly!")
    assert(&_engine.logger != nil, "logger not initialized correctly!")
    assert(_engine.platform != nil, "platform not initialized correctly!")
    assert(_engine.debug != nil, "debug not initialized correctly!")
    if IN_GAME_LOGGER {
        assert(_engine.logger != nil, "logger not initialized correctly!")
    }

    return engine
}

engine_reload :: proc(engine: ^Engine_State) {
    _engine = engine
    renderer_reload(engine.renderer)
}
