package main

import "core:log"
import "core:mem"
import "core:runtime"

import "engine"
when HOT_RELOAD_CODE == false {
    import "game"
}

HOT_RELOAD_CODE         :: #config(HOT_RELOAD_CODE, true);
HOT_RELOAD_ASSETS       :: #config(HOT_RELOAD_ASSETS, true);
MEM_BASE_ADDRESS        :: 2 * mem.Terabyte;
MEM_ENGINE_SIZE         :: 10 * mem.Megabyte;
MEM_GAME_SIZE           :: 10 * mem.Megabyte;
MEM_TEMP_START_SIZE     :: 2 * mem.Megabyte;

main :: proc() {
    default_temp_allocator_data := runtime.Default_Temp_Allocator {};
    context.allocator = mem.Allocator { engine.default_allocator_proc, nil };
    runtime.default_temp_allocator_init(&default_temp_allocator_data, MEM_TEMP_START_SIZE);
    context.temp_allocator.procedure = runtime.default_temp_allocator_proc;
    context.temp_allocator.data = &default_temp_allocator_data;

    resolution := engine.Vector2i { 1920, 1080 };
    config := engine.Config {};
    config.TRACY_ENABLE = #config(TRACY_ENABLE, true);
    config.ASSETS_PATH = #config(ASSETS_PATH, "../");
    config.HOT_RELOAD_CODE = HOT_RELOAD_CODE;
    config.HOT_RELOAD_ASSETS = HOT_RELOAD_ASSETS;
    app, app_arena := engine.init_engine(
        resolution, "Snowball", config,
        MEM_BASE_ADDRESS, MEM_ENGINE_SIZE, MEM_GAME_SIZE,
    );
    context.logger = app.logger.logger;

    when HOT_RELOAD_CODE {
        engine.game_code_reload_init(app);
    } else {
        engine.game_code_bind(rawptr(game.game_update), rawptr(game.game_fixed_update), rawptr(game.game_render));
    }

    for app.platform.quit == false {
        engine.update_and_render(app.platform, app);
        free_all(context.temp_allocator);

        when HOT_RELOAD_ASSETS {
            engine.profiler_zone("hot_reload", 0x000055);
            engine.file_watch_update(app);
        }
    }

    log.warn("Quitting...");
}
