package engine

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"

import tracy "../odin-tracy"

TRACY_ENABLE        :: #config(TRACY_ENABLE, true)
ASSETS_PATH         :: #config(ASSETS_PATH, "../")
HOT_RELOAD_CODE     :: #config(HOT_RELOAD_CODE, true)
HOT_RELOAD_ASSETS   :: #config(HOT_RELOAD_ASSETS, true)
LOG_ALLOC           :: #config(LOG_ALLOC, false)
IN_GAME_LOGGER      :: #config(IN_GAME_LOGGER, false)
RENDERER            :: Renderers(#config(RENDERER, Renderers.OpenGL))
MEM_ENGINE_SIZE     :: 1 * mem.Megabyte

Engine_State :: struct {
    main_allocator:         mem.Allocator,
    arena_allocator:        mem.Allocator,
    arena:                  ^mem.Arena,

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
    base_address: uint, game_memory_size: uint,
    allocator := context.allocator, temp_allocator := context.temp_allocator,
) -> (^Engine_State) {
    profiler_zone("engine_init")

    main_allocator := context.allocator

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

    total_memory_size := MEM_ENGINE_SIZE + game_memory_size
    app_buffer, alloc_error := platform_reserve_and_commit(total_memory_size, rawptr(uintptr((base_address))))
    if alloc_error > .None {
        fmt.eprintf("Memory reserve/commit error: %v\n", alloc_error)
        os.exit(1)
    }

    main_arena := mem.Arena {}
    mem.arena_init(&main_arena, app_buffer)
    main_arena_allocator := mem.Allocator { platform_arena_allocator_proc, &main_arena }
    app_arena_name := new(Arena_Name, main_arena_allocator)
    app_arena_name^ = .App

    engine_arena := new(mem.Arena, main_arena_allocator)
    engine_arena_allocator := platform_make_arena_allocator(.Engine, MEM_ENGINE_SIZE, engine_arena, main_arena_allocator)

    _engine = new(Engine_State, engine_arena_allocator)
    _engine.main_allocator = main_allocator
    _engine.arena_allocator = engine_arena_allocator
    _engine.arena = engine_arena

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

    log.infof("Memory allocated -------------------------------------")
    log.infof("  total:                %i", total_memory_size)
    log.infof("  engine_memory_size:   %i", MEM_ENGINE_SIZE)
    log.infof("  game_memory_size:     %i", game_memory_size)
    log.infof("Config -----------------------------------------------")
    log.infof("  TRACY_ENABLE:         %v", TRACY_ENABLE)
    log.infof("  HOT_RELOAD_CODE:      %v", HOT_RELOAD_CODE)
    log.infof("  HOT_RELOAD_ASSETS:    %v", HOT_RELOAD_ASSETS)
    log.infof("  ASSETS_PATH:          %v", ASSETS_PATH)
    log.infof("  os.args:              %v", os.args)

    if platform_init(_engine.arena_allocator, context.temp_allocator, TRACY_ENABLE) == false {
        log.error("Couldn't platform_init correctly.")
        os.exit(1)
    }

    if asset_init() == false {
        log.error("Couldn't asset_init correctly.")
        os.exit(1)
    }

    assert(&_engine.arena_allocator != nil, "arena_allocator not initialized correctly!")
    assert(&_engine.logger != nil, "logger not initialized correctly!")
    assert(_engine.platform != nil, "platform not initialized correctly!")
    assert(_engine.debug != nil, "debug not initialized correctly!")
    if IN_GAME_LOGGER {
        assert(_engine.logger != nil, "logger not initialized correctly!")
    }

    return _engine
}
