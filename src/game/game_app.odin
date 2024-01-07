package game

import "core:fmt"
import "core:log"
import "core:mem"
import "core:runtime"
import engine "../engine_v2"
import "../tools"

// TODO: why not put engine in Game_State? Why not Zoidberg?!
App_Memory :: struct {
    engine:     rawptr,
    game:       ^Game_State,
}

@(private="package")
_mem: ^App_Memory

@(export) app_init :: proc() -> rawptr {
    context.allocator = runtime.default_allocator()
    _mem = new(App_Memory)
    _mem.engine = engine.init_and_open_window({ 1920, 1080 })

    // TODO: allocate Game_State with game.allocator?
    _mem.game = tools.mem_named_arena_virtual_bootstrap_new_or_panic(Game_State, "arena", 20 * mem.Megabyte, "game")
    tools.mem_make_named_arena(&_mem.game.game_mode.arena, "game_mode", 10 * mem.Megabyte)

    return _mem
}

@(export) app_update :: proc(app_memory: ^App_Memory) -> (quit: bool, reload: bool) {
    context.logger = engine.logger_get_logger()
    return game_update(app_memory)
}

@(export) app_reload :: proc(app_memory: ^App_Memory) {
    _mem = app_memory
    context.logger = engine.logger_get_logger()
    context.allocator = _mem.game.arena.allocator
    engine.reload(app_memory.engine)
    renderer_commands_init()
}

@(export) app_quit :: proc(app_memory: ^App_Memory) {
    context.logger = engine.logger_get_logger()
    engine.quit()
}
