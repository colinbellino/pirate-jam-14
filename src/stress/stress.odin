package game

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:slice"
import "core:sort"
import "core:strings"

import "../engine"

MEM_GAME_SIZE           :: 1 * mem.Megabyte
NATIVE_RESOLUTION       :: engine.Vector2i32 { 256, 144 }
PROFILER_COLOR_RENDER   :: 0x550000
VOID_COLOR              :: engine.Color { 100, 100, 100, 255 }

ENTITY_SIZE             :: 16;
ENTITIES_COUNT          :: 2_000;

Game_Mode_Proc :: #type proc()

Game_State :: struct {
    _engine:                    ^engine.Engine_State,
    engine_allocator:           runtime.Allocator,
    engine_arena:               mem.Arena,
    game_allocator:             runtime.Allocator,
    game_arena:                 mem.Arena,

    initialized:                bool,
    asset_placeholder:          engine.Asset_Id,
    texture_placeholder:        ^engine.Texture,
    entity_position:            [ENTITIES_COUNT]engine.Vector2i32,
    entity_color:               [ENTITIES_COUNT]engine.Color,
    camera_position:            engine.Vector3f32,
    zoom:                       f32,
    grid_size:                  int,
    draw_0:                     bool,
    draw_1:                     bool,
    draw_2:                     bool,
}

@(private)
_game: ^Game_State

@(export)
game_init :: proc() -> rawptr {
    game := new(Game_State)
    _game = game
    _game.game_allocator = engine.platform_make_arena_allocator(.Game, MEM_GAME_SIZE, &_game.game_arena, context.allocator)

    _game.engine_allocator = engine.platform_make_arena_allocator(.Engine, engine.MEM_ENGINE_SIZE, &_game.engine_arena, context.allocator)
    _game._engine = engine.engine_init(game.engine_allocator)

    _game.draw_0 = true
    _game.draw_1 = true
    _game.draw_2 = true
    _game.zoom = 1
    _game.grid_size = int(math.floor(math.sqrt(f32(engine.QUAD_MAX))))

    // if engine.PROFILER {
    //     profile_allocator_data := (cast(^engine.ProfiledAllocatorData)_game.game_allocator.data)
    //     backing_allocator := profile_allocator_data^.backing_allocator
    //     game_arena := (cast(^mem.Arena)backing_allocator.data)
    //     _game.game_arena = game_arena^
    // } else {
    //     _game.game_arena = (cast(^mem.Arena)_game.game_allocator.data)^
    // }

    return game
}

@(export)
game_update :: proc(game: ^Game_State) -> (quit: bool, reload: bool) {
    engine.platform_frame_begin()

    window_size := engine.Vector2i32 { 1920, 1080 }
    rendering_scale : i32 = 7

    { engine.profiler_zone("game_update")
        // for entity_index := 0; entity_index < ENTITIES_COUNT; entity_index += 1 {
        //     entity_position := &_game.entity_position[entity_index];
        //     entity_position.x = rand.int31_max((window_size.x - ENTITY_SIZE) / rendering_scale);
        //     entity_position.y = rand.int31_max((window_size.y - ENTITY_SIZE) / rendering_scale);

        //     entity_color := &_game.entity_color[entity_index];
        //     entity_color.r = u8(rand.int31_max(255));
        //     entity_color.g = u8(rand.int31_max(255));
        //     entity_color.b = u8(rand.int31_max(255));
        //     entity_color.a = 255;
        // }

        if _game._engine.platform.keys[.F1].released {
            _game.draw_0 = !_game.draw_0
        }
        if _game._engine.platform.keys[.F2].released {
            _game.draw_1 = !_game.draw_1
        }
        if _game._engine.platform.keys[.F3].released {
            _game.draw_2 = !_game.draw_2
        }
        if _game._engine.platform.keys[.F5].released {
            reload = true
        }
        if _game._engine.platform.quit_requested || _game._engine.platform.keys[.ESCAPE].released {
            quit = true
        }

        if _game._engine.platform.keys[.F10].released {
            _game._engine.renderer.refresh_rate = 9999999
        }

        if _game._engine.platform.keys[.LEFT].down {
            _game.camera_position.x -= _game._engine.platform.delta_time
        }
        if _game._engine.platform.keys[.RIGHT].down {
            _game.camera_position.x += _game._engine.platform.delta_time
        }
        if _game._engine.platform.keys[.DOWN].down {
            _game.camera_position.y -= _game._engine.platform.delta_time
        }
        if _game._engine.platform.keys[.UP].down {
            _game.camera_position.y += _game._engine.platform.delta_time
        }
        if _game._engine.platform.mouse_wheel.y != 0 {
            _game.zoom += f32(_game._engine.platform.mouse_wheel.y) * _game._engine.platform.delta_time / 50
            // log.debugf("_game._engine.platform.mouse_wheel: %v", _game._engine.platform.mouse_wheel);
        }
        // log.debugf("pos %v | zoom %v", _game.camera_position, _game.zoom);

        engine.platform_set_window_title(get_window_title())
    }

    game_render()

    engine.platform_frame_end()

    return
}

@(export)
game_quit :: proc(game: ^Game_State) { }

@(export)
game_reload :: proc(game: ^Game_State) {
    _game = game
    engine.engine_reload(game._engine)
}

@(export)
window_open :: proc() {
    engine.platform_open_window("", { 1920, 1080 })
    if engine.renderer_scene_init() == false {
        log.error("renderer_scene_init error");
        os.exit(1)
    }
}

@(export)
window_close :: proc(game: ^Game_State) { }

get_window_title :: proc() -> string {
    return fmt.tprintf("Stress (Renderer: %v | Refresh rate: %3.0fHz | FPS: %5.0f / %5.0f | Stats: %v)",
        engine.RENDERER, f32(_game._engine.renderer.refresh_rate),
        f32(_game._engine.platform.locked_fps), f32(_game._engine.platform.actual_fps), _game._engine.renderer.stats)
}

game_render :: proc() {
    engine.profiler_zone("game_render", PROFILER_COLOR_RENDER)

    engine.renderer_render_begin()

    engine.renderer_clear(VOID_COLOR)

    if engine.renderer_is_enabled() == false {
        log.warn("Renderer disabled")
        return
    }

    if _game._engine.platform.window_resized {
        engine.platform_resize_window(NATIVE_RESOLUTION)
    }

    { engine.profiler_zone("render_entities", PROFILER_COLOR_RENDER);
        projection_matrix := engine.matrix_ortho3d_f32(0, f32(1920) / _game.zoom, 0, f32(1080) / _game.zoom, 0, 1)
        view_matrix := engine.matrix4_translate_f32(_game.camera_position)
        scale_matrix := engine.matrix4_scale_f32({ 10, 10, 0 })
        engine.renderer_scene_update(projection_matrix, view_matrix, scale_matrix)

        if _game.draw_0 {
            for y := 0; y < _game.grid_size; y += 1 {
                for x := 0; x < _game.grid_size; x += 1 {
                    color := engine.Vector4f32 { 1, 1, 1, 1 }
                    if (y + x) % 2 == 0 {
                        color = { 0, 1, 0, 1 }
                    }
                    engine.draw_quad({ f32(x), f32(y) }, { 1, 1 }, _game._engine.renderer.texture_white, color)
                }
            }
        }

        if _game.draw_1 {
            for y := 0; y < 10; y += 1 {
                for x := 0; x < 10; x += 1 {
                    texture := _game._engine.renderer.texture_0
                    if (x + y) % 2 == 0 {
                        texture = _game._engine.renderer.texture_1
                    }
                    engine.draw_quad({ f32(x * 10), f32(y * 10) }, { 10, 10 }, texture)
                }
            }
        }
    }

    engine.renderer_render_end()
}
