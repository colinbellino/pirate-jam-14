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
@(private) _game_counter := 0;

MAX_TRIES :: 10;

game_code_bind :: proc(game_update_proc, game_fixed_update_proc, game_render_proc: rawptr) {
    _game_update_proc = game_update_proc;
    _game_fixed_update_proc = game_fixed_update_proc;
    _game_render_proc = game_render_proc;
}

game_code_load :: proc(path: string, app: ^App) -> (bool) {
    game_library: dynlib.Library;
    load_success: bool;

    tries := 0;
    for true {
        game_library, load_success = dynlib.load_library(path);

        if load_success {
            break;
        }

        // This is aweful code but since we are doing the code hot reload only in debug builds, it's fine.
        time.sleep(time.Millisecond * 100);
        if load_success == false && tries > MAX_TRIES {
            log.errorf("%v not loaded.", path);
            return false;
        }
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

    app.debug.last_reload = time.now();
    _game_library = game_library;

    log.debugf("%v loaded: %v, %v, %v, %v.", path, _game_library, _game_update_proc, _game_fixed_update_proc, _game_render_proc);
    _game_counter += 1;
    return true;
}

game_code_reload_init :: proc(app: ^App) {
    dir := slashpath.dir(app.config.os_args[0], context.temp_allocator);

    file_name := fmt.tprintf("game%i.bin", 0);
    asset_id := asset_add(app, file_name, .Code);
    asset_load(app, asset_id);
}

@(private="file")
_game_update_proc_stub : Update_Proc : proc(delta_time: f64, app: ^App) {
    log.error("_game_update_proc_stub");
    os.exit(1);
}
