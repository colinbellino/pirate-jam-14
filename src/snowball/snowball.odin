package snowball

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:time"
import "core:slice"
import "core:sort"
import "core:strings"
import "core:math/linalg"
import "core:math/rand"

import tracy "../odin-tracy"
import "../engine"

Vector2i                :: engine.Vector2i;
Vector2f32              :: engine.Vector2f32;
Rect                    :: engine.Rect;
RectF32                 :: engine.RectF32;
Color                   :: engine.Color;
array_cast              :: linalg.array_cast;

TRACY_ENABLE            :: #config(TRACY_ENABLE, true);
ASSETS_PATH             :: #config(ASSETS_PATH, "../");
BASE_ADDRESS            :: 2 * mem.Terabyte;
ENGINE_MEMORY_SIZE      :: 2 * mem.Megabyte;
GAME_MEMORY_SIZE        :: 2 * mem.Megabyte;
TEMP_MEMORY_START_SIZE  :: 2 * mem.Megabyte;
NATIVE_RESOLUTION       :: Vector2i { 160, 90 };
CONTROLLER_DEADZONE     :: 15_000;
PROFILER_COLOR_RENDER   :: 0x550000;
CLEAR_COLOR             :: Color { 255, 0, 255, 255 }; // This is supposed to never show up, so it's a super flashy color. If you see it, something is broken.
VOID_COLOR              :: Color { 100, 100, 100, 255 };
WINDOW_BORDER_COLOR     :: Color { 0, 0, 0, 255 };
PIXEL_PER_CELL          :: 8;
LETTERBOX_COLOR         :: Color { 10, 10, 10, 255 };
LETTERBOX_SIZE          :: Vector2i { 40, 18 };
LETTERBOX_TOP           :: Rect { 0, 0,                                      NATIVE_RESOLUTION.x, LETTERBOX_SIZE.y };
LETTERBOX_BOTTOM        :: Rect { 0, NATIVE_RESOLUTION.y - LETTERBOX_SIZE.y, NATIVE_RESOLUTION.x, LETTERBOX_SIZE.y };
LETTERBOX_LEFT          :: Rect { 0, 0,                                      LETTERBOX_SIZE.x, NATIVE_RESOLUTION.y };
LETTERBOX_RIGHT         :: Rect { NATIVE_RESOLUTION.x - LETTERBOX_SIZE.x, 0, LETTERBOX_SIZE.x, NATIVE_RESOLUTION.y };
HUD_SIZE                :: Vector2i { 40, 20 };
HUD_RECT                :: Rect { 0, NATIVE_RESOLUTION.y - HUD_SIZE.y, NATIVE_RESOLUTION.x, HUD_SIZE.y };
HUD_COLOR               :: Color { 255, 255, 255, 255 };

Game_State :: struct {
    arena:                      ^mem.Arena,
    player_inputs:              Player_Inputs,
    window_size:                Vector2i,
    asset_world:                engine.Asset_Id,
    asset_placeholder:          engine.Asset_Id,
    asset_tilemap:              engine.Asset_Id,
    game_allocator:             runtime.Allocator,
    game_mode:                  Game_Mode,
    game_mode_entered:          bool,
    game_mode_exited:           bool,
    game_mode_allocator:        runtime.Allocator,
    battle_index:               int,
    entities:                   Entity_Data,
    world_data:                 ^Game_Mode_World,

    debug_ui_window_info:       bool,
    debug_ui_window_entities:   bool,
    debug_ui_no_tiles:          bool,
    debug_ui_room_only:         bool,
    debug_ui_entity:            Entity,
    debug_ui_show_tiles:        bool,
    draw_letterbox:             bool,
    draw_hud:                   bool,
}

Game_Mode :: enum { Init, Title, World, Battle }

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

app:  ^engine.App;
game: ^Game_State;

// Win: odin run ../src/snowball -file -out:snowball.bin -define=TRACY_ENABLE=true
// Mac: odin run ../src/snowball -file -out:snowball.bin -define=TRACY_ENABLE=true -extra-linker-flags:'-F. -rpath @loader_path'
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
    app_arena: mem.Arena;
    app, app_arena = engine.init_engine(
        { 1920, 1080 }, "Snowball", config,
        BASE_ADDRESS, ENGINE_MEMORY_SIZE, GAME_MEMORY_SIZE,
        context.allocator, context.temp_allocator);
    context.logger = app.logger.logger;

    log.debugf("- os.args:              %v", os.args);
    log.debugf("- TRACY_ENABLE:         %v", TRACY_ENABLE);
    log.debugf("- ASSETS_PATH:          %v", app.config.ASSETS_PATH);

    engine.game_code_bind(rawptr(game_update), rawptr(game_fixed_update), rawptr(game_render));

    for app.platform.quit == false {
        engine.update_and_render(app.platform, app);
        free_all(context.temp_allocator);
    }

    log.debug("Quitting...");
}

game_update :: proc(delta_time: f64, app: ^engine.App) {
    engine.profiler_zone("game_update");

    if app.game == nil {
        game = new(Game_State, app.game_allocator);
        game.game_allocator = app.game_allocator;
        game.game_mode_allocator = arena_allocator_make(1000 * mem.Kilobyte);
        app.game = game;
    }
    context.allocator = app.game_allocator;
    game = cast(^Game_State) app.game;

    { engine.profiler_zone("game_inputs");
        update_player_inputs(app.platform, game);

        engine.ui_input_mouse_move(app.ui, app.platform.mouse_position.x, app.platform.mouse_position.y);
        engine.ui_input_scroll(app.ui, app.platform.input_scroll.x * 30, app.platform.input_scroll.y * 30);

        for key, key_state in app.platform.mouse_keys {
            if key_state.pressed {
                ui_input_mouse_down(app.ui, app.platform.mouse_position, u8(key));
            }
            if key_state.released {
                ui_input_mouse_up(app.ui, app.platform.mouse_position, u8(key));
            }
        }
        for key, key_state in app.platform.keys {
            if key_state.pressed {
                ui_input_key_down(app.ui, engine.Keycode(key));
            }
            if key_state.released {
                ui_input_key_up(app.ui, engine.Keycode(key));
            }
        }
        if app.platform.input_text != "" {
            ui_input_text(app.ui, app.platform.input_text);
        }
    }

    {
        player_inputs := game.player_inputs;
        if player_inputs.cancel.released {
            app.platform.quit = true;
        }
        // if player_inputs.debug_0.released {
        //     game.debug_ui_window_console = (game.debug_ui_window_console + 1) % 2;
        // }
        if player_inputs.debug_1.released {
            game.debug_ui_window_info = !game.debug_ui_window_info;
        }
        if player_inputs.debug_2.released {
            game.debug_ui_window_entities = !game.debug_ui_window_entities;
        }
        // if player_inputs.debug_3.released {
        //     game.debug_ui_show_rect = !game.debug_ui_show_rect;
        // }
        if player_inputs.debug_4.released {
            game.debug_ui_show_tiles = !game.debug_ui_show_tiles;
        }
        // if player_inputs.debug_5.released {
        //     app.debug.save_memory = 1;
        // }
        // if player_inputs.debug_8.released {
        //     app.debug.load_memory = 1;
        // }
        // if player_inputs.debug_7.released {
        //     engine.take_screenshot(app.renderer, app.platform.window);
        // }
        if player_inputs.debug_11.released {
            game.draw_letterbox = !game.draw_letterbox;
        }
        // if player_inputs.debug_12.released {
        //     app.renderer.disabled = !app.renderer.disabled;
        // }
    }

    engine.ui_begin(app.ui);

    draw_debug_windows(app, game);

    switch game.game_mode {
        case .Init: {
            if app.config.TRACY_ENABLE {
                game.arena = cast(^mem.Arena)(cast(^engine.ProfiledAllocatorData)app.game_allocator.data).backing_allocator.data;
            } else {
                game.arena = cast(^mem.Arena)app.game_allocator.data;
            }

            game.window_size = 6 * NATIVE_RESOLUTION;
            resize_window(app.platform, app.renderer, game);

            engine.asset_init(app);
            game.asset_placeholder = engine.asset_add(app, "media/art/placeholder_0.png", .Image);
            game.asset_tilemap = engine.asset_add(app, "media/art/worldmap.png", .Image);
            game.asset_world = engine.asset_add(app, "media/levels/world.ldtk", .Map);

            engine.asset_load(app, game.asset_placeholder);
            engine.asset_load(app, game.asset_tilemap);

            game_mode_transition(.Title);
        }

        case .Title: {
            game_mode_transition(.World);
        }

        case .World: {
            game_world();
        }

        case .Battle: {
            if game_mode_enter() {
                log.debugf("Battle: %v", game.battle_index);
            }

            // for entity_index := 0; entity_index < ENTITIES_COUNT; entity_index += 1 {
            //     entity_position := &game.entity_position[entity_index];
            //     sign: i32;

            //     sign = 1;
            //     if rand.uint32() > max(u32) / 2 {
            //         sign = -1;
            //     }
            //     entity_position.x += sign;

            //     sign = 1;
            //     if rand.uint32() > max(u32) / 2 {
            //         sign = -1;
            //     }
            //     entity_position.y += sign;
            // }
        }
    }

    engine.ui_end(app.ui);
}

game_fixed_update :: proc(delta_time: f64, app: ^engine.App) { }

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

    sorted_entities: []Entity;
    { engine.profiler_zone("sort_entities", PROFILER_COLOR_RENDER);
        // TODO: This is kind of expensive to do each frame.
        // Either filter the entities before the sort or don't do this every single frame.
        sorted_entities = slice.clone(game.entities.entities[:], context.temp_allocator);
        {
            context.user_ptr = rawptr(&game.entities.components_z_index);
            sort_entities_by_z_index :: proc(a, b: Entity) -> int {
                components_z_index := cast(^map[Entity]Component_Z_Index)context.user_ptr;
                return int(components_z_index[a].z_index - components_z_index[b].z_index);
            }
            sort.heap_sort_proc(sorted_entities, sort_entities_by_z_index);
        }
    }

    { engine.profiler_zone("draw_entities", PROFILER_COLOR_RENDER);
        for entity in sorted_entities {
            position_component, has_position := game.entities.components_position[entity];
            rendering_component, has_rendering := game.entities.components_rendering[entity];
            flag_component, has_flag := game.entities.components_flag[entity];

            if has_rendering && rendering_component.visible && has_position {
                asset := app.assets.assets[rendering_component.texture_asset];
                if asset.state != .Loaded {
                    continue;
                }

                {
                    source := engine.Rect {
                        rendering_component.texture_position.x, rendering_component.texture_position.y,
                        rendering_component.texture_size.x, rendering_component.texture_size.y,
                    };
                    destination := engine.RectF32 {
                        position_component.world_position.x * f32(PIXEL_PER_CELL),
                        position_component.world_position.y * f32(PIXEL_PER_CELL),
                        PIXEL_PER_CELL,
                        PIXEL_PER_CELL,
                    };
                    info := asset.info.(engine.Asset_Info_Image);
                    engine.draw_texture(app.renderer, info.texture, &source, &destination);
                }

                if has_flag && .Tile in flag_component.value {
                    destination := engine.RectF32 {
                        position_component.world_position.x * f32(PIXEL_PER_CELL),
                        position_component.world_position.y * f32(PIXEL_PER_CELL),
                        PIXEL_PER_CELL,
                        PIXEL_PER_CELL,
                    };
                    color := Color { 100, 0, 0, 0 };
                    tile_component, has_tile := game.entities.components_tile[entity];
                    engine.draw_fill_rect(app.renderer, &destination, color);
                }
            }
        }
    }

    { engine.profiler_zone("draw_letterbox", PROFILER_COLOR_RENDER);
        engine.draw_window_border(app.renderer, NATIVE_RESOLUTION, WINDOW_BORDER_COLOR);
        if game.draw_letterbox { // Draw the letterboxes on top of the world
            engine.draw_fill_rect(app.renderer, &Rect { LETTERBOX_TOP.x, LETTERBOX_TOP.y, LETTERBOX_TOP.w, LETTERBOX_TOP.h }, LETTERBOX_COLOR);
            engine.draw_fill_rect(app.renderer, &Rect { LETTERBOX_BOTTOM.x, LETTERBOX_BOTTOM.y, LETTERBOX_BOTTOM.w, LETTERBOX_BOTTOM.h }, LETTERBOX_COLOR);
            engine.draw_fill_rect(app.renderer, &Rect { LETTERBOX_LEFT.x, LETTERBOX_LEFT.y, LETTERBOX_LEFT.w, LETTERBOX_LEFT.h }, LETTERBOX_COLOR);
            engine.draw_fill_rect(app.renderer, &Rect { LETTERBOX_RIGHT.x, LETTERBOX_RIGHT.y, LETTERBOX_RIGHT.w, LETTERBOX_RIGHT.h }, LETTERBOX_COLOR);
        }
    }

    { engine.profiler_zone("draw_hud", PROFILER_COLOR_RENDER);
        if game.draw_hud {
            engine.draw_fill_rect(app.renderer, &Rect { HUD_RECT.x, HUD_RECT.y, HUD_RECT.w, HUD_RECT.h }, HUD_COLOR);
        }
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

game_mode_transition :: proc(mode: Game_Mode) {
    log.debugf("game_mode_transition: %v", mode);
    game.game_mode = mode;
    game.game_mode_entered = false;
    arena_allocator_free_all_and_zero(game.game_mode_allocator);
}

@(deferred_out=game_mode_enter_end)
game_mode_enter :: proc() -> bool {
    return game.game_mode_entered == false;
}

game_mode_enter_end :: proc(should_trigger: bool) {
    if should_trigger {
        game.game_mode_entered = true;
    }
}

arena_allocator_make :: proc(size: int) -> runtime.Allocator {
    arena := new(mem.Arena);
    arena_backing_buffer := make([]u8, size);
    mem.arena_init(arena, arena_backing_buffer);
    allocator := mem.arena_allocator(arena);
    allocator.procedure = arena_allocator_proc;
    return allocator;
}

arena_allocator_free_all_and_zero :: proc(allocator: runtime.Allocator = context.allocator) {
    arena := cast(^mem.Arena) allocator.data;
    mem.zero_slice(arena.data);
    free_all(allocator);
}

@(deferred_out=mem.end_arena_temp_memory)
arena_temp_block :: proc(arena: ^mem.Arena) -> mem.Arena_Temp_Memory {
    return mem.begin_arena_temp_memory(arena);
}

arena_allocator_proc :: proc(
    allocator_data: rawptr, mode: mem.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr, old_size: int, location := #caller_location,
) -> (new_memory: []byte, error: mem.Allocator_Error) {
    new_memory, error = mem.arena_allocator_proc(allocator_data, mode, size, alignment, old_memory, old_size, location);

    if error != .None {
        if error == .Mode_Not_Implemented {
            log.warnf("ARENA alloc (%v) %v: %v byte at %v", mode, error, size, location);
        } else {
            log.errorf("ARENA alloc (%v) %v: %v byte at %v", mode, error, size, location);
            os.exit(0);
        }
    }

    return;
}
