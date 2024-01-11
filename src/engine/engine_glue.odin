package engine

import "core:runtime"
import "core:os"
import "core:mem"
import "core:log"
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

ASSETS_PATH             :: #config(ASSETS_PATH, "./")
HOT_RELOAD_CODE         :: #config(HOT_RELOAD_CODE, ODIN_DEBUG)
HOT_RELOAD_ASSETS       :: #config(HOT_RELOAD_ASSETS, ODIN_DEBUG)
LOG_ALLOC               :: #config(LOG_ALLOC, tools.LOG_ALLOC)
LOGGER_ENABLE           :: #config(LOGGER_ENABLE, ODIN_DEBUG)
IN_GAME_LOGGER          :: #config(IN_GAME_LOGGER, ODIN_DEBUG)
IMGUI_ENABLE            :: #config(IMGUI_ENABLE, true)
TRACY_ENABLE            :: #config(TRACY_ENABLE, false)
TIME_SCALE              :: #config(TIME_SCALE, 1)
RENDERER_ENABLE         :: #config(RENDERER_ENABLE, true)

@(private) _glue: ^Glue_State

init_and_open_window :: proc(window_size: Vector2i32, allocator := context.allocator) -> rawptr {
    log.infof("  IN_GAME_LOGGER:       %v", IN_GAME_LOGGER)
    log.infof("  TRACY_ENABLE:         %v", TRACY_ENABLE)
    log.infof("  IMGUI_ENABLE:         %v", IMGUI_ENABLE)
    log.infof("  HOT_RELOAD_CODE:      %v", HOT_RELOAD_CODE)
    log.infof("  HOT_RELOAD_ASSETS:    %v", HOT_RELOAD_ASSETS)
    log.infof("  ASSETS_PATH:          %v", ASSETS_PATH)
    log.infof("  os.args:              %v", os.args)

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
    r_sokol_init()
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
    audio_reload(_glue.audio)
    animation_reload(_glue.animation)
    core_reload(_glue.core)

    gl_init()
    r_sokol_init()
    ui_init(_glue.platform.window, _glue.platform.gl_context)

    ui_create_notification("Game code reloaded.")
    log.debugf("Reload ended. ---------------------------------------------")
}

quit :: proc() {
    ui_quit()
    r_sokol_quit()
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

ui_widget_arenas :: proc() {
    ui_memory_arena_progress(&_glue.core.arena)
    ui_memory_arena_progress(&_glue.platform.arena)
    if audio_is_enabled() {
        ui_memory_arena_progress(&_glue.audio.arena)
    }
    if _glue.assets != nil {
        ui_memory_arena_progress(&_glue.assets.arena)
    }
    if _glue.entity != nil {
        ui_memory_arena_progress(&_glue.entity.arena)
        ui_memory_arena_progress(&_glue.entity.internal_arena)
    }
    if _glue.animation != nil {
        ui_memory_arena_progress(&_glue.animation.arena)
    }
    if _glue.logger != nil {
        ui_memory_arena_progress(&_glue.logger.arena)
        ui_memory_arena_progress(&_glue.logger.internal_arena)
    }
}
