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

App_Memory :: struct {
    allocator:  mem.Allocator,
    arena:      virtual.Arena,
    engine:     ^Engine_State,
    logger:     ^Logger_State,
    game:       ^Game_State,
}

@(private="package")
_mem: ^App_Memory

@(export) app_init :: proc() -> rawptr {
    ok: bool
    _mem, context.allocator = engine.create_app_memory(App_Memory, 56 * mem.Megabyte)
    _mem.logger, ok = engine.logger_init()
    context.logger = ok ? _mem.logger.logger : log.nil_logger()
    _mem.engine = engine.engine_init({ 1920, 1080 }, NATIVE_RESOLUTION)

    // TODO: allocate Game_State with game.allocator
    _mem.game = new(Game_State)
    _mem.game.allocator = engine.platform_make_named_arena_allocator("game", 10 * mem.Megabyte)
    _mem.game.game_mode.allocator = engine.platform_make_named_arena_allocator("game_mode", 1000 * mem.Kilobyte, runtime.default_allocator())

    return _mem
}

// FIXME: free game state memory (in arena) when changing state
@(export) app_update :: proc(app_memory: ^App_Memory) -> (quit: bool, reload: bool) {
    return game_update(app_memory)
}

@(export) app_quit :: proc(app_memory: ^App_Memory) {
    context.logger = _mem.logger != nil ? _mem.logger.logger : log.nil_logger()
    engine.engine_quit()
}

@(export) app_reload :: proc(app_memory: ^App_Memory) {
    _mem = app_memory
    engine.engine_reload(_mem.engine)
}
