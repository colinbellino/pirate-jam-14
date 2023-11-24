package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/ease"
import "core:math/rand"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:sort"
import "core:time"
import "../tools"
import "../engine"

Engine_State :: engine.Engine_State
Logger_State :: engine.Logger_State
Assets_State :: engine.Assets_State

App_Memory :: struct {
    allocator:  mem.Allocator,
    arena:      virtual.Arena,
    logger:     ^Logger_State,
    assets:     ^Assets_State,
    engine:     ^Engine_State,
    game:       ^Game_State,
}

@(private="package")
_mem: ^App_Memory

@(export) app_init :: proc() -> rawptr {
    ok: bool
    engine.profiler_set_thread_name("main")
    _mem, context.allocator = engine.create_app_memory(App_Memory, 56 * mem.Megabyte)
    _mem.logger, ok = engine.logger_init()
    context.logger = ok ? _mem.logger.logger : log.nil_logger()
    _mem.assets, ok = engine.asset_init()
    _mem.engine = engine.engine_init({ 1920, 1080 }, NATIVE_RESOLUTION)

    // TODO: allocate Game_State with game.allocator
    _mem.game = new(Game_State)
    _mem.game.allocator = engine.platform_make_named_arena_allocator("game", 10 * mem.Megabyte, context.allocator)
    _mem.game.game_mode.allocator = engine.platform_make_named_arena_allocator("game_mode", 1000 * mem.Kilobyte, runtime.default_allocator())

    return _mem
}

// FIXME: free game state memory (in arena) when changing state
@(export) app_update :: proc(app_memory: ^App_Memory) -> (quit: bool, reload: bool) {
    return game_update(app_memory)
}

@(export) app_quit :: proc(app_memory: ^App_Memory) {
    engine.engine_quit()
}

@(export) app_reload :: proc(app_memory: ^App_Memory) {
    context.logger = app_memory.logger != nil ? app_memory.logger.logger : log.nil_logger()

    engine.asset_reload(app_memory.assets)
    engine.logger_reload(app_memory.logger)
    engine.engine_reload(app_memory.engine)
    engine.platform_reload(app_memory.engine.platform)
    engine.renderer_reload(app_memory.engine.renderer)
    engine.ui_create_notification("Game code reloaded.")
    log.debugf("Game code reloaded.")

    _mem = app_memory
}
