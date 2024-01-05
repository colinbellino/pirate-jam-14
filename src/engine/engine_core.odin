package engine

import "core:fmt"
import "core:log"
import "core:mem"
import "core:runtime"
import "core:mem/virtual"
import "core:os"
import "../tools"

Core_State :: struct {
    arena:                  Named_Virtual_Arena,
    time_scale:             f32,
    file_watches:           [200]File_Watch,
    file_watches_count:     int,
}

ASSETS_PATH             :: #config(ASSETS_PATH, "./")
HOT_RELOAD_CODE         :: #config(HOT_RELOAD_CODE, ODIN_DEBUG)
HOT_RELOAD_ASSETS       :: #config(HOT_RELOAD_ASSETS, ODIN_DEBUG)
LOG_ALLOC               :: #config(LOG_ALLOC, tools.LOG_ALLOC)
LOGGER_ENABLE           :: #config(LOGGER_ENABLE, ODIN_DEBUG)
IN_GAME_LOGGER          :: #config(IN_GAME_LOGGER, ODIN_DEBUG)
GPU_PROFILER            :: #config(GPU_PROFILER, false)
RENDERER                :: Renderers(#config(RENDERER, Renderers.Sokol))
IMGUI_ENABLE            :: #config(IMGUI_ENABLE, ODIN_DEBUG && RENDERER != .None)
IMGUI_GAME_VIEW         :: #config(IMGUI_GAME_VIEW, false)
TRACY_ENABLE            :: #config(TRACY_ENABLE, false)
TIME_SCALE              :: #config(TIME_SCALE, 1)
CORE_ARENA_SIZE         :: mem.Megabyte

Named_Virtual_Arena                             :: tools.Named_Virtual_Arena
mem_named_arena_virtual_bootstrap_new_or_panic  :: tools.mem_named_arena_virtual_bootstrap_new_or_panic
mem_named_arena_virtual_bootstrap_new_by_name   :: tools.mem_named_arena_virtual_bootstrap_new_by_name
mem_make_named_arena                            :: tools.mem_make_named_arena
mem_zero_named_arena                            :: tools.mem_zero_named_arena

@(private="package") _core: ^Core_State

core_init :: proc() -> (core_state: ^Core_State, ok: bool) #optional_ok {
    profiler_zone("core_init", PROFILER_COLOR_ENGINE)

    log.infof("Core init ------------------------------------------------")
    defer log_ok(ok)

    _core = mem_named_arena_virtual_bootstrap_new_or_panic(Core_State, "arena", CORE_ARENA_SIZE, "core")
    context.allocator = _core.arena.allocator

    _core.time_scale = TIME_SCALE

    log.infof("  IN_GAME_LOGGER:       %v", IN_GAME_LOGGER)
    log.infof("  GPU_PROFILER:         %v", GPU_PROFILER)
    log.infof("  TRACY_ENABLE:         %v", TRACY_ENABLE)
    log.infof("  IMGUI_ENABLE:         %v", IMGUI_ENABLE)
    log.infof("  RENDERER_DEBUG:       %v", RENDERER_DEBUG)
    log.infof("  HOT_RELOAD_CODE:      %v", HOT_RELOAD_CODE)
    log.infof("  HOT_RELOAD_ASSETS:    %v", HOT_RELOAD_ASSETS)
    log.infof("  ASSETS_PATH:          %v", ASSETS_PATH)
    log.infof("  os.args:              %v", os.args)

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
