package main

import "core:log"
import "core:fmt"
import "core:mem"
import "core:dynlib"
import "core:time"
import "core:path/slashpath"
import "core:os"

main :: proc() {
    tracking_allocator: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    main_allocator := mem.tracking_allocator(&tracking_allocator)
    context.allocator = main_allocator

    context.logger = log.create_console_logger(.Debug, { .Level, .Terminal_Color, .Short_File_Path, .Line/* , .Procedure */ })

    game_api, game_api_ok := load_game_api(0)
    assert(game_api_ok == true, "game_api couldn't be loaded.")

    game_memory := game_api.game_init()
    game_api.window_open()

    quit := false
    reload := false
    for quit == false {
        quit, reload = game_api.game_update(game_memory)

        if reload {
            new_game_api, new_game_api_ok := load_game_api(game_api.version + 1)
            if new_game_api_ok {
                game_api.game_quit(game_memory)
                mem.tracking_allocator_clear(&tracking_allocator)
                unload_game_api(&game_api)
                game_api = new_game_api
                game_memory = game_api.game_init()
                // game_api.window_close(game_memory)
                // game_api.window_open()
            }
        }
    }

    log.warn("Quitting...")

    // for key, value in allocator.allocation_map {
    //     log.warnf("%v: leaked %v bytes\n", value.location, value.size)
    // }
}

Game_API :: struct {
    library:            dynlib.Library,
    on_api_load:        proc(allocator: mem.Allocator),
    game_init:          proc() -> rawptr,
    game_update:        proc(game_memory: rawptr) -> (quit: bool, reload: bool),
    game_quit:          proc(game_memory: rawptr),
    window_open:        proc(),
    window_close:       proc(game_memory: rawptr),
    modification_time:  time.Time,
    version:            i32,
}
load_game_api :: proc(version: i32) -> (api: Game_API, ok: bool) {
    dir := slashpath.dir(os.args[0], context.temp_allocator)
    path := slashpath.join({ dir, fmt.tprintf("game%i.bin", version) }, context.temp_allocator)
    api.library, ok = dynlib.load_library(path)
    if ok == false {
        log.errorf("load_library('%s') failed.", path)
        return
    }

    api.window_open = auto_cast(dynlib.symbol_address(api.library, "window_open"))
    if api.window_open == nil {
        log.error("symbol_address('window_open') failed.")
        return
    }
    api.window_close = auto_cast(dynlib.symbol_address(api.library, "window_close"))
    if api.window_close == nil {
        log.error("symbol_address('window_close') failed.")
        return
    }
    api.game_init = auto_cast(dynlib.symbol_address(api.library, "game_init"))
    if api.game_init == nil {
        log.error("symbol_address('game_init') failed.")
        return
    }
    api.game_update = auto_cast(dynlib.symbol_address(api.library, "game_update"))
    if api.game_update == nil {
        log.error("symbol_address('game_update') failed.")
        return
    }
    api.game_quit = auto_cast(dynlib.symbol_address(api.library, "game_quit"))
    if api.game_quit == nil {
        log.error("symbol_address('game_quit') failed.")
        return
    }

    api.version = version
    api.modification_time = time.now()

    return api, true
}
unload_game_api :: proc(api: ^Game_API) {
    if api.library != nil {
        dynlib.unload_library(api.library)
    }
}

// package main

// import "core:log"
// import "core:mem"
// import "core:runtime"

// import "engine"
// when HOT_RELOAD_CODE == false {
//     import "game"
// }

// HOT_RELOAD_CODE         :: #config(HOT_RELOAD_CODE, true);
// HOT_RELOAD_ASSETS       :: #config(HOT_RELOAD_ASSETS, true);
// MEM_BASE_ADDRESS        :: 2 * mem.Terabyte;
// MEM_ENGINE_SIZE         :: 10 * mem.Megabyte;
// MEM_GAME_SIZE           :: 10 * mem.Megabyte;
// MEM_TEMP_START_SIZE     :: 2 * mem.Megabyte;

// main :: proc() {
//     default_temp_allocator_data := runtime.Default_Temp_Allocator {};
//     context.allocator = mem.Allocator { engine.default_allocator_proc, nil };
//     runtime.default_temp_allocator_init(&default_temp_allocator_data, MEM_TEMP_START_SIZE);
//     context.temp_allocator.procedure = runtime.default_temp_allocator_proc;
//     context.temp_allocator.data = &default_temp_allocator_data;

//     resolution := engine.Vector2i { 1920, 1080 };
//     config := engine.Config {};
//     config.TRACY_ENABLE = #config(TRACY_ENABLE, true);
//     config.ASSETS_PATH = #config(ASSETS_PATH, "../");
//     config.HOT_RELOAD_CODE = HOT_RELOAD_CODE;
//     config.HOT_RELOAD_ASSETS = HOT_RELOAD_ASSETS;
//     app, app_arena := engine.init_engine(
//         resolution, "Snowball", config,
//         MEM_BASE_ADDRESS, MEM_ENGINE_SIZE, MEM_GAME_SIZE,
//     );
//     context.logger = app.logger.logger;

//     when HOT_RELOAD_CODE {
//         engine.game_code_reload_init(app);
//     } else {
//         engine.game_code_bind(rawptr(game.game_update), rawptr(game.game_fixed_update), rawptr(game.game_render));
//     }

//     for app.platform.quit == false {
//         engine.update_and_render(app.platform, app);
//         free_all(context.temp_allocator);

//         when HOT_RELOAD_ASSETS {
//             engine.profiler_zone("hot_reload", 0x000055);
//             engine.file_watch_update(app);
//         }
//     }

//     log.warn("Quitting...");
// }
