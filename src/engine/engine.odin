package engine

import "core:fmt"
import "core:log"
import "core:mem"
import "core:runtime"
import "core:mem/virtual"
import "core:os"

ASSETS_PATH             :: #config(ASSETS_PATH, "./")
HOT_RELOAD_CODE         :: #config(HOT_RELOAD_CODE, ODIN_DEBUG)
HOT_RELOAD_ASSETS       :: #config(HOT_RELOAD_ASSETS, ODIN_DEBUG)
LOG_ALLOC               :: #config(LOG_ALLOC, false)
IN_GAME_LOGGER          :: #config(IN_GAME_LOGGER, ODIN_DEBUG)
GPU_PROFILER            :: #config(GPU_PROFILER, false)
IMGUI_ENABLE            :: #config(IMGUI_ENABLE, ODIN_DEBUG)
IMGUI_GAME_VIEW         :: #config(IMGUI_GAME_VIEW, false)
TRACY_ENABLE            :: #config(TRACY_ENABLE, false)
RENDERER                :: Renderers(#config(RENDERER, Renderers.OpenGL))

Engine_State :: struct {
    arena:                  virtual.Arena,
    allocator:              mem.Allocator,
    platform:               ^Platform_State,
    renderer:               ^Renderer_State,
    audio:                  ^Audio_State,
    logger:                 ^Logger_State,
    debug:                  ^Debug_State,
    assets:                 ^Assets_State,
    animation:              ^Animation_State,
    entity:                 ^Entity_State,
    time_scale:             f32,
    ctx:                    runtime.Context,
}

@(private="package")
_e: ^Engine_State

engine_init :: proc(window_size: Vector2i32, native_resolution: Vector2f32, memory_size: uint) -> ^Engine_State {
    profiler_set_thread_name("main")
    profiler_zone("engine_init", PROFILER_COLOR_ENGINE)

    err: mem.Allocator_Error
    _e, err = platform_make_virtual_arena("engine_arena", Engine_State, memory_size)
    if err != .None {
        fmt.eprintf("Couldn't create engine arena: %v\n", err)
        os.exit(1)
    }
    context.allocator = _e.allocator

    logger_init()
    context.logger = _e.logger.logger

    _e.ctx = context

    log.infof("Engine init ------------------------------------------------")
    log.infof("  IN_GAME_LOGGER:       %v", IN_GAME_LOGGER)
    log.infof("  GPU_PROFILER:         %v", GPU_PROFILER)
    log.infof("  TRACY_ENABLE:         %v", TRACY_ENABLE)
    log.infof("  IMGUI_ENABLE:         %v", IMGUI_ENABLE)
    log.infof("  RENDERER_DEBUG:       %v", RENDERER_DEBUG)
    log.infof("  HOT_RELOAD_CODE:      %v", HOT_RELOAD_CODE)
    log.infof("  HOT_RELOAD_ASSETS:    %v", HOT_RELOAD_ASSETS)
    log.infof("  ASSETS_PATH:          %v", ASSETS_PATH)
    log.infof("  os.args:              %v", os.args)

    if platform_init() == false {
        os.exit(1)
    }
    if asset_init() == false {
        os.exit(1)
    }
    audio_init()
    debug_init()

    if _platform_open_window(window_size, native_resolution) == false {
        log.error("Couldn't open game window.")
        os.exit(1)
    }

    animation_init()
    entity_init()

    _e.time_scale = 1

    return _e
}

engine_reload :: proc(engine: ^Engine_State) {
    _e = engine
    platform_reload(engine.platform)
    renderer_reload(engine.renderer)
    ui_create_notification("Game reloaded.")
}

engine_quit :: proc() {
    platform_quit()
    renderer_quit()
    audio_quit()
}
