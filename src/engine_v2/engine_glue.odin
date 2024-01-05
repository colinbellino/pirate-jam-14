package engine_v2

import "core:c"
import "core:fmt"
import "core:log"
import "core:math/linalg"
import "core:mem"
import "core:runtime"
import "core:strings"
import "../tools"

Glue_State :: struct {
    logger:     ^Logger_State,
    core:       ^Core_State,
    platform:   ^Platform_State,
    assets:     ^Assets_State,
    entity:     ^Entity_State,
    animation:  ^Animation_State,
    audio:      ^Audio_State,
    // renderer:   ^Renderer_State,
}

// FIXME: check if we still use all those
ASSETS_PATH             :: #config(ASSETS_PATH, "./")
HOT_RELOAD_CODE         :: #config(HOT_RELOAD_CODE, ODIN_DEBUG)
HOT_RELOAD_ASSETS       :: #config(HOT_RELOAD_ASSETS, ODIN_DEBUG)
LOG_ALLOC               :: #config(LOG_ALLOC, tools.LOG_ALLOC)
LOGGER_ENABLE           :: #config(LOGGER_ENABLE, ODIN_DEBUG)
IN_GAME_LOGGER          :: #config(IN_GAME_LOGGER, ODIN_DEBUG)
GPU_PROFILER            :: #config(GPU_PROFILER, false)
IMGUI_ENABLE            :: #config(IMGUI_ENABLE, true)
IMGUI_GAME_VIEW         :: #config(IMGUI_GAME_VIEW, false)
TRACY_ENABLE            :: #config(TRACY_ENABLE, false)
TIME_SCALE              :: #config(TIME_SCALE, 1)

@(private) _glue: ^Glue_State

init_and_open_window :: proc(window_size: Vector2i32, allocator := context.allocator) -> rawptr {
    _glue = new(Glue_State, allocator)
    _glue.logger = logger_init()
    context.logger = logger_get_logger()
    _glue.core = core_init()
    _glue.platform = platform_init()
    _glue.assets = asset_init()
    _glue.entity = entity_init()
    _glue.animation = animation_init()
    _glue.audio = audio_init()

    open_window(window_size)
    gl_init()
    sokol_init()
    ui_init(_glue.platform.window, _glue.platform.gl_context)

    return _glue
}

reload :: proc(glue_ptr: rawptr) {
    _glue = cast(^Glue_State) glue_ptr

    logger_reload(_glue.logger)
    context.logger = logger_get_logger()
    log.debugf("Reload started. --------------------------------------------")

    asset_reload(_glue.assets)
    entity_reload(_glue.entity)
    platform_reload(_glue.platform)
    // renderer_reload(_glue.renderer)
    audio_reload(_glue.audio)
    animation_reload(_glue.animation)
    core_reload(_glue.core)

    gl_init()
    sokol_init()
    ui_init(_glue.platform.window, _glue.platform.gl_context)

    ui_create_notification("Game code reloaded.")
    log.debugf("Reload ended. ---------------------------------------------")
}

quit :: proc() {
    ui_quit()
    sokol_quit()
}

frame_begin :: proc() {
    platform_frame_begin()
    ui_frame_begin()
}

frame_end :: proc() {
    ui_frame_end()
    platform_frame_end()
}

@(private) sokol_alloc_fn :: proc "c" (size: u64, user_data: rawptr) -> rawptr {
    context = runtime.default_context()
    ptr, err := mem.alloc(int(size))
    if err != .None { log.errorf("sokol_alloc_fn: %v", err) }
    return ptr
}

@(private) sokol_free_fn :: proc "c" (ptr: rawptr, user_data: rawptr) {
    context = runtime.default_context()
    err := mem.free(ptr)
    if err != .None { log.errorf("sokol_free_fn: %v", err) }
}
