package game

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:runtime"
import "../engine"

Logger_State :: engine.Logger_State
Assets_State :: engine.Assets_State
Entity_State :: engine.Entity_State
Renderer_State :: engine.Renderer_State
Platform_State :: engine.Platform_State
Audio_State :: engine.Audio_State
Animation_State :: engine.Animation_State
Core_State :: engine.Core_State

App_Memory :: struct {
    allocator:  mem.Allocator,
    arena:      virtual.Arena,
    logger:     ^Logger_State,
    assets:     ^Assets_State,
    entity:     ^Entity_State,
    renderer:   ^Renderer_State,
    platform:   ^Platform_State,
    audio:      ^Audio_State,
    animation:  ^Animation_State,
    core:       ^Core_State,
    game:       ^Game_State,
}

@(private="package")
_mem: ^App_Memory

@(export) app_init :: proc() -> rawptr {
    ok: bool
    engine.profiler_set_thread_name("main")
    _mem, context.allocator = engine.create_app_memory(App_Memory, 56 * mem.Megabyte)
    _mem.logger = engine.logger_init()
    context.logger = engine.logger_get_logger()
    _mem.assets = engine.asset_init()
    _mem.entity = engine.entity_init()
    _mem.platform = engine.platform_init()
    _mem.audio = engine.audio_init()
    _mem.animation = engine.animation_init()
    _mem.core = engine.core_init()
    engine.platform_open_window({ 1920, 1080 })
    _mem.renderer = engine.renderer_init(_mem.platform.window, NATIVE_RESOLUTION)

    // TODO: allocate Game_State with game.allocator
    _mem.game = new(Game_State)
    _mem.game.allocator = engine.platform_make_named_arena_allocator("game", mem.Megabyte, context.allocator)
    _mem.game.game_mode.allocator = engine.platform_make_named_arena_allocator("game_mode", mem.Megabyte, runtime.default_allocator())

    return _mem
}

@(export) app_update :: proc(app_memory: ^App_Memory) -> (quit: bool, reload: bool) {
    context.logger = engine.logger_get_logger()
    return game_update(app_memory)
}

@(export) app_reload :: proc(app_memory: ^App_Memory) {
    context.logger = engine.logger_get_logger()

    engine.asset_reload(app_memory.assets)
    engine.logger_reload(app_memory.logger)
    engine.entity_reload(app_memory.entity)
    engine.platform_reload(app_memory.platform)
    engine.renderer_reload(app_memory.renderer)
    engine.audio_reload(app_memory.audio)
    engine.core_reload(app_memory.core)
    engine.ui_create_notification("Game code reloaded.")
    log.debugf("Game code reloaded.")

    _mem = app_memory
}

@(export) app_quit :: proc(app_memory: ^App_Memory) {
    context.logger = engine.logger_get_logger()

    engine.platform_quit()
    engine.renderer_quit()
    engine.audio_quit()
    engine.core_quit()
}
