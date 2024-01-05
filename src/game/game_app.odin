package game

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:runtime"
import tracy "../odin-tracy"
import "../engine"
import e "../engine_v2"
import "../tools"

Logger_State :: engine.Logger_State
Assets_State :: engine.Assets_State
Entity_State :: engine.Entity_State
Audio_State :: engine.Audio_State
Animation_State :: engine.Animation_State
Core_State :: engine.Core_State

App_Memory :: struct {
    logger:     ^Logger_State,
    assets:     ^Assets_State,
    entity:     ^Entity_State,
    // renderer:   ^Renderer_State,
    // platform:   ^Platform_State,
    audio:      ^Audio_State,
    animation:  ^Animation_State,
    core:       ^Core_State,

    engine:     ^Engine_State,
    game:       ^Game_State,
}

@(private="package")
_mem: ^App_Memory

@(export) app_init :: proc() -> rawptr {
    _mem = new(App_Memory, runtime.default_allocator())
    _mem.engine = e.open_window({ 1920, 1080 })

    // TODO: allocate Game_State with game.allocator
    _mem.game = engine.mem_named_arena_virtual_bootstrap_new_or_panic(Game_State, "arena", mem.Megabyte, "game")
    engine.mem_make_named_arena(&_mem.game.game_mode.arena, "game_mode", mem.Megabyte)

    return _mem
}

@(export) app_update :: proc(app_memory: ^App_Memory) -> (quit: bool, reload: bool) {
    context.logger = engine.logger_get_logger()
    return game_update(app_memory)
}

@(export) app_reload :: proc(app_memory: ^App_Memory) {
    engine.logger_reload(app_memory.logger)
    context.logger = engine.logger_get_logger()
    engine.asset_reload(app_memory.assets)
    engine.entity_reload(app_memory.entity)
    // engine.platform_reload(app_memory.platform)
    // engine.renderer_reload(app_memory.renderer)
    e.init()
    engine.audio_reload(app_memory.audio)
    engine.animation_reload(app_memory.animation)
    engine.core_reload(app_memory.core)
    engine.ui_create_notification("Game code reloaded.")
    log.debugf("Game code reloaded.")

    _mem = app_memory
}

@(export) app_quit :: proc(app_memory: ^App_Memory) {
    context.logger = engine.logger_get_logger()

    e.quit()
    // engine.platform_quit()
    engine.renderer_quit()
    engine.audio_quit()
    engine.core_quit()
}
