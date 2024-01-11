package engine

import "core:log"
import "core:mem"
import "../tools"

Core_State :: struct {
    arena:                  tools.Named_Virtual_Arena,
    time_scale:             f32,
    debug_notification:     UI_Notification,
    code_version:           u32,
    file_watches:           [200]File_Watch,
    file_watches_count:     int,
}

@(private="package") _core: ^Core_State

@(private) core_init :: proc() -> (core_state: ^Core_State, ok: bool) #optional_ok {
    profiler_zone("core_init", PROFILER_COLOR_ENGINE)

    log.infof("Core -----------------------------------------------------")
    defer log_ok(ok)

    _core = tools.mem_named_arena_virtual_bootstrap_new_or_panic(Core_State, "arena", 1 * mem.Megabyte, "core")
    context.allocator = _core.arena.allocator

    _core.time_scale = TIME_SCALE

    core_state = _core
    ok = true
    return
}

@(private) core_reload :: proc(core_state: ^Core_State) {
    assert(core_state != nil)
    _core = core_state
    _core.code_version += 1
}

@(private) core_quit :: proc() {

}

get_time_scale :: proc() -> f32 {
    return _core.time_scale
}
set_time_scale :: proc(value: f32) {
    _core.time_scale = value
}

get_code_version :: proc() -> u32 {
    return _core.code_version
}
