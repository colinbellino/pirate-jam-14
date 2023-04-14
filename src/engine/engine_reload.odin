package engine

import "core:dynlib"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/slashpath"
import "core:time"

@(private="file") _game_library: dynlib.Library;
@(private) _game_update_proc := rawptr(_game_update_proc_stub);
@(private) _game_fixed_update_proc := rawptr(_game_update_proc_stub);
@(private) _game_render_proc := rawptr(_game_update_proc_stub);

game_code_bind :: proc(game_update_proc, game_fixed_update_proc, game_render_proc: rawptr) {
    _game_update_proc = game_update_proc;
    _game_fixed_update_proc = game_fixed_update_proc;
    _game_render_proc = game_render_proc;
}

game_code_load :: proc(path: string, app: ^App) -> (bool) {
    game_library, load_success := dynlib.load_library(path);
    if load_success != true {
        // log.errorf("%v not loaded.", path);
        return false;
    }

    if _game_library != nil {
        // Don't unload so we avoid having pointers to inaccessible procedures (ie: in allocators)
        // unload_success := dynlib.unload_library(_game_library);
        // assert(unload_success);
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

    app.debug_state.last_reload = time.now();
    _game_library = game_library;

    log.debugf("%v loaded: %v, %v, %v, %v.", path, _game_library, _game_update_proc, _game_fixed_update_proc, _game_render_proc);
    return true;
}

game_code_reload_init :: proc(app: ^App) {
    dir := slashpath.dir(os.args[0], context.temp_allocator);
    for i in 0 ..< 100 {
        file_name := fmt.tprintf("game%i.bin", i);
        file_path := slashpath.join([]string { dir, file_name }, context.temp_allocator);
        file_watch_add(app, file_path, _game_code_changed, _game_code_get_last_reload);
    }
}

@(private="file")
_game_code_get_last_reload :: proc(app: ^App) -> time.Time {
    return app.debug_state.last_reload;
}

@(private="file")
_game_code_changed : File_Watch_Callback_Proc : proc(file_watch: ^File_Watch, file_info: ^os.File_Info, app: ^App) {
    if game_code_load(file_watch.file_path, app) {
        log.debug("Game reloaded!");
        app.debug_state.start_game = true;
    }
}

@(private="file")
_game_update_proc_stub : Update_Proc : proc(delta_time: f64, app: ^App) {
    log.debug("_game_update_proc_stub");
}
