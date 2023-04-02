package tactics

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"

import "engine"

when HOT_RELOAD == false {
    import "game"
} else {
    import "core:path/slashpath"
}

HOT_RELOAD       :: #config(HOT_RELOAD, false);

BASE_ADDRESS           :: 2 * mem.Terabyte;
// TODO: merge all engine arenas into one ENGINE_MEMORY_SIZE?
PLATFORM_MEMORY_SIZE   :: 256 * mem.Kilobyte;
RENDERER_MEMORY_SIZE   :: 512 * mem.Kilobyte;
LOGGER_MEMORY_SIZE     :: 10  * mem.Megabyte;
DEBUG_MEMORY_SIZE      :: 1024 * mem.Kilobyte;
GAME_MEMORY_SIZE       :: 2048 * mem.Kilobyte;
TEMP_MEMORY_START_SIZE :: 1024 * mem.Kilobyte;

main :: proc() {
    engine.profiler_set_thread_name("main");

    context.allocator = mem.Allocator { engine.default_allocator_proc, nil };
    // TODO: See if this is possible to track allocs made in engine (with reserve_and_commit).
    context.allocator = engine.profiler_make_allocator(&engine.ProfiledAllocatorData {});

    default_temp_allocator_data := runtime.Default_Temp_Allocator {};
    runtime.default_temp_allocator_init(&default_temp_allocator_data, TEMP_MEMORY_START_SIZE, context.allocator);
    context.temp_allocator.procedure = runtime.default_temp_allocator_proc;
    context.temp_allocator.data = &default_temp_allocator_data;

    // TODO: Get window_size from settings
    app, app_arena := engine.init_app(
        { 1920, 1080 }, "Zeldo",
        BASE_ADDRESS, PLATFORM_MEMORY_SIZE, RENDERER_MEMORY_SIZE, LOGGER_MEMORY_SIZE, DEBUG_MEMORY_SIZE, GAME_MEMORY_SIZE,
        context.allocator, context.temp_allocator);
    context.logger = app.logger;

    log.debugf("HOT_RELOAD:       %v", HOT_RELOAD);

    when HOT_RELOAD == true {
        engine.code_load("game0.bin");
    } else {
        engine.code_bind(rawptr(game.game_update), rawptr(game.game_fixed_update), rawptr(game.game_render));
    }

    for app.platform_state.quit == false {
        engine.update_and_render(app.platform_state, app);

        if app.save_memory > 0 {
            path := fmt.tprintf("mem%i.bin", app.save_memory);
            defer app.save_memory = 0;
            success := os.write_entire_file(path, app_arena.data, false);
            if success != true {
                log.errorf("Couldn't write %s", path);
                return;
            }
            log.infof("%s written.", path);
        }
        if app.load_memory > 0 {
            path := fmt.tprintf("mem%i.bin", app.load_memory);
            defer app.load_memory = 0;
            data, success := os.read_entire_file(path);
            if success != true {
                log.errorf("Couldn't read %s", path);
                return;
            }
            mem.copy(&app_arena.data[0], &data[0], len(app_arena.data));
            log.infof("%s read.", path);
        }

        when HOT_RELOAD == true {
            engine.profiler_zone("hot_reload", 0x000055);
            dir := slashpath.dir(os.args[0], context.temp_allocator);
            for i in 0 ..< 100 {
                file_path := slashpath.join([]string { dir, fmt.tprintf("game%i.bin", i) }, context.temp_allocator);
                info, info_err := os.stat(file_path, context.temp_allocator);
                if info_err == 0 && engine.code_is_newer(info.modification_time) {
                    if engine.code_load(file_path) {
                        app.debug_state = engine.debug_init(app.debug_allocator);
                        // app.debug_state.last_reload = info.modification_time;
                    }

                    break;
                }
            }
        }

        free_all(context.temp_allocator);
    }

    log.debug("Quitting...");
}
