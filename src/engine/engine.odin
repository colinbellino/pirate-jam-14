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
RENDERER                :: #config(RENDERER, Renderers.OpenGL)
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

@(private="package")
_e: ^Engine_State

engine_init :: proc(allocator: mem.Allocator) -> ^Engine_State {
    profiler_set_thread_name("main")
    profiler_zone("engine_init")

    context.allocator = allocator

    engine := new(Engine_State)
    _e = engine

    // _e.main_allocator = main_allocator
    _e.allocator = allocator
    _e.temp_allocator = context.temp_allocator

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
    //     default_logger = log.create_multi_logger(console_logger, _e.logger.logger)
    // }
    // _e.logger.logger = default_logger
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

    assert(&_e.allocator != nil, "allocator not initialized correctly!")
    assert(&_e.logger != nil, "logger not initialized correctly!")
    assert(_e.platform != nil, "platform not initialized correctly!")
    assert(_e.debug != nil, "debug not initialized correctly!")
    if IN_GAME_LOGGER {
        assert(_e.logger != nil, "logger not initialized correctly!")
    }

    return engine
}

engine_reload :: proc(engine: ^Engine_State) {
    _e = engine
    platform_reload(engine.platform)
    renderer_reload(engine.renderer)
}
