package tactics

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:time"

import "engine"
import tracy "odin-tracy"

when HOT_RELOAD_CODE == false {
    import "game"
}

PROFILER               :: #config(PROFILER, true);
HOT_RELOAD_CODE        :: #config(HOT_RELOAD_CODE, true);
HOT_RELOAD_ASSETS      :: #config(HOT_RELOAD_ASSETS, true);
TRACY_ENABLE           :: #config(TRACY_ENABLE, PROFILER);
ASSETS_PATH            :: #config(ASSETS_PATH, "../");
// TODO: merge all engine arenas into one ENGINE_MEMORY_SIZE?
BASE_ADDRESS           :: 2    * mem.Terabyte;
PLATFORM_MEMORY_SIZE   :: 2048 * mem.Kilobyte;
RENDERER_MEMORY_SIZE   :: 512  * mem.Kilobyte;
LOGGER_MEMORY_SIZE     :: 10   * mem.Megabyte;
DEBUG_MEMORY_SIZE      :: 1024 * mem.Kilobyte;
GAME_MEMORY_SIZE       :: 2048 * mem.Kilobyte;
TEMP_MEMORY_START_SIZE :: 1024 * mem.Kilobyte;

main :: proc() {
    engine.profiler_set_thread_name("main");

    context.allocator = tracy.MakeProfiledAllocator(
        self              = &engine.ProfiledAllocatorData {},
        callstack_size    = 5,
        backing_allocator = context.allocator,
        secure            = false,
    );

    context.allocator = mem.Allocator { engine.default_allocator_proc, nil };

    default_temp_allocator_data := runtime.Default_Temp_Allocator {};
    runtime.default_temp_allocator_init(&default_temp_allocator_data, TEMP_MEMORY_START_SIZE, context.allocator);
    context.temp_allocator.procedure = runtime.default_temp_allocator_proc;
    context.temp_allocator.data = &default_temp_allocator_data;

    // TODO: Get window_size from settings
    config := engine.App_Config {};
    config.PROFILER = PROFILER;
    config.HOT_RELOAD_CODE = HOT_RELOAD_CODE;
    config.HOT_RELOAD_ASSETS = HOT_RELOAD_ASSETS;
    config.ASSETS_PATH = ASSETS_PATH;
    app, app_arena := engine.init_app(
        { 1920, 1080 }, "Zeldo", config,
        BASE_ADDRESS, PLATFORM_MEMORY_SIZE, RENDERER_MEMORY_SIZE, LOGGER_MEMORY_SIZE, DEBUG_MEMORY_SIZE, GAME_MEMORY_SIZE,
        context.allocator, context.temp_allocator);
    context.logger = app.logger;

    log.debugf("os.args:            %v", os.args);
    log.debugf("TRACY_ENABLE:       %v", TRACY_ENABLE);
    log.debugf("PROFILER:           %v", app.config.PROFILER);
    log.debugf("HOT_RELOAD_CODE:    %v", app.config.HOT_RELOAD_CODE);
    log.debugf("HOT_RELOAD_ASSETS:  %v", app.config.HOT_RELOAD_ASSETS);
    log.debugf("ASSETS_PATH:        %v", app.config.ASSETS_PATH);

    when HOT_RELOAD_CODE == true {
        engine.game_code_reload_init(app);
    } else {
        engine.game_code_bind(rawptr(game.game_update), rawptr(game.game_fixed_update), rawptr(game.game_render));
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

        when HOT_RELOAD_ASSETS == true {
            engine.profiler_zone("hot_reload", 0x000055);
            engine.file_watch_update(app);
        }

        free_all(context.temp_allocator);
    }

    log.debug("Quitting...");
}
