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
NATIVE_RESOLUTION       :: engine.Vector2f32 { 256, 144 }
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

        if engine.ui_window("Debug") {
            if engine.ui_tree_node("camera: world", .DefaultOpen) {
                camera := &_game._engine.renderer.world_camera
                engine.ui_slider_float3("position", transmute(^[3]f32)&camera.position, -100, 100)
                engine.ui_slider_float("rotation", &camera.rotation, 0, math.TAU)
                engine.ui_slider_float("zoom", &camera.zoom, 0.2, 30, "%.3f", .AlwaysClamp)
                if engine.ui_button("Reset zoom") {
                    camera.zoom = _game._engine.renderer.ideal_scale
                }
                if engine.ui_tree_node("projection_matrix", .DefaultOpen) {
                    engine.ui_slider_float4("projection_matrix[0]", transmute(^[4]f32)(&camera.projection_matrix[0]), -1, 1)
                    engine.ui_slider_float4("projection_matrix[1]", transmute(^[4]f32)(&camera.projection_matrix[1]), -1, 1)
                    engine.ui_slider_float4("projection_matrix[2]", transmute(^[4]f32)(&camera.projection_matrix[2]), -1, 1)
                    engine.ui_slider_float4("projection_matrix[3]", transmute(^[4]f32)(&camera.projection_matrix[3]), -1, 1)
                }
                if engine.ui_tree_node("view_matrix", .DefaultOpen) {
                    engine.ui_slider_float4("view_matrix[0]", transmute(^[4]f32)(&camera.view_matrix[0]), -1, 1)
                    engine.ui_slider_float4("view_matrix[1]", transmute(^[4]f32)(&camera.view_matrix[1]), -1, 1)
                    engine.ui_slider_float4("view_matrix[2]", transmute(^[4]f32)(&camera.view_matrix[2]), -1, 1)
                    engine.ui_slider_float4("view_matrix[3]", transmute(^[4]f32)(&camera.view_matrix[3]), -1, 1)
                }
                if engine.ui_tree_node("projection_view_matrix", .DefaultOpen) {
                    engine.ui_slider_float4("projection_view_matrix[0]", transmute(^[4]f32)(&camera.projection_view_matrix[0]), -1, 1, "%.3f", .NoInput)
                    engine.ui_slider_float4("projection_view_matrix[1]", transmute(^[4]f32)(&camera.projection_view_matrix[1]), -1, 1, "%.3f", .NoInput)
                    engine.ui_slider_float4("projection_view_matrix[2]", transmute(^[4]f32)(&camera.projection_view_matrix[2]), -1, 1, "%.3f", .NoInput)
                    engine.ui_slider_float4("projection_view_matrix[3]", transmute(^[4]f32)(&camera.projection_view_matrix[3]), -1, 1, "%.3f", .NoInput)
                }
            }
        }

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

        camera := &_game._engine.renderer.world_camera
        if _game._engine.platform.keys[.A].down {
            camera.position.x -= _game._engine.platform.delta_time / 5
        }
        if _game._engine.platform.keys[.D].down {
            camera.position.x += _game._engine.platform.delta_time / 5
        }
        if _game._engine.platform.keys[.W].down {
            camera.position.y -= _game._engine.platform.delta_time / 5
        }
        if _game._engine.platform.keys[.S].down {
            camera.position.y += _game._engine.platform.delta_time / 5
        }
        if _game._engine.platform.keys[.Q].down {
            camera.rotation += _game._engine.platform.delta_time / 10
        }
        if _game._engine.platform.keys[.E].down {
            camera.rotation -= _game._engine.platform.delta_time / 10
        }
        if _game._engine.platform.mouse_wheel.y != 0 {
            camera.zoom = math.clamp(camera.zoom + f32(_game._engine.platform.mouse_wheel.y) * _game._engine.platform.delta_time / 50, 0.2, 30)
        }

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
    engine.platform_open_window("", { 1920, 1080 }, NATIVE_RESOLUTION)
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
    //       log.debug(">>>>>>>>>>>>>>>>>>>>>");
    // defer log.debug("<<<<<<<<<<<<<<<<<<<<<");
    defer engine.renderer_render_end();

    engine.renderer_clear(VOID_COLOR)

    if engine.renderer_is_enabled() == false {
        log.warn("Renderer disabled")
        return
    }

    if _game._engine.platform.window_resized {
        engine.platform_resize_window()
    }

    engine.renderer_update_camera_matrix()

    // engine.renderer_push_quad({ 0, 0 }, { f32(_game._engine.platform.window_size.x), f32(_game._engine.platform.window_size.y) }, { 0.2, 0.2, 0.2, 1 })

    { engine.profiler_zone("render_entities", PROFILER_COLOR_RENDER);
        if _game.draw_0 {
            for y := 0; y < _game.grid_size; y += 1 {
                for x := 0; x < _game.grid_size; x += 1 {
                    color := engine.Color { 1, 1, 1, 1 }
                    if (y + x) % 2 == 0 {
                        color = { 0, 1, 0, 1 }
                    }
                    engine.renderer_push_quad({ f32(x), f32(y) }, { 1, 1 }, color, _game._engine.renderer.texture_white)
                }
            }
        }

        camera := &_game._engine.renderer.world_camera
        @static iTime: f32 = 0
        iTime += _game._engine.platform.delta_time / 1000
        camera.zoom = math.sin(iTime * 0.4) * 2.0 + 12.0;

        if _game.draw_1 {
            // for y := 0; y < 300; y += 1 {
            //     for x := 0; x < 300; x += 1 {
            //         texture := _game._engine.renderer.texture_1
            //         texture_position := engine.Vector2f32 {
            //             (0.8 / 7) * 0,
            //             (0.8 / 21) * 0,
            //         }
            //         if (x + y) % 2 == 0 {
            //             // texture = _game._engine.renderer.texture_1
            //             texture_position = {
            //                 (1.0 / 7) * 2,
            //                 (1.0 / 21) * 2,
            //             }
            //         }
            //         engine.renderer_push_quad({ f32(x * 10), f32(y * 10) }, { 10, 10 }, { 1, 1, 1, 1 }, texture, texture_position, { 1.0 / 7, 1.0 / 21 })
            //     }
            // }

            @static size0 := engine.Vector2f32 { 32, 32 }
            @static size1 := engine.Vector2f32 { 32, 32 }

            if engine.ui_window("Debug") {
                if engine.ui_tree_node("Frame2", .DefaultOpen) {
                    engine.ui_slider_float2("size0", transmute(^[2]f32)&size0, 0, 200)
                    engine.ui_slider_float2("size1", transmute(^[2]f32)&size1, 0, 200)

                }
            }

            engine.renderer_push_quad({ 200, 200 }, size0, { 1, 1, 1, 1 }, _game._engine.renderer.texture_1, { 0, 0 }, { 1.0, 1.0 })
            engine.renderer_push_quad({ 200 - size1.x, 200,}, size1, { 1, 1, 1, 1 }, _game._engine.renderer.texture_2, { 0, 0 }, { 0.15, 1.0 })
        }

        if _game.draw_2 {
            engine.renderer_push_quad({ 0, 32 * 0 }, { 256, 32 }, { 1, 1, 1, 1 }, _game._engine.renderer.texture_2)
            engine.renderer_push_quad({ 0, 32 * 1 }, { 256, 32 }, { 1, 1, 1, 1 }, _game._engine.renderer.texture_3)
            engine.renderer_push_quad({ 0, 32 * 2 }, { 256, 32 }, { 1, 1, 1, 1 }, _game._engine.renderer.texture_2)
            engine.renderer_push_quad({ 0, 32 * 3 }, { 256, 32 }, { 1, 1, 1, 1 }, _game._engine.renderer.texture_3)
            engine.renderer_push_quad({ 0, 32 * 4 }, { 256, 32 }, { 1, 1, 1, 1 }, _game._engine.renderer.texture_2)
            engine.renderer_push_quad({ 0, 32 * 5 }, { 256, 32 }, { 1, 1, 1, 1 }, _game._engine.renderer.texture_3)
            engine.renderer_push_quad({ 0, 32 * 6 }, { 256, 32 }, { 1, 1, 1, 1 }, _game._engine.renderer.texture_2)
            engine.renderer_push_quad({ 0, 32 * 7 }, { 256, 32 }, { 1, 1, 1, 1 }, _game._engine.renderer.texture_3)
            engine.renderer_push_quad({ 0, 32 * 8 }, { 256, 32 }, { 1, 1, 1, 1 }, _game._engine.renderer.texture_2)
            engine.renderer_push_quad({ 0, 32 * 9 }, { 256, 32 }, { 1, 1, 1, 1 }, _game._engine.renderer.texture_3)
        }
    }
}
