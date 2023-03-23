package tactics

import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:strings"
import "core:sync"
import "core:thread"
import "core:time"
import tracy "../../_thirdParty/odin-tracy"

import "engine"
import "game"

TRACY_ENABLE :: #config(TRACY_ENABLE, false);

BASE_ADDRESS         :: 2 * mem.Terabyte;
// TODO: merge all engine arenas into one ENGINE_MEMORY_SIZE?
// APP_MEMORY_SIZE      :: PLATFORM_MEMORY_SIZE + RENDERER_MEMORY_SIZE + LOGGER_MEMORY_SIZE + DEBUG_MEMORY_SIZE + TEMP_MEMORY_SIZE + GAME_MEMORY_SIZE;
PLATFORM_MEMORY_SIZE :: 256 * mem.Kilobyte;
RENDERER_MEMORY_SIZE :: 512 * mem.Kilobyte;
LOGGER_MEMORY_SIZE   :: 2048 * mem.Kilobyte;
DEBUG_MEMORY_SIZE    :: 1024 * mem.Kilobyte;
GAME_MEMORY_SIZE     :: 2048 * mem.Kilobyte;

TEMP_MEMORY_START_SIZE :: 1024 * mem.Kilobyte;

worker :: proc() {
    r : rand.Rand;
    rand.init(&r, u64(context.user_index));

    thread_name := strings.clone_to_cstring(fmt.tprintf("worker%i", context.user_index));
    defer delete(thread_name);

    tracy.SetThreadName(thread_name);

    for {
        {
            // No name given receives the name of the calling procedure
            tracy.Zone();
            random_sleep(&r);
        }
        {
            tracy.ZoneN("worker doing stuff");
            random_sleep(&r);
        }
        {
            // Name + Color. Colors in 0xRRGGBB format. 0 means "no color" (use a value
            // close to 0 for black).
            tracy.ZoneNC("worker doing stuff", 0xff0000);
            random_sleep(&r);
        }

        // sync with main thread for next frame
        sync.barrier_wait(&bar);
    }
}

bar : sync.Barrier;

random_sleep :: proc (r : ^rand.Rand) {
    time.sleep(time.Duration(rand.int_max(25, r)) * time.Millisecond);
}

random_alloc :: proc (r : ^rand.Rand) -> rawptr {
    return mem.alloc(1 + rand.int_max(1024, r));
}

main :: proc() {
    r : rand.Rand;
    rand.init(&r, u64(context.user_index));

    tracy.SetThreadName("main");

    // NUM_WORKERS :: 3;

    // sync.barrier_init(&bar, 1 + NUM_WORKERS);

    // for i in 1..=NUM_WORKERS {
    //     context.user_index = i;
    //     thread.run(worker, context);
    // }

    context.allocator = mem.Allocator { engine.default_allocator_proc, nil };

    // TODO: See if this is possible to track allocs made in engine (with reserve_and_commit).

    // Profile heap allocations with Tracy for this context.
    context.allocator = tracy.MakeProfiledAllocator(
        self              = &tracy.ProfiledAllocatorData{},
        callstack_size    = 5,
        backing_allocator = context.allocator,
        secure            = true,
    )

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

    if slice.contains(os.args, "no-hot") {
        engine.code_bind(rawptr(game.game_update), rawptr(game.game_fixed_update), rawptr(game.game_render));
    } else {
        engine.code_load("game0.bin");
    }

    for app.platform_state.quit == false {
        defer tracy.FrameMark();

        engine.zone("frame");

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

        if slice.contains(os.args, "no-hot") == false {
            engine.zone("hot_reload");
            for i in 0 ..< 100 {
                info, info_err := os.stat(fmt.tprintf("game%i.bin", i), context.temp_allocator);
                if info_err == 0 && engine.code_is_newer(info.modification_time) {
                    if engine.code_load(info.name) {
                        app.debug_state = engine.debug_init(app.debug_allocator);
                    }

                    break;
                }
            }
        }

        free_all(context.temp_allocator);
    }

    log.debug("Quitting...");
}
