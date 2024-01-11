package app_loader

import "core:fmt"
import "core:dynlib"
import "core:os"
import "core:time"
import "core:path/slashpath"

API :: struct {
    library:            dynlib.Library,
    app_init:           App_Init_Proc,
    app_update:         App_Update_Proc,
    app_quit:           App_Quit_Proc,
    app_reload:         App_Reload_Proc,
    modification_time:  time.Time,
    version:            i32,
}
App_Init_Proc   :: #type proc() -> rawptr
App_Update_Proc :: #type proc(app_memory: rawptr) -> (quit: bool, reload: bool)
App_Quit_Proc   :: #type proc(app_memory: rawptr)
App_Reload_Proc :: #type proc(app_memory: rawptr)

load :: proc(version: i32) -> (api: API, ok: bool) {
    path := slashpath.join({ fmt.tprintf("game%i.dll", version) }, context.temp_allocator)
    load_library: bool
    api.library, load_library = dynlib.load_library(path)
    if load_library == false {
        // fmt.eprintf("load_library('%s') failed.\n", path)
        return
    }

    api.app_init = auto_cast(dynlib.symbol_address(api.library, "app_init"))
    if api.app_init == nil {
        fmt.eprintf("symbol_address('app_init') failed.\n")
        return
    }
    api.app_update = auto_cast(dynlib.symbol_address(api.library, "app_update"))
    if api.app_update == nil {
        fmt.eprintf("symbol_address('app_update') failed.\n")
        return
    }
    api.app_quit = auto_cast(dynlib.symbol_address(api.library, "app_quit"))
    if api.app_quit == nil {
        fmt.eprintf("symbol_address('app_quit') failed.\n")
        return
    }
    api.app_reload = auto_cast(dynlib.symbol_address(api.library, "app_reload"))
    if api.app_reload == nil {
        fmt.eprintf("symbol_address('app_reload') failed.\n")
        return
    }

    api.version = version
    api.modification_time = time.now()

    return api, true
}

unload :: proc(api: ^API) {
    if api.library != nil {
        dynlib.unload_library(api.library)
    }
}

should_reload :: proc(api: ^API) -> bool {
    path := slashpath.join({ fmt.tprintf("game%i.dll", api.version + 1) }, context.temp_allocator)
    return os.exists(path)
}
