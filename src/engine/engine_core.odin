package engine

import "core:fmt"
import "core:log"
import "core:mem"
import "core:runtime"
import "core:mem/virtual"
import "core:os"

Core_State :: struct {
    allocator:              mem.Allocator,
    time_scale:             f32,
    file_watches:           [200]File_Watch,
    file_watches_count:     int,
}

ASSETS_PATH             :: #config(ASSETS_PATH, "./")
HOT_RELOAD_CODE         :: #config(HOT_RELOAD_CODE, ODIN_DEBUG)
HOT_RELOAD_ASSETS       :: #config(HOT_RELOAD_ASSETS, ODIN_DEBUG)
LOG_ALLOC               :: #config(LOG_ALLOC, false)
IN_GAME_LOGGER          :: #config(IN_GAME_LOGGER, ODIN_DEBUG)
GPU_PROFILER            :: #config(GPU_PROFILER, false)
RENDERER                :: Renderers(#config(RENDERER, Renderers.OpenGL))
IMGUI_ENABLE            :: #config(IMGUI_ENABLE, ODIN_DEBUG && RENDERER != .None)
IMGUI_GAME_VIEW         :: #config(IMGUI_GAME_VIEW, false)
TRACY_ENABLE            :: #config(TRACY_ENABLE, false)
CORE_ARENA_SIZE         :: mem.Megabyte

@(private="package")
_core: ^Core_State

core_init :: proc(allocator := context.allocator) -> (core_state: ^Core_State, ok: bool) #optional_ok {
    profiler_zone("core_init", PROFILER_COLOR_ENGINE)
    context.logger = logger_get_logger()

    _core = new(Core_State, allocator)
    _core.allocator = platform_make_named_arena_allocator("core", CORE_ARENA_SIZE, runtime.default_allocator())
    _core.time_scale = 1
    context.allocator = _core.allocator

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
    defer log_ok(ok)

    core_state = _core
    ok = true
    return
}

core_reload :: proc(core_state: ^Core_State) {
    assert(core_state != nil)
    _core = core_state
}

core_quit :: proc() {

}
