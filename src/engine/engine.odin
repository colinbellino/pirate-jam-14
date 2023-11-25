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
    allocator:              mem.Allocator,
    platform:               ^Platform_State,
    audio:                  ^Audio_State,
    debug:                  ^Debug_State,
    animation:              ^Animation_State,
    time_scale:             f32,
    ctx:                    runtime.Context,
}

@(private="package")
_e: ^Engine_State

create_app_memory :: proc($T: typeid, reserved: uint) -> (^T, mem.Allocator) {
    app_memory, mem_error := platform_make_virtual_arena(T, "arena", reserved)
    if mem_error != .None {
        fmt.panicf("Couldn't create main arena: %v\n", mem_error)
    }
    return app_memory, app_memory.allocator
}

engine_init :: proc() -> ^Engine_State {
    profiler_zone("engine_init", PROFILER_COLOR_ENGINE)
    context.logger = logger_get_logger()

    _e = new(Engine_State)
    _e.allocator = platform_make_named_arena_allocator("engine", 24 * mem.Megabyte, context.allocator)
    context.allocator = _e.allocator

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
    audio_init()
    debug_init()

    animation_init()

    _e.time_scale = 1

    return _e
}

engine_reload :: proc(engine: ^Engine_State) {
    _e = engine
}

engine_quit :: proc() {
    context.logger = logger_get_logger()
    platform_quit()
    renderer_quit()
    audio_quit()
}
