package stress

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:time"
import "core:math/linalg"
import "core:math/rand"

import tracy "odin-tracy"
import "engine"

Vector2i                :: engine.Vector2i;
Vector2f32              :: engine.Vector2f32;
Rect                    :: engine.Rect;
Color                   :: engine.Color;

TRACY_ENABLE            :: #config(TRACY_ENABLE, true);
ASSETS_PATH             :: #config(ASSETS_PATH, "../");
BASE_ADDRESS            :: 2  * mem.Terabyte;
ENGINE_MEMORY_SIZE      :: 10 * mem.Megabyte;
GAME_MEMORY_SIZE        :: 20  * mem.Megabyte;
TEMP_MEMORY_START_SIZE  :: 2  * mem.Megabyte;
NATIVE_RESOLUTION       :: Vector2i { 320, 180 };
CONTROLLER_DEADZONE     :: 15_000;
PROFILER_COLOR_RENDER   :: 0x550000;
CLEAR_COLOR             :: Color { 255, 0, 255, 255 }; // This is supposed to never show up, so it's a super flashy color. If you see it, something is broken.
VOID_COLOR              :: Color { 100, 100, 100, 255 };
ENTITY_SIZE             :: 16;
ENTITIES_COUNT          :: 250_000;

// odin run ../src/stress.odin -file -out:stress.bin -define=TRACY_ENABLE=true -o:speed
main :: proc() {
    context.allocator = mem.Allocator { engine.default_allocator_proc, nil };

    if TRACY_ENABLE {
        engine.profiler_set_thread_name("main");
        context.allocator = tracy.MakeProfiledAllocator(
            self              = &engine.ProfiledAllocatorData {},
            callstack_size    = 5,
            backing_allocator = context.allocator,
            secure            = false,
        );
    }

    default_temp_allocator_data := runtime.Default_Temp_Allocator {};
    runtime.default_temp_allocator_init(&default_temp_allocator_data, TEMP_MEMORY_START_SIZE, context.allocator);
    context.temp_allocator.procedure = runtime.default_temp_allocator_proc;
    context.temp_allocator.data = &default_temp_allocator_data;

    // TODO: Get window_size from settings
    config := engine.Config {};
    config.TRACY_ENABLE = TRACY_ENABLE;
    config.ASSETS_PATH = ASSETS_PATH;
    app, app_arena := engine.init_engine(
        { 1920, 1080 }, "Stress", config,
        BASE_ADDRESS, ENGINE_MEMORY_SIZE, GAME_MEMORY_SIZE,
        context.allocator, context.temp_allocator);
    context.logger = app.logger.logger;

    log.debugf("os.args:            %v", os.args);
    log.debugf("TRACY_ENABLE:       %v", TRACY_ENABLE);
    log.debugf("ASSETS_PATH:        %v", app.config.ASSETS_PATH);

    engine.game_code_bind(rawptr(game_update), rawptr(game_fixed_update), rawptr(game_render));

    for app.platform.quit == false {
        engine.update_and_render(app.platform, app);

        if app.debug.save_memory > 0 {
            path := fmt.tprintf("mem%i.bin", app.debug.save_memory);
            defer app.debug.save_memory = 0;
            success := os.write_entire_file(path, app_arena.data, false);
            if success != true {
                log.errorf("Couldn't write %s", path);
                return;
            }
            log.infof("%s written.", path);
        }
        if app.debug.load_memory > 0 {
            path := fmt.tprintf("mem%i.bin", app.debug.load_memory);
            defer app.debug.load_memory = 0;
            data, success := os.read_entire_file(path);
            if success != true {
                log.errorf("Couldn't read %s", path);
                return;
            }
            mem.copy(&app_arena.data[0], &data[0], len(app_arena.data));
            log.infof("%s read.", path);
        }

        free_all(context.temp_allocator);
    }

    log.debug("Quitting...");
}

Game_State :: struct {
    arena:                      ^mem.Arena,
    player_inputs:              Player_Inputs,
    window_size:                Vector2i,
    initialized:                bool,
    entity_position:            [ENTITIES_COUNT]Vector2i,
    entity_color:               [ENTITIES_COUNT]Color,
    entity_rect:                [ENTITIES_COUNT]Rect,
}

Player_Inputs :: struct {
    move:     Vector2f32,
    confirm:  engine.Key_State,
    cancel:   engine.Key_State,
    back:     engine.Key_State,
    start:    engine.Key_State,
    debug_0:  engine.Key_State,
    debug_1:  engine.Key_State,
    debug_2:  engine.Key_State,
    debug_3:  engine.Key_State,
    debug_4:  engine.Key_State,
    debug_5:  engine.Key_State,
    debug_6:  engine.Key_State,
    debug_7:  engine.Key_State,
    debug_8:  engine.Key_State,
    debug_9:  engine.Key_State,
    debug_10: engine.Key_State,
    debug_11: engine.Key_State,
    debug_12: engine.Key_State,
}

game_update :: proc(delta_time: f64, app: ^engine.App) {
    engine.profiler_zone("game_update");

    game: ^Game_State;
    if app.game == nil {
        game = new(Game_State, app.game_allocator);
        app.game = game;
    }
    context.allocator = app.game_allocator;
    game = cast(^Game_State) app.game;

    { engine.profiler_zone("game_inputs");
        update_player_inputs(app.platform, game);

        // engine.ui_input_mouse_move(app.ui, app.platform.mouse_position.x, app.platform.mouse_position.y);
        // engine.ui_input_scroll(app.ui, app.platform.input_scroll.x * 30, app.platform.input_scroll.y * 30);

        // for key, key_state in app.platform.mouse_keys {
        //     if key_state.pressed {
        //         ui_input_mouse_down(app.ui, app.platform.mouse_position, u8(key));
        //     }
        //     if key_state.released {
        //         ui_input_mouse_up(app.ui, app.platform.mouse_position, u8(key));
        //     }
        // }
        // for key, key_state in app.platform.keys {
        //     if key_state.pressed {
        //         ui_input_key_down(app.ui, engine.Keycode(key));
        //     }
        //     if key_state.released {
        //         ui_input_key_up(app.ui, engine.Keycode(key));
        //     }
        // }
        // if app.platform.input_text != "" {
        //     ui_input_text(app.ui, app.platform.input_text);
        // }
    }

    {
        if game.player_inputs.cancel.released {
            app.platform.quit = true;
        }

        if game.player_inputs.debug_0.released {
            // game.debug_ui_window_console = (game.debug_ui_window_console + 1) % 2;
        }
    }

    engine.ui_begin(app.ui);

    if engine.ui_window(app.ui, "Stats", { 20, 20, 200, 100 }, { .NO_CLOSE, .NO_RESIZE }) {
        engine.ui_layout_row(app.ui, { 50, -1 }, 0);
        engine.ui_label(app.ui, "FPS");
        engine.ui_label(app.ui, fmt.tprintf("%v", u32(1 / app.platform.prev_frame_duration)));
        engine.ui_label(app.ui, "Entities");
        engine.ui_label(app.ui, fmt.tprintf("%v", ENTITIES_COUNT));
    }

    if game.initialized == false {
        if app.config.TRACY_ENABLE {
            game.arena = cast(^mem.Arena)(cast(^engine.ProfiledAllocatorData)app.game_allocator.data).backing_allocator.data;
        } else {
            game.arena = cast(^mem.Arena)app.game_allocator.data;
        }

        game.window_size = 6 * NATIVE_RESOLUTION;
        resize_window(app.platform, app.renderer, game);

        engine.asset_init(app);
        engine.asset_add(app, "media/art/zelda_oracle_of_seasons_snow.png", .Image);
        engine.asset_add(app, "media/art/autotile_snow.png", .Image);
        engine.asset_add(app, "media/art/zelda_oracle_of_seasons_110850.png", .Image);

        for entity_index := 0; entity_index < ENTITIES_COUNT; entity_index += 1 {
            entity_position := &game.entity_position[entity_index];
            entity_position.x = rand.int31_max((game.window_size.x - ENTITY_SIZE) / app.renderer.rendering_scale);
            entity_position.y = rand.int31_max((game.window_size.y - ENTITY_SIZE) / app.renderer.rendering_scale);

            entity_color := &game.entity_color[entity_index];
            entity_color.r = u8(rand.int31_max(255));
            entity_color.g = u8(rand.int31_max(255));
            entity_color.b = u8(rand.int31_max(255));
            entity_color.a = 255;
        }

        log.debug("Initialized");

        game.initialized = true;
    }

    for entity_index := 0; entity_index < ENTITIES_COUNT; entity_index += 1 {
        entity_position := &game.entity_position[entity_index];
        sign: i32;

        sign = 1;
        if rand.uint32() > max(u32) / 2 {
            sign = -1;
        }
        entity_position.x += sign;

        sign = 1;
        if rand.uint32() > max(u32) / 2 {
            sign = -1;
        }
        entity_position.y += sign;
    }

    engine.ui_end(app.ui);
}

game_fixed_update :: proc(delta_time: f64, app: ^engine.App) {

}

game_render :: proc(delta_time: f64, app: ^engine.App) {
    engine.profiler_zone("game_render", PROFILER_COLOR_RENDER);

    game := cast(^Game_State) app.game;

    // It's possible render is called before the game state is initialized
    if app.game == nil {
        return;
    }

    if app.platform.window_resized {
        resize_window(app.platform, app.renderer, game);
    }

    engine.renderer_clear(app.renderer, CLEAR_COLOR);
    engine.draw_fill_rect(app.renderer, &Rect { 0, 0, game.window_size.x, game.window_size.y }, VOID_COLOR);

    { engine.profiler_zone("render_entities", PROFILER_COLOR_RENDER);
        {
            engine.profiler_zone("render_entities_loop", PROFILER_COLOR_RENDER);
            for entity_index := 0; entity_index < ENTITIES_COUNT; entity_index += 1 {
                entity_position := game.entity_position[entity_index];
                game.entity_rect[entity_index] = { entity_position.x, entity_position.y, ENTITY_SIZE, ENTITY_SIZE };
            }
        }
        engine.draw_fill_rects_i32(app.renderer, game.entity_rect[:]);
    }

    { engine.profiler_zone("ui_process_commands", PROFILER_COLOR_RENDER);
        engine.ui_process_commands(app.renderer, app.ui);
    }

    { engine.profiler_zone("present", PROFILER_COLOR_RENDER);
        engine.renderer_present(app.renderer);
    }
}

resize_window :: proc(platform: ^engine.Platform_State, renderer: ^engine.Renderer_State, game: ^Game_State) {
    game.window_size = engine.get_window_size(platform.window);
    if game.window_size.x > game.window_size.y {
        renderer.rendering_scale = i32(f32(game.window_size.y) / f32(NATIVE_RESOLUTION.y));
    } else {
        renderer.rendering_scale = i32(f32(game.window_size.x) / f32(NATIVE_RESOLUTION.x));
    }
    renderer.display_dpi = engine.get_display_dpi(renderer, platform.window);
    renderer.rendering_size = {
        NATIVE_RESOLUTION.x * renderer.rendering_scale,
        NATIVE_RESOLUTION.y * renderer.rendering_scale,
    };
    update_rendering_offset(renderer, game);
    // log.debugf("window_resized: %v %v %v", game.window_size, renderer.display_dpi, renderer.rendering_scale);
}

update_rendering_offset :: proc(renderer: ^engine.Renderer_State, game: ^Game_State) {
    odd_offset : i32 = 0;
    if game.window_size.y % 2 == 1 {
        odd_offset = 1;
    }
    renderer.rendering_offset = {
        (game.window_size.x - NATIVE_RESOLUTION.x * renderer.rendering_scale) / 2 + odd_offset,
        (game.window_size.y - NATIVE_RESOLUTION.y * renderer.rendering_scale) / 2 + odd_offset,
    };
}

update_player_inputs :: proc(platform: ^engine.Platform_State, game: ^Game_State) {
    keyboard_was_used := false;
    for key in platform.keys {
        if platform.keys[key].down || platform.keys[key].released {
            keyboard_was_used = true;
            break;
        }
    }

    {
        player_inputs := &game.player_inputs;
        player_inputs^ = {};

        if keyboard_was_used {
            if (platform.keys[.UP].down) {
                player_inputs.move.y -= 1;
            } else if (platform.keys[.DOWN].down) {
                player_inputs.move.y += 1;
            }
            if (platform.keys[.LEFT].down) {
                player_inputs.move.x -= 1;
            } else if (platform.keys[.RIGHT].down) {
                player_inputs.move.x += 1;
            }

            player_inputs.back = platform.keys[.BACKSPACE];
            player_inputs.start = platform.keys[.RETURN];
            player_inputs.confirm = platform.keys[.SPACE];
            player_inputs.cancel = platform.keys[.ESCAPE];
            player_inputs.debug_0 = platform.keys[.GRAVE];
            player_inputs.debug_1 = platform.keys[.F1];
            player_inputs.debug_2 = platform.keys[.F2];
            player_inputs.debug_3 = platform.keys[.F3];
            player_inputs.debug_4 = platform.keys[.F4];
            player_inputs.debug_5 = platform.keys[.F5];
            player_inputs.debug_6 = platform.keys[.F6];
            player_inputs.debug_7 = platform.keys[.F7];
            player_inputs.debug_8 = platform.keys[.F8];
            player_inputs.debug_9 = platform.keys[.F9];
            player_inputs.debug_10 = platform.keys[.F10];
            player_inputs.debug_11 = platform.keys[.F11];
            player_inputs.debug_12 = platform.keys[.F12];
        } else {
            controller_state, controller_found := engine.get_controller_from_player_index(platform, 0);
            if controller_found {
                if (controller_state.buttons[.DPAD_UP].down) {
                    player_inputs.move.y -= 1;
                } else if (controller_state.buttons[.DPAD_DOWN].down) {
                    player_inputs.move.y += 1;
                }
                if (controller_state.buttons[.DPAD_LEFT].down) {
                    player_inputs.move.x -= 1;
                } else if (controller_state.buttons[.DPAD_RIGHT].down) {
                    player_inputs.move.x += 1;
                }
                if (controller_state.buttons[.DPAD_UP].down) {
                    player_inputs.move.y -= 1;
                }

                // If we use the analog sticks, we ignore the DPad inputs
                if controller_state.axes[.LEFTX].value < -CONTROLLER_DEADZONE || controller_state.axes[.LEFTX].value > CONTROLLER_DEADZONE {
                    player_inputs.move.x = f32(controller_state.axes[.LEFTX].value) / f32(size_of(controller_state.axes[.LEFTX].value));
                }
                if controller_state.axes[.LEFTY].value < -CONTROLLER_DEADZONE || controller_state.axes[.LEFTY].value > CONTROLLER_DEADZONE {
                    player_inputs.move.y = f32(controller_state.axes[.LEFTY].value) / f32(size_of(controller_state.axes[.LEFTY].value));
                }

                player_inputs.back = controller_state.buttons[.BACK];
                player_inputs.start = controller_state.buttons[.START];
                player_inputs.confirm = controller_state.buttons[.A];
                player_inputs.cancel = controller_state.buttons[.B];
            }
        }

        if player_inputs.move.x != 0 || player_inputs.move.y != 0 {
            player_inputs.move = linalg.vector_normalize(player_inputs.move);
        }
    }
}
