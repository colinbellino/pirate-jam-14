package engine_v2

import "core:c"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:mem"
import "core:runtime"
import "core:strings"
import "core:os"
import gl "vendor:OpenGL"
import "../tools"

Core_State :: struct {
    arena:                  tools.Named_Virtual_Arena,
    time_scale:             f32,
    file_watches:           [200]File_Watch,
    file_watches_count:     int,
}

@(private="package") _core: ^Core_State

@(private) core_init :: proc() -> (core_state: ^Core_State, ok: bool) #optional_ok {
    profiler_zone("core_init", PROFILER_COLOR_ENGINE)

    log.infof("Core init ------------------------------------------------")
    defer log_ok(ok)

    _core = tools.mem_named_arena_virtual_bootstrap_new_or_panic(Core_State, "arena", 1 * mem.Megabyte, "core")
    context.allocator = _core.arena.allocator

    _core.time_scale = TIME_SCALE

    log.infof("  IN_GAME_LOGGER:       %v", IN_GAME_LOGGER)
    log.infof("  GPU_PROFILER:         %v", GPU_PROFILER)
    log.infof("  TRACY_ENABLE:         %v", TRACY_ENABLE)
    log.infof("  IMGUI_ENABLE:         %v", IMGUI_ENABLE)
    log.infof("  HOT_RELOAD_CODE:      %v", HOT_RELOAD_CODE)
    log.infof("  HOT_RELOAD_ASSETS:    %v", HOT_RELOAD_ASSETS)
    log.infof("  ASSETS_PATH:          %v", ASSETS_PATH)
    log.infof("  os.args:              %v", os.args)

    core_state = _core
    ok = true
    return
}

@(private) core_reload :: proc(core_state: ^Core_State) {
    assert(core_state != nil)
    _core = core_state
}

@(private) core_quit :: proc() {

}

// FIXME: i don't like that we send back a reference to the time scale that everyone can change... But do i like this better than creating a set_time_scale proc, not sure...
get_time_scale :: proc() -> ^f32 {
    return &_core.time_scale
}
