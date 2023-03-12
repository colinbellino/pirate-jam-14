package engine

import "core:dynlib"
import "core:log"
import "core:time"

@(private="file") _game_library: dynlib.Library;
@(private="file") _game_load_timestamp: time.Time;
@(private) _game_update_proc := rawptr(_game_update_proc_stub);
@(private) _game_fixed_update_proc := rawptr(_game_update_proc_stub);
@(private) _game_render_proc := rawptr(_game_update_proc_stub);

code_bind :: proc(game_update_proc, game_fixed_update_proc, game_render_proc: rawptr) {
    _game_update_proc = game_update_proc;
    _game_fixed_update_proc = game_fixed_update_proc;
    _game_render_proc = game_render_proc;
}

code_is_newer :: proc(timestamp: time.Time) -> bool {
    return time.diff(_game_load_timestamp, timestamp) > 0;
}

code_load :: proc(path: string) -> (bool) {
    game_library, load_success := dynlib.load_library(path);
    if load_success == false {
        // log.errorf("%v not loaded.", path);
        return false;
    }

    if _game_library != nil {
        unload_success := dynlib.unload_library(_game_library);
        assert(unload_success);
        _game_library = nil;
        _game_update_proc = rawptr(_game_update_proc_stub);
        _game_fixed_update_proc = rawptr(_game_update_proc_stub);
        _game_render_proc = rawptr(_game_update_proc_stub);
        log.debug("game.bin unloaded.");
    }

    _game_update_proc = dynlib.symbol_address(game_library, "game_update");
    assert(_game_update_proc != nil, "game_update can't be nil.");
    assert(_game_update_proc != rawptr(_game_update_proc_stub), "game_update can't be a stub.");

    _game_fixed_update_proc = dynlib.symbol_address(game_library, "game_fixed_update");
    assert(_game_fixed_update_proc != nil, "game_fixed_update can't be nil.");
    assert(_game_fixed_update_proc != rawptr(_game_update_proc_stub), "game_fixed_update can't be a stub.");

    _game_render_proc = dynlib.symbol_address(game_library, "game_render");
    assert(_game_render_proc != nil, "game_render can't be nil.");
    assert(_game_render_proc != rawptr(_game_update_proc_stub), "game_render can't be a stub.");

    _game_load_timestamp = time.now();
    _game_library = game_library;

    log.debugf("%v loaded: %v, %v, %v, %v.", path, _game_library, _game_update_proc, _game_fixed_update_proc, _game_render_proc);
    return true;
}

@(private="file")
_game_update_proc_stub : Update_Proc : proc(delta_time: f64, app: ^App) {
    log.debug("_game_update_proc_stub");
}
