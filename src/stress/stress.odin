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

ENTITY_SIZE             :: 16;
ENTITIES_COUNT          :: 2_000;

Game_Mode_Proc :: #type proc()

Game_State :: struct {
    engine_state:               ^engine.Engine_State,
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
    _game.engine_state = engine.engine_init(game.engine_allocator)
    _game.draw_0 = false
    _game.draw_1 = false
    _game.draw_2 = false
    _game.zoom = 1
    _game.grid_size = int(math.floor(math.sqrt(f32(engine.QUAD_MAX))))

    return game
}

@(export)
game_update :: proc(game: ^Game_State) -> (quit: bool, reload: bool) {
    engine.platform_set_window_title(get_window_title())
    engine.platform_frame()

    if _game.engine_state.platform.window_resized {
        engine.platform_resize_window()
    }

    camera := &_game.engine_state.renderer.world_camera

    if engine.ui_window("Debug") {
        if engine.ui_tree_node("camera: world", .DefaultOpen) {
            camera := &_game.engine_state.renderer.world_camera
            engine.ui_slider_float3("position", transmute(^[3]f32)&camera.position, -100, 100)
            engine.ui_slider_float("rotation", &camera.rotation, 0, math.TAU)
            engine.ui_slider_float("zoom", &camera.zoom, 0.2, 30, "%.3f", .AlwaysClamp)
            if engine.ui_button("Reset zoom") {
                camera.zoom = _game.engine_state.renderer.ideal_scale
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

    {
        // window_size := engine.Vector2i32 { 1920, 1080 }
        // rendering_scale : i32 = 7
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

        if _game.engine_state.platform.keys[.F1].released {
            _game.draw_0 = !_game.draw_0
        }
        if _game.engine_state.platform.keys[.F2].released {
            _game.draw_1 = !_game.draw_1
        }
        if _game.engine_state.platform.keys[.F3].released {
            _game.draw_2 = !_game.draw_2
        }
        if _game.engine_state.platform.keys[.F5].released {
            reload = true
        }
        if _game.engine_state.platform.quit_requested || _game.engine_state.platform.keys[.ESCAPE].released {
            quit = true
        }

        if _game.engine_state.platform.keys[.F10].released {
            _game.engine_state.renderer.refresh_rate = 9999999
        }

        camera := &_game.engine_state.renderer.world_camera
        if _game.engine_state.platform.keys[.A].down {
            camera.position.x -= _game.engine_state.platform.delta_time / 5
        }
        if _game.engine_state.platform.keys[.D].down {
            camera.position.x += _game.engine_state.platform.delta_time / 5
        }
        if _game.engine_state.platform.keys[.W].down {
            camera.position.y -= _game.engine_state.platform.delta_time / 5
        }
        if _game.engine_state.platform.keys[.S].down {
            camera.position.y += _game.engine_state.platform.delta_time / 5
        }
        if _game.engine_state.platform.keys[.Q].down {
            camera.rotation += _game.engine_state.platform.delta_time / 10
        }
        if _game.engine_state.platform.keys[.E].down {
            camera.rotation -= _game.engine_state.platform.delta_time / 10
        }
        if _game.engine_state.platform.mouse_wheel.y != 0 {
            camera.zoom = math.clamp(camera.zoom + f32(_game.engine_state.platform.mouse_wheel.y) * _game.engine_state.platform.delta_time / 50, 0.2, 30)
        }
        if _game.engine_state.platform.keys[.LSHIFT].down {
            @static iTime: f32 = 0
            iTime += _game.engine_state.platform.delta_time / 1000
            camera.zoom = math.sin(iTime * 0.4) * 2.0 + 12.0;
        }
    }

    { engine.profiler_zone("game_render", PROFILER_COLOR_RENDER)

        engine.renderer_clear({ 0.2, 0.2, 0.2, 1 })
        engine.renderer_update_camera_matrix()

        { engine.profiler_zone("render_entities", PROFILER_COLOR_RENDER);

            if _game.draw_0 {
                for y := 0; y < _game.grid_size; y += 1 {
                    for x := 0; x < _game.grid_size; x += 1 {
                        color := engine.Color { 1, 1, 1, 1 }
                        if (y + x) % 2 == 0 {
                            color = { 0, 1, 0, 1 }
                        }
                        engine.renderer_push_quad({ f32(x * 10), f32(y * 10) }, { 1 * 10, 1 * 10 }, color, _game.engine_state.renderer.texture_white)
                    }
                }
            }

            if _game.draw_1 {
                @static size0 := engine.Vector2f32 { 32, 32 }
                @static size1 := engine.Vector2f32 { 32, 32 }

                if engine.ui_window("Debug") {
                    if engine.ui_tree_node("Frame2", .DefaultOpen) {
                        engine.ui_slider_float2("size0", transmute(^[2]f32)&size0, 0, 200)
                        engine.ui_slider_float2("size1", transmute(^[2]f32)&size1, 0, 200)

                    }
                }

                engine.renderer_push_quad({ 200, 200 }, size0, { 1, 1, 1, 1 }, _game.engine_state.renderer.texture_1, { 0, 0 }, { 1.0, 1.0 })
                engine.renderer_push_quad({ 200 - size1.x, 200,}, size1, { 1, 1, 1, 1 }, _game.engine_state.renderer.texture_2, { 0, 0 }, { 0.15, 1.0 })
            }

            if _game.draw_2 {
                engine.renderer_push_quad({ 0, 32 * 0 }, { 256, 32 }, { 1, 1, 1, 1 }, _game.engine_state.renderer.texture_2)
                engine.renderer_push_quad({ 0, 32 * 1 }, { 256, 32 }, { 1, 1, 1, 1 }, _game.engine_state.renderer.texture_3)
                engine.renderer_push_quad({ 0, 32 * 2 }, { 256, 32 }, { 1, 1, 1, 1 }, _game.engine_state.renderer.texture_2)
                engine.renderer_push_quad({ 0, 32 * 3 }, { 256, 32 }, { 1, 1, 1, 1 }, _game.engine_state.renderer.texture_3)
                engine.renderer_push_quad({ 0, 32 * 4 }, { 256, 32 }, { 1, 1, 1, 1 }, _game.engine_state.renderer.texture_2)
                engine.renderer_push_quad({ 0, 32 * 5 }, { 256, 32 }, { 1, 1, 1, 1 }, _game.engine_state.renderer.texture_3)
                engine.renderer_push_quad({ 0, 32 * 6 }, { 256, 32 }, { 1, 1, 1, 1 }, _game.engine_state.renderer.texture_2)
                engine.renderer_push_quad({ 0, 32 * 7 }, { 256, 32 }, { 1, 1, 1, 1 }, _game.engine_state.renderer.texture_3)
                engine.renderer_push_quad({ 0, 32 * 8 }, { 256, 32 }, { 1, 1, 1, 1 }, _game.engine_state.renderer.texture_2)
                engine.renderer_push_quad({ 0, 32 * 9 }, { 256, 32 }, { 1, 1, 1, 1 }, _game.engine_state.renderer.texture_3)
            }
        }
    }

    return
}

@(export)
game_quit :: proc(game: ^Game_State) { }

@(export)
game_reload :: proc(game: ^Game_State) {
    _game = game
    engine.engine_reload(game.engine_state)
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
        engine.RENDERER, f32(_game.engine_state.renderer.refresh_rate),
        f32(_game.engine_state.platform.locked_fps), f32(_game.engine_state.platform.actual_fps), _game.engine_state.renderer.stats)
}
